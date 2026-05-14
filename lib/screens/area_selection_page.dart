import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/submission_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class AreaSelectionPage extends StatelessWidget {
  final String? operatorName;
  final String? operatorId;

  const AreaSelectionPage({super.key, this.operatorName, this.operatorId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submissionService = SubmissionService();
    final areas = ChecklistArea.getAreas();
    final op = operatorName;
    final opQuery = (op != null && op.trim().isNotEmpty)
        ? 'op=${Uri.encodeComponent(op)}'
        : null;
    final opId = operatorId;
    final opIdQuery = (opId != null && opId.trim().isNotEmpty)
        ? 'opId=${Uri.encodeComponent(opId)}'
        : null;
    final query = [
      if (opQuery != null) opQuery,
      if (opIdQuery != null) opIdQuery
    ].join('&');
    final suffix = query.isNotEmpty ? '?$query' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Morro do Peão'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: submissionService.pendingQueueCount,
            builder: (context, count, _) {
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (op != null && op.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primaryGreen),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Operador: $op',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/operator'),
                        child: const Text('Trocar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                'O que você vai fazer?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Escolha uma área',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: areas.length,
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    return AreaButton(
                      label: area.simpleName,
                      icon: area.icon,
                      color: area.color,
                      onPressed: () {
                        context.push('/checklists/${area.id}$suffix');
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
