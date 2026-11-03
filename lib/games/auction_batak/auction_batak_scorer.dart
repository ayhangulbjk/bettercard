import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/auction_scoring_rules.dart';
import '../../core/rules/rule_profile.dart';
import '../spades_batak/spades_batak_scorer.dart' show HandScore;

/// Scores one completed Herkes Tek Ihaleli Batak hand.
///
/// One contract, one declarer, three defenders. Every number comes from
/// [AuctionScoringRules], which is the single authority on the payoff: the
/// rules screen, the bidding AI and this scorer all read it, so none of them
/// can disagree about what a contract is worth.
///
/// Deliberately **not** reusing the Koz Maca scorer. The two modes pay
/// different shapes -- four independent promises against one contract -- and
/// sharing a scorer between them is how a rule from one quietly leaks into
/// the other. The hand result object is shared, because a score sheet is a
/// score sheet.
abstract final class AuctionBatakScorer {
  /// Points per seat for the completed hand in [state].
  ///
  /// Throws when the hand is unfinished or the contract is missing: a partial
  /// hand has no score, and a hand that reached scoring without a declarer is
  /// an engine bug rather than player input.
  static HandScore scoreHand({
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
        'A contract hand reached scoring with declarer $declarerSeat '
        'and bid $bid',
      );
    }
    final AuctionScoringRules rules = profile.auctionScoringRules;
    if (!rules.enabled) {
      throw StateError(
        'Profile ${profile.id} has no auction scoring but played a contract',
      );
    }

    final List<int> tricks = state.tricksWon;
    return HandScore(
      points: <int>[
        for (int seat = 0; seat < tricks.length; seat++)
          rules.scoreFor(
            seat: seat,
            declarerSeat: declarerSeat,
            bid: bid,
            tricksTaken: tricks[seat],
          ),
      ],
      tricks: tricks,
      // The declarer's number is recorded against its own seat and nowhere
      // else: the defenders promised nothing, and writing the contract next
      // to their names on the score sheet would read as if they had.
      declarations: <int?>[
        for (int seat = 0; seat < tricks.length; seat++)
          seat == declarerSeat ? bid : null,
      ],
    );
  }
}
