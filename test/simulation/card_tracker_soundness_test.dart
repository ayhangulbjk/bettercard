// Every conclusion the AI draws about a hidden hand must be true.
//
// `CardTracker` is allowed to rule possibilities out, never in, and a
// one-sided inference is only useful if it is never wrong: a policy that
// trusts a card placement which cannot happen plays worse than one that knows
// nothing. So this plays real hands and checks each inference against the
// hands it could not see.
//
// Reading the true hands here is allowed and is the point. The rule is that
// hidden state may be used to *score* an agent, never fed back into one, and
// nothing here reaches a policy.

import 'package:batak_king/core/ai/card_tracker.dart';
import 'package:batak_king/core/ai/hidden_hand_sampler.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/deck.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_engine.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:batak_king/core/util/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands to play. Enough to see plenty of cut tricks and declined raises,
/// few enough to keep the suite fast.
const int _handCount = 60;
const int _players = 4;

void main() {
  group('card tracker soundness', () {
    test('no inference about a hidden hand is ever false', () {
      int voidsChecked = 0;
      int ceilingsChecked = 0;

      _forEachPly((TrickPlayState state) {
        for (int observer = 0; observer < _players; observer++) {
          final CardTracker tracker = CardTracker.fromObservation(
            SeatObservation.fromState(state, observer),
          );

          for (int other = 0; other < _players; other++) {
            if (other == observer) {
              continue;
            }
            final List<PlayingCard> real = state.handOf(other);

            for (final Suit suit in Suit.values) {
              if (tracker.isKnownVoid(other, suit)) {
                voidsChecked++;
                expect(
                  real.any((PlayingCard c) => c.suit == suit),
                  isFalse,
                  reason: 'Seat $other was called void in $suit but holds one',
                );
              }
              final int? ceiling = tracker.ceilingOf(other, suit);
              if (ceiling == null) {
                continue;
              }
              ceilingsChecked++;
              for (final PlayingCard card in real) {
                expect(
                  card.suit != suit || card.strength <= ceiling,
                  isTrue,
                  reason: 'Seat $other was capped at $ceiling in $suit '
                      'but holds $card',
                );
              }
            }
          }
        }
      });

      // A test that proved nothing would pass silently, so assert that the
      // inferences actually fired. The ceiling one is new and is the reason
      // this file exists.
      expect(voidsChecked, greaterThan(0));
      expect(ceilingsChecked, greaterThan(0));
    });

    test('the unseen set never omits a card another seat holds', () {
      _forEachPly((TrickPlayState state) {
        for (int observer = 0; observer < _players; observer++) {
          final CardTracker tracker = CardTracker.fromObservation(
            SeatObservation.fromState(state, observer),
          );
          for (int other = 0; other < _players; other++) {
            if (other == observer) {
              continue;
            }
            for (final PlayingCard card in state.handOf(other)) {
              expect(
                tracker.unseenCards.contains(card),
                isTrue,
                reason: '$card is in seat $other but not in the unseen set',
              );
            }
          }
        }
      });
    });

    test('every sampled world could have been the real one', () {
      // The sampler is the only thing that turns inferences into play, so a
      // sound tracker with a careless sampler would still cheat the agent out
      // of its own knowledge. Each sampled deal must respect hand sizes, the
      // played cards, and every inference drawn.
      const HiddenHandSampler sampler = HiddenHandSampler();
      int worlds = 0;

      _forEachPly((TrickPlayState state) {
        if (state.completedTricks.length % 3 != 1) {
          return; // Sampling every ply would make the test slow for no gain.
        }
        const int observer = 0;
        final SeatObservation observation =
            SeatObservation.fromState(state, observer);
        final CardTracker tracker = CardTracker.fromObservation(observation);
        final SeededRandom random = SeededRandom(
          state.completedTricks.length * 7919 + 13,
        );

        for (final SampledDeal deal in sampler.sampleMany(
          observation: observation,
          tracker: tracker,
          random: random,
          count: 4,
        )) {
          worlds++;
          expect(deal.hands[observer], equals(observation.hand));
          for (int seat = 0; seat < _players; seat++) {
            expect(
              deal.hands[seat].length,
              observation.handSizes[seat],
              reason: 'Sampled hand for seat $seat is the wrong size',
            );
            if (seat == observer) {
              continue;
            }
            for (final PlayingCard card in deal.hands[seat]) {
              expect(
                tracker.playedCards.contains(card),
                isFalse,
                reason: '$card has already been played',
              );
              expect(
                tracker.couldHold(seat, card),
                isTrue,
                reason: '$card contradicts what seat $seat has shown',
              );
            }
          }
        }
      });

      expect(worlds, greaterThan(0));
    });
  });
}

/// Plays [_handCount] Koz Maca hands with the heuristic policy and calls
/// [check] before every card, with the authoritative state.
///
/// Koz Maca rules specifically: compulsory cutting, overcutting and raising
/// are what produce the inferences under test, and a permissive rule set
/// would exercise none of them.
void _forEachPly(void Function(TrickPlayState state) check) {
  const TrickPlayEngine engine = TrickPlayEngine();

  for (int hand = 0; hand < _handCount; hand++) {
    final int seed = 4242 + hand;
    final Deal deal = Deck.shuffleAndDeal(
      seed: seed,
      handCount: _players,
      handSize: 52 ~/ _players,
    );
    TrickPlayState state = TrickPlayState.opening(
      hands: deal.hands,
      seating: SeatingPlan.individual(_players),
      rules: TrickRules.kozMaca,
      trump: Suit.spades,
      leadSeat: seed % _players,
    );
    final List<HeuristicPolicy> policies = <HeuristicPolicy>[
      for (int seat = 0; seat < _players; seat++)
        HeuristicPolicy(seed: seed * 31 + seat),
    ];

    while (!engine.isTerminal(state)) {
      check(state);
      final int seat = state.turnSeat;
      final PlayingCard card = policies[seat].chooseCardSync(
        SeatObservation.fromState(state, seat),
      );
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: seat, card: card),
      );
      state = switch (outcome) {
        CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
          next,
        CommandRejected<TrickPlayState>() =>
          throw StateError('Illegal move in hand $seed'),
      };
    }
  }
}
