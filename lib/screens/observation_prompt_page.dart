import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ObservationPromptPage extends StatelessWidget {
  const ObservationPromptPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opName = context.watch<AppSession>().selectedOperator?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Observação'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quer gravar alguma observação?',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                opName.trim().isEmpty ? 'Se precisar, grave uma observação rápida em áudio.' : 'Se precisar, grave uma observação rápida em áudio, $opName.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                height: 72,
                child: FilledButton.icon(
                  onPressed: () => context.go('/observation/record'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  icon: Icon(Icons.mic, color: theme.colorScheme.onPrimary, size: 28),
                  label: Text(
                    'Sim, gravar áudio',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 72,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  icon: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 28),
                  label: Text(
                    'Não, finalizar',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
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
