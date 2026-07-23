import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/inline_audio_recorder.dart';
import 'package:morro_do_peo/components/media_preview.dart';
import 'package:morro_do_peo/components/media_source_sheet.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/services/private_audio_player.dart';
import 'package:morro_do_peo/services/tts_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ExecutionDetailPage extends StatefulWidget {
  final String executionId;
  const ExecutionDetailPage({super.key, required this.executionId});

  @override
  State<ExecutionDetailPage> createState() => _ExecutionDetailPageState();
}

class _ExecutionDetailPageState extends State<ExecutionDetailPage> {
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  ExecutionDetail? _detail;
  bool _fromCache = false;

  // Simple checklist state.
  bool? _simpleBoolean;
  final TextEditingController _notesController = TextEditingController();
  XFile? _simplePhoto;
  XFile? _simpleAudio;
  XFile? _simpleVideo;

  // Structured checklist state.
  final Map<String, _QuestionAnswerState> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Ensure we never leave audio playing when navigating away.
    PrivateAudioPlayer.instance.stop();
    TtsService.instance.stop();
    _notesController.dispose();
    super.dispose();
  }

  PrivateAudioRef? _narrationRef(ExecutionDetail d) {
    final raw = d.raw['narration_audio'];
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final sha = (map['sha256'] as String?) ?? '';
    final url = (map['url'] as String?) ?? '';
    if (sha.trim().isEmpty || url.trim().isEmpty) return null;
    return PrivateAudioRef(sha256: sha.trim(), url: url.trim());
  }

  Future<void> _playAudioRef(PrivateAudioRef ref) async {
    await TtsService.instance.stop();
    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      if (mounted) setState(() => _error = 'Sem acesso configurado.');
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
        setState(() => _error = 'Não foi possível reproduzir o áudio.');
      }
    } finally {
      client.dispose();
    }
  }

  Future<void> _speakQuestion(String text) async {
    // If the backend didn't provide a narration file for this question, we still
    // guarantee an "ouvir" action using TTS.
    await PrivateAudioPlayer.instance.stop();
    await TtsService.instance.speak(text);
  }

  Future<void> _playNarration() async {
    final d = _detail;
    if (d == null) return;

    final ref = _narrationRef(d);
    if (ref == null) {
      setState(() => _error = 'Áudio não disponível.');
      return;
    }

    await _playAudioRef(ref);
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
      final detail = await api.getExecutionDetail(
        employeeId: employeeId,
        executionId: widget.executionId,
      );
      unawaited(
        LocalCacheService.instance.saveExecutionDetail(
          employeeId,
          widget.executionId,
          detail.raw,
        ),
      );
      setState(() {
        _detail = detail;
        _fromCache = false;
        _bootstrapForm(detail);
        _loading = false;
      });
    } on MobileApiException catch (e) {
      await _fallBackToCache(employeeId, e.message);
    } catch (e) {
      await _fallBackToCache(employeeId, 'Falha ao carregar execução.');
    } finally {
      client.dispose();
    }
  }

  Future<void> _fallBackToCache(String employeeId, String errorMessage) async {
    final cached = await LocalCacheService.instance.getExecutionDetail(
      employeeId,
      widget.executionId,
    );
    if (cached == null) {
      setState(() {
        _error = errorMessage;
        _fromCache = false;
        _loading = false;
      });
      return;
    }
    final (_, raw) = cached;
    final detail = ExecutionDetail(raw);
    setState(() {
      _detail = detail;
      _fromCache = true;
      _error = null;
      _bootstrapForm(detail);
      _loading = false;
    });
  }

  void _bootstrapForm(ExecutionDetail d) {
    final req = (d.raw['requirements'] is Map)
        ? (d.raw['requirements'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final requiresBoolean = req['boolean'] == true;

    if (d.isSimpleBoolean) {
      _simpleBoolean = requiresBoolean ? true : null;
      _notesController.text = (d.raw['notes'] as String?) ?? '';
      _simplePhoto = null;
      _simpleAudio = null;
      _answers.clear();
      return;
    }

    _simpleBoolean = null;
    _notesController.text = (d.raw['notes'] as String?) ?? '';
    _simplePhoto = null;
    _simpleAudio = null;
    _answers.clear();

    final questions = _questionsFrom(d);
    for (final q in questions) {
      _answers[q.id] = _QuestionAnswerState(questionId: q.id);
    }
  }

  // Future<void> _start() => _mutate(
  //   (api, employeeId, key) => api.markExecutionStarted(
  //     employeeId: employeeId,
  //     executionId: widget.executionId,
  //     idempotencyKey: key,
  //   ),
  // );

  Future<void> _complete() async {
    final d = _detail;
    if (d == null) return;

    final payload = _buildCompletionPayload(d);
    if (payload == null) return;

    final evidence = await _buildEvidenceParts(d);
    if (evidence == null) return;

    // Prefer the evidence endpoint (production path). If the backend rejects a
    // request without multipart files, fall back to JSON completion.
    await _mutate((api, employeeId, key) async {
      try {
        await api.completeExecutionWithEvidence(
          employeeId: employeeId,
          executionId: widget.executionId,
          idempotencyKey: key,
          payload: payload,
          photo: evidence.photo,
          audio: evidence.audio,
          photos: evidence.photos,
          photoQuestionIds: evidence.photoQuestionIds,
          audios: evidence.audios,
          audioQuestionIds: evidence.audioQuestionIds,
          videos: evidence.videos,
          videoQuestionIds: evidence.videoQuestionIds,
        );
      } on MobileApiException {
        await api.completeExecutionJson(
          employeeId: employeeId,
          executionId: widget.executionId,
          idempotencyKey: key,
          payload: payload,
        );
      }
    });

    // If completion succeeded, go back to the list so it can refresh.
    if (!mounted) return;
    if ((_error ?? '').trim().isEmpty &&
        (_detail?.status ?? '') == 'completed') {
      context.pop(true);
    }
  }

  Map<String, dynamic>? _buildCompletionPayload(ExecutionDetail d) {
    setState(() => _error = null);

    final req = (d.raw['requirements'] is Map)
        ? (d.raw['requirements'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final requiresBoolean = req['boolean'] == true;
    final notes = _notesController.text.trim();

    if (d.isSimpleBoolean) {
      if (requiresBoolean && _simpleBoolean == null) {
        setState(() => _error = 'Responda Sim/Não para concluir.');
        return null;
      }
      return {
        'boolean_answer': _simpleBoolean,
        'answers': null,
        'notes': notes.isEmpty ? null : notes,
      };
    }

    final questions = _visibleQuestions(d);
    final answersPayload = <String, dynamic>{};
    for (final q in questions) {
      final st = _answers[q.id];
      if (st == null) continue;

      if (q.required && (st.answer ?? '').trim().isEmpty) {
        setState(() => _error = 'Responda: ${q.text}');
        return null;
      }

      // Additional field required?
      if (q.additionalRequiredWhenAnswer != null &&
          st.answer == q.additionalRequiredWhenAnswer) {
        final hasText = (st.additionalText ?? '').trim().isNotEmpty;
        final hasAudio = st.additionalAudio != null;
        if (!hasText && !hasAudio) {
          setState(
            () => _error =
                'Preencha o campo adicional: ${q.additionalLabel ?? 'Observação'}',
          );
          return null;
        }
      }

      // Photo required?
      if (q.photoRequiredWhenAnswer != null &&
          st.answer == q.photoRequiredWhenAnswer) {
        if (st.photo == null) {
          setState(
            () => _error = 'Envie a foto solicitada: ${q.photoLabel ?? q.text}',
          );
          return null;
        }
      }

      // Modern evidenceRequests (photo/audio/video) validation.
      if (q.evidenceRequired('photo', st.answer) && st.photo == null) {
        setState(
          () => _error =
              'Envie a foto solicitada: ${q.evidenceRequestFor('photo')?.label ?? q.text}',
        );
        return null;
      }
      if (q.evidenceRequired('audio', st.answer) &&
          st.additionalAudio == null) {
        setState(
          () => _error =
              'Envie o áudio solicitado: ${q.evidenceRequestFor('audio')?.label ?? q.text}',
        );
        return null;
      }
      if (q.evidenceRequired('video', st.answer) && st.video == null) {
        setState(
          () => _error =
              'Envie o vídeo solicitado: ${q.evidenceRequestFor('video')?.label ?? q.text}',
        );
        return null;
      }

      // Level required?
      if (q.levelRequired && (st.levelValue == null)) {
        setState(() => _error = 'Selecione o nível: ${q.levelLabel ?? q.text}');
        return null;
      }
      if (q.levelRequiredWhenAnswer != null &&
          st.answer == q.levelRequiredWhenAnswer &&
          st.levelValue == null) {
        setState(() => _error = 'Selecione o nível: ${q.levelLabel ?? q.text}');
        return null;
      }

      if ((st.answer ?? '').trim().isEmpty) continue;
      final answerMap = <String, dynamic>{
        'answer': st.answer,
        'additional_text': (st.additionalText ?? '').trim().isEmpty
            ? null
            : st.additionalText!.trim(),
      };

      // Only include `level` when the user selected one.
      // Some backend validators treat the presence of the key (even null) as
      // "level provided", which fails for questions that don't request it.
      if (st.levelValue != null) answerMap['level'] = st.levelValue;
      answersPayload[q.id] = answerMap;
    }

    return {
      'boolean_answer': null,
      'answers': answersPayload,
      'notes': notes.isEmpty ? null : notes,
    };
  }

  Future<_EvidenceParts?> _buildEvidenceParts(ExecutionDetail d) async {
    setState(() => _error = null);

    final req = (d.raw['requirements'] is Map)
        ? (d.raw['requirements'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final requiresPhoto = req['photo'] == true;
    final requiresAudio = req['audio'] == true;
    final requiresVideo = req['video'] == true;

    http.MultipartFile? photo;
    http.MultipartFile? audio;
    final photos = <http.MultipartFile>[];
    final photoQuestionIds = <String>[];
    final audios = <http.MultipartFile>[];
    final audioQuestionIds = <String>[];
    final videos = <http.MultipartFile>[];
    final videoQuestionIds = <String>[];

    try {
      if (d.isSimpleBoolean) {
        if (requiresPhoto && _simplePhoto == null) {
          setState(() => _error = 'Envie a foto para concluir.');
          return null;
        }
        if (requiresAudio && _simpleAudio == null) {
          setState(() => _error = 'Envie o áudio para concluir.');
          return null;
        }
        if (requiresVideo && _simpleVideo == null) {
          setState(() => _error = 'Envie o vídeo para concluir.');
          return null;
        }

        if (_simplePhoto != null) {
          photo = await _multipartFromXFile('photo', _simplePhoto!);
          if (photo == null) {
            setState(() => _error = 'Falha ao ler a foto selecionada.');
            return null;
          }
        }
        if (_simpleAudio != null) {
          audio = await _multipartFromXFile('audio', _simpleAudio!);
          if (audio == null) {
            setState(() => _error = 'Falha ao ler o áudio selecionado.');
            return null;
          }
        }
        if (_simpleVideo != null) {
          final mp = await _multipartFromXFile('videos', _simpleVideo!);
          if (mp == null) {
            setState(() => _error = 'Falha ao ler o vídeo selecionado.');
            return null;
          }
          videos.add(mp);
          videoQuestionIds.add('');
        }

        return _EvidenceParts(
          photo: photo,
          audio: audio,
          photos: photos,
          photoQuestionIds: photoQuestionIds,
          audios: audios,
          audioQuestionIds: audioQuestionIds,
          videos: videos,
          videoQuestionIds: videoQuestionIds,
        );
      }

      final questions = _visibleQuestions(d);
      for (final q in questions) {
        final st = _answers[q.id];
        if (st == null) continue;

        if (st.photo != null) {
          final mp = await _multipartFromXFile('photos', st.photo!);
          if (mp != null) {
            photos.add(mp);
            photoQuestionIds.add(q.id);
          } else {
            setState(() => _error = 'Falha ao ler a foto selecionada.');
            return null;
          }
        }
        if (st.additionalAudio != null) {
          final mp = await _multipartFromXFile('audios', st.additionalAudio!);
          if (mp != null) {
            audios.add(mp);
            audioQuestionIds.add(q.id);
          } else {
            setState(() => _error = 'Falha ao ler o áudio selecionado.');
            return null;
          }
        }
        if (st.video != null) {
          final mp = await _multipartFromXFile('videos', st.video!);
          if (mp != null) {
            videos.add(mp);
            videoQuestionIds.add(q.id);
          } else {
            setState(() => _error = 'Falha ao ler o vídeo selecionado.');
            return null;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to build evidence parts: $e');
      setState(() => _error = 'Falha ao preparar arquivos.');
      return null;
    }

    return _EvidenceParts(
      photo: photo,
      audio: audio,
      photos: photos,
      photoQuestionIds: photoQuestionIds,
      audios: audios,
      audioQuestionIds: audioQuestionIds,
      videos: videos,
      videoQuestionIds: videoQuestionIds,
    );
  }

  Future<http.MultipartFile?> _multipartFromXFile(
    String fieldName,
    XFile file,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('Selected file has zero length: ${file.name}');
        return null;
      }
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
      );
    } catch (e) {
      debugPrint('Failed to build multipart file ($fieldName): $e');
      return null;
    }
  }

  Future<void> _mutate(
    Future<void> Function(
      MobileApiServices api,
      String employeeId,
      String idempotencyKey,
    )
    fn,
  ) async {
    if (_mutating) return;
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

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      final key = const Uuid().v4();
      await fn(api, employeeId, key);
      await _load();
    } on MobileApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Falha na operação.');
      debugPrint('Mutation error: $e');
    } finally {
      client.dispose();
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _detail;

    final status = d?.status ?? '';
    // final canStart = status == 'pending' || status == 'overdue';
    final canComplete =
        status == 'in_progress' || status == 'pending' || status == 'overdue';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(d == null ? 'Checklist' : d.title),
        actions: [
          if (d != null && _narrationRef(d) != null)
            IconButton(
              onPressed: _playNarration,
              icon: Icon(
                Icons.volume_up_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Ouvir checklist',
            ),
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          ),
        ],
      ),
      bottomNavigationBar: (d == null || d.status == 'completed')
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // if (canStart) ...[
                    //   Expanded(
                    //     child: FilledButton.icon(
                    //       onPressed: _mutating ? null : _start,
                    //       icon: Icon(
                    //         Icons.play_arrow,
                    //         color: theme.colorScheme.onPrimary,
                    //       ),
                    //       label: Text(
                    //         'Iniciar',
                    //         style: theme.textTheme.titleSmall?.copyWith(
                    //           fontWeight: FontWeight.w900,
                    //           color: theme.colorScheme.onPrimary,
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    //   const SizedBox(width: AppSpacing.md),
                    // ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (!canComplete || _mutating)
                            ? null
                            : _complete,
                        icon: Icon(
                          Icons.check,
                          color: theme.colorScheme.onPrimary,
                        ),
                        label: Text(
                          'Concluir',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 860,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((_error ?? '').trim().isNotEmpty) ...[
                      ErrorBanner(message: _error!, onRetry: _load),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_fromCache) ...[
                      const OfflineIndicator(pendingCount: 0),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (d != null) ...[
                      if ((d.location ?? '').trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  d.location!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Expanded(
                      child: d == null
                          ? const SizedBox.shrink()
                          : (d.status == 'completed'
                                ? _CompletedExecutionView(
                                    detail: d,
                                    questions: _questionsFrom(d),
                                    origin: context.read<AppSession>().origin,
                                    authHeaders: {
                                      'Authorization':
                                          'Bearer ${context.read<AppSession>().apiKey}',
                                    },
                                    onPlayAudio: _playAudioRef,
                                  )
                                : _ExecutionForm(
                                    detail: d,
                                    notesController: _notesController,
                                    onPlayQuestionNarration: _playAudioRef,
                                    onSpeakQuestion: (text) =>
                                        _speakQuestion(text),
                                    simpleBoolean: _simpleBoolean,
                                    onSimpleBooleanChanged: (v) =>
                                        setState(() => _simpleBoolean = v),
                                    simplePhoto: _simplePhoto,
                                    onPickSimplePhoto: _mutating
                                        ? null
                                        : () async {
                                            final file = await _pickImage();
                                            if (file == null) return;
                                            setState(() => _simplePhoto = file);
                                          },
                                    simpleAudio: _simpleAudio,
                                    onSimpleAudioChanged: _mutating
                                        ? null
                                        : (file) => setState(
                                            () => _simpleAudio = file,
                                          ),
                                    simpleVideo: _simpleVideo,
                                    onPickSimpleVideo: _mutating
                                        ? null
                                        : () async {
                                            final file = await _pickVideo();
                                            if (file == null) return;
                                            setState(() => _simpleVideo = file);
                                          },
                                    answers: _answers,
                                    onPickQuestionPhoto: _mutating
                                        ? null
                                        : (questionId) async {
                                            final file = await _pickImage();
                                            if (file == null) return;
                                            setState(
                                              () => _answers[questionId] =
                                                  (_answers[questionId] ??
                                                          _QuestionAnswerState(
                                                            questionId:
                                                                questionId,
                                                          ))
                                                      .copyWith(photo: file),
                                            );
                                          },
                                    onQuestionAudioChanged: _mutating
                                        ? null
                                        : (questionId, file) {
                                            setState(
                                              () => _answers[questionId] =
                                                  (_answers[questionId] ??
                                                          _QuestionAnswerState(
                                                            questionId:
                                                                questionId,
                                                          ))
                                                      .copyWith(
                                                        additionalAudio: file,
                                                      ),
                                            );
                                          },
                                    onPickQuestionVideo: _mutating
                                        ? null
                                        : (questionId) async {
                                            final file = await _pickVideo();
                                            if (file == null) return;
                                            setState(
                                              () => _answers[questionId] =
                                                  (_answers[questionId] ??
                                                          _QuestionAnswerState(
                                                            questionId:
                                                                questionId,
                                                          ))
                                                      .copyWith(video: file),
                                            );
                                          },
                                    onAnswerChanged: (questionId, next) =>
                                        setState(
                                          () => _answers[questionId] = next,
                                        ),
                                  )),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<XFile?> _pickImage() async {
    final source = await showMediaSourceSheet(context, title: 'Enviar Foto');
    if (source == null) return null;
    try {
      return await ImagePicker().pickImage(source: source);
    } catch (e) {
      debugPrint('Pick image failed: $e');
      return null;
    }
  }

  Future<XFile?> _pickVideo() async {
    final source = await showMediaSourceSheet(
      context,
      title: 'Enviar Vídeo',
      isVideo: true,
    );
    if (source == null) return null;
    try {
      return await ImagePicker().pickVideo(source: source);
    } catch (e) {
      debugPrint('Pick video failed: $e');
      return null;
    }
  }

  List<_ApiQuestion> _questionsFrom(ExecutionDetail d) {
    final raw = d.raw['questions'];
    if (raw is! List) return const [];
    final out = <_ApiQuestion>[];
    for (final it in raw) {
      // Avoid duplicating items (Map<String, dynamic> is also a Map).
      if (it is Map<String, dynamic>) {
        out.add(_ApiQuestion.fromJson(it));
      } else if (it is Map) {
        out.add(_ApiQuestion.fromJson(it.cast<String, dynamic>()));
      }
    }
    return out;
  }

  List<_ApiQuestion> _visibleQuestions(ExecutionDetail d) {
    final all = _questionsFrom(d);
    return all.where((q) => _isQuestionVisible(q)).toList();
  }

  bool _isQuestionVisible(_ApiQuestion q) {
    bool condOne(_DisplayCond c) =>
        (_answers[c.questionId]?.answer ?? '') == c.answer;

    final hasDisplayWhen = q.displayWhen != null;
    final hasAny = q.displayWhenAny.isNotEmpty;
    if (!hasDisplayWhen && !hasAny) return true;

    final oneOk = !hasDisplayWhen || condOne(q.displayWhen!);
    final anyOk = !hasAny || q.displayWhenAny.any(condOne);
    return oneOk && anyOk;
  }
}

@immutable
class _EvidenceParts {
  final http.MultipartFile? photo;
  final http.MultipartFile? audio;
  final List<http.MultipartFile> photos;
  final List<String> photoQuestionIds;
  final List<http.MultipartFile> audios;
  final List<String> audioQuestionIds;
  final List<http.MultipartFile> videos;
  final List<String> videoQuestionIds;

  const _EvidenceParts({
    required this.photo,
    required this.audio,
    required this.photos,
    required this.photoQuestionIds,
    required this.audios,
    required this.audioQuestionIds,
    required this.videos,
    required this.videoQuestionIds,
  });
}

@immutable
class _QuestionAnswerState {
  final String questionId;
  final String? answer;
  final String? additionalText;
  final Object? levelValue;
  final XFile? photo;
  final XFile? additionalAudio;
  final XFile? video;

  const _QuestionAnswerState({
    required this.questionId,
    this.answer,
    this.additionalText,
    this.levelValue,
    this.photo,
    this.additionalAudio,
    this.video,
  });

  /// Use [_absent] as the default for nullable XFile/String fields so that
  /// passing `null` explicitly clears the value (workaround for Dart's lack
  /// of a built-in absent/present distinction in copyWith patterns).
  static const Object _absent = Object();

  _QuestionAnswerState copyWith({
    String? answer,
    String? additionalText,
    Object? levelValue,
    Object? photo = _absent,
    Object? additionalAudio = _absent,
    Object? video = _absent,
  }) => _QuestionAnswerState(
    questionId: questionId,
    answer: answer ?? this.answer,
    additionalText: additionalText ?? this.additionalText,
    levelValue: levelValue ?? this.levelValue,
    photo: identical(photo, _absent) ? this.photo : photo as XFile?,
    additionalAudio: identical(additionalAudio, _absent)
        ? this.additionalAudio
        : additionalAudio as XFile?,
    video: identical(video, _absent) ? this.video : video as XFile?,
  );
}

@immutable
class _DisplayCond {
  final String questionId;
  final String answer;
  const _DisplayCond({required this.questionId, required this.answer});

  factory _DisplayCond.fromJson(Map<String, dynamic> json) => _DisplayCond(
    questionId:
        (json['questionId'] as String?) ??
        (json['question_id'] as String?) ??
        '',
    answer: (json['answer'] as String?) ?? '',
  );
}

@immutable
class _ApiQuestion {
  final String id;
  final String text;
  final List<String> options;
  final bool required;
  final String? answerType;
  final String? alertWhenAnswer;
  final String? alertMessage;
  final String? stage;
  final String? block;

  final String? additionalLabel;
  final String? additionalRequiredWhenAnswer;

  final String? photoLabel;
  final String? photoRequiredWhenAnswer;

  final String? levelLabel;
  final bool levelRequired;
  final String? levelRequiredWhenAnswer;
  final List<_LevelOption> levelOptions;

  final _DisplayCond? displayWhen;
  final List<_DisplayCond> displayWhenAny;

  /// Optional narration/prompt audio for this specific question.
  final PrivateAudioRef? narrationAudio;

  /// Modern evidence requests (photo/audio/video) declared by the backend.
  final List<_EvidenceRequest> evidenceRequests;

  const _ApiQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.required,
    required this.answerType,
    required this.alertWhenAnswer,
    required this.alertMessage,
    required this.stage,
    required this.block,
    required this.additionalLabel,
    required this.additionalRequiredWhenAnswer,
    required this.photoLabel,
    required this.photoRequiredWhenAnswer,
    required this.levelLabel,
    required this.levelRequired,
    required this.levelRequiredWhenAnswer,
    required this.levelOptions,
    required this.displayWhen,
    required this.displayWhenAny,
    required this.narrationAudio,
    required this.evidenceRequests,
  });

  /// True when the given evidence kind (photo/audio/video) is required for the
  /// selected answer, or when it's required and there is no per-answer filter.
  bool evidenceRequired(String kind, String? answer) {
    for (final r in evidenceRequests) {
      if (r.kind != kind) continue;
      if (!r.required) continue;
      if (r.whenAnswers.isEmpty) return true;
      if (answer != null && r.whenAnswers.contains(answer)) return true;
    }
    return false;
  }

  /// True when the evidence kind should be offered/collected for the selected
  /// answer (whether required or not).
  bool evidenceOffered(String kind, String? answer) {
    for (final r in evidenceRequests) {
      if (r.kind != kind) continue;
      if (r.whenAnswers.isEmpty) return true;
      if (answer != null && r.whenAnswers.contains(answer)) return true;
    }
    return false;
  }

  _EvidenceRequest? evidenceRequestFor(String kind) {
    for (final r in evidenceRequests) {
      if (r.kind == kind) return r;
    }
    return null;
  }

  static PrivateAudioRef? _parseAudioRef(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final sha = (map['sha256'] as String?) ?? '';
    final url = (map['url'] as String?) ?? '';
    if (sha.trim().isEmpty || url.trim().isEmpty) return null;
    return PrivateAudioRef(sha256: sha.trim(), url: url.trim());
  }

  factory _ApiQuestion.fromJson(Map<String, dynamic> json) {
    // Question-level narration audio may come under a few keys depending on the backend.
    final narrationAudio =
        _parseAudioRef(json['narration_audio']) ??
        _parseAudioRef(json['narrationAudio']) ??
        _parseAudioRef(json['audio']);
    final add = (json['additionalField'] is Map)
        ? (json['additionalField'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final photo = (json['photoRequest'] is Map)
        ? (json['photoRequest'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final level = (json['level'] is Map)
        ? (json['level'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final displayWhen = (json['displayWhen'] is Map)
        ? _DisplayCond.fromJson(
            (json['displayWhen'] as Map).cast<String, dynamic>(),
          )
        : null;
    final displayWhenAnyRaw = json['displayWhenAny'];
    final displayWhenAny = <_DisplayCond>[];
    if (displayWhenAnyRaw is List) {
      for (final it in displayWhenAnyRaw) {
        // Avoid duplicating items (Map<String, dynamic> is also a Map).
        if (it is Map<String, dynamic>) {
          displayWhenAny.add(_DisplayCond.fromJson(it));
        } else if (it is Map) {
          displayWhenAny.add(_DisplayCond.fromJson(it.cast<String, dynamic>()));
        }
      }
    }

    final evidenceRequests = <_EvidenceRequest>[];
    final evReqRaw = json['evidenceRequests'];
    if (evReqRaw is List) {
      for (final it in evReqRaw) {
        Map<String, dynamic>? m;
        if (it is Map<String, dynamic>) {
          m = it;
        } else if (it is Map) {
          m = it.cast<String, dynamic>();
        }
        if (m != null) evidenceRequests.add(_EvidenceRequest.fromJson(m));
      }
    }

    final levelOptions = <_LevelOption>[];
    final levelOptionsRaw = level['options'];
    if (levelOptionsRaw is List) {
      for (final it in levelOptionsRaw) {
        // Avoid duplicating items (Map<String, dynamic> is also a Map).
        if (it is Map<String, dynamic>) {
          levelOptions.add(_LevelOption.fromJson(it));
        } else if (it is Map) {
          levelOptions.add(_LevelOption.fromJson(it.cast<String, dynamic>()));
        }
      }
    }

    // Defensive: ensure dropdown options are unique by `value`.
    // Flutter's DropdownButton asserts when multiple items share the same value.
    final uniqueLevelOptionsByValue = <Object, _LevelOption>{};
    for (final opt in levelOptions) {
      uniqueLevelOptionsByValue.putIfAbsent(opt.value, () => opt);
    }

    return _ApiQuestion(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      options: (json['options'] is List)
          ? (json['options'] as List).whereType<String>().toList()
          : const [],
      required: json['required'] == true,
      answerType: json['answerType'] as String?,
      alertWhenAnswer: json['alertWhenAnswer'] as String?,
      alertMessage: json['alertMessage'] as String?,
      stage: json['stage'] as String?,
      block: json['block'] as String?,
      additionalLabel: add['label'] as String?,
      additionalRequiredWhenAnswer: add['requiredWhenAnswer'] as String?,
      photoLabel: photo['label'] as String?,
      photoRequiredWhenAnswer: photo['requiredWhenAnswer'] as String?,
      levelLabel: level['label'] as String?,
      levelRequired: level['required'] == true,
      levelRequiredWhenAnswer: level['requiredWhenAnswer'] as String?,
      levelOptions: uniqueLevelOptionsByValue.values.toList(growable: false),
      displayWhen: displayWhen,
      displayWhenAny: displayWhenAny,
      narrationAudio: narrationAudio,
      evidenceRequests: evidenceRequests,
    );
  }
}

@immutable
class _EvidenceRequest {
  final String kind; // 'photo' | 'audio' | 'video'
  final bool required;
  final List<String> whenAnswers;
  final String? label;
  final String? instruction;

  const _EvidenceRequest({
    required this.kind,
    required this.required,
    required this.whenAnswers,
    required this.label,
    required this.instruction,
  });

  factory _EvidenceRequest.fromJson(Map<String, dynamic> json) {
    final wa = <String>[];
    final raw = json['whenAnswers'];
    if (raw is List) {
      for (final e in raw) {
        if (e is String) wa.add(e);
      }
    }
    return _EvidenceRequest(
      kind: (json['kind'] as String?)?.trim().toLowerCase() ?? '',
      required: json['required'] == true,
      whenAnswers: wa,
      label: json['label'] as String?,
      instruction: json['instruction'] as String?,
    );
  }
}

@immutable
class _LevelOption {
  final String label;

  /// Backend may send this as either `num` (ex.: 1, 2) or `String` (ex.: "boa").
  /// Keep it as Object to preserve the original type in the completion payload.
  final Object value;
  const _LevelOption({required this.label, required this.value});

  factory _LevelOption.fromJson(Map<String, dynamic> json) => _LevelOption(
    label: (json['label'] as String?) ?? '',
    value: _parseLevelValue(json['value']),
  );

  static Object _parseLevelValue(Object? v) {
    if (v is num) return v;
    if (v is String) return v;
    if (v == null) return '';
    return v.toString();
  }
}

class _ExecutionForm extends StatelessWidget {
  final ExecutionDetail detail;
  final TextEditingController notesController;

  final void Function(PrivateAudioRef ref) onPlayQuestionNarration;
  final void Function(String text) onSpeakQuestion;

  final bool? simpleBoolean;
  final ValueChanged<bool?> onSimpleBooleanChanged;
  final XFile? simplePhoto;
  final VoidCallback? onPickSimplePhoto;
  final XFile? simpleAudio;
  final ValueChanged<XFile?>? onSimpleAudioChanged;
  final XFile? simpleVideo;
  final VoidCallback? onPickSimpleVideo;

  final Map<String, _QuestionAnswerState> answers;
  final void Function(String questionId, _QuestionAnswerState next)
  onAnswerChanged;
  final void Function(String questionId)? onPickQuestionPhoto;
  final void Function(String questionId, XFile? file)? onQuestionAudioChanged;
  final void Function(String questionId)? onPickQuestionVideo;

  const _ExecutionForm({
    required this.detail,
    required this.notesController,
    required this.onPlayQuestionNarration,
    required this.onSpeakQuestion,
    required this.simpleBoolean,
    required this.onSimpleBooleanChanged,
    required this.simplePhoto,
    required this.onPickSimplePhoto,
    required this.simpleAudio,
    required this.onSimpleAudioChanged,
    required this.simpleVideo,
    required this.onPickSimpleVideo,
    required this.answers,
    required this.onAnswerChanged,
    required this.onPickQuestionPhoto,
    required this.onQuestionAudioChanged,
    required this.onPickQuestionVideo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = (detail.raw['requirements'] is Map)
        ? (detail.raw['requirements'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final requiresPhoto = req['photo'] == true;
    final requiresAudio = req['audio'] == true;
    final requiresVideo = req['video'] == true;

    String friendlyFileLabel(
      XFile? f, {
      required String empty,
      required String prefix,
    }) {
      if (f == null) return empty;
      final name = f.name.trim();
      final shown = name.isEmpty
          ? 'selecionado'
          : (name.length > 26 ? '${name.substring(0, 23)}…' : name);
      return '$prefix: $shown';
    }

    if (detail.isSimpleBoolean) {
      return ListView(
        children: [
          Text(
            'Checklist simples',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _YesNoSelector(
            value: simpleBoolean,
            onChanged: onSimpleBooleanChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (requiresPhoto || requiresAudio || requiresVideo) ...[
            Text(
              'Evidências',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (requiresPhoto)
            OutlinedButton.icon(
              onPressed: onPickSimplePhoto,
              icon: Icon(Icons.photo, color: theme.colorScheme.primary),
              label: Text(
                friendlyFileLabel(
                  simplePhoto,
                  empty: 'Selecionar foto (obrigatório)',
                  prefix: 'Foto',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (requiresAudio) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineAudioRecorder(
              value: simpleAudio,
              onChanged: onSimpleAudioChanged ?? (_) {},
              idleLabel: 'Gravar áudio (obrigatório)',
            ),
          ],
          if (requiresVideo) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onPickSimpleVideo,
              icon: Icon(Icons.videocam, color: theme.colorScheme.primary),
              label: Text(
                friendlyFileLabel(
                  simpleVideo,
                  empty: 'Selecionar vídeo (obrigatório)',
                  prefix: 'Vídeo',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    final questionsRaw = detail.raw['questions'];
    final questions = <_ApiQuestion>[];
    if (questionsRaw is List) {
      for (final it in questionsRaw) {
        // Avoid double-adding when `it` is already a `Map<String, dynamic>` (it also
        // satisfies `it is Map`). This was causing duplicated questions in the UI.
        if (it is Map<String, dynamic>) {
          questions.add(_ApiQuestion.fromJson(it));
        } else if (it is Map) {
          questions.add(_ApiQuestion.fromJson(it.cast<String, dynamic>()));
        }
      }
    }

    // Visibility evaluation lives in the parent state, but we can keep it simple
    // here: show all; hidden ones will be skipped by backend validation anyway.
    // For UX, we still hide them when conditions aren't met.
    bool condOne(_DisplayCond c) =>
        (answers[c.questionId]?.answer ?? '') == c.answer;
    bool isVisible(_ApiQuestion q) {
      final hasDisplayWhen = q.displayWhen != null;
      final hasAny = q.displayWhenAny.isNotEmpty;
      if (!hasDisplayWhen && !hasAny) return true;
      final oneOk = !hasDisplayWhen || condOne(q.displayWhen!);
      final anyOk = !hasAny || q.displayWhenAny.any(condOne);
      return oneOk && anyOk;
    }

    final visible = questions.where(isVisible).toList();

    return ListView(
      children: [
        Text(
          'Checklist estruturado',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final q in visible) ...[
          _QuestionCard(
            question: q,
            state: answers[q.id] ?? _QuestionAnswerState(questionId: q.id),
            onChanged: (next) => onAnswerChanged(q.id, next),
            onPlayNarration: () {
              final ref = q.narrationAudio;
              if (ref != null) {
                onPlayQuestionNarration(ref);
              } else {
                onSpeakQuestion(q.text);
              }
            },
            onPickPhoto: onPickQuestionPhoto == null
                ? null
                : () => onPickQuestionPhoto!(q.id),
            onAudioChanged: onQuestionAudioChanged == null
                ? null
                : (file) => onQuestionAudioChanged!(q.id, file),
            onPickVideo: onPickQuestionVideo == null
                ? null
                : () => onPickQuestionVideo!(q.id),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: notesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observações gerais (opcional)',
          ),
        ),
      ],
    );
  }
}

class _YesNoSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?> onChanged;
  const _YesNoSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yesSelected = value == true;
    final noSelected = value == false;

    Widget pill(
      String label,
      bool selected,
      VoidCallback onTap, {
      required Color color,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected
                    ? color
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 0 : 1.5,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          'Não',
          noSelected,
          () => onChanged(false),
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: AppSpacing.md),
        pill(
          'Sim',
          yesSelected,
          () => onChanged(true),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final _ApiQuestion question;
  final _QuestionAnswerState state;
  final ValueChanged<_QuestionAnswerState> onChanged;
  final VoidCallback? onPlayNarration;
  final VoidCallback? onPickPhoto;
  final ValueChanged<XFile?>? onAudioChanged;
  final VoidCallback? onPickVideo;

  const _QuestionCard({
    required this.question,
    required this.state,
    required this.onChanged,
    required this.onPlayNarration,
    required this.onPickPhoto,
    required this.onAudioChanged,
    required this.onPickVideo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAlert =
        question.alertWhenAnswer != null &&
        (state.answer == question.alertWhenAnswer);
    final wantsAdditional =
        question.additionalRequiredWhenAnswer != null &&
        state.answer == question.additionalRequiredWhenAnswer;
    final wantsPhoto =
        (question.photoRequiredWhenAnswer != null &&
            state.answer == question.photoRequiredWhenAnswer) ||
        question.evidenceOffered('photo', state.answer);
    final wantsAudio = question.evidenceOffered('audio', state.answer);
    final wantsVideo = question.evidenceOffered('video', state.answer);
    bool wantsLevelFor(String? answer) =>
        question.levelOptions.isNotEmpty &&
        (question.levelRequired ||
            (question.levelRequiredWhenAnswer != null &&
                answer == question.levelRequiredWhenAnswer));
    final wantsLevel = wantsLevelFor(state.answer);

    String friendlyFileLabel(
      XFile? f, {
      required String empty,
      required String prefix,
    }) {
      if (f == null) return empty;
      final name = f.name.trim();
      final shown = name.isEmpty
          ? 'selecionado'
          : (name.length > 26 ? '${name.substring(0, 23)}…' : name);
      return '$prefix: $shown';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onPlayNarration != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onPlayNarration,
                  tooltip: 'Ouvir áudio',
                  icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final opt in question.options)
                ChoiceChip(
                  label: Text(opt),
                  selected: state.answer == opt,
                  onSelected: (_) {
                    // Clear stale level when the new answer doesn't request it.
                    // This avoids sending `level` for answers that don't support it.
                    final needsLevel = wantsLevelFor(opt);
                    onChanged(
                      state.copyWith(
                        answer: opt,
                        levelValue: needsLevel ? state.levelValue : null,
                      ),
                    );
                  },
                ),
            ],
          ),
          if (showAlert && (question.alertMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(message: question.alertMessage!),
          ],
          if (wantsLevel) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<Object>(
              initialValue: state.levelValue,
              decoration: InputDecoration(
                labelText: question.levelLabel ?? 'Nível',
              ),
              items: [
                for (final opt in question.levelOptions)
                  DropdownMenuItem(value: opt.value, child: Text(opt.label)),
              ],
              onChanged: (v) => onChanged(state.copyWith(levelValue: v)),
            ),
          ],
          if (wantsAdditional) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: question.additionalLabel ?? 'Observação',
              ),
              onChanged: (v) => onChanged(state.copyWith(additionalText: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            InlineAudioRecorder(
              value: state.additionalAudio,
              onChanged: onAudioChanged ?? (_) {},
              idleLabel: 'Adicionar áudio (opcional)',
            ),
          ],
          if (wantsPhoto) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onPickPhoto,
              icon: Icon(Icons.photo, color: theme.colorScheme.primary),
              label: Text(
                friendlyFileLabel(
                  state.photo,
                  empty:
                      (question.evidenceRequestFor('photo')?.label ??
                      question.photoLabel ??
                      'Adicionar foto'),
                  prefix: 'Foto',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (wantsAudio && !wantsAdditional) ...[
            const SizedBox(height: AppSpacing.md),
            InlineAudioRecorder(
              value: state.additionalAudio,
              onChanged: onAudioChanged ?? (_) {},
              idleLabel:
                  question.evidenceRequestFor('audio')?.label ??
                  'Adicionar áudio',
            ),
          ],
          if (wantsVideo) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onPickVideo,
              icon: Icon(Icons.videocam, color: theme.colorScheme.primary),
              label: Text(
                friendlyFileLabel(
                  state.video,
                  empty:
                      (question.evidenceRequestFor('video')?.label ??
                      'Adicionar vídeo'),
                  prefix: 'Vídeo',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only summary shown once an execution's status is `completed` — no
/// inputs, no evidence pickers, just what was actually submitted.
class _CompletedExecutionView extends StatelessWidget {
  final ExecutionDetail detail;
  final List<_ApiQuestion> questions;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _CompletedExecutionView({
    required this.detail,
    required this.questions,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final evidence = detail.completedEvidence
        .map(MobileEvidenceRef.fromJson)
        .toList();
    final generalEvidence = evidence
        .where((e) => (e.questionId ?? '').trim().isEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _CompletedHeaderCard(detail: detail),
        const SizedBox(height: AppSpacing.lg),
        if (detail.isSimpleBoolean) ...[
          _SimpleAnswerCard(
            booleanAnswer: detail.completedBooleanAnswer,
            evidence: generalEvidence,
            origin: origin,
            authHeaders: authHeaders,
            onPlayAudio: onPlayAudio,
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          for (final q in questions) ...[
            _CompletedQuestionCard(
              question: q,
              answer: (detail.completedAnswers[q.id] is Map)
                  ? (detail.completedAnswers[q.id] as Map)
                        .cast<String, dynamic>()
                  : const <String, dynamic>{},
              evidence: evidence.where((e) => e.questionId == q.id).toList(),
              origin: origin,
              authHeaders: authHeaders,
              onPlayAudio: onPlayAudio,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (generalEvidence.isNotEmpty) ...[
            _GeneralEvidenceCard(
              evidence: generalEvidence,
              origin: origin,
              authHeaders: authHeaders,
              onPlayAudio: onPlayAudio,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
        _CompletedNotesCard(notes: detail.completedNotes),
      ],
    );
  }
}

class _CompletedHeaderCard extends StatelessWidget {
  final ExecutionDetail detail;
  const _CompletedHeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedAt = detail.completedAt;
    final dateText = completedAt == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm').format(completedAt.toLocal());

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
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist Concluído',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
                if (dateText != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    dateText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
                if ((detail.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.location!,
                    style: theme.textTheme.bodySmall?.copyWith(
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

class _AnswerBadge extends StatelessWidget {
  final String answer;
  const _AnswerBadge({required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = answer.trim().toLowerCase();
    const positive = {'sim', 'conforme', 'ok', 'yes', 'true'};
    const negative = {'nao', 'não', 'inconforme', 'no', 'false'};

    final Color bg;
    final Color fg;
    if (positive.contains(normalized)) {
      bg = AppColors.successLight;
      fg = AppColors.success;
    } else if (negative.contains(normalized)) {
      bg = AppColors.errorLight;
      fg = AppColors.error;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        answer.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _SimpleAnswerCard extends StatelessWidget {
  final bool? booleanAnswer;
  final List<MobileEvidenceRef> evidence;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _SimpleAnswerCard({
    required this.booleanAnswer,
    required this.evidence,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resposta',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnswerBadge(
            answer: booleanAnswer == null
                ? '—'
                : (booleanAnswer! ? 'Sim' : 'Não'),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _EvidenceGrid(
              evidence: evidence,
              origin: origin,
              authHeaders: authHeaders,
              onPlayAudio: onPlayAudio,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedQuestionCard extends StatelessWidget {
  final _ApiQuestion question;
  final Map<String, dynamic> answer;
  final List<MobileEvidenceRef> evidence;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _CompletedQuestionCard({
    required this.question,
    required this.answer,
    required this.evidence,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answerText = (answer['answer'] as String?) ?? '';
    final additionalText = (answer['additional_text'] as String?) ?? '';
    final level = answer['level'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (answerText.isNotEmpty) _AnswerBadge(answer: answerText),
              if (level != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Nível $level',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (additionalText.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      additionalText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _EvidenceGrid(
              evidence: evidence,
              origin: origin,
              authHeaders: authHeaders,
              onPlayAudio: onPlayAudio,
            ),
          ],
        ],
      ),
    );
  }
}

class _GeneralEvidenceCard extends StatelessWidget {
  final List<MobileEvidenceRef> evidence;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _GeneralEvidenceCard({
    required this.evidence,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evidências gerais',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _EvidenceGrid(
            evidence: evidence,
            origin: origin,
            authHeaders: authHeaders,
            onPlayAudio: onPlayAudio,
          ),
        ],
      ),
    );
  }
}

class _CompletedNotesCard extends StatelessWidget {
  final String? notes;
  const _CompletedNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (notes ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observações gerais',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text.isEmpty ? 'Nenhuma observação adicional informada.' : text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: text.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceGrid extends StatelessWidget {
  final List<MobileEvidenceRef> evidence;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _EvidenceGrid({
    required this.evidence,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in evidence) ...[
          _EvidenceThumb(
            evidence: e,
            origin: origin,
            authHeaders: authHeaders,
            onPlayAudio: onPlayAudio,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  final MobileEvidenceRef evidence;
  final String origin;
  final Map<String, String> authHeaders;
  final void Function(PrivateAudioRef ref) onPlayAudio;

  const _EvidenceThumb({
    required this.evidence,
    required this.origin,
    required this.authHeaders,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final absUrl = absoluteMediaUrl(origin: origin, url: evidence.url);

    switch (evidence.kind) {
      case 'photo':
        return GestureDetector(
          onTap: () =>
              showFullscreenImage(context, url: absUrl, headers: authHeaders),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.network(
              absUrl,
              headers: authHeaders,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 160,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
              errorBuilder: (context, error, stack) => Container(
                height: 160,
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
      case 'audio':
        return OutlinedButton.icon(
          onPressed: () => onPlayAudio(
            PrivateAudioRef(sha256: evidence.sha256, url: evidence.url),
          ),
          icon: Icon(Icons.play_circle, color: theme.colorScheme.primary),
          label: Text(
            'Reproduzir áudio',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      case 'video':
        return EvidenceVideoPlayer(url: absUrl, headers: authHeaders);
      default:
        return Container(
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
                child: Text(
                  evidence.originalName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    }
  }
}
