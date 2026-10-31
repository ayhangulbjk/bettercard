import 'package:batak_king/core/ai/card_tracker.dart';
import 'package:batak_king/core/ai/hidden_hand_sampler.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/util/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_positions.dart';

const HiddenHandSampler sampler = HiddenHandSampler();

({SeatObservation observation, CardTracker tracker}) viewOf(
  TrickPlayState state, {
  int seat = 0,
}) {
  final SeatObservation observation = SeatObservation.fromState(state, seat);
  return (
    observation: observation,
    tracker: CardTracker.fromObservation(observation),
  );
}

void main() {
  test('sampled deals match public hand sizes and exclude played cards', () {
    final TrickPlayState state = TestPositions.dealt(plies: 10);
    final view = viewOf(state);

    final List<SampledDeal> deals = sampler.sampleMany(
      observation: view.observation,
      tracker: view.tracker,
      random: SeededRandom(4242),
      count: 40,
    );
    expect(deals, hasLength(40));

    final Set<PlayingCard> played =
        view.observation.publiclyPlayedCards.toSet();

    for (final SampledDeal deal in deals) {
      expect(deal.hands[0], equals(view.observation.hand));
      for (int seat = 0; seat < 4; seat++) {
        expect(deal.hands[seat], hasLength(view.observation.handSizes[seat]));
        for (final PlayingCard card in deal.hands[seat]) {
          expect(played, isNot(contains(card)));
        }
      }
      final List<PlayingCard> all = <PlayingCard>[
        for (final List<PlayingCard> hand in deal.hands) ...hand,
      ];
      expect(all.toSet(), hasLength(all.length));
    }
  });

  test('sampled deals respect every inferred void', () {
    final TrickPlayState state = TestPositions.dealt(seed: 31, plies: 18);
    final view = viewOf(state);

    final List<SampledDeal> deals = sampler.sampleMany(
      observation: view.observation,
      tracker: view.tracker,
      random: SeededRandom(9),
      count: 30,
    );
    expect(deals, isNotEmpty);

    for (final SampledDeal deal in deals) {
      for (int seat = 1; seat < 4; seat++) {
        for (final Suit suit in view.tracker.knownVoids[seat]) {
          expect(
            deal.hands[seat].any((PlayingCard card) => card.suit == suit),
            isFalse,
          );
        }
      }
    }
  });

  test('the sampler explores more than one world', () {
    // A sampler that always returned the same assignment would make Monte
    // Carlo rollouts worthless, so this guards against a degenerate shuffle.
    final view = viewOf(TestPositions.dealt(plies: 4));
    final SeededRandom random = SeededRandom(55);
    final Set<String> distinct = <String>{
      for (int i = 0; i < 20; i++)
        (sampler.sample(
          observation: view.observation,
          tracker: view.tracker,
          random: random,
        )!)
            .hands[1]
            .map((PlayingCard c) => c.id)
            .join(','),
    };
    expect(distinct.length, greaterThan(1));
  });

  test('sampling is reproducible for a given seed', () {
    final view = viewOf(TestPositions.dealt(plies: 6));
    final SampledDeal? first = sampler.sample(
      observation: view.observation,
      tracker: view.tracker,
      random: SeededRandom(100),
    );
    final SampledDeal? second = sampler.sample(
      observation: view.observation,
      tracker: view.tracker,
      random: SeededRandom(100),
    );
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.hands[1], equals(second!.hands[1]));
  });

  test('an inconsistent bury count is a caller error, not a bad draw', () {
    final view = viewOf(TestPositions.dealt());
    expect(
      () => sampler.sample(
        observation: view.observation,
        tracker: view.tracker,
        random: SeededRandom(1),
        buriedCount: 5,
      ),
      throwsArgumentError,
    );
  });
}
