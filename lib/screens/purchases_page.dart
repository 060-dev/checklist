import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  static const int _pageSize = 25;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PurchaseRequestSummary> _items = const [];
  String _statusFilter = 'pending';
  bool _fromCache = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
      _items = const [];
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
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      final res = await api.listPurchases(
        status: _statusFilter,
        page: 1,
        pageSize: _pageSize,
      );
      final items = res.items;
      unawaited(LocalCacheService.instance.savePurchases(employeeId, items));
      if (mounted) {
        setState(() {
          _items = items;
          _hasMore = res.page < res.pages;
          _currentPage = res.page;
          _fromCache = false;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[PurchasesPage] fetch error: $e');
      final cached = await LocalCacheService.instance.getPurchases(employeeId);
      if (mounted) {
        setState(() {
          if (cached != null) {
            _items = cached.items
                .where((item) => item.status == _statusFilter)
                .toList();
            _fromCache = true;
            _error = null;
          } else {
            _error = 'Falha ao carregar compras e sem dados offline.';
            _items = const [];
          }
          _hasMore = false; // Disable pagination when offline
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _fromCache) return;

    setState(() {
      _loadingMore = true;
    });

    final session = context.read<AppSession>();
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);

    try {
      final nextPage = _currentPage + 1;
      final res = await api.listPurchases(
        status: _statusFilter,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _items = [..._items, ...res.items];
          _hasMore = res.page < res.pages;
          _currentPage = res.page;
          _loadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[PurchasesPage] loadMore error: $e');
      if (mounted) {
        setState(() {
          _loadingMore = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Falha ao carregar mais itens')));
        });
      }
    }
  }

  void _onStatusChanged(String status) {
    if (_statusFilter == status) return;
    setState(() {
      _statusFilter = status;
    });
    _load();
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppSpacing.horizontalMd,
      child: Row(
        children: [
          _filterChip('Pendentes', 'pending'),
          const SizedBox(width: AppSpacing.sm),
          _filterChip('Rascunhos', 'draft'),
          const SizedBox(width: AppSpacing.sm),
          _filterChip('Aprovadas', 'approved'),
          const SizedBox(width: AppSpacing.sm),
          _filterChip('Rejeitadas', 'rejected'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _onStatusChanged(value),
      selectedColor: AppColors.brandRed,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.brandInk,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textLight),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma solicitação encontrada.',
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium?.withColor(
                AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(PurchaseRequestSummary item) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/compras/${item.id}');
        },
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.number.isNotEmpty ? item.number : 'Novo Pedido',
                    style: context.textStyles.titleMedium?.bold,
                  ),
                  _buildStatusBadge(item.status),
                ],
              ),
              if (item.name != null && item.name!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.name!,
                  style: context.textStyles.bodyMedium?.bold,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${item.itemCount} ite${item.itemCount == 1 ? 'm' : 'ns'}',
                    style: context.textStyles.bodySmall?.withColor(
                      AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(
                    Icons.landscape_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.farmName.isNotEmpty ? item.farmName : 'Fazenda Indefinida',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.withColor(
                        AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.paddingMd,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildItem(_items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compras'),
        centerTitle: false,
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildStatusFilter(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/compras/nova');
        },
        backgroundColor: AppColors.brandRed,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              if (_error != null) ErrorBanner(message: _error!),
              if (_fromCache && _error == null)
                Container(
                  width: double.infinity,
                  color: AppColors.warningLight,
                  padding: AppSpacing.paddingSm,
                  child: const Text(
                    'Modo offline (mostrando itens em cache)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }
}
