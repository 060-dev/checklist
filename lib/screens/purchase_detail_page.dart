import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PurchaseDetailPage extends StatefulWidget {
  final String requestId;

  const PurchaseDetailPage({
    super.key,
    required this.requestId,
  });

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  bool _loading = true;
  String? _error;
  PurchaseRequestDetail? _detail;
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
        _error = 'Sem configuração da API ou funcionário não selecionado.';
      });
      return;
    }

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);

    try {
      final detail = await api.getPurchaseDetail(requestId: widget.requestId);
      unawaited(LocalCacheService.instance.savePurchaseDetail(
        employeeId,
        widget.requestId,
        detail.toJson(),
      ));
      if (mounted) {
        setState(() {
          _detail = detail;
          _fromCache = false;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[PurchaseDetailPage] fetch error: $e');
      final cached = await LocalCacheService.instance.getPurchaseDetail(
        employeeId,
        widget.requestId,
      );
      if (mounted) {
        setState(() {
          if (cached != null) {
            _detail = PurchaseRequestDetail(cached.$2);
            _fromCache = true;
            _error = null;
          } else {
            _error = 'Falha ao carregar detalhes e sem dados offline.';
          }
          _loading = false;
        });
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'draft':
        bg = AppColors.surfaceVariant;
        fg = AppColors.textPrimary;
        label = 'Rascunho';
        break;
      case 'pending':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Pendente';
        break;
      case 'approved':
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = 'Aprovada';
        break;
      case 'rejected':
      case 'canceled':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        label = status == 'canceled' ? 'Cancelada' : 'Rejeitada';
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_error != null)
                SliverToBoxAdapter(child: ErrorBanner(message: _error!)),
              if (_fromCache && _error == null)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    color: AppColors.warningLight,
                    padding: AppSpacing.paddingSm,
                    child: const Text(
                      'Modo offline (mostrando dados em cache)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ),
              if (_loading)
                SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(strokeWidth: 3.0)),
                )
              else if (_detail != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _detail!.number.isNotEmpty ? _detail!.number : 'N/A',
                              style: context.textStyles.headlineSmall?.bold,
                            ),
                            _buildStatusBadge(_detail!.status),
                          ],
                        ),
                        if (_detail!.name != null && _detail!.name!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _detail!.name!,
                            style: context.textStyles.titleMedium,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const Divider(color: AppColors.brandBorder),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Icon(Icons.landscape_outlined, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _detail!.farmName,
                                style: context.textStyles.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _detail!.sectorName,
                                style: context.textStyles.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                        if (_detail!.notes != null && _detail!.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Observações',
                            style: context.textStyles.titleMedium?.bold,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _detail!.notes!,
                            style: context.textStyles.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Itens (${_detail!.items.length})',
                          style: context.textStyles.titleLarge?.bold,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ..._detail!.items.map((item) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              side: const BorderSide(color: AppColors.brandBorder),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: AppSpacing.paddingMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName.isNotEmpty ? item.productName : (item.description ?? 'Sem descrição'),
                                          style: context.textStyles.titleMedium?.bold,
                                        ),
                                        if (item.description != null && item.productName.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            item.description!,
                                            style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.quantity} ${item.unit}',
                                        style: context.textStyles.titleMedium?.bold,
                                      ),
                                      if (item.status.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          item.status,
                                          style: context.textStyles.bodySmall?.withColor(AppColors.brandRed),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
