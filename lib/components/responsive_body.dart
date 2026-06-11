import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';

/// Constrains content width and provides adaptive horizontal padding.
///
/// This keeps pages readable on tablet/web while still feeling native on phones.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 560, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = width >= 900
            ? AppSpacing.xxl
            : width >= 600
                ? AppSpacing.xl
                : AppSpacing.lg;

        final resolvedPadding = padding.resolve(Directionality.of(context));
        final base = EdgeInsets.fromLTRB(
          horizontal,
          resolvedPadding.top,
          horizontal,
          resolvedPadding.bottom,
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: base, child: child),
          ),
        );
      },
    );
  }
}
