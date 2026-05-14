import 'package:flutter/material.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class ChecklistIntroPage extends StatelessWidget {
  final String checklistId;
  final String? operatorName;
  final String? operatorId;

  const ChecklistIntroPage({
    super.key,
    required this.checklistId,
    this.operatorName,
    this.operatorId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistService = ChecklistService();
    final checklist = checklistService.getChecklistById(checklistId);

    if (checklist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Checklist não encontrado')),
      );
    }

    final area = ChecklistArea.getAreas().firstWhere(
      (a) => a.id == checklist.areaId,
      orElse: () => ChecklistArea.getAreas().first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(area.name),
        backgroundColor: area.color,
        foregroundColor: AppColors.onColorFor(area.color),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: area.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  checklist.icon,
                  size: 64,
                  color: AppColors.emphasisColor(area.color),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Checklist name
              Text(
                checklist.simpleName,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.emphasisColor(area.color),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Description
              Text(
                checklist.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStat(
                    Icons.quiz_outlined,
                    '${checklist.questions.length}',
                    'perguntas',
                    area.color,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _buildStat(
                    Icons.access_time,
                    '~${checklist.estimatedMinutes}',
                    'minutos',
                    area.color,
                  ),
                ],
              ),
              const Spacer(),
              const Spacer(),
              // Start button
              LargeActionButton(
                label: 'Começar',
                icon: Icons.play_arrow,
                color: area.color,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.question,
                    arguments: {
                      'checklistId': checklistId,
                      'questionIndex': 0,
                      'op': operatorName,
                      'opId': operatorId,
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    final emphasis = AppColors.emphasisColor(color);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Icon(icon, color: emphasis, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                value,
                style: TextStyle(
                  fontSize: FontSizes.titleLarge,
                  fontWeight: FontWeight.w800,
                  color: emphasis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: FontSizes.bodySmall,
            color: emphasis.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
