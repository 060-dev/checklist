import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class OccurrencesPage extends StatefulWidget {
  const OccurrencesPage({super.key});

  @override
  State<OccurrencesPage> createState() => _OccurrencesPageState();
}

class _OccurrencesPageState extends State<OccurrencesPage> {
  bool _loading = true;
  String? _error;
  List<OccurrenceSummary> _items = const [];
  String _statusFilter = 'open';
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
      final res = await api.listOccurrences(
        employeeId: employeeId,
        status: _statusFilter,
      );
      // Defensive de-duplication (some backends/proxies can return duplicated rows).
      final byId = <String, OccurrenceSummary>{};
      for (final it in res.items) {
        byId[it.occurrenceId] = it;
      }
      final items = byId.values.toList();
      unawaited(LocalCacheService.instance.saveOccurrences(employeeId, items));
      setState(() {
        _items = items;
        _fromCache = false;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      await _fallBackToCache(employeeId, e.message);
    } catch (e) {
      await _fallBackToCache(employeeId, 'Falha ao carregar ocorrências.');
    } finally {
      client.dispose();
    }
  }

  Future<void> _fallBackToCache(String employeeId, String errorMessage) async {
    final cached = await LocalCacheService.instance.getOccurrences(employeeId);
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
        maxWidth: 760,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((_error ?? '').trim().isNotEmpty) ...[
                    ErrorBanner(message: _error!, onRetry: _load),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('Abertas'),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('Em andamento'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('Resolvidas'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Canceladas'),
                          ),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _statusFilter = v);
                          await _load();
                        },
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _load,
                              icon: Icon(
                                Icons.refresh,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                final res = await context.push(
                                  '/api/occurrences/new',
                                );
                                if (res is String && res.isNotEmpty) {
                                  await _load();
                                  if (mounted) {
                                    await context.push('/api/occurrences/$res');
                                  }
                                } else if (res == true) {
                                  await _load();
                                }
                              },
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
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
                        return _OccurrenceCard(
                          item: it,
                          onTap: () => context.push(
                            '/api/occurrences/${it.occurrenceId}',
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

class _OccurrenceCard extends StatelessWidget {
  final OccurrenceSummary item;
  final VoidCallback onTap;
  const _OccurrenceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = item.dueAt;
    final dueText = due == null
        ? null
        : '${due.toLocal().day.toString().padLeft(2, '0')}/${due.toLocal().month.toString().padLeft(2, '0')} ${due.toLocal().hour.toString().padLeft(2, '0')}:${due.toLocal().minute.toString().padLeft(2, '0')}';
    final subtitleBits = <String>[];
    if ((item.location ?? '').trim().isNotEmpty) {
      subtitleBits.add(item.location!.trim());
    }
    if (dueText != null) subtitleBits.add('Até: $dueText');
    final subtitle = subtitleBits.join(' · ');

    final isResolved =
        item.status == 'resolved' ||
        item.status == 'solucionada' ||
        item.status == 'concluida';

    final (
      Color iconBg,
      Color iconFg,
      IconData iconData,
      Color borderColor,
      Color cardBg,
      Color arrowColor,
    ) = isResolved
        ? (
            AppColors.successLight,
            AppColors.success,
            Icons.check_circle_rounded,
            AppColors.success.withValues(alpha: 0.35),
            AppColors.successLight.withValues(alpha: 0.2),
            AppColors.success,
          )
        : (
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.primary,
            Icons.warning_rounded,
            theme.colorScheme.primary.withValues(alpha: 0.22),
            theme.colorScheme.primary.withValues(alpha: 0.06),
            theme.colorScheme.primary,
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(iconData, color: iconFg, size: 30),
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
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (isResolved) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Resolvida',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.arrow_forward_ios, color: arrowColor, size: 20),
          ],
        ),
      ),
    );
  }
}
