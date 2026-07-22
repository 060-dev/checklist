import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/employees_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

/// Hybrid operator picker: tries the Mobile API first (real employees, feeds
/// the API-driven flow at `/api`); falls back to a locally cached / default
/// collaborator list (feeds the offline checklist flow at `/areas`) when the
/// API is unreachable or unconfigured.
class OperatorSelectionPage extends StatefulWidget {
  const OperatorSelectionPage({super.key});

  @override
  State<OperatorSelectionPage> createState() => _OperatorSelectionPageState();
}

class _OperatorSelectionPageState extends State<OperatorSelectionPage> {
  static const String _demoFarmId = 'morro-do-peao-demo';
  static const String _prefsKey = 'collaborators_v1';

  String? _selectedOperatorId;
  bool _loading = true;
  bool _fromApi = false;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();
  final List<Operator> _collaborators = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Operator> _fallbackCollaborators() => const [
        Operator(id: 'op-0', farmId: _demoFarmId, name: 'Marcos', active: true),
        Operator(id: 'op-1', farmId: _demoFarmId, name: 'João', active: true),
        Operator(id: 'op-2', farmId: _demoFarmId, name: 'Maria', active: true),
        Operator(id: 'op-3', farmId: _demoFarmId, name: 'Pedro', active: true),
      ];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final session = context.read<AppSession>();
    if (session.hasApiConfig) {
      final loadedFromApi = await _loadFromApi(session);
      if (loadedFromApi) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    await _loadFromLocalStorage();
    if (mounted) setState(() => _loading = false);
  }

  /// Returns true when the API list loaded successfully (even if empty).
  Future<bool> _loadFromApi(AppSession session) async {
    final client = MobileApiClient(
      apiBaseUrl: session.apiBaseUrl.trim(),
      apiKey: session.apiKey.trim(),
      requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
      uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
    );
    final svc = EmployeesService(client: client);
    try {
      final list = await svc.listEmployees();
      _collaborators
        ..clear()
        ..addAll(list.where((e) => e.id.trim().isNotEmpty && e.name.trim().isNotEmpty));
      _fromApi = true;
      return true;
    } catch (e) {
      debugPrint('Employees API unavailable, falling back to local list: $e');
      return false;
    } finally {
      client.dispose();
    }
  }

  Future<void> _loadFromLocalStorage() async {
    _fromApi = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      List<Operator> parsed = const [];

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final out = <Operator>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final op = Operator.fromJson(item);
              if (op.id.trim().isNotEmpty && op.name.trim().isNotEmpty) out.add(op);
            } else if (item is Map) {
              final op = Operator.fromJson(item.cast<String, dynamic>());
              if (op.id.trim().isNotEmpty && op.name.trim().isNotEmpty) out.add(op);
            }
          }
          parsed = out;
        }
      }

      _collaborators
        ..clear()
        ..addAll(parsed.isEmpty ? _fallbackCollaborators() : parsed);
      await _saveLocalCollaborators();
    } catch (e) {
      debugPrint('Failed to load local collaborators: $e');
      _collaborators
        ..clear()
        ..addAll(_fallbackCollaborators());
    }
  }

  Future<void> _saveLocalCollaborators() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _collaborators.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Failed to save local collaborators: $e');
    }
  }

  Future<void> _openFakeRegister() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => const _FakeRegisterSheet(),
    );

    if (!mounted) return;
    final clean = (name ?? '').trim();
    if (clean.isEmpty) return;

    setState(() {
      _collaborators.insert(
        0,
        Operator(
          id: 'op-${DateTime.now().millisecondsSinceEpoch}',
          farmId: _demoFarmId,
          name: clean,
          active: true,
        ),
      );
    });

    await _saveLocalCollaborators();
  }

  Future<void> _confirmAndSelect(Operator op) async {
    setState(() => _selectedOperatorId = op.id);

    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text('Você é ${op.name}?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Não')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Sim')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    context.read<AppSession>().selectOperator(op);
    context.go(_fromApi ? '/api' : '/areas');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final search = _searchController.text.trim().toLowerCase();
    final filtered = search.isEmpty
        ? _collaborators
        : _collaborators.where((e) => e.name.toLowerCase().contains(search)).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Funcionários'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((_loadError ?? '').trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: Text(_loadError!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('Selecione seu nome', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _fromApi ? 'Se tiver dúvida, peça ajuda ao responsável.' : 'Sem conexão com o servidor — usando lista salva neste aparelho.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar pelo nome',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!_fromApi) ...[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _openFakeRegister,
                          icon: Icon(Icons.person_add, color: theme.colorScheme.primary, size: 22),
                          label: Text('Cadastrar novo colaborador', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final op = filtered[index];
                          return _OperatorTile(
                            name: op.name,
                            selected: _selectedOperatorId == op.id,
                            onTap: () => _confirmAndSelect(op),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OperatorTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final bool selected;

  const _OperatorTile({required this.name, required this.onTap, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Selecionar colaborador $name',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: (selected ? theme.colorScheme.primary.withValues(alpha: 0.14) : theme.colorScheme.primary.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: (selected ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.22)), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(selected ? Icons.check : Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: theme.colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeRegisterSheet extends StatefulWidget {
  const _FakeRegisterSheet();

  @override
  State<_FakeRegisterSheet> createState() => _FakeRegisterSheetState();
}

class _FakeRegisterSheetState extends State<_FakeRegisterSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomInset + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Cadastrar colaborador', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          Text('Cadastre um novo colaborador para usar no checklist.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => context.pop(v),
            decoration: InputDecoration(
              labelText: 'Nome do colaborador',
              hintText: 'Ex.: Ana',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => context.pop(_controller.text),
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text('Adicionar', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
