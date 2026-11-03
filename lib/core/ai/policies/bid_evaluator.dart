import 'dart:math' as math;

import '../../cards/playing_card.dart';
import '../../cards/rank.dart';
import '../../cards/suit.dart';
import '../../rules/auction_scoring_rules.dart';

/// What a hand is worth as a contract, suit by suit.
///
/// The auction is the first real test of a bot in this mode, and the usual
/// mistake is to answer it with a count of aces. That gets both halves wrong:
/// it over-values a hand with scattered honours and no trump length, and it
/// under-values a hand whose shape is the whole point -- a void and six
/// trumps takes tricks that no amount of counting aces predicts.
///
/// So each of the four suits is valued as a *candidate trump*, and the answer
/// is a capacity in tricks plus a spread. A bid is then judged the way the
/// declaration evaluator judges a word: by the points it is expected to be
/// paid across that spread, through [AuctionScoringRules] -- the same
/// authority that pays the real hand. Passing is an option with a value too,
/// and it is compared on the same scale rather than treated as a fallback.
///
/// Pure, Flutter-free and deterministic. It sees one hand, which is the hand
/// of whoever is asking.
abstract final class BidEvaluator {
  /// Spread of the capacity estimate, in tricks.
  ///
  /// Wider than the Koz Maca equivalent on purpose: a declarer here picks its
  /// own trump and leads to the first trick, but it is also one seat against
  /// three, so the outcome is less concentrated.
  static const double capacitySpread = 1.6;

  /// Correction added to the raw hand valuation, in tricks.
  ///
  /// The count below values the winners a hand can point at. What it cannot
  /// see is the rest: a long suit that runs once trumps are drawn, a cut that
  /// lands, an opponent's honour that falls under a higher one. Measured
  /// against the simulator, a declarer takes about this much more than the
  /// count credits it with -- see tool/checks/auction_probe.dart, which is
  /// what this was set from.
  ///
  /// The same lesson as Koz Maca's `capacityBias`, and learned the same way:
  /// the first version left it out, every bot passed on every hand, and the
  /// auction passed out six times in ten.
  static const double capacityBias = 1.2;

  /// What share of its capacity a hand keeps when it is defending.
  ///
  /// A declarer picks the trump, leads to the first trick and drives the
  /// hand; a defender does none of that, so the same cards take fewer
  /// tricks. Used to value passing on the same scale as bidding, so a bot
  /// declines a contract because defending is worth more rather than because
  /// a threshold said so.
  static const double defenceShare = 0.55;

  /// The suit this hand plays best in, with what it is worth.
  static TrumpAppraisal bestTrump(List<PlayingCard> hand) {
    TrumpAppraisal? best;
    for (final Suit suit in Suit.values) {
      final TrumpAppraisal appraisal = appraise(hand, suit);
      if (best == null || appraisal.capacity > best.capacity) {
        best = appraisal;
      }
    }
    return best!;
  }

  /// Every suit appraised, strongest first. The trump chooser wants the whole
  /// list, not just the winner, so it can see how close the runner-up was.
  static List<TrumpAppraisal> appraiseAll(List<PlayingCard> hand) =>
      <TrumpAppraisal>[
        for (final Suit suit in Suit.values) appraise(hand, suit),
      ]..sort(
          (TrumpAppraisal a, TrumpAppraisal b) =>
              b.capacity.compareTo(a.capacity),
        );

