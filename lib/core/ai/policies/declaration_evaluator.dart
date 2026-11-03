import 'dart:math' as math;

import '../../cards/playing_card.dart';
import '../../cards/rank.dart';
import '../../cards/suit.dart';
import '../../rules/declaration_rules.dart';
import '../seat_observation.dart';

/// How many tricks a hand is worth promising.
///
/// Split out of the policy because it is a different question from which card
/// to play: it is asked once a hand, from a static hand, against a payoff
/// table. Keeping it here also keeps the three measured constants together
/// with the reasoning that set them.
///
/// The numbers below were tuned against the simulator, not chosen. Each one
/// records what moved it, because a constant with no measurement behind it is
/// a guess with a decimal point; see docs/AI_BENCHMARKS.md for the sweeps.

/// Spread of the capacity estimate, in tricks.
///
/// The hand is promised before a card is played, so what the estimate is
/// worth depends entirely on how wrong it usually is. Measured against the
/// simulator rather than guessed; see docs/AI_BENCHMARKS.md.
const double declarationSpread = 1.30;

/// The share of unwanted tricks the policy actually manages to shed.
///
/// This is the number that makes the declaration model honest. A seat that
/// promises fewer tricks than its hand can take does not then take fewer:
/// with cutting, overcutting and raising all compulsory, a hand full of
/// high cards is dragged into tricks it would rather lose. Measurement puts
/// the leak at roughly half -- see docs/AI_BENCHMARKS.md -- so promising
/// one trick below capacity costs about half a trick of overshoot, not a
/// whole one.
///
/// An earlier version of this evaluator left it out, treating the trick
/// count as independent of the word. It promised about one trick low, the
/// overshoot rate went from 18% to 30%, and the agent lost half its points
/// per hand. The feedback between the word and the play is not a detail.
const double duckEffectiveness = 0.0;

/// Correction added to the raw hand valuation, in tricks.
///
/// [expectedTricks] counts winners a hand holds. What it misses is that a
/// seat chasing its word takes tricks the valuation never credited -- a
/// long suit that runs, a cut that lands, an opponent's winner that falls
/// under a higher one. Measured against the simulator the shortfall is
/// about this much; see docs/AI_BENCHMARKS.md.
const double capacityBias = 0.6;

/// How far another seat's word pulls this seat's estimate down.
const double crowdingWeight = 0.35;

/// Promises the number of tricks worth the most points, not the number the
/// hand is most likely to take.
///
/// Those are different answers and the difference is the whole problem.
/// Rounding the estimate maximises the chance of being exactly right, which
/// would be correct if the payoff were symmetric. It is not: missing the
/// word costs the full stake, and so does collecting [overtrickBustThreshold]
/// extras, so the penalty is one-sided around a number that is itself
/// uncertain by more than a trick. Promising the rounded estimate therefore
/// loses points to both edges at once.
///
/// Instead the estimate becomes a distribution over trick counts, and each
/// legal word is scored by what it would be paid across that distribution
/// through [DeclarationRules.scoreFor] -- the same authority that pays the
/// real hand. The best expected payoff wins. Two useful things fall out of
/// that rather than being coded: a table that busts on two extras is
/// promised more cautiously than one that busts on three, and "el almaz"
/// stops being a special case and becomes the option whose expected payoff
/// is almost always -50.
int chooseDeclarationFor(SeatObservation observation, List<int> options) {
  final DeclarationRules rules = observation.match.declarationRules;
  final int tricksInHand = observation.hand.length;
  final List<double> capacity = _capacityDistribution(
    mean: _adjustedEstimate(observation, tricksInHand),
    tricksInHand: tricksInHand,
  );

  int best = options.first;
  double bestValue = double.negativeInfinity;
  for (final int option in options) {
    double value = 0;
    for (int reachable = 0; reachable <= tricksInHand; reachable++) {
      if (capacity[reachable] == 0) {
        continue;
      }
      value += capacity[reachable] *
          rules.scoreFor(
            declaration: option,
            tricksTaken: _expectedTaken(option, reachable),
          );
    }
    // Strictly greater, so a tie goes to the lower word: the same expected
    // points for a smaller stake is the better bet.
    if (value > bestValue) {
      bestValue = value;
      best = option;
    }
  }
  return best;
}

