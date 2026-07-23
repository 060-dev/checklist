import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/media_source_sheet.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/services/private_audio_player.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

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
  ApiOccurrenceDetail? _detail;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    PrivateAudioPlayer.instance.stop();
    super.dispose();
  }

  PrivateAudioRef? _narrationRef(ApiOccurrenceDetail d) {
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
      final ok = await PrivateAudioPlayer.instance.play(client: client, origin: session.origin, ref: ref);
      if (!ok && mounted) setState(() => _error = 'Não foi possível baixar o áudio. Tente novamente.');
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
      final d = await api.getOccurrenceDetail(employeeId: employeeId, occurrenceId: widget.occurrenceId);
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

  Future<void> _pickImage() async {
    final source = await showMediaSourceSheet(context, title: 'Anexar Foto à Ocorrência');
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null) return;
      setState(() => _pickedImage = file);
    } catch (e) {
      debugPrint('Pick image failed: $e');
    }
  }

  Future<void> _attach() async {
    if (_mutating) return;
    final file = _pickedImage;
    if (file == null) {
      setState(() => _error = 'Selecione uma imagem primeiro.');
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

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      final mp = await _multipartFromXFile('file', file);
      if (mp == null) {
        setState(() => _error = 'Falha ao ler a imagem selecionada.');
        return;
      }
      await api.attachOccurrenceImage(employeeId: employeeId, occurrenceId: widget.occurrenceId, idempotencyKey: const Uuid().v4(), file: mp);
      setState(() => _pickedImage = null);
      await _load();
    } on MobileApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Attach failed: $e');
      setState(() => _error = 'Falha ao anexar.');
    } finally {
      client.dispose();
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<http.MultipartFile?> _multipartFromXFile(String fieldName, XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return http.MultipartFile.fromBytes(fieldName, bytes, filename: file.name);
    } catch (e) {
      debugPrint('Failed to build multipart file ($fieldName): $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _detail;
    final raw = d?.raw ?? const <String, dynamic>{};

    final subtitleBits = <String>[];
    final status = (d?.status ?? '').trim();
    final location = (d?.location ?? '').trim();
    if (status.isNotEmpty) subtitleBits.add(status.replaceAll('_', ' '));
    if (location.isNotEmpty) subtitleBits.add(location);

    final details = <MapEntry<String, String>>[];
    final priority = (raw['priority'] as String?) ?? '';
    if (priority.trim().isNotEmpty) details.add(MapEntry('Prioridade', priority));
    final dueAt = raw['due_at'] as String?;
    if ((dueAt ?? '').trim().isNotEmpty) details.add(MapEntry('Vencimento', dueAt!));
    final createdAt = raw['created_at'] as String?;
    if ((createdAt ?? '').trim().isNotEmpty) details.add(MapEntry('Criado em', createdAt!));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => context.pop()),
        title: Text(d == null ? 'Ocorrência' : d.title),
        actions: [
          if (d != null && _narrationRef(d) != null)
            IconButton(
              onPressed: _playNarration,
              icon: Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary),
              tooltip: 'Ouvir ocorrência',
            ),
          IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: theme.colorScheme.primary)),
        ],
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
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (d != null) ...[
                      if (subtitleBits.isNotEmpty)
                        Text(subtitleBits.join(' · '), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.md),
                      if (details.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Detalhes', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: AppSpacing.sm),
                              for (final it in details) ...[
                                Row(
                                  children: [
                                    SizedBox(width: 110, child: Text(it.key, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800))),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(it.value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mutating ? null : _pickImage,
                            icon: Icon(Icons.photo, color: theme.colorScheme.primary),
                            label: Text(_pickedImage == null ? 'Selecionar imagem' : 'Imagem: ${_pickedImage!.name}', overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _mutating ? null : _attach,
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                            icon: Icon(Icons.upload, color: theme.colorScheme.onPrimary),
                            label: Text('Anexar', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }
}
