import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ApiTodayPage extends StatefulWidget {
  const ApiTodayPage({super.key});

  @override
  State<ApiTodayPage> createState() => _ApiTodayPageState();
}

class _ApiTodayPageState extends State<ApiTodayPage> {
  bool _loading = true;
  String? _error;
  List<ApiExecutionSummary> _items = const [];

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
      final res = await api.listExecutions(employeeId: employeeId, dateFrom: ymd, dateTo: ymd, order: 'due_asc', pageSize: 100);

      final items = res.items;
      items.sort((a, b) => _statusRank(a.status).compareTo(_statusRank(b.status)));

      setState(() {
        _items = items;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      setState(() {
        _error = e.message;
        _items = const [];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Falha ao carregar.';
        _items = const [];
        _loading = false;
      });
    } finally {
      client.dispose();
    }
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
                      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      Expanded(child: Text('Hoje', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                      IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: theme.colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_items.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 54, color: theme.colorScheme.primary),
                            const SizedBox(height: AppSpacing.md),
                            Text('Nenhum checklist para hoje', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
                              label: Text('Atualizar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onPrimary)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return _ExecutionCard(
                            item: it,
                            onTap: () async {
                              final res = await context.push('/api/executions/${it.executionId}');
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
    final due = item.dueAt;
    final dueText = due == null ? '' : DateFormat('dd/MM HH:mm').format(due.toLocal());

    final status = item.status;
    final statusLabel = switch (status) {
      'pending' => 'Para fazer',
      'in_progress' => 'Em andamento',
      'overdue' => 'Atrasado — fazer agora',
      'completed' => 'Concluído e enviado',
      _ => 'Situação: $status',
    };

    final (Color pillBg, Color pillFg, IconData icon) = switch (status) {
      'completed' => (AppColors.successLight, AppColors.success, Icons.check_circle),
      'overdue' => (AppColors.errorLight, AppColors.error, Icons.warning_rounded),
      'in_progress' => (AppColors.infoLight, AppColors.info, Icons.play_circle),
      _ => (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant, Icons.pending_actions),
    };

    final cta = switch (status) {
      'completed' => 'Ver respostas',
      'in_progress' => 'Continuar',
      _ => 'Começar',
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.22), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Icon(icon, color: theme.colorScheme.onPrimary, size: 30),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.xs),
                  if ((item.location ?? '').trim().isNotEmpty)
                    Text(item.location!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(99), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
                        child: Text(statusLabel, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: pillFg)),
                      ),
                      if (dueText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(99), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
                          child: Text('Até: $dueText', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cta, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                const SizedBox(height: 6),
                Icon(Icons.arrow_forward_ios, color: theme.colorScheme.primary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