/// Tricks actually taken when this hand can reach [capacity] and the seat
/// promised [declaration].
///
/// Below the word the hand simply falls short: there is nothing to shed.
/// Above it, the seat spends the rest of the hand trying to lose and keeps
/// only the [duckEffectiveness] share it cannot avoid.
int _expectedTaken(int declaration, int capacity) {
  if (capacity <= declaration) {
    return capacity;
  }
  final double leaked = (capacity - declaration) * (1 - duckEffectiveness);
  return declaration + leaked.round();
}

/// The trick estimate, pulled down by what the table has already claimed.
///
/// The words spoken before this seat are evidence about how the tricks are
/// spread, and the hand holds only so many. The correction is one-way by
/// design: tables over-claim far more often than they under-claim, and the
/// seat that insists on its own optimistic count when the others have
/// already spoken for the hand is the one that goes down.
double _adjustedEstimate(SeatObservation observation, int tricksInHand) {
  final double estimate = expectedTricks(observation) + capacityBias;
  final List<int?> words = observation.match.declarations;
  if (words.isEmpty) {
    return estimate;
  }
  int claimed = 0;
  int silent = 0;
  for (final int? word in words) {
    if (word == null) {
      silent++;
    } else {
      claimed += word;
    }
  }
  if (silent == 0) {
    return estimate;
  }
  final double available = math.max(0, tricksInHand - claimed) / silent;
  if (available >= estimate) {
    return estimate;
  }
  return estimate * (1 - crowdingWeight) + available * crowdingWeight;
}

/// A discrete distribution over how many tricks this hand can take if the
/// seat tries for all of them.
///
/// Capacity, not outcome: what the hand is worth when chased. The outcome
/// follows from it and the word, through [_expectedTaken].
///
/// A truncated bell of width [declarationSpread]. It is an approximation and
/// is labelled as one: the real distribution is skewed and depends on the
/// hand's shape.
List<double> _capacityDistribution({
  required double mean,
  required int tricksInHand,
}) {
  final List<double> weights = List<double>.filled(tricksInHand + 1, 0);
  double total = 0;
  const double variance = declarationSpread * declarationSpread;
  for (int taken = 0; taken <= tricksInHand; taken++) {
    final double delta = taken - mean;
    final double weight = math.exp(-(delta * delta) / (2 * variance));
    weights[taken] = weight;
    total += weight;
  }
  if (total == 0) {
    // Degenerate only if every weight underflowed, which needs an estimate
    // far outside the hand. Fall back to certainty at the nearest count.
    final int nearest = mean.round().clamp(0, tricksInHand);
    weights[nearest] = 1;
    return weights;
  }
  for (int taken = 0; taken <= tricksInHand; taken++) {
    weights[taken] /= total;
  }
  return weights;
}

/// Expected trick count for a hand that has not been played yet.
double expectedTricks(SeatObservation observation) {
  final Suit? trump = observation.trump;
  final Map<Suit, List<PlayingCard>> bySuit = <Suit, List<PlayingCard>>{};
  for (final PlayingCard card in observation.hand) {
    bySuit.putIfAbsent(card.suit, () => <PlayingCard>[]).add(card);
  }

  double tricks = 0;
  for (final MapEntry<Suit, List<PlayingCard>> entry in bySuit.entries) {
    final List<PlayingCard> cards = entry.value
      ..sort(
          (PlayingCard a, PlayingCard b) => b.strength.compareTo(a.strength));
    final bool isTrump = entry.key == trump;
    final int length = cards.length;

    for (int index = 0; index < cards.length; index++) {
      final Rank rank = cards[index].rank;
      if (rank == Rank.ace) {
        tricks += 1;
      } else if (rank == Rank.king) {
        // A king needs one card to duck under it before it can win.
        tricks += length >= 2 ? 0.85 : 0.45;
      } else if (rank == Rank.queen) {
        tricks += length >= 3 ? 0.55 : 0.2;
      } else if (isTrump && rank == Rank.jack && length >= 4) {
        tricks += 0.3;
      }
    }

    if (isTrump) {
      // Trumps past the fourth tend to win once the others are drawn.
      tricks += length > 4 ? (length - 4) * 0.8 : 0;
    } else if (trump != null && length <= 1) {
      // A short side suit is a chance to cut -- worth something, but less
      // than tables assume, because every other seat must cut as well.
      tricks += length == 0 ? 0.5 : 0.25;
    }
  }
  return tricks;
}
