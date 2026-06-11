import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PecuariaChecklistTypePage extends StatelessWidget {
  const PecuariaChecklistTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;
    final area = session.selectedArea;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              context.pop();
            } else {
              context.go('/areas');
            }
          },
        ),
        title: Text(area?.title ?? 'Pecuária'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'O que você quer preencher?',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (op != null)
                Text(
                  'Funcionário: ${op.name}',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    _ChecklistTypeCard(
                      title: 'Checklists por Curral',
                      description: 'Confinamento, manutenção e bebedouro por curral',
                      icon: Icons.holiday_village_rounded,
                      tone: AppColors.info,
                      onTap: () => context.push('/pecuaria/currais'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ChecklistTypeCard(
                      title: 'Checklists Gerais',
                      description: 'Alimentação e outras rotinas gerais da pecuária',
                      icon: Icons.playlist_add_check_circle_rounded,
                      tone: AppColors.success,
                      onTap: () => context.push('/pecuaria/gerais'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  const _ChecklistTypeCard({required this.title, required this.description, required this.icon, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: primary.withValues(alpha: 0.18), width: 2),
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
                child: Icon(icon, color: theme.colorScheme.onPrimary, size: 40),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
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