  /// What [hand] can take with [trump] as trump.
  ///
  /// Three sources of tricks, counted separately because they behave
  /// differently and a single weighted sum hides which one a hand is relying
  /// on:
  ///
  /// * **trump length** -- trumps past the number needed to draw the others
  ///   win by themselves, and the top trumps win immediately;
  /// * **side-suit honours** -- an ace is close to a trick, a king needs one
  ///   card under it, a queen needs two, and all of them are worth less in a
  ///   suit long enough that somebody will be void and cutting;
  /// * **shortness** -- a void or singleton is a chance to cut, but only as
  ///   many times as there are trumps to spare, which is why it is capped by
  ///   the trump length rather than added freely.
  static TrumpAppraisal appraise(List<PlayingCard> hand, Suit trump) {
    final Map<Suit, List<PlayingCard>> bySuit = <Suit, List<PlayingCard>>{
      for (final Suit suit in Suit.values) suit: <PlayingCard>[],
    };
    for (final PlayingCard card in hand) {
      bySuit[card.suit]!.add(card);
    }

    final List<PlayingCard> trumps = bySuit[trump]!
      ..sort(
        (PlayingCard a, PlayingCard b) => b.strength.compareTo(a.strength),
      );
    final int trumpLength = trumps.length;

    // Top trumps: each honour in sequence from the ace is a trick almost
    // nobody can take away. Below the sequence a trump is a drawing card
    // rather than a winner.
    double trumpTricks = 0;
    int expected = Rank.ace.strength;
    for (final PlayingCard card in trumps) {
      if (card.strength == expected) {
        trumpTricks += 1;
        expected--;
      } else {
        break;
      }
    }
    // Length past the three rounds it takes to draw the table, less whatever
    // the honours above already counted.
    final double lengthTricks = math.max(0, trumpLength - 3).toDouble();
    trumpTricks = math.max(trumpTricks, 0) + lengthTricks * 0.85;
    if (trumpTricks > trumpLength) {
      trumpTricks = trumpLength.toDouble();
    }

    double sideTricks = 0;
    double shortness = 0;
    for (final Suit suit in Suit.values) {
      if (suit == trump) {
        continue;
      }
      final List<PlayingCard> cards = bySuit[suit]!
        ..sort(
          (PlayingCard a, PlayingCard b) => b.strength.compareTo(a.strength),
        );
      final int length = cards.length;
      for (int index = 0; index < cards.length; index++) {
        final Rank rank = cards[index].rank;
        if (rank == Rank.ace) {
          // An ace is only nearly a trick: somebody may be void and cutting,
          // and the longer this suit is the more likely that is.
          sideTricks += length >= 5 ? 0.75 : 0.9;
        } else if (rank == Rank.king) {
          sideTricks += length >= 2 ? 0.55 : 0.2;
        } else if (rank == Rank.queen) {
          sideTricks += length >= 3 ? 0.3 : 0.1;
        }
      }
      if (length == 0) {
        shortness += 1.2;
      } else if (length == 1) {
        shortness += 0.7;
      } else if (length == 2) {
        shortness += 0.25;
      }
    }
    // A cut needs a trump to spare, so shortness cannot be worth more than
    // the trumps left after the drawing rounds.
    shortness = math.min(shortness, math.max(0, trumpLength - 2).toDouble());

    final double capacity =
        (trumpTricks + sideTricks + shortness + capacityBias)
            .clamp(0, hand.length)
            .toDouble();
    return TrumpAppraisal(
      trump: trump,
      capacity: capacity,
      trumpLength: trumpLength,
      topTrumps: trumpTricks.round(),
    );
  }

  /// The best contract to offer, or null to pass.
  ///
  /// [legalBids] is handed in by the engine for the same reason a card policy
  /// is handed its legal moves: what may be bid is a rule, and rules have one
  /// authority. [mustBid] is the passed-out case, where there is no pass to
  /// compare against.
  ///
  /// ### Why the comparison is relative
  ///
  /// This payoff is not zero sum. A made contract of five pays the declarer
  /// fifty and still leaves eight tricks paying the defenders eighty between
  /// them, so every seat at the table usually finishes a hand richer than it
  /// started. Judging a contract by the points it earns therefore answers the
  /// wrong question, and answers it the same way every time: defending looks
  /// profitable, so a bot that maximises its own points passes on every hand
  /// it is ever dealt.
  ///
  /// What decides a match is the gap, not the total. So every option is
  /// valued as **own points minus the table average**, which is the quantity
  /// that is actually zero sum, and bidding and passing are compared on it.
  /// A contract is worth taking when it gains ground, not when it gains
  /// points.
  static int? chooseBid({
    required List<PlayingCard> hand,
    required List<int> legalBids,
    required AuctionScoringRules rules,
    required TrumpAppraisal appraisal,
    int? standingBid,
    bool mustBid = false,
    double riskAppetite = 0,
  }) {
    if (legalBids.isEmpty) {
      return null;
    }
    final int tricksInHand = hand.length;
    final List<double> capacity = _capacityDistribution(
      mean: appraisal.capacity + riskAppetite,
      tricksInHand: tricksInHand,
    );

    final double passValue = mustBid
        ? double.negativeInfinity
        : expectedDefenceValue(
            hand: hand,
            appraisal: appraisal,
            rules: rules,
            againstBid: standingBid ?? legalBids.first,
          );

    int? best;
    double bestValue = passValue;
    for (final int bid in legalBids) {
      double value = 0;
      for (int taken = 0; taken < capacity.length; taken++) {
        if (capacity[taken] == 0) {
          continue;
        }
        value += capacity[taken] *
            _relativeAsDeclarer(
              rules: rules,
              bid: bid,
              tricksTaken: taken,
              tricksInHand: tricksInHand,
            );
      }
      if (value > bestValue) {
        bestValue = value;
        best = bid;
      }
    }
    return best ?? (mustBid ? legalBids.first : null);
  }

