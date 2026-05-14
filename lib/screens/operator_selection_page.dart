import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/operator_service.dart';
import 'package:morro_do_peo/theme.dart';

class OperatorSelectionPage extends StatefulWidget {
  const OperatorSelectionPage({super.key});

  @override
  State<OperatorSelectionPage> createState() => _OperatorSelectionPageState();
}

class _OperatorSelectionPageState extends State<OperatorSelectionPage> {
  late Future<List<Operator>> _future;

  void _reload() {
    setState(() {
      _future = OperatorService().listOperators(active: true);
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quem vai preencher?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Toque no seu nome',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Isso ajuda a identificar quem fez o checklist',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: FutureBuilder<List<Operator>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _OperatorLoadingState();
                    }

                    if (snapshot.hasError) {
                      return _OperatorEmptyState(
                        title: 'Não foi possível carregar',
                        subtitle: 'Verifique a internet e tente novamente.',
                        buttonLabel: 'Tentar novamente',
                        onRetry: _reload,
                      );
                    }

                    final list = snapshot.data ?? const <Operator>[];
                    if (list.isEmpty) {
                      return _OperatorEmptyState(
                        title: 'Nenhum operador encontrado',
                        subtitle: 'Peça ao gestor para cadastrar os operadores.',
                        buttonLabel: 'Atualizar lista',
                        onRetry: _reload,
                      );
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final op = list[index];
                        return _OperatorTile(
                          name: op.name,
                          onTap: () {
                            final opName = Uri.encodeComponent(op.name);
                            final opId = Uri.encodeComponent(op.id);
                            context.go('/areas?op=$opName&opId=$opId');
                          },
                        );
                      },
                    );
                  },
                )
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

  const _OperatorTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Selecionar operador $name',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppColors.primaryGreen, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperatorLoadingState extends StatelessWidget {
  const _OperatorLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primaryGreen,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Carregando operadores…',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aguarde um instante',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OperatorEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onRetry;

  const _OperatorEmptyState({required this.title, required this.subtitle, required this.buttonLabel, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.group, color: AppColors.primaryGreen, size: 34),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                  label: Text(buttonLabel, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
