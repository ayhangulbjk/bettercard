import 'package:batak_king/core/ai/card_tracker.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_positions.dart';

void main() {
  group('the observation leaks no hidden information', () {
    test('it exposes only the observer hand and publicly played cards', () {
      // The decisive anti-cheating property: everything reachable through the
      // observation must be either the observer hand or already public.
      for (int plies = 0; plies <= 7; plies++) {
        final TrickPlayState state = TestPositions.dealt(plies: plies);
        for (int seat = 0; seat < 4; seat++) {
          final SeatObservation observation =
              SeatObservation.fromState(state, seat);

          final Set<PlayingCard> visible = <PlayingCard>{
            ...observation.hand,
            ...observation.publiclyPlayedCards,
            ...observation.legalMoves,
          };
          final Set<PlayingCard> hidden = <PlayingCard>{
            for (int other = 0; other < 4; other++)
              if (other != seat) ...state.handOf(other),
          };

          expect(
            visible.intersection(hidden),
            isEmpty,
            reason: 'seat $seat could see another hand after $plies plies',
          );
        }
      }
    });

    test('the observed hand is exactly the real hand for that seat', () {
      final TrickPlayState state = TestPositions.dealt(plies: 5);
      for (int seat = 0; seat < 4; seat++) {
        expect(
          SeatObservation.fromState(state, seat).hand,
          equals(state.handOf(seat)),
        );
      }
    });

    test('hand sizes are public', () {
      final TrickPlayState state = TestPositions.dealt(plies: 6);
      expect(
        SeatObservation.fromState(state, 0).handSizes,
        equals(state.handSizes),
      );
    });

    test('legal moves are a subset of the observer hand', () {
      final TrickPlayState state = TestPositions.dealt(plies: 3);
      final SeatObservation observation =
          SeatObservation.fromState(state, state.turnSeat);
      for (final PlayingCard card in observation.legalMoves) {
        expect(observation.hand, contains(card));
      }
    });

    test('observation collections are unmodifiable', () {
      final SeatObservation observation =
          SeatObservation.fromState(TestPositions.dealt(), 0);
      expect(
        () => observation.hand.add(const PlayingCard(Suit.spades, Rank.ace)),
        throwsUnsupportedError,
      );
      expect(() => observation.handSizes.add(0), throwsUnsupportedError);
    });
  });

  group('CardTracker infers only what is provable', () {
    test('unseen cards exclude played cards and the observer hand', () {
      final TrickPlayState state = TestPositions.dealt(plies: 9);
      final SeatObservation observation = SeatObservation.fromState(state, 0);
      final CardTracker tracker = CardTracker.fromObservation(observation);

      for (final PlayingCard card in observation.hand) {
        expect(tracker.unseenCards, isNot(contains(card)));
      }
      for (final PlayingCard card in observation.publiclyPlayedCards) {
        expect(tracker.unseenCards, isNot(contains(card)));
      }
      expect(
        tracker.unseenCards.length,
        52 - observation.hand.length - observation.publiclyPlayedCards.length,
      );
    });

    test('unseen cards are exactly the other seats cards', () {
      final TrickPlayState state = TestPositions.dealt(plies: 8);
      final CardTracker tracker = CardTracker.fromObservation(
        SeatObservation.fromState(state, 0),
      );
      expect(
        tracker.unseenCards,
        equals(<PlayingCard>{
          for (int seat = 1; seat < 4; seat++) ...state.handOf(seat),
        }),
      );
    });

    test('a recorded void is always a real void', () {
      // Every inference must be true of the actual deal, otherwise the AI
      // would be reasoning from a false premise.
      for (int seed = 1; seed <= 20; seed++) {
        final TrickPlayState state = TestPositions.dealt(seed: seed, plies: 16);
        final CardTracker tracker = CardTracker.fromObservation(
          SeatObservation.fromState(state, 0),
        );
        for (int seat = 0; seat < 4; seat++) {
          for (final Suit suit in tracker.knownVoids[seat]) {
            expect(
              state.handOf(seat).any((PlayingCard card) => card.suit == suit),
              isFalse,
              reason: 'seat $seat marked void in $suit but still holds one',
            );
          }
        }
      }
    });

    test('the observer is never marked void in anything', () {
      final CardTracker tracker = CardTracker.fromObservation(
        SeatObservation.fromState(TestPositions.dealt(plies: 12), 1),
      );
      expect(tracker.knownVoids[1], isEmpty);
    });
  });
}
