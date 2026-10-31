import 'package:meta/meta.dart';

/// What a successful declarer scores.
enum DeclarerSuccessScore {
  /// Exactly the contract, however many tricks were actually taken.
  bidValue,

  /// Every trick taken, so overtricks pay.
  tricksTaken,
}

/// What a failed declarer scores.
enum DeclarerFailureScore {
  /// Minus the contract value.
  minusBid,

  /// Minus the contract value, doubled.
  minusBidDoubled,

  /// Minus one per trick short of the contract.
  minusShortfall,
}

/// How a match ends.
enum MatchEndCondition {
  /// First to reach a target score.
  targetScore,

  /// A fixed number of hands.
  fixedRounds,
}

/// Batak-family scoring.
///
/// Values here are configurable because Turkish tables genuinely differ. The
/// defaults reproduce the most commonly reported custom; every alternative is
/// documented in docs/RULE_PROFILES.md together with its open questions.
@immutable
class BatakScoringRules {
  const BatakScoringRules({
    this.declarerSuccess = DeclarerSuccessScore.tricksTaken,
    this.declarerFailure = DeclarerFailureScore.minusBid,
    this.pointsPerTrickForOthers = 1,
    this.endCondition = MatchEndCondition.fixedRounds,
    this.targetScore = 51,
    this.roundCount = 8,
  });

  /// Payoff for a made contract.
  final DeclarerSuccessScore declarerSuccess;

  /// Penalty for a broken contract.
  final DeclarerFailureScore declarerFailure;

  /// Points a non-declaring seat earns per trick. Zero means only the
  /// declarer scores.
  final int pointsPerTrickForOthers;

  /// Whether the match runs to a score or to a hand count.
  final MatchEndCondition endCondition;

  /// Target used when [endCondition] is [MatchEndCondition.targetScore].
  final int targetScore;

  /// Hand count used when [endCondition] is [MatchEndCondition.fixedRounds].
  final int roundCount;

  BatakScoringRules copyWith({
    DeclarerSuccessScore? declarerSuccess,
    DeclarerFailureScore? declarerFailure,
    int? pointsPerTrickForOthers,
    MatchEndCondition? endCondition,
    int? targetScore,
    int? roundCount,
  }) =>
      BatakScoringRules(
        declarerSuccess: declarerSuccess ?? this.declarerSuccess,
        declarerFailure: declarerFailure ?? this.declarerFailure,
        pointsPerTrickForOthers:
            pointsPerTrickForOthers ?? this.pointsPerTrickForOthers,
        endCondition: endCondition ?? this.endCondition,
        targetScore: targetScore ?? this.targetScore,
        roundCount: roundCount ?? this.roundCount,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'declarerSuccess': declarerSuccess.name,
        'declarerFailure': declarerFailure.name,
        'pointsPerTrickForOthers': pointsPerTrickForOthers,
        'endCondition': endCondition.name,
        'targetScore': targetScore,
        'roundCount': roundCount,
      };

  static BatakScoringRules fromJson(Map<String, Object?> json) =>
      BatakScoringRules(
        declarerSuccess: DeclarerSuccessScore.values.firstWhere(
          (DeclarerSuccessScore v) => v.name == json['declarerSuccess'],
          orElse: () => DeclarerSuccessScore.tricksTaken,
        ),
        declarerFailure: DeclarerFailureScore.values.firstWhere(
          (DeclarerFailureScore v) => v.name == json['declarerFailure'],
          orElse: () => DeclarerFailureScore.minusBid,
        ),
        pointsPerTrickForOthers: json['pointsPerTrickForOthers'] as int? ?? 1,
        endCondition: MatchEndCondition.values.firstWhere(
          (MatchEndCondition v) => v.name == json['endCondition'],
          orElse: () => MatchEndCondition.fixedRounds,
        ),
        targetScore: json['targetScore'] as int? ?? 51,
        roundCount: json['roundCount'] as int? ?? 8,
      );

  @override
  bool operator ==(Object other) =>
      other is BatakScoringRules &&
      other.declarerSuccess == declarerSuccess &&
      other.declarerFailure == declarerFailure &&
      other.pointsPerTrickForOthers == pointsPerTrickForOthers &&
      other.endCondition == endCondition &&
      other.targetScore == targetScore &&
      other.roundCount == roundCount;

  @override
  int get hashCode => Object.hash(
        declarerSuccess,
        declarerFailure,
        pointsPerTrickForOthers,
        endCondition,
        targetScore,
        roundCount,
      );
}
