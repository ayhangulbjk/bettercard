import 'dart:math' as math;

import '../../cards/suit.dart';
import '../../rules/partnership_scoring_rules.dart';
import '../ai_difficulty.dart';
import '../auction_policy.dart';
import '../seat_observation.dart';
import 'partnership_bid_evaluator.dart';

/// The esli auction player: what to bid for the side, and what to name as
/// trump once the side has the hand.
///
/// Separate from the solo [HeuristicAuctionPolicy] rather than a flag on it,
/// because the two are answering different questions. There, a bid is a
/// promise about one hand against three opponents. Here it is a promise about
/// **two** hands, one of which this seat has never seen, against two
/// opponents -- and the option of passing can mean handing the contract to a
/// partner rather than to an enemy.
///
/// What it gets right that a count-the-aces bidder does not:
///
/// * it does not add its partner's likely tricks to its own. See
///   [PartnershipBidEvaluator], which subtracts the overlap;
/// * it reads its partner's bid as evidence rather than as a number to beat,
///   and will not raise its own side without a clear reason;
/// * it tells a partner's bid from an opponent's, so passing is valued
///   correctly in both cases;
/// * it reads the scoreboard: a side that cannot win by defending has
///   nothing to lose by bidding;
/// * a forced contract is bid differently from a chosen one, because being
///   stuck with a hand is not evidence that the hand is good.
///
/// Everything it knows arrives through [SeatObservation]: its own thirteen
/// cards, the calls already made, and the scoreboard. Its partner's cards are
/// not among them -- in acik esli they do not go face up until the trump is
/// named, which is after both of these decisions, and that ordering is the
/// engine's rather than this policy's good manners.
final class PartnershipAuctionPolicy implements AuctionPolicy {
  const PartnershipAuctionPolicy({
    this.difficulty = AiDifficulty.hard,
    this.riskAppetite = 0,
  });

  /// How the level changes the bidder.
  ///
  /// Not a handicap on the cards and not a delay: the weaker levels read less
  /// of the position. Baslangic ignores the scoreboard and shades its
  /// estimate pessimistically, which produces the recognisable weak-partner
  /// behaviour of leaving good hands on the table.
  final AiDifficulty difficulty;

  /// Tricks added to the team capacity estimate before valuing a contract.
  /// Positive is optimism; the match-position adjustment feeds into it.
  final double riskAppetite;

  @override
  int? chooseBid(SeatObservation observation, List<int> legalBids) {
    if (legalBids.isEmpty) {
      return null;
    }
    final PartnershipScoringRules rules =
        observation.match.partnershipScoringRules;
    if (!rules.enabled) {
      return null;
    }
    final int? standingBid = observation.match.standingBid;
    final bool fromPartner =
        observation.match.standingBidIsOurs(observation.seat);
    final int floor = legalBids.first;

    final TeamAppraisal appraisal = PartnershipBidEvaluator.bestTrump(
      observation.hand,
      // Evidence, not instruction: only a partner's call says anything about
      // the hand opposite. An opponent's bid says the opposite thing and is
      // valued where passing is valued, not here.
      partnerBid: fromPartner ? standingBid : null,
      minimumBid: observation.match.auction?.rules.minimumBid ?? floor,
    );

    return PartnershipBidEvaluator.chooseBid(
      hand: observation.hand,
      legalBids: legalBids,
      rules: rules,
      appraisal: appraisal,
      standingBid: standingBid,
      standingBidderIsPartner: fromPartner,
      // Only when a pass really would end the auction. Before that, who ends
      // up with a silent hand is anybody's guess, and valuing a guess as a
      // certainty is how a bidder talks itself into contracts.
      forcedBid: observation.match.passWouldForceContract
          ? observation.match.forcedBid
          : null,
      forcedOnOurSide: _forcedOnOurSide(observation),
      riskAppetite:
          riskAppetite + _levelShading() + _scorePressure(observation),
    );
  }

