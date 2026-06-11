import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/data/checklists_repository.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PecuariaGeneralChecklistSelectionPage extends StatelessWidget {
  const PecuariaGeneralChecklistSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;

    final list = ChecklistsRepository.availableForArea(OperationalAreasRepository.pecuariaId).where((c) => !c.appliesPerPen).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              context.pop();
            } else {
              context.go('/pecuaria');
            }
          },
        ),
        title: const Text('Checklists gerais'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Checklists Gerais da Pecuária',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Escolha o checklist',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (op != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Funcionário: ${op.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final checklist = list[index];
                    final status = session.statusForGeneralChecklistToday(checklist.id);
                    return _GeneralChecklistCard(
                      checklist: checklist,
                      status: status,
                      onTap: () {
                        context.read<AppSession>().startChecklist(checklist);
                        context.push('/checklists/${checklist.id}/questions');
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

class _GeneralChecklistCard extends StatelessWidget {
  final ChecklistDefinition checklist;
  final ChecklistDayStatus status;
  final VoidCallback onTap;

  const _GeneralChecklistCard({required this.checklist, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final (label, tone) = switch (status) {
      ChecklistDayStatus.pendente => ('Pendente', AppColors.info),
      ChecklistDayStatus.preenchido => ('Preenchido', AppColors.success),
      ChecklistDayStatus.comAlerta => ('Com alerta', AppColors.warning),
    };

    return Semantics(
      button: true,
      label: 'Abrir checklist ${checklist.title}. Status: $label',
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
                child: Icon(checklist.icon, color: theme.colorScheme.onPrimary, size: 40),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            checklist.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusBadge(label: label, tone: tone),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      checklist.description,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color tone;

  const _StatusBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: tone)),
        ],
      ),
    );
  }
}
