import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';

class SyncIndicator extends StatelessWidget {
  final bool isPendingSync;
  final int pendingCount;

  const SyncIndicator({
    super.key,
    required this.isPendingSync,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPendingSync && pendingCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done, size: 18, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sincronizado',
              style: TextStyle(
                fontSize: FontSizes.labelMedium,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            pendingCount > 0 ? '$pendingCount pendentes' : 'Salvando...',
            style: TextStyle(
              fontSize: FontSizes.labelMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineIndicator extends StatelessWidget {
  final int pendingCount;

  const OfflineIndicator({super.key, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.warningLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Text(
            pendingCount > 0
                ? '$pendingCount checklist(s) salvo(s) no aparelho'
                : 'Dados salvos no aparelho',
            style: TextStyle(
              fontSize: FontSizes.labelMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
