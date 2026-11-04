import 'dart:math' as math;

import '../../cards/playing_card.dart';
import '../../cards/rank.dart';
import '../../cards/suit.dart';
import '../../rules/partnership_scoring_rules.dart';
import 'bid_evaluator.dart';

/// What a hand is worth as a **team** contract.
///
/// The hard part of an esli auction, and the place a naive bidder goes wrong
/// in a way that is easy to describe: it adds. Five tricks in my hand and
/// four in my partner's does not make nine, because a trick can only be won
/// once and there are only thirteen of them. My ace of hearts and my
/// partner's king of hearts are two honours and one trick. Worse, the error
/// compounds: every seat at the table reasons the same way, so every hand
/// gets bid a level too high and every contract goes down.
///
/// So the estimate is built in three explicit pieces rather than one sum:
///
/// * what **my** hand takes with a given trump, which is
///   [BidEvaluator.appraise] -- the shape valuation is the same question in
///   both auction modes and is not duplicated here;
/// * what an **unknown partner** adds, estimated from what is outstanding
///   rather than guessed: a third of the honours I cannot see and a third of
///   the trumps I do not hold are on my partner's side of the table;
/// * how much of that addition **overlaps** with what I already counted,
///   which is the correction the naive bidder is missing.
///
/// Every number below is a parameter, named and in one place, because the
/// honest status of this model is that it is calibrated against the
/// simulator rather than derived -- see `tool/checks/partnership_probe.dart`,
/// which prints bid-versus-taken for thousands of deals and is what these
/// were set from.
///
/// Pure, Flutter-free and deterministic. It sees one hand and the public
/// auction, which is what the seat asking it can see.
abstract final class PartnershipBidEvaluator {
  /// Spread of the team capacity estimate, in tricks.
  ///
  /// Wider than the solo equivalent: two hands are playing the contract and
  /// only one of them is known, so the outcome is less concentrated than a
  /// declarer playing alone.
  static const double capacitySpread = 2.1;

  /// Share of an outstanding card that sits with the partner.
  ///
  /// Three seats hold the thirty-nine cards I cannot see and one of them is
  /// my partner, so a third. Not a guess -- it is the count.
  static const double partnerShare = 1 / 3;

  /// What one outstanding ace in a side suit is worth to the partnership,
  /// before the partner's share is applied.
  static const double outstandingAceValue = 0.80;

  /// The same for a king. Lower, because a king needs the ace gone first.
  static const double outstandingKingValue = 0.35;

  /// What one trump past the second is worth in the partner's hand.
  ///
  /// The first two are drawing cards rather than winners; past that, length
  /// and the chance to ruff start paying.
  static const double partnerTrumpValue = 0.55;

  /// Base tricks an unknown partner contributes on an average hand.
  ///
  /// Thirteen cards always win something. Measured as the floor of the
  /// partner contribution across sampled deals.
  static const double partnerBase = 0.9;

  /// How much a partner's bid raises the estimate of its hand, in tricks.
  ///
  /// A seat that said nine has told the table something real, and the only
  /// honest reading of it is relative: a bid above the floor is evidence of
  /// extra strength, roughly a trick for every two the bid is raised by.
  static const double partnerBidEvidence = 0.5;

  /// Tricks a side gains from holding the contract rather than defending it.
  ///
  /// It picks the trump, it leads to the first trick, and in the open mode it
  /// plays both hands to one plan. None of that is in the hand valuation,
  /// which values cards, so it is added where a *contract* is valued and
  /// nowhere else -- adding it to the appraisal itself would inflate the
  /// defence estimate by the same amount, which is backwards.
  ///
  /// Measured rather than assumed: with a contract forced on a random hand,
  /// `tool/checks/partnership_probe.dart` reports the declaring side taking
  /// about 7.5 of 13 while the plain team appraisal centres on 6.3.
  static const double declarerAdvantage = 1.2;

  /// How much a side's own strength shifts what it takes on defence.
  ///
  /// The two sides' tricks add up to the deal, so a defence estimate cannot
  /// be built the way a contract estimate is. A side defending a contract of
  /// `b` takes about `tricks - b` by definition -- that is what the opponents
  /// are claiming -- and the only honest adjustment is how far this hand is
  /// from an average one. Shading the whole deal by a fixed share instead
  /// produced the bug this replaced: our side was credited with 7.5 tricks
  /// when declaring and 3.5 when defending the *same* cards, which made
  /// defending look safe and every contract look reckless.
  static const double defenceSensitivity = 0.5;

