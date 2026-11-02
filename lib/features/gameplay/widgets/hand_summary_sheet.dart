import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../games/spades_batak/spades_batak_scorer.dart';
import 'felt_background.dart';

/// The score sheet for a finished hand.
///
/// It shows tricks, the points those tricks paid, and the new total, side by
/// side per seat. Both columns are there on purpose: a scoreboard that printed
/// only points would leave the player unable to check the arithmetic against
/// the tricks they just watched being taken.
final class HandSummarySheet extends StatelessWidget {
  const HandSummarySheet({
    required this.strings,
    required this.score,
    required this.totals,
    required this.seatNames,
    required this.title,
    required this.actionLabel,
    required this.onContinue,
    super.key,
  });

  final AppStrings strings;

  /// What each seat took and scored in the hand that just ended.
  final HandScore score;

  /// Cumulative points after the hand, indexed by seat.
  final List<int> totals;

  final List<String> seatNames;
  final String title;
  final String actionLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppPanel(
          borderRadius: AppRadius.sheet,
          accent: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: text.titleLarge?.copyWith(color: AppColors.goldBright),
              ),
              const SizedBox(height: AppSpacing.md),
              _HeaderRow(strings: strings, text: text),
              const Divider(color: AppColors.goldDim, height: AppSpacing.lg),
              for (int seat = 0; seat < score.seatCount; seat++)
                _ScoreRow(
                  name: seat < seatNames.length ? seatNames[seat] : '',
                  tricks: score.tricksOf(seat),
                  points: score.pointsOf(seat),
                  total: seat < totals.length ? totals[seat] : 0,
                  text: text,
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.strings, required this.text});

  final AppStrings strings;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          const Spacer(flex: 3),
          Expanded(
            child: Text(
              strings.gameplayTricksColumn,
              style: text.labelSmall,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            child: Text(
              strings.gameplayPointsColumn,
              style: text.labelSmall,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            child: Text(
              strings.gameplayTotalColumn,
              style: text.labelSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.tricks,
    required this.points,
    required this.total,
    required this.text,
  });

  final String name;
  final int tricks;
  final int points;
  final int total;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                name,
                style: text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                '$tricks',
                style: text.bodyMedium,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                '+$points',
                style: text.bodyMedium,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                '$total',
                style: text.titleMedium?.copyWith(color: AppColors.goldBright),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
}
