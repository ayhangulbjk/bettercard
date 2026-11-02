import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/statistics/match_statistics.dart';
import '../../gameplay/widgets/felt_background.dart';

/// One block of statistics: overall, or one mode's.
///
/// Rates are rounded for display only; the underlying numbers stay exact, so
/// nothing here can drift from the record list it was derived from.
final class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({
    required this.strings,
    required this.statistics,
    this.title,
    this.compact = false,
    super.key,
  });

  final AppStrings strings;
  final MatchStatistics statistics;

  /// Heading inside the panel. Null for the unlabelled overall block.
  final String? title;

  /// Whether to show the short list. A per-mode block repeats the headline
  /// numbers only: the full list four times over is a wall, not a report.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: text.titleMedium?.copyWith(color: AppColors.goldBright),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _row(text, strings.statisticsPlayed, '${statistics.played}'),
          _row(text, strings.statisticsWon, '${statistics.won}'),
          _row(
            text,
            strings.statisticsWinRate,
            '%${(statistics.winRate * 100).round()}',
            highlight: true,
          ),
          if (!compact) ...<Widget>[
            _row(text, strings.statisticsDrawn, '${statistics.drawn}'),
            _row(text, strings.statisticsLost, '${statistics.lost}'),
            const Divider(),
            _row(
              text,
              strings.statisticsAveragePoints,
              statistics.averagePoints.toStringAsFixed(1),
            ),
            _row(
              text,
              strings.statisticsAverageTricks,
              statistics.averageTricksPerHand.toStringAsFixed(2),
            ),
            _row(text, strings.statisticsBestScore, '${statistics.bestScore}'),
            _row(
              text,
              strings.statisticsBestMargin,
              _signed(statistics.bestMargin),
            ),
            const Divider(),
            _row(
              text,
              strings.statisticsCurrentStreak,
              '${statistics.currentWinStreak}',
            ),
            _row(
              text,
              strings.statisticsLongestStreak,
              '${statistics.longestWinStreak}',
            ),
          ],
        ],
      ),
    );
  }

  static String _signed(int value) => value > 0 ? '+$value' : '$value';

  Widget _row(
    TextTheme text,
    String label,
    String value, {
    bool highlight = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: text.bodyMedium)),
            Text(
              value,
              style: text.titleMedium?.copyWith(
                color: highlight ? AppColors.goldBright : null,
              ),
            ),
          ],
        ),
      );
}