  /// Margin a seat needs before it raises **its own partner**.
  ///
  /// Not a rule and not a prohibition: the engine allows it, tables allow it,
  /// and it is right in the rare hand where this seat genuinely plays the
  /// contract better. It is just almost never right, because the side already
  /// holds the hand and raising only makes the same contract harder. So it
  /// takes a clear gain rather than a hair's breadth.
  static const double partnerRaiseMargin = 2.0;

  /// What [hand] and an unknown partner can take with [trump] as trump.
  ///
  /// [partnerBid] is the partner's standing bid when it has one, which is
  /// public and is evidence about a hand this seat cannot see.
  static TeamAppraisal appraise(
    List<PlayingCard> hand,
    Suit trump, {
    int? partnerBid,
    int minimumBid = 0,
  }) {
    final TrumpAppraisal mine = BidEvaluator.appraise(hand, trump);
    final double partner = _partnerContribution(
      hand: hand,
      trump: trump,
      trumpLength: mine.trumpLength,
      partnerBid: partnerBid,
      minimumBid: minimumBid,
    );
    // The overlap correction. A hand that already expects most of the deal
    // leaves its partner little to add; a weak hand leaves it nearly all of
    // its own value. Linear in what is left of the deal, which is the
    // simplest shape that gets both ends right.
    final int tricksInHand = hand.length;
    final double room =
        ((tricksInHand - mine.capacity) / tricksInHand).clamp(0.0, 1.0);
    final double team =
        (mine.capacity + partner * room).clamp(0.0, tricksInHand.toDouble());
    return TeamAppraisal(
      trump: trump,
      ownCapacity: mine.capacity,
      partnerCapacity: partner,
      teamCapacity: team,
      trumpLength: mine.trumpLength,
      topTrumps: mine.topTrumps,
    );
  }

  /// Every suit appraised as a team contract, strongest first.
  static List<TeamAppraisal> appraiseAll(
    List<PlayingCard> hand, {
    int? partnerBid,
    int minimumBid = 0,
  }) =>
      <TeamAppraisal>[
        for (final Suit suit in Suit.values)
          appraise(
            hand,
            suit,
            partnerBid: partnerBid,
            minimumBid: minimumBid,
          ),
      ]..sort(
          (TeamAppraisal a, TeamAppraisal b) =>
              b.teamCapacity.compareTo(a.teamCapacity),
        );

  /// The suit this hand plays best in as a team contract.
  static TeamAppraisal bestTrump(
    List<PlayingCard> hand, {
    int? partnerBid,
    int minimumBid = 0,
  }) =>
      appraiseAll(hand, partnerBid: partnerBid, minimumBid: minimumBid).first;

  /// What an unknown partner adds, in tricks.
  static double _partnerContribution({
    required List<PlayingCard> hand,
    required Suit trump,
    required int trumpLength,
    required int? partnerBid,
    required int minimumBid,
  }) {
    double outstanding = 0;
    for (final Suit suit in Suit.values) {
      if (suit == trump) {
        continue;
      }
      final bool holdsAce = hand.any(
        (PlayingCard c) => c.suit == suit && c.rank == Rank.ace,
      );
      final bool holdsKing = hand.any(
        (PlayingCard c) => c.suit == suit && c.rank == Rank.king,
      );
      if (!holdsAce) {
        outstanding += outstandingAceValue;
      }
      if (!holdsKing) {
        outstanding += outstandingKingValue;
      }
    }
    // Trumps I do not hold are spread over three hands; the ones that land
    // with my partner are worth something past the drawing rounds.
    final double partnerTrumps =
        (Rank.values.length - trumpLength) * partnerShare;
    final double trumpValue =
        math.max(0, partnerTrumps - 2) * partnerTrumpValue;

    double contribution = partnerBase + outstanding * partnerShare + trumpValue;
    if (partnerBid != null && partnerBid > minimumBid) {
      contribution += (partnerBid - minimumBid) * partnerBidEvidence;
    }
    return contribution;
  }

