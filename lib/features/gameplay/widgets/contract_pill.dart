import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// `Ihale: Selin 9`.
///
/// Sits above the table rather than inside it: with a seat on every edge, the
/// middle of the felt belongs to the cards and the far edge belongs to the
/// player sitting there.
///
/// It carries the contract and nothing else. The trump moved to [TrumpBadge]
/// on the felt, next to the cards it governs, and the trick counter was
/// dropped: the hand in front of the player already says how far through the
/// deal it is, and a seat's own trick count is on its panel. Who took the hand
/// and for how much is the number every decision for the next thirteen tricks
/// is measured against, so it stays visible rather than being announced once.
///
/// A mode with no contract shows nothing at all, which is why the caller is
/// expected to omit the pill rather than pass an empty label.
final class ContractPill extends StatelessWidget {
  const ContractPill({required this.label, super.key});

  /// `Ihale: Selin 9`, or a partnership's `Ihale: Selin 9 (Rakip takim)`.
  final String label;

  @override
  Widget build(BuildContext context) => AppPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxs,
        ),
        borderRadius: AppRadius.pill,
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      );
}
