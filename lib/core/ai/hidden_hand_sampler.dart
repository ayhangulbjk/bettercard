import '../cards/playing_card.dart';
import '../util/seeded_random.dart';
import 'card_tracker.dart';
import 'seat_observation.dart';

/// One complete, plausible deal consistent with a seat's observation.
///
/// The observer's own hand is the real one; every other seat's hand is a guess
/// drawn from the unseen cards.
final class SampledDeal {
  SampledDeal({
    required List<List<PlayingCard>> hands,
    required List<PlayingCard> buried,
  })  : hands = List<List<PlayingCard>>.unmodifiable(
          hands.map(List<PlayingCard>.unmodifiable),
        ),
        buried = List<PlayingCard>.unmodifiable(buried);

  /// Hands indexed by seat.
  final List<List<PlayingCard>> hands;

  /// Cards assigned to the face-down pile, for buried variants.
  final List<PlayingCard> buried;
}

/// Invents hidden hands that are consistent with everything a seat legally
/// knows.
///
/// This is what lets a Monte Carlo policy reason about a hidden-information
/// game without cheating: instead of peeking at the real hands, it samples
/// many worlds that *could* be the real one and evaluates its options across
/// them.
///
/// Consistency means every sampled deal satisfies, exactly:
///
/// * the observer's own hand is unchanged,
/// * no sampled hand contains a card already played,
/// * each seat receives exactly as many cards as it publicly holds,
/// * no seat receives a suit it has proved it is void in,
/// * no seat receives a card above a ceiling it has proved.
///
/// All four are asked through `CardTracker.couldHold`, so a new inference is
/// honoured here the moment the tracker can draw it.
///
/// Sampling is seeded, so a rollout batch is reproducible and a benchmark run
/// is comparable across machines.
final class HiddenHandSampler {
  const HiddenHandSampler({this.maxAttempts = 32});

  /// How many times to retry a constrained assignment before giving up.
  ///
  /// Failure is possible in principle (a tight void pattern can make the
  /// greedy pass paint itself into a corner) but rare. Bounding the retries
  /// keeps a sampling call inside the AI compute budget rather than spinning.
  final int maxAttempts;

  /// Samples one deal, or returns null when no consistent assignment was found
  /// within [maxAttempts].
  ///
  /// [buriedCount] reserves that many unseen cards for the face-down pile.
  SampledDeal? sample({
    required SeatObservation observation,
    required CardTracker tracker,
    required SeededRandom random,
    int buriedCount = 0,
  }) {
    final int players = observation.seating.playerCount;
    final List<int> capacity = List<int>.generate(
      players,
      (int seat) => seat == observation.seat ? 0 : observation.handSizes[seat],
      growable: false,
    );
    final int demand =
        capacity.fold<int>(0, (int a, int b) => a + b) + buriedCount;
    if (demand != tracker.unseenCards.length) {
      // The observation and the requested bury count disagree with the number
      // of unseen cards. That is a caller bug, not an unlucky draw.
      throw ArgumentError(
        'Unseen cards (${tracker.unseenCards.length}) do not match demand '
        '($demand) for ${players}p with buriedCount $buriedCount',
      );
    }

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final SampledDeal? deal = _attempt(
        observation: observation,
        tracker: tracker,
        random: random,
        capacity: capacity,
        buriedCount: buriedCount,
      );
      if (deal != null) {
        return deal;
      }
    }
    return null;
  }

  /// Samples [count] deals, skipping failed attempts.
  ///
  /// Returns fewer than [count] entries if sampling repeatedly fails; the
  /// caller decides whether a thin sample is still usable rather than being
  /// blocked.
  List<SampledDeal> sampleMany({
    required SeatObservation observation,
    required CardTracker tracker,
    required SeededRandom random,
    required int count,
    int buriedCount = 0,
  }) {
    final List<SampledDeal> deals = <SampledDeal>[];
    for (int i = 0; i < count; i++) {
      final SampledDeal? deal = sample(
        observation: observation,
        tracker: tracker,
        random: random,
        buriedCount: buriedCount,
      );
      if (deal != null) {
        deals.add(deal);
      }
    }
    return deals;
  }

  SampledDeal? _attempt({
    required SeatObservation observation,
    required CardTracker tracker,
    required SeededRandom random,
    required List<int> capacity,
    required int buriedCount,
  }) {
    final List<int> remaining = List<int>.of(capacity);
    int buriedRemaining = buriedCount;
    final List<List<PlayingCard>> hands = List<List<PlayingCard>>.generate(
      observation.seating.playerCount,
      (_) => <PlayingCard>[],
      growable: false,
    );
    final List<PlayingCard> buried = <PlayingCard>[];

    // Most-constrained-first: a card that only one seat could hold must be
    // placed before the cards that fit anywhere, or that seat fills up with
    // flexible cards and the assignment dead-ends.
    final List<PlayingCard> order = tracker.unseenCards.toList()
      ..sort((PlayingCard a, PlayingCard b) {
        final int byFreedom = _eligibleSeatCount(a, tracker, capacity)
            .compareTo(_eligibleSeatCount(b, tracker, capacity));
        return byFreedom != 0 ? byFreedom : a.id.compareTo(b.id);
      });

    for (final PlayingCard card in order) {
      final List<int> options = <int>[
        for (int seat = 0; seat < remaining.length; seat++)
          if (remaining[seat] > 0 && tracker.couldHold(seat, card)) seat,
      ];
      final int optionCount = options.length + (buriedRemaining > 0 ? 1 : 0);
      if (optionCount == 0) {
        return null;
      }
      final int pick = random.nextInt(optionCount);
      if (pick == options.length) {
        buried.add(card);
        buriedRemaining--;
      } else {
        final int seat = options[pick];
        hands[seat].add(card);
        remaining[seat]--;
      }
    }

    hands[observation.seat] = observation.hand.toList();
    return SampledDeal(hands: hands, buried: buried);
  }

  static int _eligibleSeatCount(
    PlayingCard card,
    CardTracker tracker,
    List<int> capacity,
  ) {
    int count = 0;
    for (int seat = 0; seat < capacity.length; seat++) {
      if (capacity[seat] > 0 && tracker.couldHold(seat, card)) {
        count++;
      }
    }
    return count;
  }
}
