import '../../app/l10n/app_strings.dart';
import '../../core/rules/scoring_rules.dart';
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
