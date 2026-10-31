import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_positions.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit, rank);

void main() {
  group('invariants hold throughout a hand', () {
    test('every ply of a full hand passes the invariant check', () {
      for (int seed = 1; seed <= 25; seed++) {
        TrickPlayState state = TestPositions.dealt(seed: seed);
        int ply = 0;
        while (!TestPositions.engine.isTerminal(state)) {
          state.checkInvariants(expectedTotalCards: 52);
          state = TestPositions.advanceOnePly(state);
          ply++;
          expect(ply, lessThanOrEqualTo(52), reason: 'hand did not terminate');
        }
        state.checkInvariants(expectedTotalCards: 52);
      }
    });

    test('a completed hand distributes exactly 13 tricks', () {
      final TrickPlayState state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 5));
      expect(
        state.tricksWon.reduce((int a, int b) => a + b),
        13,
      );
      expect(state.completedTricks, hasLength(13));
      for (final List<PlayingCard> hand in state.hands) {
        expect(hand, isEmpty);
      }
    });

    test('no card appears twice across hands, trick and history', () {
      final TrickPlayState state = TestPositions.dealt(plies: 23);
      final List<PlayingCard> all = <PlayingCard>[
        for (final List<PlayingCard> hand in state.hands) ...hand,
        ...state.currentTrick.plays.map((PlayedCard p) => p.card),
        for (final CompletedTrick trick in state.completedTricks)
          ...trick.cards,
      ];
      expect(all, hasLength(52));
      expect(all.toSet(), hasLength(52));
    });

    test('team trick counts agree with seat trick counts', () {
      final TrickPlayState state = TestPositions.playToCompletion(
        TrickPlayState.opening(
          hands: TestPositions.dealt().hands,
          seating: SeatingPlan.partnership4(),
          rules: TrickRules.batakStandard,
          trump: Suit.spades,
          leadSeat: 0,
        ),
      );
      final List<int> seats = state.tricksWon;
      final Map<int, int> teams = state.tricksWonByTeam;
      expect((teams[0] ?? 0) + (teams[1] ?? 0), 13);
      expect(teams[0] ?? 0, seats[0] + seats[2]);
      expect(teams[1] ?? 0, seats[1] + seats[3]);
    });
  });

  group('the invariant check actually catches corruption', () {
    test('a duplicated card is rejected', () {
      final TrickPlayState corrupt = TrickPlayState(
        hands: <List<PlayingCard>>[
          <PlayingCard>[c(Suit.hearts, Rank.ace)],
          <PlayingCard>[c(Suit.hearts, Rank.ace)],
          <PlayingCard>[c(Suit.clubs, Rank.two)],
          <PlayingCard>[c(Suit.clubs, Rank.three)],
        ],
        seating: SeatingPlan.individual(4),
        rules: TrickRules.batakStandard,
        trump: Suit.spades,
        turnSeat: 0,
        currentTrick: Trick.empty(leadSeat: 0, expectedPlays: 4),
        completedTricks: const <CompletedTrick>[],
        trumpBroken: false,
      );
      expect(corrupt.checkInvariants, throwsStateError);
    });

    test('a drifted card count is rejected', () {
      final TrickPlayState state = TestPositions.dealt();
      expect(
        () => state.checkInvariants(expectedTotalCards: 51),
        throwsStateError,
      );
    });

    test('an out-of-range turn seat is rejected', () {
      final TrickPlayState corrupt = TrickPlayState(
        hands: <List<PlayingCard>>[
          <PlayingCard>[c(Suit.hearts, Rank.ace)],
          <PlayingCard>[c(Suit.hearts, Rank.king)],
        ],
        seating: SeatingPlan.individual(2),
        rules: TrickRules.batakStandard,
        trump: Suit.spades,
        turnSeat: 5,
        currentTrick: Trick.empty(leadSeat: 0, expectedPlays: 2),
        completedTricks: const <CompletedTrick>[],
        trumpBroken: false,
      );
      expect(corrupt.checkInvariants, throwsStateError);
    });

    test('a stale trumpBroken flag is rejected', () {
      final TrickPlayState corrupt = TrickPlayState(
        hands: <List<PlayingCard>>[
          <PlayingCard>[c(Suit.hearts, Rank.ace)],
          <PlayingCard>[c(Suit.hearts, Rank.king)],
        ],
        seating: SeatingPlan.individual(2),
        rules: TrickRules.batakStandard,
        trump: Suit.spades,
        turnSeat: 1,
        currentTrick: Trick(
          leadSeat: 0,
          expectedPlays: 2,
          plays: <PlayedCard>[
            PlayedCard(seat: 0, card: c(Suit.spades, Rank.two)),
          ],
        ),
        completedTricks: const <CompletedTrick>[],
        trumpBroken: false,
      );
      expect(corrupt.checkInvariants, throwsStateError);
    });

    test('a hand count mismatched with the seating plan is rejected', () {
      expect(
        () => TrickPlayState(
          hands: <List<PlayingCard>>[
            <PlayingCard>[c(Suit.hearts, Rank.ace)],
          ],
          seating: SeatingPlan.individual(4),
          rules: TrickRules.batakStandard,
          trump: Suit.spades,
          turnSeat: 0,
          currentTrick: Trick.empty(leadSeat: 0, expectedPlays: 4),
          completedTricks: const <CompletedTrick>[],
          trumpBroken: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('immutability', () {
    test('hands are unmodifiable', () {
      final TrickPlayState state = TestPositions.dealt();
      expect(
        () => state.handOf(0).add(c(Suit.spades, Rank.ace)),
        throwsUnsupportedError,
      );
      expect(() => state.hands.clear(), throwsUnsupportedError);
    });

    test('applying a command does not mutate the previous snapshot', () {
      final TrickPlayState before = TestPositions.dealt();
      final List<PlayingCard> handBefore = before.handOf(0).toList();
      TestPositions.advanceOnePly(before);
      expect(before.handOf(0), equals(handBefore));
      expect(before.currentTrick.plays, isEmpty);
    });

    test('a trick cannot accept two plays from one seat', () {
      final Trick trick = Trick(
        leadSeat: 0,
        expectedPlays: 4,
        plays: <PlayedCard>[
          PlayedCard(seat: 0, card: c(Suit.hearts, Rank.two)),
        ],
      );
      expect(
        () => trick.withPlay(
          PlayedCard(seat: 0, card: c(Suit.hearts, Rank.three)),
        ),
        throwsStateError,
      );
    });
  });
}
