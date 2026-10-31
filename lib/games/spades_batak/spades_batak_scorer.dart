import 'package:meta/meta.dart';

import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/scoring_rules.dart';

/// What each seat scored in one completed hand.
@immutable
final class HandScore {
  HandScore({required List<int> points, required List<int> tricks})
      : points = List<int>.unmodifiable(points),
        tricks = List<int>.unmodifiable(tricks);

  /// Points earned, indexed by seat.
  final List<int> points;

  /// Tricks taken, indexed by seat. Kept alongside the points because the
  /// scoreboard shows both and a scorer that reported only points would make
  /// the arithmetic unverifiable to the player.
  final List<int> tricks;

  int get seatCount => points.length;

  int pointsOf(int seat) => points[seat];

  int tricksOf(int seat) => tricks[seat];

  int get totalPoints => points.fold(0, (int a, int b) => a + b);

  int get totalTricks => tricks.fold(0, (int a, int b) => a + b);

  @override
  String toString() => 'HandScore(points: $points, tricks: $tricks)';
}

/// Scores one completed Koz Maca hand.
///
/// Koz Maca has no auction, so it has **no declarer**. That matters because
/// [BatakScoringRules] is shaped around one: `declarerSuccess` and
/// `declarerFailure` describe what a contract pays or costs. Neither applies
/// here, and this scorer deliberately ignores them rather than inventing a
/// declarer to feed them. The only field that governs Koz Maca is
/// [BatakScoringRules.pointsPerTrickForOthers]: every seat earns that much per
/// trick it took.
///
/// Recorded as an open question rather than silently assumed: see
/// docs/RULE_PROFILES.md. Some tables play Koz Maca with a minimum-trick
/// penalty, which this scorer does not implement because no shipped preset
/// configures one.
abstract final class SpadesBatakScorer {
  /// Points per seat for the completed hand in [state].
  ///
  /// Throws [StateError] if the hand is not finished, because a partial hand
  /// has no score and silently returning one would let the UI show a number
  /// that later changes.
  static HandScore scoreHand(
    TrickPlayState state,
    BatakScoringRules rules,
  ) {
    if (!state.isComplete) {
      throw StateError(
        'Cannot score an unfinished hand: '
        '${state.completedTricks.length} tricks played, '
        'hands still hold ${state.handSizes}',
      );
    }
    final List<int> tricks = state.tricksWon;
    return HandScore(
      points: <int>[
        for (final int won in tricks) won * rules.pointsPerTrickForOthers,
      ],
      tricks: tricks,
    );
  }
}
