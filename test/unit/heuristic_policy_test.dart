// What the heuristic policy does at the positions where points and tricks
// disagree.
//
// The benchmark says whether the policy is stronger on average; these say
// whether it does the right thing in the specific situations the rules make
// interesting. Both are needed: an average can hide a position that is always
// played wrong, and a position cannot tell you whether the whole is an
// improvement.

import 'package:batak_king/core/ai/match_context.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/rules/declaration_rules.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard card(Suit suit, Rank rank) => PlayingCard(suit, rank);

/// An observation for seat 0 with the declaration situation spelled out.
///
/// Built directly rather than through `SeatObservation.fromState` because the
/// point is to pin one position exactly; the funnel itself is tested in
/// `ai_information_filter_test.dart`.
SeatObservation observation({
  required List<PlayingCard> hand,
  required List<PlayingCard> legal,
  required int declared,
  required int tricksTaken,
  Trick? trick,
  int? bustThreshold = 3,
}) {
  const int seats = 4;
  return SeatObservation(
    seat: 0,
    hand: hand,
    seating: SeatingPlan.individual(seats),
    rules: TrickRules.kozMaca,
    trump: Suit.spades,
    trumpBroken: true,
    currentTrick: trick ?? Trick(leadSeat: 0, expectedPlays: seats),
    trickHistory: const <CompletedTrick>[],
    handSizes: <int>[hand.length, hand.length, hand.length, hand.length],
    tricksWon: <int>[tricksTaken, 0, 0, 0],
    legalMoves: legal,
    match: MatchContext(
      declarationRules: DeclarationRules.kozMacaStandard.copyWith(
        overtrickBustThreshold: bustThreshold,
        clearOvertrickBustThreshold: bustThreshold == null,
      ),
      declarations: <int?>[declared, 4, 3, 3],
      totalScores: const <int>[0, 0, 0, 0],
    ),
  );
}

/// A trick led by seat 1 with a middling heart, which seat 0 can beat or duck.
Trick heartsLed() => Trick(
      leadSeat: 1,
      expectedPlays: 4,
      plays: const <PlayedCard>[
        PlayedCard(seat: 1, card: PlayingCard(Suit.hearts, Rank.nine)),
      ],
    );

