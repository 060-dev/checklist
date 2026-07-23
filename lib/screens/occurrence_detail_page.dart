import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/inline_audio_recorder.dart';
import 'package:morro_do_peo/components/media_preview.dart';
import 'package:morro_do_peo/components/media_source_sheet.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/models/pending_queue_item.dart';
import 'package:morro_do_peo/models/queued_media_item.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:morro_do_peo/services/private_audio_player.dart';
import 'package:morro_do_peo/services/tts_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/utils/connectivity.dart';
import 'package:morro_do_peo/utils/file_staging.dart';

class OccurrenceDetailPage extends StatefulWidget {
  final String occurrenceId;
  const OccurrenceDetailPage({super.key, required this.occurrenceId});

  @override
  State<OccurrenceDetailPage> createState() => _OccurrenceDetailPageState();
}

class _OccurrenceDetailPageState extends State<OccurrenceDetailPage> {
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  OccurrenceDetail? _detail;

  // Draft evidence being composed before upload.
  XFile? _pickedMedia;
  String? _pickedMediaKind; // 'photo' | 'audio' | 'video'
  bool _recordingAudio = false;

  final _resolutionNotesController = TextEditingController();

  StreamSubscription<PendingQueueItem>? _queueFailureSub;
  String? _pendingResolveItemId;

  @override
  void initState() {
    super.initState();
    _load();
    _queueFailureSub = OfflineQueueService.instance.onItemFailed.listen(
      _onQueueItemFailed,
    );
  }

  @override
  void dispose() {
    PrivateAudioPlayer.instance.stop();
    TtsService.instance.stop();
    _resolutionNotesController.dispose();
    _queueFailureSub?.cancel();
    super.dispose();
  }

  /// Reverts the optimistic "resolved" state if the queued resolve mutation
  /// this page enqueued eventually gives up (max retries / non-retryable
  /// error) instead of ever reaching the server.
  void _onQueueItemFailed(PendingQueueItem item) {
    if (item.id != _pendingResolveItemId) return;
    _pendingResolveItemId = null;
    if (!mounted) return;
    final d = _detail;
    if (d == null) return;
    final reverted = Map<String, dynamic>.from(d.raw);
    reverted['status'] = 'open';
    reverted.remove('resolved_at');
    setState(() {
      _detail = OccurrenceDetail(reverted);
      _error = 'Não foi possível resolver a ocorrência. Tente novamente.';
    });
  }

  PrivateAudioRef? _narrationRef(OccurrenceDetail d) {
    final raw = d.raw['narration_audio'];
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final sha = (map['sha256'] as String?) ?? '';
    final url = (map['url'] as String?) ?? '';
    if (sha.trim().isEmpty || url.trim().isEmpty) return null;
    return PrivateAudioRef(sha256: sha.trim(), url: url.trim());
  }