  /// The contract to offer, or null to pass.
  ///
  /// [legalBids] is handed in by the engine, for the same reason a card policy
  /// is handed its legal moves: what may be bid is a rule, and rules have one
  /// authority.
  ///
  /// ### Why the comparison is a margin
  ///
  /// This payoff is close to zero sum but not exactly: both sides are usually
  /// paid in a made hand, so judging a contract by the points it earns says
  /// "defending is profitable" about every hand ever dealt, and a bot that
  /// maximises its own points passes for ever. What decides a match is the
  /// **gap**, so every option is valued as our points minus theirs, and
  /// bidding and passing are compared on that one scale. A contract is worth
  /// taking when it gains ground, not when it gains points.
  ///
  /// Passing is not a fallback here either. It has three different values and
  /// the bot distinguishes them: nobody has bid, so passing risks a forced
  /// hand; an opponent holds the contract, so passing means defending it; or
  /// **our own partner** holds it, so passing means playing it from the other
  /// side of the table -- which is usually better than raising, and is where
  /// [partnerRaiseMargin] comes in.
  static int? chooseBid({
    required List<PlayingCard> hand,
    required List<int> legalBids,
    required PartnershipScoringRules rules,
    required TeamAppraisal appraisal,
    int? standingBid,
    bool standingBidderIsPartner = false,
    bool mustBid = false,
    double riskAppetite = 0,
    int? forcedBid,
    bool forcedOnOurSide = false,
  }) {
    if (legalBids.isEmpty) {
      return null;
    }
    final int tricksInHand = hand.length;
    // Two distributions, because the same cards take a different number of
    // tricks depending on which side of the contract they are on.
    final List<double> declaring = _distribution(
      mean: appraisal.teamCapacity + declarerAdvantage + riskAppetite,
      tricksInHand: tricksInHand,
    );

    final double passValue = mustBid
        ? double.negativeInfinity
        : _passValue(
            declaring: declaring,
            appraisal: appraisal,
            rules: rules,
            standingBid: standingBid,
            standingBidderIsPartner: standingBidderIsPartner,
            tricksInHand: tricksInHand,
            riskAppetite: riskAppetite,
            forcedBid: forcedBid,
            forcedOnOurSide: forcedOnOurSide,
          );

    int? best;
    // Raising one's own side has to clear a margin, not merely tie: the side
    // already holds the hand, and the same contract one trick higher is only
    // harder. It stays possible, because the rare hand that really does play
    // better from this side exists.
    double bestValue =
        passValue + (standingBidderIsPartner ? partnerRaiseMargin : 0);
    for (final int bid in legalBids) {
      final double value = _expectedMargin(
        capacity: declaring,
        rules: rules,
        bid: bid,
        tricksInHand: tricksInHand,
        weDeclare: true,
      );
      if (value > bestValue) {
        bestValue = value;
        best = bid;
      }
    }
    return best ?? (mustBid ? legalBids.first : null);
  }

  /// Ground gained by letting the auction stand where it is.
  static double _passValue({
    required List<double> declaring,
    required TeamAppraisal appraisal,
    required PartnershipScoringRules rules,
    required int? standingBid,
    required bool standingBidderIsPartner,
    required int tricksInHand,
    required double riskAppetite,
    required int? forcedBid,
    required bool forcedOnOurSide,
  }) {
    if (standingBid == null) {
      // Nobody has bid. Passing hands the hand to whoever bids next, or --
      // when this is the last seat with nothing on the table -- forces the
      // small contract on a known side. That second case is a certainty
      // rather than a guess, and it is worth a lot: a forced seven is
      // *easier* than a voluntary eight, so a seat that would receive it has
      // a real reason to decline the auction.
      if (forcedBid == null) {
        return 0;
      }
      return forcedOnOurSide
          ? _expectedMargin(
              capacity: declaring,
              rules: rules,
              bid: forcedBid,
              tricksInHand: tricksInHand,
              weDeclare: true,
            )
          : _expectedMargin(
              capacity: _defenceDistribution(
                appraisal: appraisal,
                againstBid: forcedBid,
                tricksInHand: tricksInHand,
                riskAppetite: riskAppetite,
              ),
              rules: rules,
              bid: forcedBid,
              tricksInHand: tricksInHand,
              weDeclare: false,
            );
    }
    if (standingBidderIsPartner) {
      // Our side already holds the hand. Passing means our partner plays it
      // with us opposite, so it is the same contract from the same side --
      // which is exactly why the capacity estimate here is the declaring one.
      return _expectedMargin(
        capacity: declaring,
        rules: rules,
        bid: standingBid,
        tricksInHand: tricksInHand,
        weDeclare: true,
      );
    }
    // An opponent holds it, so passing means defending it.
    return _expectedMargin(
      capacity: _defenceDistribution(
        appraisal: appraisal,
        againstBid: standingBid,
        tricksInHand: tricksInHand,
        riskAppetite: riskAppetite,
      ),
      rules: rules,
      bid: standingBid,
      tricksInHand: tricksInHand,
      weDeclare: false,
    );
  }

