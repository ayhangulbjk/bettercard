import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../match_session.dart';
import 'felt_background.dart';

/// The scoreboard, behind the app bar's score button.
///
/// It used to be a permanent strip above the table. A running total is not
/// something a player reads between every trick -- the promise under each name
/// is -- so it costs a row of a portrait phone to say what is wanted twice a
/// hand. Behind a tap it can afford to say more: the hand number, each seat's
/// total, and what each one promised and has taken so far.
final class ScoreSheetPanel extends StatelessWidget {
  const ScoreSheetPanel({
    required this.session,
    required this.strings,
    required this.seatNames,
    required this.caption,
    required this.onClose,
    super.key,
  });

  final MatchSession session;
  final AppStrings strings;
  final List<String> seatNames;

  /// `Dagitim 3 / 8`, plus the target when the match ends on a score.
  final String caption;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<int> totals = session.totals;
    final List<int> tricks = session.tricksThisHand;
    final List<int?> declarations = session.declarations;
    final List<int> leaders = session.match.leadingSeats;

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC000000),
        child: GestureDetector(
          // Anywhere outside the sheet closes it, which is what a player
          // reaches for after a glance at the score.
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppPanel(
                  accent: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              strings.gameplayScoreboardTitle,
                              style: text.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: strings.commonClose,
                          ),
                        ],
                      ),
                      Text(caption, style: text.labelSmall),
                      const SizedBox(height: AppSpacing.md),
                      for (int seat = 0; seat < totals.length; seat++)
                        _SeatRow(
                          name: seat < seatNames.length ? seatNames[seat] : '',
                          total: totals[seat],
                          declaration: seat < declarations.length
                              ? declarations[seat]
                              : null,
                          tricksWon: tricks[seat],
                          isLeading: leaders.contains(seat),
                          strings: strings,
                        ),
                    ],
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

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.name,
    required this.total,
    required this.declaration,
    required this.tricksWon,
    required this.isLeading,
    required this.strings,
  });

  final String name;
  final int total;
  final int? declaration;
  final int tricksWon;
  final bool isLeading;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              style: text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              declaration == null
                  ? '$tricksWon ${strings.gameplayTrickWord}'
                  : strings.declarationProgress(tricksWon, declaration!),
              style: text.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$total',
              style: text.titleMedium?.copyWith(
                color: isLeading ? AppColors.goldBright : AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
