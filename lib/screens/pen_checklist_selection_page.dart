import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/data/checklists_repository.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/screens/checklist_selection_page.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PenChecklistSelectionPage extends StatelessWidget {
  const PenChecklistSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;
    final pen = session.selectedPen;
    final area = session.selectedArea;
    final responsible = session.operationalResponsible;

    final perPen = ChecklistsRepository.availableForArea(OperationalAreasRepository.pecuariaId).where((c) => c.appliesPerPen).toList();
    final filtered = responsible == null ? const <ChecklistDefinition>[] : perPen.where((c) => c.responsible == responsible).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              context.pop();
            } else {
              context.go('/pecuaria/currais');
            }
          },
        ),
        title: Text(pen?.name ?? 'Curral'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha sua rotina',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                responsible == null ? 'Quem vai lançar a atividade?' : 'Rotina do ${responsible.label}',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (op != null)
                Text(
                  'Funcionário: ${op.name}',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              if (area != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Área: ${area.title}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: responsible == null
                      ? _ResponsibleChoicePanel(
                          key: const ValueKey('choice'),
                          onPick: (value) => context.read<AppSession>().setOperationalResponsible(value),
                        )
                      : _ResponsibleChecklistList(
                          key: const ValueKey('list'),
                          theme: theme,
                          list: filtered,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsibleChoicePanel extends StatelessWidget {
  final ValueChanged<OperationalResponsible> onPick;

  const _ResponsibleChoicePanel({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        _BigRoleButton(
          label: 'Tratador',
          icon: Icons.grass_rounded,
          onTap: () => onPick(OperationalResponsible.tratador),
        ),
        const SizedBox(height: AppSpacing.md),
        _BigRoleButton(
          label: 'Vaqueiro',
          icon: Icons.how_to_reg_rounded,
          onTap: () => onPick(OperationalResponsible.vaqueiro),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Dica: escolha só a sua rotina.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ResponsibleChecklistList extends StatelessWidget {
  final ThemeData theme;
  final List<ChecklistDefinition> list;

  const _ResponsibleChecklistList({super.key, required this.theme, required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Nenhum checklist disponível para esta rotina.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final checklist = list[index];
        return ChecklistCard(
          checklist: checklist,
          onTap: () {
            context.read<AppSession>().startChecklist(checklist);
            context.push('/checklists/${checklist.id}/questions');
          },
        );
      },
    );
  }
}

class _BigRoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BigRoleButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Escolher rotina: $label',
      child: SizedBox(
        height: 84,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          ),
          icon: Icon(icon, color: theme.colorScheme.onPrimary, size: 28),
          label: Text(label, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
