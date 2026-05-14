import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: FontSizes.displaySmall,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                fontSize: FontSizes.bodySmall,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class SubmissionCard extends StatelessWidget {
  final String checklistName;
  final String areaName;
  final String userName;
  final DateTime date;
  final int problemsFound;
  final int photosCount;
  final bool isSynced;
  final VoidCallback? onTap;

  const SubmissionCard({
    super.key,
    required this.checklistName,
    required this.areaName,
    required this.userName,
    required this.date,
    required this.problemsFound,
    required this.photosCount,
    required this.isSynced,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checklistName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            _buildTag(areaName, theme.colorScheme.primary),
                            const SizedBox(width: AppSpacing.sm),
                            _buildTag(userName, theme.colorScheme.secondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildSyncStatus(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatDate(date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (problemsFound > 0) ...[
                    Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$problemsFound',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: FontSizes.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (photosCount > 0) ...[
                    const Icon(Icons.photo_camera, size: 16, color: AppColors.accentBlue),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$photosCount',
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: FontSizes.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: FontSizes.labelSmall,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

  Widget _buildSyncStatus() => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: isSynced
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.warning.withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    child: Icon(
      isSynced ? Icons.cloud_done : Icons.cloud_upload,
      size: 20,
      color: isSynced ? AppColors.success : AppColors.warning,
    ),
  );

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Há ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
