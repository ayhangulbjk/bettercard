import 'dart:math' as math;

import '../cards/playing_card.dart';
import '../cards/suit.dart';
import '../rules/auction_scoring_rules.dart';
import 'ai_difficulty.dart';
import 'policies/bid_evaluator.dart';
import 'seat_observation.dart';

/// Decides the two things a card policy cannot: what to bid, and what to name
/// as trump.
///
/// Kept separate from [AiPolicy] rather than bolted onto it because only one
/// mode has an auction, and three of the five never will. A policy that
/// implements both is a policy for this mode; one that implements neither is
/// still a complete card player.
///
/// Both answers are drawn from the observation and nothing else. The hand is
/// the seat's own, the auction so far is public, and the scoreboard is on the
/// table.
abstract interface class AuctionPolicy {
  /// The contract to offer, or null to pass.
  ///
  /// [legalBids] comes from the engine, so a policy cannot decide for itself
  /// what the rules allow. An empty list means passing is the only option.
  int? chooseBid(SeatObservation observation, List<int> legalBids);

  /// The trump to name, having won the contract.
  ///
  /// [options] comes from the engine for the same reason. Never null: naming
  /// a trump is compulsory in this mode, and a policy that declined would
  /// deadlock the hand rather than express a preference.
  Suit chooseTrump(SeatObservation observation, List<Suit> options);
}

/// The shipped auction player.
///
/// It values every suit as a candidate trump, picks a contract by expected
/// points rather than by a trick threshold, and compares bidding against
/// **defending** on the same scale -- so it passes because defence is worth
/// more, not because a number said stop.
///
/// Three things it gets right that a count-the-aces bidder does not:
///
/// * it will not raise merely because it can. A hand worth six does not say
///   seven over an opponent's six; it passes, and the opponent keeps a
///   contract it may well go down on.
/// * it reads the score. A seat that is behind in the last hands of a match
///   values a contract it would otherwise decline, because second place pays
///   the same as fourth.
/// * a forced contract is bid differently from a chosen one. Being stuck with
///   a hand is not evidence that the hand is good.
final class HeuristicAuctionPolicy implements AuctionPolicy {
  const HeuristicAuctionPolicy({
    this.difficulty = AiDifficulty.hard,
    this.riskAppetite = 0,
  });

  /// How the level changes the bidder.
  ///
  /// Not a handicap on the cards and not a delay: the weaker levels read less
  /// of the position. Beginner ignores the score and shades its estimate
  /// pessimistically, which produces the recognisable weak-player behaviour
  /// of under-bidding good hands.
  final AiDifficulty difficulty;

  /// Tricks added to the capacity estimate before valuing a contract.
  ///
  /// Positive is optimism. The match-position adjustment feeds this, so the
  /// whole of "how much risk am I taking" is one number rather than scattered
  /// through the valuation.
  final double riskAppetite;

  @override
  int? chooseBid(SeatObservation observation, List<int> legalBids) {
    if (legalBids.isEmpty) {
      return null;
    }
    final AuctionScoringRules rules = observation.match.auctionScoringRules;
    if (!rules.enabled) {
      return null;
    }
    final List<PlayingCard> hand = observation.hand;
    final TrumpAppraisal appraisal = BidEvaluator.bestTrump(hand);

    return BidEvaluator.chooseBid(
      hand: hand,
      legalBids: legalBids,
      rules: rules,
      appraisal: appraisal,
      // The lowest legal bid is one above the standing one, so this recovers
      // what is on the table -- the contract this seat would be defending if
      // it passed.
      standingBid: legalBids.first > 1 ? legalBids.first - 1 : null,
      riskAppetite:
          riskAppetite + _levelShading() + _scorePressure(observation),
    );
  }

  @override
  Suit chooseTrump(SeatObservation observation, List<Suit> options) {
    if (options.isEmpty) {
      throw StateError('A contract winner was offered no trump to name');
    }
    final List<TrumpAppraisal> ranked =
        BidEvaluator.appraiseAll(observation.hand);
    for (final TrumpAppraisal appraisal in ranked) {
      if (options.contains(appraisal.trump)) {
        return appraisal.trump;
      }
    }
    return options.first;
  }

  /// What the level costs in optimism.
  double _levelShading() => switch (difficulty) {
        AiDifficulty.beginner => -0.8,
        AiDifficulty.normal => -0.2,
        AiDifficulty.hard || AiDifficulty.expert || AiDifficulty.legendary => 0,
      };

  /// How far behind this seat is, as extra appetite for a contract.
  ///
  /// A seat that cannot win by defending has nothing to lose by bidding, and
  /// a seat comfortably ahead has no reason to. Beginner does not look at the
  /// scoreboard at all, which is most of what makes it beatable.
  double _scorePressure(SeatObservation observation) {
    if (difficulty == AiDifficulty.beginner) {
      return 0;
    }
    final List<int> totals = observation.match.totalScores;
    if (totals.length < 2) {
      return 0;
    }
    final int mine = observation.match.scoreOf(observation.seat);
    int best = totals.first;
    for (final int total in totals) {
      if (total > best) {
        best = total;
      }
    }
    final int behind = best - mine;
    if (behind <= 0) {
      // Leading. Shade down a little: a contract risks the lead, defending
      // does not.
      return -0.25;
    }
    // One contract is worth roughly 60 points, so being that far back is
    // worth about one trick of extra optimism. Capped, because no deficit
    // makes a bad hand good.
    return math.min(behind / 60.0, 1.2);
  }
}
