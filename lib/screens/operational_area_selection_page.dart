import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class OperationalAreaSelectionPage extends StatelessWidget {
  const OperationalAreaSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              context.pop();
            } else {
              context.go('/collaborators');
            }
          },
        ),
        title: const Text('Escolha a área'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                op == null ? 'Olá' : 'Olá, ${op.name}',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Selecione a área operacional',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: OperationalAreasRepository.available.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final area = OperationalAreasRepository.available[index];
                    return OperationalAreaCard(
                      area: area,
                      onTap: () {
                        context.read<AppSession>().selectOperationalArea(area);
                        if (area.id == OperationalAreasRepository.pecuariaId) {
                          context.push('/pecuaria');
                        } else {
                          context.push('/checklists');
                        }
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

/// Big card suitable for bright outdoor use.
class OperationalAreaCard extends StatelessWidget {
  final OperationalAreaDefinition area;
  final VoidCallback onTap;

  const OperationalAreaCard({super.key, required this.area, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Selecionar área ${area.title}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: primary.withValues(alpha: 0.24), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(area.icon, color: theme.colorScheme.onPrimary, size: 40),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      area.description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.arrow_forward_ios, color: primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
