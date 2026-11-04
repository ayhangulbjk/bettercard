import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/partnership_scoring_rules.dart';
import '../../core/rules/rule_profile.dart';
import '../spades_batak/spades_batak_scorer.dart' show HandScore;

/// One completed Esli Ihaleli Batak hand, scored.
///
/// Every number comes from [PartnershipScoringRules], which is the single
/// authority on the team payoff: the rules screen, the bidding AI, the search
/// and this scorer all read it, so none of them can disagree about what a
/// contract is worth.
///
/// Deliberately **not** reusing either of the other two scorers. Koz Maca
/// pays four independent promises and Herkes Tek Ihaleli pays one declarer
/// against three defenders that are each on the hook alone; this pays two
/// sides, and a side's floor is a *team* floor. Sharing a scorer between them
/// is how a rule from one quietly leaks into the other.
///
/// The hand result object is shared, because a score sheet is a score sheet.
/// Within it the three columns mean what a team game needs them to mean:
///
/// * `points[seat]` is the seat's **side's** score for the hand -- the two
///   partners carry the same number, which is the honest answer to "what did
///   this player score", and it is what makes the running total a team total;
/// * `tricks[seat]` stays the seat's **own** tricks, so the four of them add
///   up to the deal and the player can check the arithmetic;
/// * `declarations[seat]` holds the contract against the declarer's name and
///   nowhere else, because its partner promised nothing even though it is
///   held to the same result.
abstract final class PartnershipBatakScorer {
  /// Scores the completed hand in [state].
  ///
  /// Throws when the hand is unfinished or the contract is missing: a partial
  /// hand has no score, and a hand that reached scoring without a declarer is
  /// an engine bug rather than player input.
  static PartnershipHandResult scoreHand({
    required TrickPlayState state,
    required RuleProfile profile,
    required int? declarerSeat,
    required int? bid,
  }) {
    if (!state.isComplete) {
      throw StateError(
        'Cannot score an unfinished hand: '
        '${state.completedTricks.length} tricks played, '
        'hands still hold ${state.handSizes}',
      );
    }
    if (declarerSeat == null || bid == null) {
      throw StateError(
        'A team contract reached scoring with declarer $declarerSeat '
        'and bid $bid',
      );
    }
    final PartnershipScoringRules rules = profile.partnershipScoringRules;
    if (!rules.enabled) {
      throw StateError(
        'Profile ${profile.id} has no team scoring but played a team hand',
      );
    }

    final SeatingPlan seating = state.seating;
    final List<int> tricksBySeat = state.tricksWon;
    final List<int> teamTricks = List<int>.filled(2, 0);
    for (int seat = 0; seat < tricksBySeat.length; seat++) {
      teamTricks[seating.teamOf(seat)] += tricksBySeat[seat];
    }

    final TeamHandOutcome outcome = rules.score(
      contractBid: bid,
      declarerTeam: seating.teamOf(declarerSeat),
      teamTricks: teamTricks,
      tricksPerHand: state.completedTricks.length,
    );

    return PartnershipHandResult(
      outcome: outcome,
      score: HandScore(
        points: <int>[
          for (int seat = 0; seat < tricksBySeat.length; seat++)
            outcome.teamPoints[seating.teamOf(seat)],
        ],
        tricks: tricksBySeat,
        declarations: <int?>[
          for (int seat = 0; seat < tricksBySeat.length; seat++)
            seat == declarerSeat ? bid : null,
        ],
      ),
    );
  }
}

/// A scored partnership hand: the score sheet row and the team result behind
/// it.
///
/// Two objects rather than one because they answer different questions. The
/// [score] is what the player reads; the [outcome] is what the match needs --
/// whether a KING just ended it, and whether the contract was made.
final class PartnershipHandResult {
  const PartnershipHandResult({required this.outcome, required this.score});

  final TeamHandOutcome outcome;
  final HandScore score;
}
