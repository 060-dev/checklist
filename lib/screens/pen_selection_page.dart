import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class PenSelectionPage extends StatelessWidget {
  const PenSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;

    final pens = PensRepository.available;

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
        title: const Text('Selecionar curral'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha o curral para selecionar um checklist',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (op != null)
                Text(
                  'Funcionário: ${op.name}',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                  ),
                  itemCount: pens.length,
                  itemBuilder: (context, index) {
                    final pen = pens[index];
                    final status = session.statusForPenToday(pen.id);
                    return PenCard(
                      pen: pen,
                      status: status,
                      onTap: () {
                        context.read<AppSession>().selectPen(pen);
                        context.push('/pecuaria/currais/checklists');
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

class PenCard extends StatelessWidget {
  final PenDefinition pen;
  final PenChecklistStatus status;
  final VoidCallback onTap;

  const PenCard(
      {super.key,
      required this.pen,
      required this.status,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final (label, tone) = switch (status) {
      PenChecklistStatus.pendente => ('Pendente', AppColors.info),
      PenChecklistStatus.parcial => ('Parcial', AppColors.info),
      PenChecklistStatus.preenchido => ('Preenchido', AppColors.success),
      PenChecklistStatus.comAlerta => ('Com alerta', AppColors.warning),
    };

    return Semantics(
      button: true,
      label: '${pen.name}. Status: $label',
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Em alguns devices (ou com fonte maior), os cards ficam mais baixos.
            // Ajustamos espaçamentos e tipografia para não estourar.
            final isCompact = constraints.maxHeight < 150;
            final padding = isCompact ? AppSpacing.md : AppSpacing.lg;
            final iconBox = isCompact ? 42.0 : 46.0;
            final iconSize = isCompact ? 24.0 : 26.0;
            final titleStyle = (isCompact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge)
                ?.copyWith(fontWeight: FontWeight.w900);
            final badgeTextStyle = (isCompact
                    ? theme.textTheme.labelMedium
                    : theme.textTheme.labelLarge)
                ?.copyWith(fontWeight: FontWeight.w900, color: tone);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                    color: primary.withValues(alpha: 0.16), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: primary.withValues(alpha: 0.18)),
                        ),
                        child: Icon(Icons.holiday_village_rounded,
                            color: primary, size: iconSize),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          color: primary.withValues(alpha: 0.8), size: 18),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(pen.name,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tone.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: tone,
                                  borderRadius: BorderRadius.circular(99))),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                              child: Text(label,
                                  style: badgeTextStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
