import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// `El 3 / 13  |  Koz: Maca`.
///
/// Sits above the table rather than inside it: with a seat on every edge,
/// the middle of the felt belongs to the cards and the far edge belongs to
/// the player sitting there.
final class TrickStatusPill extends StatelessWidget {
  const TrickStatusPill({
    required this.trumpTitle,
    required this.trumpLabel,
    required this.progressLabel,
    super.key,
  });

  /// Localised word for trump, e.g. `Koz`.
  final String trumpTitle;

  /// The trump suit's name, or the no-trump label.
  final String trumpLabel;

  /// `El 3 / 13`.
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      borderRadius: AppRadius.pill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(progressLabel, style: text.labelSmall),
          const SizedBox(width: AppSpacing.md),
          Container(width: 1, height: 14, color: AppColors.goldDim),
          const SizedBox(width: AppSpacing.md),
          Text('$trumpTitle: ', style: text.bodySmall),
          Text(
            trumpLabel,
            style: text.titleMedium?.copyWith(color: AppColors.goldBright),
          ),
        ],
      ),
    );
  }
}
