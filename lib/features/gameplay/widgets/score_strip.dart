import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// Running totals for the match, above the table.
///
/// The score is the one number a player checks between every trick, so it sits
/// in a fixed strip rather than behind a tap. Columns are evenly divided and
/// each name is capped at one line: four seats share a phone's width, and a
/// name that wraps would push the table down a row mid-hand.
final class ScoreStrip extends StatelessWidget {
  const ScoreStrip({
    required this.seatNames,
    required this.totals,
    required this.caption,
    this.leadingSeats = const <int>[],
    super.key,
  });

  final List<String> seatNames;

  /// Cumulative points, indexed by seat.
  final List<int> totals;

  /// `Dagitim 3 / 8`, plus the target when the match ends on a score.
  final String caption;

  /// Seats currently in the lead, shown in gold.
  final List<int> leadingSeats;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          Text(caption, style: text.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              for (int seat = 0; seat < totals.length; seat++)
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        seat < seatNames.length ? seatNames[seat] : '',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${totals[seat]}',
                        style: text.titleMedium?.copyWith(
                          color: leadingSeats.contains(seat)
                              ? AppColors.goldBright
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
