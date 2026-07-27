import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  Future<void> _handleBegin(BuildContext context) async {
    final session = context.read<AppSession>();
    await session.ensureLoaded();
    if (!context.mounted) return;
    context.go(session.isActivated ? '/collaborators' : '/activate');
  }

  /// Home background image.
  static const String _backgroundAsset = 'assets/images/background.png';

  /// Transparent logo centered on the home.
  static const String _logoAsset = 'assets/images/logo.png';

  static const String _welcomeTitle = 'Bem-vindo ao Morro do Peão';
  static const String _welcomeSubtitle = 'Checklist operacional diário. Toque em “Começar”.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scrim = theme.colorScheme.scrim;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 0.72, 1.0],
                colors: [
                  // Keep the sky readable and the image “alive”, while increasing
                  // contrast on the center/bottom where content sits.
                  scrim.withValues(alpha: 0.06),
                  scrim.withValues(alpha: 0.18),
                  scrim.withValues(alpha: 0.38),
                  scrim.withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.94, end: 1.0),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Transform.scale(scale: value, child: child),
                      child: const HomeLogoBadge(assetPath: _logoAsset),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _HomeWelcomeText(title: _welcomeTitle, subtitle: _welcomeSubtitle),
                  const Spacer(flex: 3),
                  HomePrimaryCta(
                    onPressed: () => _handleBegin(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular badge for the home logo, using the app theme colors.
class HomeLogoBadge extends StatelessWidget {
  const HomeLogoBadge({super.key, required this.assetPath, this.size = 212});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.32);

    // Fully opaque fill to avoid “checkerboard / quadriculado” artifacts.
    // Also helps when the PNG still has a white background.
    final fill = theme.colorScheme.surface;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            // Keep a little breathing room so the border doesn't touch the logo.
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ClipOval(
              child: ColoredBox(
                // Opaque background to make the logo look consistent across devices.
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  // Minimal padding so the image reaches the clip and doesn't look like a square.
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ClipOval(
                    // Clipping again here ensures that even if the logo asset is a square
                    // (e.g. white canvas), it becomes circular.
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeWelcomeText extends StatelessWidget {
  const _HomeWelcomeText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.10,
              letterSpacing: -0.2,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.90),
                shadows: [
                  Shadow(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.55),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePrimaryCta extends StatelessWidget {
  const HomePrimaryCta({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: (bottomInset > 0 ? AppSpacing.sm : 0)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.scrim.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SizedBox(
          height: AppButtonSizes.mediumHeight,
          child: FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            icon: Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary, size: 22),
            label: Text(
              'Começar',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
