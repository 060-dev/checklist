import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/error_banner.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

class _DraftItem {
  int? id;
  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  final TextEditingController unit = TextEditingController(text: 'un');

  void dispose() {
    description.dispose();
    quantity.dispose();
    unit.dispose();
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'description': description.text.trim(),
    'quantity': quantity.text.trim(),
    'unit': unit.text.trim(),
  };
}

class CreatePurchasePage extends StatefulWidget {
  final PurchaseRequestDetail? initialDetail;

  const CreatePurchasePage({super.key, this.initialDetail});

  @override
  State<CreatePurchasePage> createState() => _CreatePurchasePageState();
}

class _CreatePurchasePageState extends State<CreatePurchasePage> {
  bool _submitting = false;
  String? _error;

  int? _selectedFarmId;
  int? _selectedSectorId;
  final List<_DraftItem> _items = [_DraftItem()]; // start with 1 empty item

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _selectedFarmId = widget.initialDetail!.farmId;
      _selectedSectorId = widget.initialDetail!.sectorId;
      _items.clear();
      for (final it in widget.initialDetail!.items) {
        final draft = _DraftItem();
        draft.id = it.id;
        draft.description.text = it.productName.isNotEmpty
            ? it.productName
            : (it.description ?? '');
        draft.quantity.text = it.quantity.toString();
        draft.unit.text = it.unit;
        _items.add(draft);
      }
      if (_items.isEmpty) _items.add(_DraftItem());
    }
  }

  @override
  void dispose() {
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_DraftItem());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final it = _items.removeAt(index);
      it.dispose();
    });
  }

  Future<void> _submit(bool submitNow) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final session = context.read<AppSession>();
    final employeeId = session.selectedOperator?.id ?? '';
    if (!session.hasApiConfig || employeeId.isEmpty) {
      setState(() {
        _submitting = false;
        _error = 'Sem configuração da API ou funcionário não selecionado.';
      });
      return;
    }

    final farmIdToSubmit =
        _selectedFarmId ??
        (context.read<AppSession>().purchaseContext?.farms.length == 1
            ? context.read<AppSession>().purchaseContext!.farms.first.id
            : null);

    if (farmIdToSubmit == null) {
      setState(() {
        _submitting = false;
        _error = 'Selecione a fazenda.';
      });
      return;
    }

    if (_selectedSectorId == null) {
      setState(() {
        _submitting = false;
        _error = 'Selecione o setor.';
      });
      return;
    }

    final validItems = _items.where((it) {
      return it.description.text.trim().isNotEmpty &&
          it.quantity.text.trim().isNotEmpty &&
          it.unit.text.trim().isNotEmpty;
    }).toList();

    if (validItems.isEmpty) {
      setState(() {
        _submitting = false;
        _error =
            'Preencha pelo menos um item (descrição, quantidade e unidade).';
      });
      return;
    }

    final payload = <String, dynamic>{
      'farm_id': farmIdToSubmit,
      'territory_area_id': _selectedSectorId,
      'submit': submitNow,
      'items': validItems.map((e) => e.toJson()).toList(),
    };

    final isOnline = Connectivity.instance.isOnline;

    if (isOnline) {
      final client = MobileApiClient(
        apiBaseUrl: session.apiBaseUrl.trim(),
        apiKey: session.apiKey.trim(),
        employeeCode: session.employeeCode,
        requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      );
      final api = MobileApiServices(client: client);
      try {
        final idempotencyKey = const Uuid().v4();
        if (widget.initialDetail != null) {
          await api.updatePurchase(
            requestId: widget.initialDetail!.id.toString(),
            idempotencyKey: idempotencyKey,
            payload: payload,
          );
          if (submitNow) {
            await api.submitPurchase(
              requestId: widget.initialDetail!.id.toString(),
              idempotencyKey: const Uuid().v4(),
            );
          }
          if (!mounted) return;
          context.pop(true);
        } else {
          final created = await api.createPurchase(
            idempotencyKey: idempotencyKey,
            payload: payload,
          );
          if (!mounted) return;
          final newId =
              (created['request_id'] as num?)?.toString() ??
              (created['id'] as num?)?.toString() ??
              '';
          context.pop(newId.isNotEmpty ? newId : true);
        }
      } on MobileApiException catch (e) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Erro interno ao criar solicitação.';
          _submitting = false;
        });
      }
    } else {
      // Offline queue logic
      try {
        if (widget.initialDetail != null) {
          await OfflineQueueService.instance.enqueueApiMutation(
            method: 'PUT',
            path: '/purchases/requests/${widget.initialDetail!.id}',
            jsonBody: payload,
            employeeId: employeeId,
            employeeCode: session.employeeCode,
          );
          if (submitNow) {
            await OfflineQueueService.instance.enqueueApiMutation(
              method: 'POST',
              path: '/purchases/requests/${widget.initialDetail!.id}/submit',
              jsonBody: const {},
              employeeId: employeeId,
              employeeCode: session.employeeCode,
            );
          }
        } else {
          await OfflineQueueService.instance.enqueueApiMutation(
            method: 'POST',
            path: '/purchases/requests',
            jsonBody: payload,
            employeeId: employeeId,
            employeeCode: session.employeeCode,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitação salva offline. Será sincronizada quando houver conexão.',
            ),
          ),
        );
        context.pop(true);
      } catch (e) {
        setState(() {
          _error = 'Falha ao salvar offline.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<AppSession>().purchaseContext;
    final farms = ctx?.farms ?? [];

    List<PurchaseSector> availableSectors = [];

    // Default to the first farm if there's only one available
    final actualFarmId =
        _selectedFarmId ?? (farms.length == 1 ? farms.first.id : null);

    if (actualFarmId != null) {
      final selectedFarm = farms.where((f) => f.id == actualFarmId).firstOrNull;
      if (selectedFarm != null) {
        availableSectors = selectedFarm.sectors;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.initialDetail != null ? 'Editar Rascunho' : 'Nova Solicitação',
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(message: _error!),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (farms.length > 1) ...[
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Fazenda',
                          border: OutlineInputBorder(),
                        ),
                        // ignore: deprecated_member_use
                        value: _selectedFarmId,
                        items: farms.map((f) {
                          return DropdownMenuItem<int>(
                            value: f.id,
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFarmId = val;
                            _selectedSectorId = null; // reset sector
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Setor',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Selecione'),
                      // ignore: deprecated_member_use
                      value: _selectedSectorId,
                      items: availableSectors.map((s) {
                        return DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedSectorId = val;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Itens', style: context.textStyles.titleLarge?.bold),
                    const SizedBox(height: AppSpacing.sm),
                    ..._items.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: const BorderSide(color: AppColors.brandBorder),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: AppSpacing.paddingMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Item ${i + 1}',
                                    style: context.textStyles.titleMedium?.bold,
                                  ),
                                  if (_items.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () => _removeItem(i),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: item.description,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 2,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Descrição (Ex: Cano PVC)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: item.quantity,
                                      decoration: const InputDecoration(
                                        labelText: 'Qtd.',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextField(
                                      controller: item.unit,
                                      decoration: const InputDecoration(
                                        labelText: 'Unid.',
                                        hintText: 'ex: cx, kg',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Item'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _submit(false),
                      style: OutlinedButton.styleFrom(
                        padding: AppSpacing.paddingMd,
                        side: const BorderSide(color: AppColors.brandRed),
                        foregroundColor: AppColors.brandRed,
                      ),
                      child: const Text('Salvar Rascunho'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _submit(true),
                      style: ElevatedButton.styleFrom(
                        padding: AppSpacing.paddingMd,
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: AppColors.white,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
