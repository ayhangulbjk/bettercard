import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// The table felt.
///
/// A radial pool of light at the centre plus a darker vignette at the edges.
/// That is what sells "a table under a lamp" rather than "a green rectangle",
/// and it costs one decoration instead of an image.
final class FeltBackground extends StatelessWidget {
  const FeltBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.1,
            colors: <Color>[
              AppColors.feltRaised,
              AppColors.feltBase,
              AppColors.feltDeep,
              AppColors.feltEdge,
            ],
            stops: <double>[0.0, 0.45, 0.8, 1.0],
          ),
        ),
        child: child,
      );
}

/// A raised panel on the felt, used for score strips and seat badges.
///
/// Replaces Material `Card` so the app does not depend on `cardTheme`, whose
/// type differs across Flutter releases.
///
/// Built on [Material] rather than a decorated box on purpose. `ListTile`,
/// `InkWell` and the switch/radio tiles paint their background and ink
/// splashes onto the nearest `Material` ancestor; a `DecoratedBox` with a
/// background colour in between hides them, so taps inside a panel would give
/// no visible feedback. Letting `Material` draw the fill, border and shadow
/// through its own `shape` keeps ink working for every child.
final class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 16,
    this.accent = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Draws a gold hairline border, for the one or two elements that should
  /// draw the eye.
  final bool accent;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceElevated,
        // Material 3 tints an elevated surface towards the primary colour.
        // The felt palette is deliberate, so the tint is switched off.
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: const Color(0x40000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: accent ? AppColors.goldDim : const Color(0x1AFFFFFF),
            width: accent ? 1 : 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}
