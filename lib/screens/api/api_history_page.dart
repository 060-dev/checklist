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

class ApiHistoryPage extends StatefulWidget {
  const ApiHistoryPage({super.key});

  @override
  State<ApiHistoryPage> createState() => _ApiHistoryPageState();
}

class _ApiHistoryPageState extends State<ApiHistoryPage> {
  static const String _scope = 'history';

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
      final now = DateTime.now().toLocal();
      final from = now.subtract(const Duration(days: 30));
      final dateFrom = DateFormat('yyyy-MM-dd').format(from);
      final dateTo = DateFormat('yyyy-MM-dd').format(now);

      final res = await api.listExecutions(
        employeeId: employeeId,
        status: 'completed',
        dateFrom: dateFrom,
        dateTo: dateTo,
        order: 'due_desc',
        pageSize: 100,
      );
      unawaited(
        LocalCacheService.instance.saveExecutions(
          employeeId,
          res.items,
          scope: _scope,
        ),
      );

      setState(() {
        _items = res.items;
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
                          'Histórico',
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
                              Icons.history,
                              size: 54,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Nada enviado ainda',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Os checklists concluídos aparecem aqui.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                          return _HistoryCard(
                            item: it,
                            onTap: () => context.push(
                              '/api/executions/${it.executionId}',
                            ),
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

class _HistoryCard extends StatelessWidget {
  final ApiExecutionSummary item;
  final VoidCallback onTap;
  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = item.dueAt;
    final dueText = due == null
        ? ''
        : DateFormat('dd/MM HH:mm').format(due.toLocal());
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 30),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if ((item.location ?? '').trim().isNotEmpty)
                        item.location!.trim(),
                      if (dueText.isNotEmpty) 'Data: $dueText',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
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
