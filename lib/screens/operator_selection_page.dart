import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/employees_service.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

/// Real-employees-only picker: fetches from the Mobile API and feeds the
/// API-driven flow at `/api`. When offline, shows the last cached real list
/// (never fake/demo data); with no cache yet, shows a first-time offline
/// state with a retry button.
class OperatorSelectionPage extends StatefulWidget {
  const OperatorSelectionPage({super.key});

  @override
  State<OperatorSelectionPage> createState() => _OperatorSelectionPageState();
}

class _OperatorSelectionPageState extends State<OperatorSelectionPage> {
  String? _selectedOperatorId;
  bool _loading = true;
  bool _fromCache = false;
  DateTime? _cacheUpdatedAt;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();
  List<Operator> _collaborators = [];

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final session = context.read<AppSession>();
    if (session.hasApiConfig) {
      final loaded = await _loadFromApi(session);
      if (loaded) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    await _loadFromCache();
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
      final valid = list
          .where((e) => e.id.trim().isNotEmpty && e.name.trim().isNotEmpty)
          .toList();
      _collaborators = valid;
      _fromCache = false;
      _cacheUpdatedAt = null;
      unawaited(LocalCacheService.instance.saveEmployees(valid));
      return true;
    } catch (e) {
      debugPrint('Employees API unavailable, falling back to cache: $e');
      return false;
    } finally {
      client.dispose();
    }
  }

  Future<void> _loadFromCache() async {
    final cached = await LocalCacheService.instance.getEmployees();
    if (cached == null || cached.items.isEmpty) {
      _collaborators = [];
      _fromCache = false;
      _cacheUpdatedAt = null;
      _loadError =
          'Sem conexão à internet. Conecte-se para carregar os colaboradores.';
      return;
    }
    _collaborators = cached.items;
    _fromCache = true;
    _cacheUpdatedAt = cached.updatedAt;
  }

  void _selectAndGo(Operator op) {
    setState(() => _selectedOperatorId = op.id);
    context.read<AppSession>().selectOperator(op);
    context.go('/api');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final search = _searchController.text.trim().toLowerCase();
    final filtered = search.isEmpty
        ? _collaborators
        : _collaborators
              .where((e) => e.name.toLowerCase().contains(search))
              .toList(growable: false);

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
              : (_collaborators.isEmpty
                    ? _FirstRunOfflineState(
                        message: _loadError ?? 'Sem conexão à internet.',
                        onRetry: _load,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_fromCache) ...[
                            Align(
                              alignment: Alignment.center,
                              child: OfflineIndicator(pendingCount: 0),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Text(
                            'Selecione seu nome',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _fromCache
                                ? 'Modo offline — exibindo dados salvos${_cacheUpdatedAt != null ? ' de ${DateFormat('dd/MM HH:mm').format(_cacheUpdatedAt!.toLocal())}' : ''}.'
                                : 'Se tiver dúvida, peça ajuda ao responsável.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
                          const SizedBox(height: AppSpacing.lg),
                          Expanded(
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final op = filtered[index];
                                return _OperatorTile(
                                  name: op.name,
                                  selected: _selectedOperatorId == op.id,
                                  onTap: () => _selectAndGo(op),
                                );
                              },
                            ),
                          ),
                        ],
                      )),
        ),
      ),
    );
  }
}

class _FirstRunOfflineState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FirstRunOfflineState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 54,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
              label: Text(
                'Tentar novamente',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final bool selected;

  const _OperatorTile({
    required this.name,
    required this.onTap,
    required this.selected,
  });

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
              width: 2,
            ),
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
                child: Icon(
                  selected ? Icons.check : Icons.person,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