void main() {
  group('declaration', () {
    test('a tighter bust threshold is promised more cautiously', () {
      // The same hand at two tables. Nothing about the cards changes, so any
      // difference is the rule being read -- which is the whole reason the
      // threshold is carried in the observation.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.spades, Rank.ace),
        card(Suit.spades, Rank.king),
        card(Suit.spades, Rank.queen),
        card(Suit.spades, Rank.five),
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.king),
        card(Suit.hearts, Rank.three),
        card(Suit.clubs, Rank.ace),
        card(Suit.clubs, Rank.four),
        card(Suit.diamonds, Rank.king),
        card(Suit.diamonds, Rank.seven),
        card(Suit.diamonds, Rank.six),
        card(Suit.diamonds, Rank.two),
      ];
      final List<int> options = <int>[for (int i = 0; i <= 13; i++) i];
      final HeuristicPolicy policy = HeuristicPolicy(seed: 1);

      final int atThree = policy.chooseDeclarationSync(
        observation(
          hand: hand,
          legal: hand,
          declared: 0,
          tricksTaken: 0,
        ),
        options,
      );
      final int atTwo = policy.chooseDeclarationSync(
        observation(
          hand: hand,
          legal: hand,
          declared: 0,
          tricksTaken: 0,
          bustThreshold: 2,
        ),
        options,
      );
      expect(atTwo, lessThanOrEqualTo(atThree));
    });

    test('the promise is always one of the offered numbers', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.spades, Rank.two),
        card(Suit.hearts, Rank.three),
        card(Suit.clubs, Rank.four),
      ];
      // A deliberately gappy option list: a policy that computes a number and
      // returns it would fail here, which is the point.
      const List<int> options = <int>[2, 5, 9];
      final int promise = HeuristicPolicy(seed: 7).chooseDeclarationSync(
        observation(hand: hand, legal: hand, declared: 0, tricksTaken: 0),
        options,
      );
      expect(options, contains(promise));
    });
  });

  group('playing past the word', () {
    test('ducks the trick when one more would sink the hand', () {
      // Declared 3, taken 5: two extras, and a third sinks it. The ace wins
      // the trick and costs 50 points; the two loses it and costs nothing.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.two),
        card(Suit.clubs, Rank.eight),
      ];
      final PlayingCard played = HeuristicPolicy(seed: 3).chooseCardSync(
        observation(
          hand: hand,
          legal: <PlayingCard>[
            card(Suit.hearts, Rank.ace),
            card(Suit.hearts, Rank.two),
          ],
          declared: 3,
          tricksTaken: 5,
          trick: heartsLed(),
        ),
      );
      expect(played, card(Suit.hearts, Rank.two));
    });

    test('still chases while the word is unkept', () {
      // Same cards, same trick, but the word is not made yet. Now the trick
      // is worth taking and the ace is the card that takes it.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.two),
        card(Suit.clubs, Rank.eight),
      ];
      final PlayingCard played = HeuristicPolicy(seed: 3).chooseCardSync(
        observation(
          hand: hand,
          legal: <PlayingCard>[
            card(Suit.hearts, Rank.ace),
            card(Suit.hearts, Rank.two),
          ],
          declared: 6,
          tricksTaken: 5,
          trick: heartsLed(),
        ),
      );
      expect(played, card(Suit.hearts, Rank.ace));
    });

    test('a table with no bust rule keeps taking tricks', () {
      // Identical to the ducking case except that extras cannot sink a hand.
      // Then an extra is worth a point and there is nothing to avoid.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.two),
      ];
      final PlayingCard played = HeuristicPolicy(seed: 3).chooseCardSync(
        observation(
          hand: hand,
          legal: hand,
          declared: 3,
          tricksTaken: 5,
          trick: heartsLed(),
          bustThreshold: null,
        ),
      );
      expect(played, card(Suit.hearts, Rank.ace));
    });

    test('sheds the biggest card when the trick cannot be avoided', () {
      // Only hearts are legal and both of them beat the nine, so the trick is
      // coming whatever happens. Taking it with the ace gets rid of the card
      // most likely to force the next one too.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.king),
        card(Suit.clubs, Rank.three),
      ];
      final PlayingCard played = HeuristicPolicy(seed: 3).chooseCardSync(
        observation(
          hand: hand,
          legal: <PlayingCard>[
            card(Suit.hearts, Rank.ace),
            card(Suit.hearts, Rank.king),
          ],
          declared: 3,
          tricksTaken: 5,
          trick: heartsLed(),
        ),
      );
      expect(played, card(Suit.hearts, Rank.ace));
    });

    test('a kept nil is defended, a broken one is not', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.two),
      ];
      final HeuristicPolicy policy = HeuristicPolicy(seed: 3);

      expect(
        policy.chooseCardSync(
          observation(
            hand: hand,
            legal: hand,
            declared: 0,
            tricksTaken: 0,
            trick: heartsLed(),
          ),
        ),
        card(Suit.hearts, Rank.two),
        reason: 'one trick breaks el almaz',
      );
      expect(
        policy.chooseCardSync(
          observation(
            hand: hand,
            legal: hand,
            declared: 0,
            tricksTaken: 1,
            trick: heartsLed(),
          ),
        ),
        card(Suit.hearts, Rank.ace),
        reason: 'el almaz is already broken; further tricks cost nothing',
      );
    });

    test('the trick-greedy control takes it either way', () {
      // The control exists so the score-aware behaviour has something to be
      // measured against. If it ever starts ducking, the benchmark comparison
      // stops meaning anything.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.ace),
        card(Suit.hearts, Rank.two),
      ];
      expect(
        HeuristicPolicy.trickGreedy(seed: 3).chooseCardSync(
          observation(
            hand: hand,
            legal: hand,
            declared: 3,
            tricksTaken: 5,
            trick: heartsLed(),
          ),
        ),
        card(Suit.hearts, Rank.ace),
      );
    });
  });
}