  @override
  Suit chooseTrump(SeatObservation observation, List<Suit> options) {
    if (options.isEmpty) {
      throw StateError('A contract winner was offered no trump to name');
    }
    // The contract is already fixed, so the question is not "which suit is my
    // hand best in" but "which suit makes *this* contract", and those differ:
    // a long weak trump that takes nine beats a short strong one that takes
    // eight when the contract is nine. Valued through the scorer for exactly
    // that reason.
    final PartnershipScoringRules rules =
        observation.match.partnershipScoringRules;
    final int? bid = observation.match.contractBid;
    final List<TeamAppraisal> ranked =
        PartnershipBidEvaluator.appraiseAll(observation.hand);
    if (!rules.enabled || bid == null) {
      for (final TeamAppraisal appraisal in ranked) {
        if (options.contains(appraisal.trump)) {
          return appraisal.trump;
        }
      }
      return options.first;
    }

    Suit? best;
    double bestValue = double.negativeInfinity;
    final int tricksInHand = observation.hand.length;
    for (final TeamAppraisal appraisal in ranked) {
      if (!options.contains(appraisal.trump)) {
        continue;
      }
      final double value = _expectedMargin(
        rules: rules,
        bid: bid,
        mean: appraisal.teamCapacity + riskAppetite + _levelShading(),
        tricksInHand: tricksInHand,
      );
      if (value > bestValue) {
        bestValue = value;
        best = appraisal.trump;
      }
    }
    return best ?? options.first;
  }

  /// Expected ground gained by playing [bid] with a capacity centred on
  /// [mean].
  static double _expectedMargin({
    required PartnershipScoringRules rules,
    required int bid,
    required double mean,
    required int tricksInHand,
  }) {
    const double spread = PartnershipBidEvaluator.capacitySpread;
    double total = 0;
    double weightSum = 0;
    for (int taken = 0; taken <= tricksInHand; taken++) {
      final double delta = taken - mean;
      final double weight = math.exp(-(delta * delta) / (2 * spread * spread));
      if (weight == 0) {
        continue;
      }
      final TeamHandOutcome outcome = rules.project(
        contractBid: bid,
        declarerTeam: 0,
        teamTricks: <int>[taken, tricksInHand - taken],
        tricksPerHand: tricksInHand,
      );
      total += weight * (outcome.teamPoints[0] - outcome.teamPoints[1]);
      weightSum += weight;
    }
    return weightSum == 0 ? 0 : total / weightSum;
  }

  /// Whether a pass-out would stick the contract on this seat's own side.
  static bool _forcedOnOurSide(SeatObservation observation) {
    final int? forced = observation.match.seatIfPassedOut;
    return forced != null &&
        observation.seating.sameTeam(forced, observation.seat);
  }

  /// What the level costs in optimism.
  double _levelShading() => switch (difficulty) {
        AiDifficulty.beginner => -1.0,
        AiDifficulty.normal => -0.3,
        AiDifficulty.hard || AiDifficulty.expert || AiDifficulty.legendary => 0,
      };

  /// How far behind this side is, as extra appetite for a contract.
  ///
  /// A side that cannot win by defending has nothing to lose by bidding, and
  /// a side comfortably ahead has no reason to. Read off the *team* total,
  /// which is the only total that decides this match. Baslangic does not look
  /// at the scoreboard at all, which is most of what makes it beatable.
  double _scorePressure(SeatObservation observation) {
    if (difficulty == AiDifficulty.beginner) {
      return 0;
    }
    final int mine = observation.match.scoreOf(observation.seat);
    final int? partner = observation.partnerSeat;
    int best = mine;
    for (int seat = 0; seat < observation.seating.playerCount; seat++) {
      if (seat == observation.seat || seat == partner) {
        continue;
      }
      final int total = observation.match.scoreOf(seat);
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
    // A made contract is worth roughly nine team points, so being that far
    // back is worth about a trick of extra optimism. Capped, because no
    // deficit makes a bad hand good.
    return math.min(behind / 9.0, 1.2);
  }
}