  /// Ground gained by declaring [bid] and taking [tricksTaken].
  ///
  /// The other three seats share what is left of the hand, which is what
  /// makes a contract worth more than its own points: every trick the
  /// declarer takes is a trick no defender is paid for.
  static double _relativeAsDeclarer({
    required AuctionScoringRules rules,
    required int bid,
    required int tricksTaken,
    required int tricksInHand,
  }) {
    final int mine = rules.declarerScore(bid: bid, tricksTaken: tricksTaken);
    final double theirs = _defenderShare(
      rules: rules,
      bid: bid,
      tricksLeft: tricksInHand - tricksTaken,
    );
    return mine - (mine + theirs * 3) / 4;
  }

  /// Ground gained by defending a contract of [againstBid] with the hand this
  /// [appraisal] describes.
  ///
  /// The declarer is assumed to make its contract, which is the pessimistic
  /// reading and the right one for a seat deciding whether to let somebody
  /// else have the hand.
  static double expectedDefenceValue({
    required List<PlayingCard> hand,
    required TrumpAppraisal appraisal,
    required AuctionScoringRules rules,
    required int againstBid,
  }) {
    final int tricksInHand = hand.length;
    final List<double> defence = _capacityDistribution(
      mean: appraisal.capacity * defenceShare,
      tricksInHand: tricksInHand,
    );
    final int declarerPoints =
        rules.declarerScore(bid: againstBid, tricksTaken: againstBid);

    double value = 0;
    for (int taken = 0; taken < defence.length; taken++) {
      if (defence[taken] == 0) {
        continue;
      }
      final int mine = rules.defenderScore(bid: againstBid, tricksTaken: taken);
      // The two other defenders share whatever this seat did not take.
      final double others = _defenderShare(
        rules: rules,
        bid: againstBid,
        tricksLeft: tricksInHand - againstBid - taken,
        amongSeats: 2,
      );
      value +=
          defence[taken] * (mine - (mine + declarerPoints + others * 2) / 4);
    }
    return value;
  }

  /// What one of [amongSeats] defenders scores from [tricksLeft] tricks.
  static double _defenderShare({
    required AuctionScoringRules rules,
    required int bid,
    required int tricksLeft,
    int amongSeats = 3,
  }) {
    if (tricksLeft <= 0) {
      // Everybody is shut out, which is the expensive case and the reason a
      // declarer wants the last tricks as well as the ones it promised.
      return rules.defenderScore(bid: bid, tricksTaken: 0).toDouble();
    }
    final double each = tricksLeft / amongSeats;
    final int low = each.floor();
    final double fraction = each - low;
    return (1 - fraction) * rules.defenderScore(bid: bid, tricksTaken: low) +
        fraction * rules.defenderScore(bid: bid, tricksTaken: low + 1);
  }

  /// A truncated bell over trick counts, centred on [mean].
  static List<double> _capacityDistribution({
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

/// What one suit is worth as trump for one hand.
final class TrumpAppraisal {
  const TrumpAppraisal({
    required this.trump,
    required this.capacity,
    required this.trumpLength,
    required this.topTrumps,
  });

  final Suit trump;

  /// Tricks this hand expects to take with [trump] as trump, if it tries for
  /// all of them.
  final double capacity;

  final int trumpLength;

  /// Trumps winning from the top, counting down from the ace.
  final int topTrumps;

  @override
  String toString() => 'TrumpAppraisal($trump: ${capacity.toStringAsFixed(2)} '
      'tricks, $trumpLength long, $topTrumps top)';
}
