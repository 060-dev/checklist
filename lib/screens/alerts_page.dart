import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/alert_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

// ---------------------------------------------------------------------------
// Public callback type so HomePage can react to badge count changes.
// ---------------------------------------------------------------------------
typedef AlertCountChanged = void Function(int unhandledCount);

class AlertsPage extends StatefulWidget {
  /// Called whenever the unhandled alert count changes (load / update).
  final AlertCountChanged? onCountChanged;

  const AlertsPage({super.key, this.onCountChanged});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<MobileAlert> _items = const [];

  Timer? _refreshTimer;
  static const _refreshInterval = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Resume timer when the app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _load();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _items = const [];
          _error = 'Selecione seu nome novamente.';
        });
      }
      return;
    }

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      final alerts = await api.listAlerts(employeeId: employeeId);
      // Sort: pending/sent first, then viewed, then handled; newest first within each.
      alerts.sort((a, b) {
        final rankA = _statusRank(a.status);
        final rankB = _statusRank(b.status);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return b.createdAt.compareTo(a.createdAt);
      });
      if (mounted) {
        setState(() {
          _items = alerts;
          _loading = false;
        });
        _notifyCount(alerts);
      }
    } on MobileApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Falha ao carregar avisos.';
          _loading = false;
        });
      }
    } finally {
      client.dispose();
    }
  }

  int _statusRank(String status) => switch (status) {
    'pending' => 0,
    'sent' => 0,
    'viewed' => 1,
    'handled' => 2,
    _ => 3,
  };

  void _notifyCount(List<MobileAlert> alerts) {
    final unhandled = alerts.where((a) => !a.isHandled).length;
    widget.onCountChanged?.call(unhandled);
  }

  /// Optimistically marks an alert as `viewed` silently in background,
  /// then (if [andHandle]) also marks it as `handled`.
  Future<void> _acknowledge(MobileAlert alert, {required bool andHandle}) async {
    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (employeeId.isEmpty) return;

    // --- Optimistic UI update ---
    final targetStatus = andHandle ? 'handled' : 'viewed';
    final idx = _items.indexWhere((a) => a.id == alert.id);
    if (idx == -1) return;

    final updated = alert.copyWithStatus(targetStatus);
    setState(() => _items = [..._items]..[idx] = updated);
    _notifyCount(_items);

    // --- API call in background ---
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      // If jumping straight to handled, mark viewed first (server may require it).
      if (andHandle && (alert.status == 'pending' || alert.status == 'sent')) {
        await api.updateAlert(
          employeeId: employeeId,
          alertId: alert.id.toString(),
          status: 'viewed',
          idempotencyKey: const Uuid().v4(),
        );
      }
      await api.updateAlert(
        employeeId: employeeId,
        alertId: alert.id.toString(),
        status: targetStatus,
        idempotencyKey: const Uuid().v4(),
      );
    } catch (e) {
      // Roll back optimistic update on failure.
      if (mounted) {
        final rollbackIdx = _items.indexWhere((a) => a.id == alert.id);
        if (rollbackIdx != -1) {
          setState(() => _items = [..._items]..[rollbackIdx] = alert);
          _notifyCount(_items);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao atualizar aviso.')),
          );
        }
      }
    } finally {
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount =
        _items.where((a) => a.status == 'pending' || a.status == 'sent').length;

    return SafeArea(
      child: ResponsiveBody(
        maxWidth: 760,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        if (pendingCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$pendingCount',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        const Spacer(),
                        IconButton(
                          onPressed: _load,
                          icon: Icon(
                            Icons.refresh,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error banner
                  if ((_error ?? '').trim().isNotEmpty) ...[
                    ErrorBanner(message: _error!, onRetry: _load),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // List or empty state
                  if (_items.isEmpty && (_error == null || _error!.isEmpty))
                    Expanded(child: _EmptyState())
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, i) {
                            final alert = _items[i];
                            return _AlertCard(
                              alert: alert,
                              onTapCard: () => context.push(
                                '/api/occurrences/${alert.occurrenceId}',
                              ),
                              onAcknowledge: alert.status == 'pending' ||
                                      alert.status == 'sent'
                                  ? () => _acknowledge(
                                        alert,
                                        andHandle: false,
                                      )
                                  : alert.status == 'viewed'
                                      ? () => _acknowledge(
                                            alert,
                                            andHandle: true,
                                          )
                                      : null,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhum aviso',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alert card
// ---------------------------------------------------------------------------

class _AlertCard extends StatelessWidget {
  final MobileAlert alert;
  final VoidCallback onTapCard;

  /// null = no action button (handled state).
  final VoidCallback? onAcknowledge;

  const _AlertCard({
    required this.alert,
    required this.onTapCard,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (
      Color iconBg,
      Color iconFg,
      IconData iconData,
      Color borderColor,
      Color cardBg,
      double opacity,
    ) = switch (alert.status) {
      'handled' => (
          AppColors.successLight,
          AppColors.success,
          Icons.check_circle_rounded,
          AppColors.success.withValues(alpha: 0.3),
          AppColors.successLight.withValues(alpha: 0.15),
          0.65,
        ),
      'viewed' => (
          AppColors.infoLight,
          AppColors.info,
          Icons.visibility_rounded,
          AppColors.info.withValues(alpha: 0.4),
          AppColors.infoLight.withValues(alpha: 0.2),
          1.0,
        ),
      _ => (
          // pending | sent
          AppColors.warningLight,
          AppColors.warning,
          Icons.notifications_active_rounded,
          AppColors.warning.withValues(alpha: 0.5),
          AppColors.warningLight.withValues(alpha: 0.3),
          1.0,
        ),
    };

    final (
      Color btnBg,
      Color btnFg,
      IconData btnIcon,
      String btnLabel,
    ) = switch (alert.status) {
      'viewed' => (
          AppColors.brandRed,
          AppColors.white,
          Icons.check_circle_outline_rounded,
          'Resolvi',
        ),
      _ => (
          AppColors.success,
          AppColors.white,
          Icons.visibility_rounded,
          'Vi',
        ),
    };

    // Relative time label.
    final now = DateTime.now();
    final diff = now.difference(alert.createdAt.toLocal());
    final timeLabel = diff.inMinutes < 1
        ? 'Agora'
        : diff.inHours < 1
            ? '${diff.inMinutes}min'
            : diff.inDays < 1
                ? '${diff.inHours}h'
                : '${diff.inDays}d';

    return Opacity(
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Card body (tappable -> occurrence detail) ------------------
            InkWell(
              onTap: onTapCard,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(AppRadius.xl),
                bottom: Radius.circular(onAcknowledge != null ? 0 : AppRadius.xl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status icon
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

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),

                          // Sender row
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  alert.sender.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Time chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // --- Action button (only when not handled) ---------------------
            if (onAcknowledge != null) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor,
              ),
              InkWell(
                onTap: onAcknowledge,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.xl),
                ),
                child: Container(
                  height: AppButtonSizes.largeHeight,
                  decoration: BoxDecoration(
                    color: btnBg,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.xl - 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(btnIcon, color: btnFg, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        btnLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: btnFg,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
