import 'package:meta/meta.dart';

import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/declaration_rules.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/scoring_rules.dart';

/// What each seat scored in one completed hand.
@immutable
final class HandScore {
  HandScore({
    required List<int> points,
    required List<int> tricks,
    List<int?>? declarations,
  })  : points = List<int>.unmodifiable(points),
        tricks = List<int>.unmodifiable(tricks),
        declarations = List<int?>.unmodifiable(
          declarations ?? List<int?>.filled(points.length, null),
        );

  /// Points earned, indexed by seat.
  final List<int> points;

  /// Tricks taken, indexed by seat. Kept alongside the points because the
  /// scoreboard shows both and a scorer that reported only points would make
  /// the arithmetic unverifiable to the player.
  final List<int> tricks;

  /// What each seat declared, or null in a mode with no declaration round.
  ///
  /// Stored for the same reason as [tricks]: without it the score sheet shows
  /// a minus sign the player cannot check.
  final List<int?> declarations;

  int get seatCount => points.length;

  int pointsOf(int seat) => points[seat];

  int tricksOf(int seat) => tricks[seat];

  int? declarationOf(int seat) => declarations[seat];

  /// Whether [seat] kept its word. Null when it declared nothing.
  bool? madeDeclaration(int seat) {
    final int? declared = declarations[seat];
    if (declared == null) {
      return null;
    }
    return declared == 0 ? tricks[seat] == 0 : tricks[seat] >= declared;
  }

  int get totalPoints => points.fold(0, (int a, int b) => a + b);

  int get totalTricks => tricks.fold(0, (int a, int b) => a + b);

  @override
  String toString() => 'HandScore(points: $points, tricks: $tricks, '
      'declarations: $declarations)';
}

/// Scores one completed Koz Maca hand.
///
/// Koz Maca has no auction and therefore **no declarer**, which is why
/// [BatakScoringRules.declarerSuccess] and `declarerFailure` play no part
/// here: they describe what one contract pays, and this mode has four
/// independent promises instead. The payoff for each lives in
/// [DeclarationRules.scoreFor].
///
/// With declarations switched off the hand falls back to flat trick scoring,
/// [BatakScoringRules.pointsPerTrickForOthers] per trick, which is what the
/// mode scored before the declaration round existed and what a saved match
/// started under those rules must keep scoring.
abstract final class SpadesBatakScorer {
  /// Points per seat for the completed hand in [state].
  ///
  /// Throws [StateError] if the hand is not finished, because a partial hand
  /// has no score and silently returning one would let the UI show a number
  /// that later changes. Also throws if a declaring profile reaches scoring
  /// with a seat that never declared: that is an engine bug, not player input.
  static HandScore scoreHand({
    required TrickPlayState state,
    required RuleProfile profile,
    List<int?> declarations = const <int?>[],
  }) {
    if (!state.isComplete) {
      throw StateError(
        'Cannot score an unfinished hand: '
        '${state.completedTricks.length} tricks played, '
        'hands still hold ${state.handSizes}',
      );
    }
    final List<int> tricks = state.tricksWon;
    final DeclarationRules rules = profile.declarationRules;

    if (!rules.enabled) {
      return HandScore(
        points: <int>[
          for (final int won in tricks)
            won * profile.scoringRules.pointsPerTrickForOthers,
        ],
        tricks: tricks,
      );
    }

    if (declarations.length != tricks.length ||
        declarations.any((int? value) => value == null)) {
      throw StateError(
        'A declaring hand reached scoring with declarations $declarations',
      );
    }
    return HandScore(
      points: <int>[
        for (int seat = 0; seat < tricks.length; seat++)
          rules.scoreFor(
            declaration: declarations[seat]!,
            tricksTaken: tricks[seat],
          ),
      ],
      tricks: tricks,
      declarations: declarations,
    );
  }
}
