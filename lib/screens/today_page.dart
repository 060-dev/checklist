import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  static const String _scope = 'today';

  bool _loading = true;
  String? _error;
  List<ApiExecutionSummary> _items = const [];
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
        _error = 'Selecione seu nome novamente.';
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
      // The "today" boundary follows the device's local calendar day.
      final ymd = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      final res = await api.listExecutions(
        employeeId: employeeId,
        dateFrom: ymd,
        dateTo: ymd,
        order: 'due_asc',
        pageSize: 100,
      );

      final items = res.items;
      items.sort(
        (a, b) => _statusRank(a.status).compareTo(_statusRank(b.status)),
      );
      unawaited(
        LocalCacheService.instance.saveExecutions(
          employeeId,
          items,
          scope: _scope,
        ),
      );

      setState(() {
        _items = items;
        _fromCache = false;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      await _fallBackToCache(employeeId, e.message);
    } catch (_) {
      await _fallBackToCache(employeeId, 'Falha ao carregar.');
    } finally {
      client.dispose();
    }
  }

  Future<void> _fallBackToCache(String employeeId, String errorMessage) async {
    final cached = await LocalCacheService.instance.getExecutions(
      employeeId,
      scope: _scope,
    );
    if (cached == null) {
      setState(() {
        _error = errorMessage;
        _items = const [];
        _fromCache = false;
        _loading = false;
      });
      return;
    }
    final items = List<ApiExecutionSummary>.from(cached.items)
      ..sort((a, b) => _statusRank(a.status).compareTo(_statusRank(b.status)));
    setState(() {
      _items = items;
      _fromCache = true;
      _error = null;
      _loading = false;
    });
  }

  int _statusRank(String status) {
    switch (status) {
      case 'overdue':
        return 0;
      case 'pending':
        return 1;
      case 'in_progress':
        return 2;
      case 'completed':
        return 3;
      default:
        return 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ResponsiveBody(
        maxWidth: 780,
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hoje',
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
                  if (_items.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 54,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Nenhum checklist para hoje',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: Icon(
                                Icons.refresh,
                                color: theme.colorScheme.onPrimary,
                              ),
                              label: Text(
                                'Atualizar',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return _ExecutionCard(
                            item: it,
                            onTap: () async {
                              final res = await context.push(
                                '/api/executions/${it.executionId}',
                              );
                              if (res == true) await _load();
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

class _ExecutionCard extends StatelessWidget {
  final ApiExecutionSummary item;
  final VoidCallback onTap;
  const _ExecutionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item.status;

    final timeText = (status != 'completed' && item.dueAt != null)
        ? DateFormat('HH:mm').format(item.dueAt!.toLocal())
        : null;

    final (Color iconBg, Color iconFg, IconData statusIcon) = switch (status) {
      'completed' => (
        AppColors.successLight,
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      'overdue' => (
        AppColors.errorLight,
        AppColors.error,
        Icons.warning_rounded,
      ),
      'in_progress' => (
        AppColors.infoLight,
        AppColors.info,
        Icons.play_circle_filled_rounded,
      ),
      _ => (
        theme.colorScheme.primary.withValues(alpha: 0.12),
        theme.colorScheme.primary,
        Icons.assignment_outlined,
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 64),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(statusIcon, color: iconFg, size: 24),
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
                  if ((item.location ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.location!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (timeText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'overdue'
                            ? AppColors.errorLight
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: status == 'overdue'
                                ? AppColors.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Até $timeText',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
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