  /// What our side takes while defending a contract of [againstBid].
  ///
  /// Centred on what the contract leaves us, moved by how far this hand is
  /// from average. Symmetric with the declaring estimate by construction: the
  /// two sides' tricks sum to the deal in every case this produces.
  static List<double> _defenceDistribution({
    required TeamAppraisal appraisal,
    required int againstBid,
    required int tricksInHand,
    required double riskAppetite,
  }) {
    final double average = tricksInHand / 2;
    final double mean = (tricksInHand - againstBid) +
        (appraisal.teamCapacity - average) * defenceSensitivity +
        riskAppetite;
    return _distribution(mean: mean, tricksInHand: tricksInHand);
  }

  /// Ground gained across a capacity distribution.
  static double _expectedMargin({
    required List<double> capacity,
    required PartnershipScoringRules rules,
    required int bid,
    required int tricksInHand,
    required bool weDeclare,
  }) {
    double value = 0;
    for (int taken = 0; taken < capacity.length; taken++) {
      if (capacity[taken] == 0) {
        continue;
      }
      value += capacity[taken] *
          _margin(
            rules: rules,
            bid: bid,
            ourTricks: taken,
            tricksInHand: tricksInHand,
            weDeclare: weDeclare,
          );
    }
    return value;
  }

  /// Our points minus theirs, for a hand of [bid] in which our side takes
  /// [ourTricks].
  ///
  /// Through [PartnershipScoringRules.project], which is the same authority
  /// that pays the real hand -- so the bidder cannot disagree with the scorer
  /// about what a contract is worth, KING and sweeps included.
  static double _margin({
    required PartnershipScoringRules rules,
    required int bid,
    required int ourTricks,
    required int tricksInHand,
    required bool weDeclare,
  }) {
    final List<int> teamTricks = weDeclare
        ? <int>[ourTricks, tricksInHand - ourTricks]
        : <int>[tricksInHand - ourTricks, ourTricks];
    final TeamHandOutcome outcome = rules.project(
      contractBid: bid,
      declarerTeam: 0,
      teamTricks: teamTricks,
      tricksPerHand: tricksInHand,
    );
    final int ours = weDeclare ? outcome.teamPoints[0] : outcome.teamPoints[1];
    final int theirs =
        weDeclare ? outcome.teamPoints[1] : outcome.teamPoints[0];
    return (ours - theirs).toDouble();
  }

  /// A truncated bell over team trick counts, centred on [mean].
  static List<double> _distribution({
    required double mean,
    required int tricksInHand,
  }) {
    final List<double> weights = List<double>.filled(tricksInHand + 1, 0);
    double total = 0;
    const double variance = capacitySpread * capacitySpread;
    for (int taken = 0; taken <= tricksInHand; taken++) {
      final double delta = taken - mean;
      final double weight = math.exp(-(delta * delta) / (2 * variance));
      weights[taken] = weight;
      total += weight;
    }
    if (total == 0) {
      weights[mean.round().clamp(0, tricksInHand)] = 1;
      return weights;
    }
    for (int taken = 0; taken <= tricksInHand; taken++) {
      weights[taken] /= total;
    }
    return weights;
  }
}

/// What one suit is worth as trump for one side.
///
/// Carries the two halves separately as well as the total, because which half
/// a contract rests on changes how it should be played: a hand whose value is
/// its own trump length plays differently from one relying on an unseen
/// partner.
final class TeamAppraisal {
  const TeamAppraisal({
    required this.trump,
    required this.ownCapacity,
    required this.partnerCapacity,
    required this.teamCapacity,
    required this.trumpLength,
    required this.topTrumps,
  });

  final Suit trump;

  /// Tricks the asking hand expects on its own.
  final double ownCapacity;

  /// Tricks an unknown partner is expected to add, before overlap.
  final double partnerCapacity;

  /// Tricks the side expects together, overlap already subtracted.
  final double teamCapacity;

  final int trumpLength;

  /// Trumps winning from the top, counting down from the ace.
  final int topTrumps;

  @override
  String toString() => 'TeamAppraisal($trump: '
      '${teamCapacity.toStringAsFixed(2)} tricks '
      '(${ownCapacity.toStringAsFixed(2)} mine + '
      '${partnerCapacity.toStringAsFixed(2)} partner), '
      '$trumpLength long)';
}