  Future<void> _playNarration() async {
    final d = _detail;
    if (d == null) return;

    final ref = _narrationRef(d);
    if (ref == null) {
      setState(() => _error = 'Áudio não disponível.');
      return;
    }

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() => _error = 'Sem acesso configurado.');
      return;
    }

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    try {
      final ok = await PrivateAudioPlayer.instance.play(
        client: client,
        origin: session.origin,
        ref: ref,
      );
      if (!ok && mounted) {
        setState(
          () => _error = 'Não foi possível baixar o áudio. Tente novamente.',
        );
      }
    } finally {
      client.dispose();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sem configuração da API ou funcionário não selecionado.';
      });
      return;
    }

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      final d = await api.getOccurrenceDetail(
        employeeId: employeeId,
        occurrenceId: widget.occurrenceId,
      );
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar ocorrência.';
        _loading = false;
      });
    } finally {
      client.dispose();
    }
  }

  Future<void> _pickPhotoDraft() async {
    final source = await showMediaSourceSheet(
      context,
      title: 'Anexar Foto à Ocorrência',
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null) return;
      setState(() {
        _pickedMedia = file;
        _pickedMediaKind = 'photo';
        _recordingAudio = false;
      });
    } catch (e) {
      debugPrint('Pick image failed: $e');
    }
  }

  Future<void> _pickVideoDraft() async {
    final source = await showMediaSourceSheet(
      context,
      title: 'Anexar Vídeo à Ocorrência',
      isVideo: true,
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickVideo(source: source);
      if (file == null) return;
      setState(() {
        _pickedMedia = file;
        _pickedMediaKind = 'video';
        _recordingAudio = false;
      });
    } catch (e) {
      debugPrint('Pick video failed: $e');
    }
  }

  void _startAudioDraft() {
    setState(() {
      _pickedMedia = null;
      _pickedMediaKind = 'audio';
      _recordingAudio = true;
    });
  }

  void _cancelDraft() {
    setState(() {
      _pickedMedia = null;
      _pickedMediaKind = null;
      _recordingAudio = false;
    });
  }

  Future<void> _attach() async {
    if (_mutating) return;
    final file = _pickedMedia;
    final kind = _pickedMediaKind;
    if (file == null || kind == null) {
      setState(() => _error = 'Selecione uma foto, áudio ou vídeo primeiro.');
      return;
    }

    setState(() {
      _mutating = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() {
        _mutating = false;
        _error = 'Sem configuração da API ou funcionário não selecionado.';
      });
      return;
    }

    var networkFailure = !Connectivity.instance.isOnline;
    if (!networkFailure) {
      final client = MobileApiClient(
        apiBaseUrl: session.apiBaseUrl.trim(),
        apiKey: session.apiKey.trim(),
        requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
        uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
      );
      final api = MobileApiServices(client: client);
      try {
        final mp = await _multipartFromXFile('file', file, kind);
        if (mp == null) {
          setState(() => _error = 'Falha ao ler o arquivo selecionado.');
        } else {
          await api.attachOccurrenceFile(
            employeeId: employeeId,
            occurrenceId: widget.occurrenceId,
            idempotencyKey: const Uuid().v4(),
            file: mp,
          );
          setState(() {
            _pickedMedia = null;
            _pickedMediaKind = null;
            _recordingAudio = false;
          });
          await _load();
        }
      } on SocketException {
        networkFailure = true;
      } on TimeoutException {
        networkFailure = true;
      } on MobileApiException catch (e) {
        setState(() => _error = e.message);
      } catch (e) {
        debugPrint('Attach failed: $e');
        setState(() => _error = 'Falha ao anexar.');
      } finally {
        client.dispose();
      }
    }

    if (!networkFailure) {
      if (mounted) setState(() => _mutating = false);
      return;
    }

    // Offline, or a transient network error above — stage the file and let
    // the queue send it once connectivity returns.
    final stagedPath = await stageFileForQueue(file.path);
    await OfflineQueueService.instance.enqueueApiMutation(
      method: 'POST',
      path:
          '/employees/$employeeId/occurrences/${widget.occurrenceId}/attachments',
      jsonBody: const {},
      mediaItems: [QueuedMediaItem(stagedPath: stagedPath, fieldName: 'file')],
    );
    if (!mounted) return;
    setState(() {
      _pickedMedia = null;
      _pickedMediaKind = null;
      _recordingAudio = false;
      _mutating = false;
    });
  }

  /// Guesses a MIME type from the draft's kind + file extension, since
  /// `image_picker`/the audio recorder don't reliably expose one, and the
  /// backend has no separate "kind" field — it stores whatever
  /// Content-Type is sent (see `MobileOccurrenceAttachment.content_type`).
  String _guessContentType(String kind, String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (kind) {
      'photo' => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      },
      'audio' => switch (ext) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'aac' => 'audio/aac',
        _ => 'audio/mp4',
      },
      'video' => switch (ext) {
        'mov' => 'video/quicktime',
        _ => 'video/mp4',
      },
      _ => 'application/octet-stream',
    };
  }

  Future<http.MultipartFile?> _multipartFromXFile(
    String fieldName,
    XFile file,
    String kind,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
        contentType: MediaType.parse(_guessContentType(kind, file.name)),
      );
    } catch (e) {
      debugPrint('Failed to build multipart file ($fieldName): $e');
      return null;
    }
  }

  Future<void> _playAttachmentAudio(PrivateAudioRef ref) async {
    final session = context.read<AppSession>();
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    try {
      final ok = await PrivateAudioPlayer.instance.play(
        client: client,
        origin: session.origin,
        ref: ref,
      );
      if (!ok && mounted) {
        setState(() => _error = 'Não foi possível reproduzir o áudio.');
      }
    } finally {
      client.dispose();
    }
  }

  Future<bool> _showResolveConfirmation() async {
    _resolutionNotesController.clear();
    const prompt =
        'Você tem certeza que deseja marcar essa ocorrência como resolvida?';
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Resolução'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(prompt, style: theme.textTheme.bodyMedium),
                ),
                IconButton(
                  onPressed: () => TtsService.instance.speak(prompt),
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Ouvir',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _resolutionNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observação da solução (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => context.pop(true),
            child: const Text('Sim, Resolver'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _resolve() async {
    if (_mutating) return;
    final d = _detail;
    if (d == null) return;

    final confirmed = await _showResolveConfirmation();
    if (!confirmed || !mounted) return;

    setState(() {
      _mutating = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() {
        _mutating = false;
        _error = 'Sem configuração da API ou funcionário não selecionado.';
      });
      return;
    }

    final notes = _resolutionNotesController.text;
    var networkFailure = !Connectivity.instance.isOnline;
    if (!networkFailure) {
      final client = MobileApiClient(
        apiBaseUrl: session.apiBaseUrl.trim(),
        apiKey: session.apiKey.trim(),
        requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
        uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
      );
      final api = MobileApiServices(client: client);
      try {
        final updated = await api.resolveOccurrence(
          employeeId: employeeId,
          occurrenceId: widget.occurrenceId,
          idempotencyKey: const Uuid().v4(),
          currentDetail: d,
          resolutionNotes: notes,
        );
        // Optimistic update from the PATCH response, then reload so the
        // authoritative server state wins if it differs.
        setState(() => _detail = updated);
        await _load();
      } on SocketException {
        networkFailure = true;
      } on TimeoutException {
        networkFailure = true;
      } on MobileApiException catch (e) {
        setState(() => _error = e.message);
      } catch (e) {
        debugPrint('Resolve occurrence failed: $e');
        setState(() => _error = 'Falha ao resolver ocorrência.');
      } finally {
        client.dispose();
      }
    }

    if (!networkFailure) {
      if (mounted) setState(() => _mutating = false);
      return;
    }

    // Offline, or a transient network error above — queue it with an
    // optimistic local update; `_onQueueItemFailed` reverts this if the
    // queued send later gives up for good.
    final enqueued = await OfflineQueueService.instance.enqueueApiMutation(
      method: 'PATCH',
      path: MobileApiServices.resolveOccurrencePath(
        employeeId: employeeId,
        occurrenceId: widget.occurrenceId,
      ),
      jsonBody: MobileApiServices.resolveOccurrencePayload(
        currentDetail: d,
        resolutionNotes: notes,
      ),
    );
    _pendingResolveItemId = enqueued.id;

    final optimistic = Map<String, dynamic>.from(d.raw);
    optimistic['status'] = 'resolved';
    optimistic['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    final trimmedNotes = notes.trim();
    if (trimmedNotes.isNotEmpty) optimistic['resolution_notes'] = trimmedNotes;

    if (!mounted) return;
    setState(() {
      _detail = OccurrenceDetail(optimistic);
      _mutating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _detail;
    final session = context.watch<AppSession>();
    final authHeaders = {'Authorization': 'Bearer ${session.apiKey}'};

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(d == null ? 'Ocorrência' : d.title),
        actions: [
          if (d != null && _narrationRef(d) != null)
            IconButton(
              onPressed: _playNarration,
              icon: Icon(
                Icons.volume_up_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Ouvir ocorrência',
            ),
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 860,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    if ((_error ?? '').trim().isNotEmpty) ...[
                      ErrorBanner(message: _error!, onRetry: _load),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (d != null) ...[
                      _OccurrenceHeader(detail: d),
                      const SizedBox(height: AppSpacing.lg),
                      if (d.status == 'resolved')
                        _ResolvedStatusCard(detail: d)
                      else
                        SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _mutating ? null : _resolve,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Resolver Ocorrência',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      'Adicionar evidência',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mutating ? null : _pickPhotoDraft,
                            icon: Icon(
                              Icons.camera_alt,
                              color: theme.colorScheme.primary,
                            ),
                            label: const Text('Foto'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mutating ? null : _startAudioDraft,
                            icon: Icon(
                              Icons.mic,
                              color: theme.colorScheme.primary,
                            ),
                            label: const Text('Áudio'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mutating ? null : _pickVideoDraft,
                            icon: Icon(
                              Icons.videocam,
                              color: theme.colorScheme.primary,
                            ),
                            label: const Text('Vídeo'),
                          ),
                        ),
                      ],
                    ),
                    if (_pickedMediaKind != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      if (_pickedMediaKind == 'photo' && _pickedMedia != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            File(_pickedMedia!.path),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_pickedMediaKind == 'video' &&
                          _pickedMedia != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.videocam,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _pickedMedia!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_recordingAudio)
                        InlineAudioRecorder(
                          value: _pickedMedia,
                          onChanged: (f) => setState(() => _pickedMedia = f),
                          idleLabel: 'Gravar áudio',
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: (_mutating || _pickedMedia == null)
                                  ? null
                                  : _attach,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                              ),
                              icon: _mutating
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.upload,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                              label: Text(
                                'Enviar anexo',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          TextButton.icon(
                            onPressed: _mutating ? null : _cancelDraft,
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.error,
                            ),
                            label: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (d != null && d.attachments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Anexos',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _UploadedAttachments(
                        attachments: d.attachments
                            .map(MobileEvidenceRef.fromJson)
                            .toList(),
                        origin: session.origin,
                        authHeaders: authHeaders,
                        onPlayAudio: _playAttachmentAudio,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UploadedAttachments extends StatelessWidget {
  final List<MobileEvidenceRef> attachments;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _UploadedAttachments({
    required this.attachments,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = attachments.where((a) => a.kind == 'photo').toList();
    final audios = attachments.where((a) => a.kind == 'audio').toList();
    final videos = attachments.where((a) => a.kind == 'video').toList();
    final others = attachments
        .where(
          (a) => a.kind != 'photo' && a.kind != 'audio' && a.kind != 'video',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in photos)
                _AttachmentThumb(
                  url: absoluteMediaUrl(origin: origin, url: a.url),
                  authHeaders: authHeaders,
                ),
            ],
          ),
        for (final a in audios) ...[
          if (photos.isNotEmpty || audios.first != a)
            const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                onPlayAudio(PrivateAudioRef(sha256: a.sha256, url: a.url)),
            icon: Icon(Icons.play_circle, color: theme.colorScheme.primary),
            label: Text(
              'Reproduzir áudio',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        for (final a in videos) ...[
          if (photos.isNotEmpty || audios.isNotEmpty || videos.first != a)
            const SizedBox(height: AppSpacing.sm),
          EvidenceVideoPlayer(
            url: absoluteMediaUrl(origin: origin, url: a.url),
            headers: authHeaders,
          ),
        ],
        for (final a in others) ...[
          if (photos.isNotEmpty ||
              audios.isNotEmpty ||
              videos.isNotEmpty ||
              others.first != a)
            const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(a.originalName, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OccurrenceHeader extends StatelessWidget {
  final OccurrenceDetail detail;
  const _OccurrenceHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdText = detail.createdAt == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm').format(detail.createdAt!.toLocal());
    final dueText = detail.dueAt == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm').format(detail.dueAt!.toLocal());
    final location = (detail.location ?? '').trim();
    final description = (detail.description ?? '').trim();
    final priority = (detail.priority ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusBadge(status: detail.status),
            if (priority.isNotEmpty) _PriorityBadge(priority: priority),
            if (location.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
        if (createdText != null || dueText != null) ...[
          const SizedBox(height: AppSpacing.md),
          if (createdText != null)
            Text(
              'Criado em: $createdText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (dueText != null) ...[
            const SizedBox(height: 4),
            Text(
              'Prazo: $dueText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ResolvedStatusCard extends StatelessWidget {
  final OccurrenceDetail detail;
  const _ResolvedStatusCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedText = detail.resolvedAt == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm').format(detail.resolvedAt!.toLocal());
    final notes = (detail.resolutionNotes ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ocorrência Resolvida',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
                if (resolvedText != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Resolvida em: $resolvedText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    notes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg, String label) = switch (status) {
      'open' => (AppColors.primaryRedLight, AppColors.white, 'Aberto'),
      'in_progress' => (
        AppColors.warningLight,
        AppColors.warning,
        'Em andamento',
      ),
      'resolved' => (AppColors.successLight, AppColors.success, 'Resolvido'),
      'cancelled' => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'Cancelado',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        status,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg, String label) = switch (priority) {
      'urgent' => (AppColors.primaryRedLight, Colors.white, 'Urgente'),
      'high' => (AppColors.warningLight, AppColors.warning, 'Alta'),
      'low' => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'Baixa',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'Normal',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  final String url;
  final Map<String, String> authHeaders;
  const _AttachmentThumb({required this.url, required this.authHeaders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => showFullscreenImage(context, url: url, headers: authHeaders),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Image.network(
          url,
          headers: authHeaders,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
          errorBuilder: (context, error, stack) => Container(
            width: 96,
            height: 96,
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
