import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

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

  final List<Operator> _collaborators = [];

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  List<Operator> _fallbackCollaborators() => const [
        Operator(id: 'op-0', farmId: _demoFarmId, name: 'Marcos', active: true),
        Operator(id: 'op-1', farmId: _demoFarmId, name: 'João', active: true),
        Operator(id: 'op-2', farmId: _demoFarmId, name: 'Maria', active: true),
        Operator(id: 'op-3', farmId: _demoFarmId, name: 'Pedro', active: true),
      ];

  Future<void> _loadCollaborators() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _collaborators
          ..clear()
          ..addAll(_fallbackCollaborators());
        await _saveCollaborators();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _collaborators
          ..clear()
          ..addAll(_fallbackCollaborators());
        await _saveCollaborators();
        return;
      }

      final parsed = <Operator>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final op = Operator.fromJson(item);
          if (op.id.trim().isNotEmpty && op.name.trim().isNotEmpty) {
            parsed.add(op);
          }
        } else if (item is Map) {
          final op = Operator.fromJson(item.cast<String, dynamic>());
          if (op.id.trim().isNotEmpty && op.name.trim().isNotEmpty) {
            parsed.add(op);
          }
        }
      }

      if (parsed.isEmpty) {
        _collaborators
          ..clear()
          ..addAll(_fallbackCollaborators());
        await _saveCollaborators();
        return;
      }

      _collaborators
        ..clear()
        ..addAll(parsed);
      await _saveCollaborators(); // sanitize
    } catch (e) {
      debugPrint('Failed to load collaborators: $e');
      _collaborators
        ..clear()
        ..addAll(_fallbackCollaborators());
      try {
        await _saveCollaborators();
      } catch (e2) {
        debugPrint('Failed to save fallback collaborators: $e2');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveCollaborators() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _collaborators.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Failed to save collaborators: $e');
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

    await _saveCollaborators();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    Text('Equipe de campo',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Cadastre e selecione um funcionário',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _openFakeRegister,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                              width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg)),
                        ),
                        icon: Icon(Icons.person_add,
                            color: theme.colorScheme.primary, size: 22),
                        label: Text('Cadastrar novo colaborador',
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _collaborators.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final op = _collaborators[index];
                          return _OperatorTile(
                            name: op.name,
                            selected: _selectedOperatorId == op.id,
                            onTap: () {
                              setState(() => _selectedOperatorId = op.id);
                              context.read<AppSession>().selectOperator(op);
                              context.go('/areas');
                            },
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

  const _OperatorTile(
      {required this.name, required this.onTap, required this.selected});

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
            color: (selected
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.primary.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color: (selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.22)),
                width: 2),
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
                child: Icon(selected ? Icons.check : Icons.person,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: theme.colorScheme.primary, size: 22),
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
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          bottomInset + AppSpacing.lg),
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
          Text('Cadastrar colaborador',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          Text('Cadastre um novo colaborador para usar no checklist.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => context.pop(v),
            decoration: InputDecoration(
              labelText: 'Nome do colaborador',
              hintText: 'Ex.: Ana',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => context.pop(_controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text('Adicionar',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
