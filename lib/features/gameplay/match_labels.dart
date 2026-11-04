import '../../app/l10n/app_strings.dart';
import '../../core/rules/scoring_rules.dart';
import '../../games/spades_batak/spades_batak_scorer.dart';
import 'match_session.dart';

/// The sentences the table screen puts around a match: where it has got to,
/// and how it ended.
///
/// Pure, and kept out of the screen because each one is a small decision about
/// wording and rule shape -- a match that ends on a score says something
/// different from one that ends on a hand count -- and those read better
/// together than scattered through a widget.
abstract final class MatchLabels {
  /// `Dagitim 3 / 8`, or the hand number plus the target score.
  static String caption(AppStrings strings, MatchSession session) {
    final BatakScoringRules rules = session.profile.scoringRules;
    return switch (rules.endCondition) {
      MatchEndCondition.fixedRounds =>
        strings.handProgress(session.displayHandNumber, rules.roundCount),
      MatchEndCondition.targetScore =>
        '${strings.handProgress(session.displayHandNumber, null)}'
            '   ${strings.targetScore(rules.targetScore)}',
    };
  }

  /// Title for the hand that just finished.
  ///
  /// Names a KING or an all-thirteen sweep, because a hand that pays the
  /// whole deal is not an ordinary hand and the score sheet alone does not
  /// say which of the two happened. Derived from the finished hand's own
  /// trick counts and contract rather than stored: a side holding every
  /// trick is a fact about the sheet in front of the player, so there is
  /// nothing to keep in step.
  static String handTitle(AppStrings strings, MatchSession session) {
    final HandScore? score = session.lastHandScore;
    if (score == null || !session.hasTeams) {
      return strings.gameplayHandSummaryTitle;
    }
    final int perHand = session.profile.tricksPerHand;
    int sweeper = -1;
    for (int team = 0; team < 2; team++) {
      int tricks = 0;
      for (int seat = 0; seat < score.seatCount; seat++) {
        if (session.teamOf(seat) == team) {
          tricks += score.tricksOf(seat);
        }
      }
      if (tricks == perHand) {
        sweeper = team;
      }
    }
    if (sweeper < 0) {
      return strings.gameplayHandSummaryTitle;
    }
    final bool king = sweeper == session.declarerTeam &&
        session.contractBid == perHand &&
        session.profile.partnershipScoringRules.kingEnabled;
    return king ? strings.handResultKing : strings.handResultSweep;
  }

  /// Won, lost, or drawn.
  static String headline(AppStrings strings, MatchSession session) {
    if (session.winners.length > 1) {
      return strings.gameplayDraw;
    }
    return session.humanWon ? strings.gameplayYouWon : strings.gameplayYouLost;
  }

  /// Who won, named. A tie lists everyone who tied.
  static String detail(
    AppStrings strings,
    MatchSession session,
    List<String> seatNames,
  ) {
    final List<String> names = <String>[
      for (final int seat in session.winners)
        seat < seatNames.length ? seatNames[seat] : '',
    ];
    return names.length == 1
        ? strings.winnerLine(names.first)
        : names.join(', ');
  }
}
