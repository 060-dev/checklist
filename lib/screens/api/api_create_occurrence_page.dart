import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ApiCreateOccurrencePage extends StatefulWidget {
  const ApiCreateOccurrencePage({super.key});

  @override
  State<ApiCreateOccurrencePage> createState() => _ApiCreateOccurrencePageState();
}

class _ApiCreateOccurrencePageState extends State<ApiCreateOccurrencePage> {
  bool _submitting = false;
  String? _error;

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  String _priority = 'normal';
  DateTime? _dueAt;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: _dueAt ?? now);
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dueAt ?? now));
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatIsoWithOffset(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = two(local.month);
    final d = two(local.day);
    final hh = two(local.hour);
    final mm = two(local.minute);
    final ss = two(local.second);
    final off = local.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final offAbs = off.abs();
    final offH = two(offAbs.inHours);
    final offM = two(offAbs.inMinutes.remainder(60));
    return '$y-$m-${d}T$hh:$mm:$ss$sign$offH:$offM';
  }

  Future<void> _submit() async {
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

    final due = _dueAt;
    if (due == null) {
      setState(() {
        _submitting = false;
        _error = 'Informe um prazo (due_at).';
      });
      return;
    }

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'priority': _priority,
      'due_at': _formatIsoWithOffset(due),
    };

    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final api = MobileApiServices(client: client);
    try {
      await api.createOccurrence(employeeId: employeeId, idempotencyKey: const Uuid().v4(), payload: payload);
      if (!mounted) return;
      context.pop(true);
    } on MobileApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Create occurrence failed: $e');
      setState(() => _error = 'Falha ao criar ocorrência.');
    } finally {
      client.dispose();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueLabel = _dueAt == null ? 'Selecionar prazo' : _dueAt!.toLocal().toIso8601String();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => context.pop()),
        title: const Text('Nova ocorrência'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((_error ?? '').trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(controller: _title, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _description, textInputAction: TextInputAction.next, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _location, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Local')),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Baixa')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('Alta')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                decoration: const InputDecoration(labelText: 'Prioridade'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickDueAt,
                icon: Icon(Icons.event, color: theme.colorScheme.primary),
                label: Text(dueLabel, overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              SizedBox(
                height: 60,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                  icon: _submitting ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)) : Icon(Icons.send, color: theme.colorScheme.onPrimary),
                  label: Text('Criar ocorrência', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
