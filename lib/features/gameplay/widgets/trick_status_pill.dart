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
/// felt, where it is next to the cards it governs. What it does carry, in the
/// modes that have one, is the contract: who took the hand and for how much
/// is the number every decision for the next thirteen tricks is measured
/// against, so it stays visible rather than being announced once.
final class TrickStatusPill extends StatelessWidget {
  const TrickStatusPill({
    required this.progressLabel,
    this.contractLabel,
    super.key,
  });

  /// `El 3 / 13`.
  final String progressLabel;

  /// `İhale: Selin 7`, or null in a mode with no contract.
  final String? contractLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxs,
      ),
      borderRadius: AppRadius.pill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(progressLabel, style: text.labelSmall),
          if (contractLabel != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Text(contractLabel!, style: text.labelSmall),
          ],
        ],
      ),
    );
  }
}
