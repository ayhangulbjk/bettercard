import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../match_session.dart';
import 'felt_background.dart';

/// The two team totals, and where the hand in play has got to.
///
/// A partnership match is decided by two numbers, not four, and the player
/// checks them constantly: how far is our side from the target, and is this
/// contract going to stand. Four seat columns answer neither question -- the
/// player would have to add the pairs up in their head twice a hand -- so the
/// two sides get a line of their own.
///
/// The second line is the hand: who holds the contract and for how much, what
/// each side has taken, and how many tricks are left. Those four numbers are
/// what every decision for the rest of the deal is measured against, which is
/// why they stay on screen instead of being announced once.
final class TeamStatusBar extends StatelessWidget {
  const TeamStatusBar({
    required this.session,
    required this.strings,
    required this.seatNames,
    super.key,
  });

  final MatchSession session;
  final AppStrings strings;
  final List<String> seatNames;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int humanTeam = session.humanTeam;
    final List<int> totals = session.teamTotals;
    final int ours = humanTeam < totals.length ? totals[humanTeam] : 0;
    final int theirs = humanTeam < totals.length ? totals[1 - humanTeam] : 0;

    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      borderRadius: AppRadius.pill,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _score(text, strings.teamOursLabel, ours, ours >= theirs),
              const SizedBox(width: AppSpacing.md),
              Text('·', style: text.labelSmall),
              const SizedBox(width: AppSpacing.md),
              _score(text, strings.teamTheirsLabel, theirs, theirs >= ours),
            ],
          ),
          if (_handLine != null)
            Text(
              _handLine!,
              style: text.labelSmall,
              textAlign: TextAlign.center,
              // Two lines rather than one: at a large system font the line
              // does not fit, and "Kalan 3" is the half a player checks most.
              // Ellipsising it cut exactly that off.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _score(TextTheme text, String label, int value, bool ahead) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$label ', style: text.labelSmall),
          Text(
            '$value',
            style: text.titleSmall?.copyWith(
              color: ahead ? AppColors.goldBright : AppColors.textPrimary,
            ),
          ),
        ],
      );

  /// `Ihale: Selin 9 (rakip) · Biz 7 - Onlar 3 · Kalan 3`.
  ///
  /// Null before a contract exists, because there is nothing true to say yet.
  String? get _handLine {
    final int? declarer = session.declarerSeat;
    final int? bid = session.contractBid;
    if (declarer == null || bid == null) {
      return null;
    }
    final String who = declarer < seatNames.length ? seatNames[declarer] : '';
    final bool oursIsDeclaring = session.declarerTeam == session.humanTeam;
    return <String>[
      strings.teamContractLine(who, bid, oursIsDeclaring),
      strings.teamTrickSplit(
        session.humanTeamTricks,
        session.opponentTeamTricks,
      ),
      strings.teamTricksLeft(session.tricksLeftThisHand),
    ].join('   ·   ');
  }
}
