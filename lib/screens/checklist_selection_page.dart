import 'package:flutter/material.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class ChecklistSelectionPage extends StatelessWidget {
  final String areaId;
  final String? operatorName;
  final String? operatorId;

  const ChecklistSelectionPage({
    super.key,
    required this.areaId,
    this.operatorName,
    this.operatorId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistService = ChecklistService();
    final checklists = checklistService.getChecklistsByArea(areaId);
    final area = ChecklistArea.getAreas().firstWhere(
      (a) => a.id == areaId,
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: area.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: area.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(area.icon, color: AppColors.onColorFor(area.color), size: 28),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escolha o checklist',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.emphasisColor(area.color),
                            ),
                          ),
                          Text(
                            '${checklists.length} disponíveis',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.emphasisColor(area.color).withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.builder(
                  itemCount: checklists.length,
                  itemBuilder: (context, index) {
                    final checklist = checklists[index];
                    return ChecklistButton(
                      label: checklist.simpleName,
                      icon: checklist.icon,
                      description: checklist.description,
                      estimatedMinutes: checklist.estimatedMinutes,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.checklistIntro,
                          arguments: {
                            'checklistId': checklist.id,
                            'op': operatorName,
                            'opId': operatorId,
                          },
                        );
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
