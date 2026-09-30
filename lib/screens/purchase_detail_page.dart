import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

class PurchaseDetailPage extends StatefulWidget {
  final String requestId;

  const PurchaseDetailPage({super.key, required this.requestId});

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
      unawaited(
        LocalCacheService.instance.savePurchaseDetail(
          employeeId,
          widget.requestId,
          detail.toJson(),
        ),
      );
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
      if (e is MobileApiException && e.statusCode == 403) {
        unawaited(session.refreshPurchaseContext());
        if (mounted) {
          setState(() {
            _error = e.message.isNotEmpty ? e.message : 'Acesso negado.';
            _loading = false;
            _fromCache = false;
          });
        }
        return;
      }
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

  String _getDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Pedido';
    if (name.trim().startsWith('SOL-')) return 'Pedido';
    return name.trim();
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
      case 'submitted':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Pendente';
        break;
      case 'in_triage':
      case 'triage':
      case 'awaiting_validation':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Em Validação';
        break;
      case 'in_quote':
      case 'quoting':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Em Cotação';
        break;
      case 'in_progress':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        label = 'Em Andamento';
        break;
      case 'in_approval':
      case 'awaiting_approval':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Em Aprovação';
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String _getItemStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Rascunho';
      case 'pending':
        return 'Pendente';
      case 'in_triage':
        return 'Em Triagem';
      case 'awaiting_validation':
        return 'Em Validação';
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'canceled':
        return 'Cancelado';
      case 'adjusted':
        return 'Ajustado';
      case 'quoting':
        return 'Em Cotação';
      case 'in_progress':
        return 'Em Andamento';
      default:
        return status;
    }
  }

  bool _canEditOrSubmit(AppSession session) {
    if (_detail == null || _detail!.status != 'draft') return false;
    final cap = session.purchaseCapabilities;
    if (!cap.editOwnRequests) return false;
    final isOwn =
        _detail!.requesterId == (session.purchaseCurrentUser?.id ?? 0);
    return isOwn || cap.createForOthers;
  }

  bool _canManage(AppSession session) {
    if (_detail == null) return false;
    return session.purchaseCapabilities.manage;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final canEditSubmit = _canEditOrSubmit(session);
    final canManage = _canManage(session);
    final showMenu = canEditSubmit || canManage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
        actions: [
          if (showMenu)
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'edit') {
                  context.push('/compras/nova', extra: _detail).then((res) {
                    if (res == true) _load();
                  });
                } else if (val == 'submit') {
                  final isOnline = Connectivity.instance.isOnline;
                  if (isOnline) {
                    final client = MobileApiClient(
                      apiBaseUrl: session.apiBaseUrl.trim(),
                      apiKey: session.apiKey.trim(),
                      employeeCode: session.employeeCode,
                      requestTimeout: Duration(
                        seconds: session.requestTimeoutSeconds,
                      ),
                    );
                    final api = MobileApiServices(client: client);
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const Center(child: CircularProgressIndicator()),
                      );
                      await api.submitPurchase(
                        requestId: _detail!.id.toString(),
                        idempotencyKey: const Uuid().v4(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context); // close dialog
                      _load();
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context); // close dialog
                      final msg = e is MobileApiException
                          ? e.message
                          : e.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao enviar: $msg')),
                      );
                    }
                  } else {
                    try {
                      await OfflineQueueService.instance.enqueueApiMutation(
                        method: 'POST',
                        path: '/purchases/requests/${_detail!.id}/submit',
                        jsonBody: const {},
                        employeeId:
                            session.selectedOperator?.id.toString() ?? '',
                        employeeCode: session.employeeCode,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Envio salvo offline. Será sincronizado depois.',
                          ),
                        ),
                      );
                      _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Falha ao salvar offline.'),
                        ),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                if (canEditSubmit) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar Solicitação'),
                  ),
                  const PopupMenuItem(
                    value: 'submit',
                    child: Text('Enviar Solicitação'),
                  ),
                ],
                if (canManage) ...[
                  if (canEditSubmit) const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Text('Ações Operacionais'),
                  ),
                ],
              ],
            ),
        ],
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
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3.0),
                  ),
                )
              else if (_detail != null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getDisplayName(_detail!.name),
                              style: context.textStyles.headlineSmall?.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _buildStatusBadge(_detail!.status),
                        ],
                      ),
                      // Removed name from below title
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.brandBorder),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.landscape_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
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
                          const Icon(
                            Icons.business_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _detail!.sectorName,
                              style: context.textStyles.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      if (_detail!.notes != null &&
                          _detail!.notes!.isNotEmpty) ...[
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
                            side: const BorderSide(
                              color: AppColors.brandBorder,
                            ),
                          ),
                          elevation: 0,
                          child: Padding(
                            padding: AppSpacing.paddingMd,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName.isNotEmpty
                                                ? item.productName
                                                : (item.description ??
                                                      'Sem descrição'),
                                            style: context
                                                .textStyles
                                                .titleMedium
                                                ?.bold,
                                          ),
                                          if (item.description != null &&
                                              item.productName.isNotEmpty) ...[
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              item.description!,
                                              style: context
                                                  .textStyles
                                                  .bodyMedium
                                                  ?.withColor(
                                                    AppColors.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.quantity} ${item.unit}',
                                          style: context
                                              .textStyles
                                              .titleMedium
                                              ?.bold,
                                        ),
                                        if (item.status.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            _getItemStatusLabel(item.status),
                                            style: context.textStyles.bodySmall
                                                ?.withColor(AppColors.brandRed),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (canManage) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: AppColors.textSecondary,
                                        ),
                                        onSelected: (val) {
                                          if (val == 'triage') {
                                            _showTriageDialog(item);
                                          } else if (val == 'quote') {
                                            _showQuoteDialog(item);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'triage',
                                            child: Text('Fazer Triagem'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'quote',
                                            child: Text('Adicionar Cotação'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                if (item.quotes.isNotEmpty) ...[
                                  const Divider(height: 32),
                                  Text(
                                    'Cotações',
                                    style: context.textStyles.titleSmall?.bold,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ...item.quotes.map(
                                    (q) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: q.id == item.selectedQuoteId
                                            ? AppColors.successLight.withValues(
                                                alpha: 0.3,
                                              )
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: q.id == item.selectedQuoteId
                                              ? AppColors.success
                                              : AppColors.brandBorder,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  q.supplierName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Valor un: R\$ ${q.unitPrice.toStringAsFixed(2)}',
                                                ),
                                                if (q.conditions != null &&
                                                    q.conditions!.isNotEmpty)
                                                  Text(
                                                    'Condições: ${q.conditions}',
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (canManage &&
                                              item.selectedQuoteId == null)
                                            TextButton(
                                              onPressed: () =>
                                                  _selectQuote(item, q),
                                              child: const Text('Selecionar'),
                                            )
                                          else if (q.id == item.selectedQuoteId)
                                            const Icon(
                                              Icons.check_circle,
                                              color: AppColors.success,
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
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Anexos (${_detail!.attachments.length})',
                        style: context.textStyles.titleLarge?.bold,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._detail!.attachments.map((att) {
                        return ListTile(
                          leading: const Icon(
                            Icons.attachment,
                            color: AppColors.brandRed,
                          ),
                          title: Text(att.originalName),
                          subtitle: Text(
                            '${(att.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          ),
                          onTap: () {
                            // TODO: view attachment
                          },
                        );
                      }),
                      if (canEditSubmit) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () => _uploadAttachment(session),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Adicionar Anexo'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAttachment(AppSession session) async {
    if (_detail == null) return;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final isOnline = Connectivity.instance.isOnline;
      if (!isOnline) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'É necessário conexão com a internet para enviar anexos.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await image.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
      );

      final client = MobileApiClient(
        apiBaseUrl: session.apiBaseUrl.trim(),
        apiKey: session.apiKey.trim(),
        employeeCode: session.employeeCode,
        requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      );
      final api = MobileApiServices(client: client);

      await api.uploadPurchaseAttachment(
        target: 'request',
        targetId: _detail!.id.toString(),
        idempotencyKey: const Uuid().v4(),
        file: multipartFile,
      );

      if (!mounted) return;
      Navigator.pop(context); // close dialog
      _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      final msg = e is MobileApiException ? e.message : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao anexar: $msg')));
    }
  }

  void _showTriageDialog(PurchaseItem item) {
    showDialog(
      context: context,
      builder: (context) {
        String action = 'accept';
        final reasonCtrl = TextEditingController();
        final qtyCtrl = TextEditingController(text: item.quantity);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Triagem: ${item.productName.isNotEmpty ? item.productName : item.description}',
                style: const TextStyle(fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      decoration: const InputDecoration(labelText: 'Ação'),
                      items: const [
                        DropdownMenuItem(
                          value: 'accept',
                          child: Text('Aceitar'),
                        ),
                        DropdownMenuItem(
                          value: 'return',
                          child: Text('Devolver ao solicitante'),
                        ),
                        DropdownMenuItem(
                          value: 'cancel',
                          child: Text('Cancelar item'),
                        ),
                        DropdownMenuItem(
                          value: 'adjust',
                          child: Text('Ajustar quantidade'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => action = val);
                      },
                    ),
                    if (action == 'adjust') ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nova Quantidade',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                    if (action == 'return' ||
                        action == 'cancel' ||
                        action == 'adjust') ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: reasonCtrl,
                        decoration: InputDecoration(
                          labelText:
                              'Motivo ${action == 'adjust' ? '(opcional)' : '(obrigatório)'}',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () {
                    if ((action == 'return' || action == 'cancel') &&
                        reasonCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Motivo é obrigatório')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _submitTriage(
                      item: item,
                      action: action,
                      reason: reasonCtrl.text.trim(),
                      quantity: action == 'adjust'
                          ? double.tryParse(qtyCtrl.text.replaceAll(',', '.'))
                          : null,
                    );
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitTriage({
    required PurchaseItem item,
    required String action,
    String? reason,
    num? quantity,
  }) async {
    final isOnline = Connectivity.instance.isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É necessário internet para triagem.')),
      );
      return;
    }

    final session = context.read<AppSession>();
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      employeeCode: session.employeeCode,
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await api.triagePurchaseItem(
        itemId: item.id.toString(),
        idempotencyKey: const Uuid().v4(),
        action: action,
        reason: reason,
        quantity: quantity,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      final msg = e is MobileApiException ? e.message : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro na triagem: $msg')));
    }
  }

  Future<void> _showQuoteDialog(PurchaseItem item) async {
    final session = context.read<AppSession>();
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl,
      apiKey: session.apiKey,
      employeeCode: session.employeeCode ?? '',
    );
    final api = MobileApiServices(client: client);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<Supplier> suppliers;
    try {
      suppliers = await api.listSuppliers();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar fornecedores: $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum fornecedor cadastrado.')),
      );
      return;
    }

    int? supplierId = suppliers.first.id;
    final priceCtrl = TextEditingController();
    final conditionsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Cotação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor',
                      ),
                      items: suppliers.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => supplierId = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Valor Unitário',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: conditionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Condições de Pagamento (opcional)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final priceStr = priceCtrl.text.trim().replaceAll(',', '.');
                    final price = double.tryParse(priceStr);
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Valor inválido.')),
                      );
                      return;
                    }
                    Navigator.pop(context);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final res = await api.createOrUpdateQuote(
                        itemId: item.id,
                        supplierId: supplierId!,
                        unitPrice: price,
                        conditions: conditionsCtrl.text.trim(),
                        idempotencyKey: const Uuid().v4(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context); // close loading
                      if (res.success) {
                        _load();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.message ?? 'Erro ao salvar cotação',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context); // close loading
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectQuote(PurchaseItem item, PurchaseItemQuote quote) async {
    final session = context.read<AppSession>();
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl,
      apiKey: session.apiKey,
      employeeCode: session.employeeCode ?? '',
    );
    final api = MobileApiServices(client: client);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await api.selectQuote(
        itemId: item.id,
        quoteId: quote.id,
        idempotencyKey: const Uuid().v4(),
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading
      if (res.success) {
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Erro ao selecionar cotação')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }
}
