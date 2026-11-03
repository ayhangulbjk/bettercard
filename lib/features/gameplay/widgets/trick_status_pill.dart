import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// `El 3 / 13`.
///
/// Sits above the table rather than inside it: with a seat on every edge, the
/// middle of the felt belongs to the cards and the far edge belongs to the
/// player sitting there.
///
/// It used to carry the trump as well. The trump moved to [TrumpBadge] on the
/// felt, where it is next to the cards it governs, and this pill went back to
/// saying one thing.
final class TrickStatusPill extends StatelessWidget {
  const TrickStatusPill({required this.progressLabel, super.key});

  /// `El 3 / 13`.
  final String progressLabel;

  @override
  Widget build(BuildContext context) => AppPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxs,
        ),
        borderRadius: AppRadius.pill,
        child: Text(
          progressLabel,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}
