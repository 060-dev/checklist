import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ApiChecklistsPage extends StatefulWidget {
  const ApiChecklistsPage({super.key});

  @override
  State<ApiChecklistsPage> createState() => _ApiChecklistsPageState();
}

class _ApiChecklistsPageState extends State<ApiChecklistsPage> {
  bool _loading = true;
  String? _error;
  List<ApiChecklistAssignment> _items = const [];
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() {
        _loading = false;
        _items = const [];
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
      final res = await api.listAssignments(employeeId: employeeId);
      // Defensive de-duplication: if the backend returns duplicate rows (or if
      // there is caching/proxy duplication), we keep the latest occurrence.
      final byKey = <String, ApiChecklistAssignment>{};
      for (final it in res.items) {
        final k = '${it.assignmentId}::${(it.nextExecutionId ?? '').trim()}';
        byKey[k] = it;
      }
      final items = byKey.values.toList();
      unawaited(LocalCacheService.instance.saveAssignments(employeeId, items));
      setState(() {
        _items = items;
        _fromCache = false;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      await _fallBackToCache(employeeId, e.message);
    } catch (e) {
      await _fallBackToCache(employeeId, 'Falha ao carregar checklists.');
    } finally {
      client.dispose();
    }
  }

  Future<void> _fallBackToCache(String employeeId, String errorMessage) async {
    final cached = await LocalCacheService.instance.getAssignments(employeeId);
    if (cached == null) {
      setState(() {
        _error = errorMessage;
        _items = const [];
        _fromCache = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _items = cached.items;
      _fromCache = true;
      _error = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ResponsiveBody(
        maxWidth: 720,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((_error ?? '').trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Checklists',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: Icon(
                          Icons.refresh,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_fromCache) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const OfflineIndicator(pendingCount: 0),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final it = _items[i];
                        final nextExecutionId = (it.nextExecutionId ?? '')
                            .trim();
                        return _AssignmentCard(
                          item: it,
                          onTap: () async {
                            // The mobile flow is execution-driven. If the assignment already
                            // has a scheduled execution, jump straight into the checklist UI.
                            if (nextExecutionId.isNotEmpty) {
                              final res = await context.push(
                                '/api/executions/$nextExecutionId',
                              );
                              if (res == true) await _load();
                            } else {
                              final res = await context.push(
                                '/api/checklists/${it.assignmentId}',
                              );
                              if (res == true) await _load();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final ApiChecklistAssignment item;
  final VoidCallback onTap;

  const _AssignmentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = (item.location ?? '').trim().isEmpty
        ? item.description
        : '${item.location} · ${item.description}';
    final due = item.nextDueAt;
    final dueText = due == null
        ? null
        : '${due.toLocal().day.toString().padLeft(2, '0')}/${due.toLocal().month.toString().padLeft(2, '0')} ${due.toLocal().hour.toString().padLeft(2, '0')}:${due.toLocal().minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                Icons.checklist,
                color: theme.colorScheme.onPrimary,
                size: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dueText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          label: 'Previsto: $dueText',
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ApiAssignmentDetailPage extends StatefulWidget {
  final String assignmentId;
  const ApiAssignmentDetailPage({super.key, required this.assignmentId});

  @override
  State<ApiAssignmentDetailPage> createState() =>
      _ApiAssignmentDetailPageState();
}

class _ApiAssignmentDetailPageState extends State<ApiAssignmentDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
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
      final detail = await api.getAssignmentDetail(
        employeeId: employeeId,
        assignmentId: widget.assignmentId,
      );
      unawaited(
        LocalCacheService.instance.saveAssignmentDetail(
          employeeId,
          widget.assignmentId,
          detail,
        ),
      );
      setState(() {
        _data = detail;
        _fromCache = false;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      await _fallBackToCache(employeeId, e.message);
    } catch (e) {
      await _fallBackToCache(employeeId, 'Falha ao carregar detalhe.');
    } finally {
      client.dispose();
    }
  }

  Future<void> _fallBackToCache(String employeeId, String errorMessage) async {
    final cached = await LocalCacheService.instance.getAssignmentDetail(
      employeeId,
      widget.assignmentId,
    );
    if (cached == null) {
      setState(() {
        _error = errorMessage;
        _data = null;
        _fromCache = false;
        _loading = false;
      });
      return;
    }
    final (_, data) = cached;
    setState(() {
      _data = data;
      _fromCache = true;
      _error = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data ?? const <String, dynamic>{};
    final nextExecutionId =
        (data['next_execution_id'] as num?)?.toString() ??
        (data['next_execution_id']?.toString() ?? '');
    final checklistTitle = (data['title'] as String?) ?? '';
    final checklistDesc = (data['description'] as String?) ?? '';
    final location = (data['location'] as String?) ?? '';
    final requirements = (data['requirements'] is Map)
        ? (data['requirements'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final requiresBoolean = requirements['boolean'] == true;
    final requiresPhoto = requirements['photo'] == true;
    final requiresAudio = requirements['audio'] == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          checklistTitle.trim().isEmpty
              ? 'Assignment ${widget.assignmentId}'
              : checklistTitle,
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 760,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((_error ?? '').trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_fromCache) ...[
                      const OfflineIndicator(pendingCount: 0),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      'Checklist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.18,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (location.trim().isNotEmpty)
                            Text(
                              location,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          if (checklistDesc.trim().isNotEmpty) ...[
                            if (location.trim().isNotEmpty)
                              const SizedBox(height: AppSpacing.xs),
                            Text(
                              checklistDesc,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (requiresBoolean)
                                _Pill(
                                  label: 'resposta: Sim/Não',
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              if (requiresPhoto)
                                _Pill(
                                  label: 'foto obrigatória',
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              if (requiresAudio)
                                _Pill(
                                  label: 'áudio obrigatório',
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (nextExecutionId.trim().isNotEmpty)
                            FilledButton.icon(
                              onPressed: () => context.push(
                                '/api/executions/$nextExecutionId',
                              ),
                              icon: Icon(
                                Icons.play_arrow,
                                color: theme.colorScheme.onPrimary,
                              ),
                              label: Text(
                                'Fazer checklist agora',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              child: Text(
                                'Sem execução pendente para este checklist no momento. Quando houver uma execução agendada, ela aparecerá aqui.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.35,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
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
