import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final name = session.selectedOperator?.name ?? '';
    final title = (session.successTitleOverride ?? '').trim().isEmpty ? 'Checklist enviado' : session.successTitleOverride!;
    final message = (session.successMessageOverride ?? '').trim().isEmpty
        ? (name.trim().isEmpty ? 'Obrigado. Seu checklist foi registrado.' : 'Obrigado, $name. Seu checklist foi registrado.')
        : session.successMessageOverride!;
    final returnLabel = session.successReturnLabel;
    final returnLocation = session.successReturnLocation;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sucesso'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                height: 72,
                child: FilledButton.icon(
                  onPressed: () {
                    // Default: keep operator/area for faster next submission.
                    context.read<AppSession>().resetChecklistRunOnly();
                    context.go(returnLocation);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  icon: Icon(returnLocation.startsWith('/pecuaria/currais') ? Icons.grid_view_rounded : Icons.list_alt_rounded, color: theme.colorScheme.onPrimary, size: 24),
                  label: Text(returnLabel, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
