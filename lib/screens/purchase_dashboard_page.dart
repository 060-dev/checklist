import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PurchaseDashboardPage extends StatefulWidget {
  const PurchaseDashboardPage({super.key});

  @override
  State<PurchaseDashboardPage> createState() => _PurchaseDashboardPageState();
}

class _PurchaseDashboardPageState extends State<PurchaseDashboardPage> {
  bool _loading = true;
  String? _error;
  PurchaseDashboard? _dashboard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    if (!session.hasApiConfig || session.selectedOperator == null) {
      if (mounted) {
        setState(() {
          _error = 'Configuração da API ausente.';
          _loading = false;
        });
      }
      return;
    }

    try {
      final client = MobileApiClient(
        apiBaseUrl: session.apiBaseUrl.trim(),
        apiKey: session.apiKey.trim(),
        employeeCode: session.employeeCode,
        requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      );
      final api = MobileApiServices(client: client);
      final dash = await api.getPurchaseDashboard();

      if (mounted) {
        setState(() {
          _dashboard = dash;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          final msg = e is MobileApiException ? e.message : e.toString();
          _error = msg.isNotEmpty ? msg : 'Erro ao carregar dashboard.';
        });
      }
    }
  }

  Widget _buildMetricCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value.toString(),
              style: context.textStyles.headlineMedium?.bold,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard de Compras'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_error != null)
                SliverToBoxAdapter(child: ErrorBanner(message: _error!)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_dashboard != null)
                SliverPadding(
                  padding: AppSpacing.paddingMd,
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildMetricCard(
                        'Total',
                        _dashboard!.totalRequests,
                        Icons.list_alt,
                        AppColors.brandRed,
                      ),
                      _buildMetricCard(
                        'Pendentes',
                        _dashboard!.pendingApproval,
                        Icons.pending_actions,
                        AppColors.warning,
                      ),
                      _buildMetricCard(
                        'Aprovadas',
                        _dashboard!.approved,
                        Icons.check_circle_outline,
                        AppColors.success,
                      ),
                      _buildMetricCard(
                        'Rejeitadas',
                        _dashboard!.rejected,
                        Icons.cancel_outlined,
                        AppColors.error,
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
