import 'package:flutter/material.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/utils/connectivity.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class SuccessPage extends StatefulWidget {
  final String checklistId;
  final String? operatorName;
  final String? operatorId;
  final String? result;

  const SuccessPage({
    super.key,
    required this.checklistId,
    this.operatorName,
    this.operatorId,
    this.result,
  });

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistService = ChecklistService();
    final checklist = checklistService.getChecklistById(widget.checklistId);

    final area = checklist != null
        ? ChecklistArea.getAreas().firstWhere(
            (a) => a.id == checklist.areaId,
            orElse: () => ChecklistArea.getAreas().first,
          )
        : ChecklistArea.getAreas().first;

    final op = widget.operatorName;
    final result = widget.result;
    final isQueued = result == 'queued';
    final isActuallyOffline = isQueued && !Connectivity.instance.isOnline;
    final showSuccess = !isActuallyOffline;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Animated success icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 100,
                    color: showSuccess ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                showSuccess
                    ? 'Checklist enviado\ncom sucesso!'
                    : 'Checklist salvo\npara enviar depois',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: showSuccess ? AppColors.success : AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              if (checklist != null) ...[
                Text(
                  checklist.simpleName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (op != null && op.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: area.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person,
                          size: 18, color: AppColors.emphasisColor(area.color)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Operador: $op',
                        style: TextStyle(
                          fontSize: FontSizes.labelMedium,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emphasisColor(area.color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isQueued
                      ? AppColors.warningLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                      color: (isQueued ? AppColors.warning : AppColors.success)
                          .withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(showSuccess ? Icons.cloud_done : Icons.cloud_off,
                        size: 18,
                        color: showSuccess
                            ? AppColors.success
                            : AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      showSuccess
                          ? 'Salvo no servidor'
                          : 'Salvo no aparelho (pendente)',
                      style: TextStyle(
                        fontSize: FontSizes.labelMedium,
                        fontWeight: FontWeight.w600,
                        color:
                            showSuccess ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Spacer(),
              // Action buttons
              LargeActionButton(
                label: 'Fazer Outro Checklist',
                icon: Icons.add,
                color: area.color,
                onPressed: () {
                  Navigator.popUntil(context, ModalRoute.withName(AppRoutes.areas));
                },
              ),
              const SizedBox(height: AppSpacing.md),
              LargeActionButton(
                label: 'Voltar ao Início',
                icon: Icons.home,
                color: theme.colorScheme.onSurfaceVariant,
                isOutlined: true,
                onPressed: () =>
                    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home)),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
