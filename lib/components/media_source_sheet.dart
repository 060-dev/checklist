import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:morro_do_peo/theme.dart';

/// Shows a bottom sheet letting the user choose camera vs. gallery for photo
/// or video capture. Returns `null` if dismissed/cancelled.
Future<ImageSource?> showMediaSourceSheet(
  BuildContext context, {
  required String title,
  bool isVideo = false,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isVideo ? 'Como deseja enviar o vídeo?' : 'Como deseja enviar a foto?',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                icon: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 24),
                label: Text(
                  isVideo ? 'Gravar Vídeo' : 'Tirar Foto',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                icon: Icon(Icons.photo_library, color: theme.colorScheme.primary, size: 24),
                label: Text(
                  'Escolher da Galeria',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
