import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_engine.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/rule_violation.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const TrickPlayEngine engine = TrickPlayEngine();

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit, rank);

/// A tiny four-seat position: two cards each, spades trump.
TrickPlayState openingState({
  TrickRules rules = TrickRules.batakStandard,
  Suit? trump = Suit.spades,
  int leadSeat = 0,
}) =>
    TrickPlayState.opening(
      hands: <List<PlayingCard>>[
        <PlayingCard>[c(Suit.hearts, Rank.ace), c(Suit.clubs, Rank.two)],
        <PlayingCard>[c(Suit.hearts, Rank.king), c(Suit.spades, Rank.three)],
        <PlayingCard>[c(Suit.hearts, Rank.queen), c(Suit.clubs, Rank.four)],
        <PlayingCard>[c(Suit.hearts, Rank.jack), c(Suit.diamonds, Rank.five)],
      ],
      seating: SeatingPlan.individual(4),
      rules: rules,
      trump: trump,
      leadSeat: leadSeat,
    );

RuleViolation? violationOf(CommandOutcome<TrickPlayState> outcome) =>
    outcome is CommandRejected<TrickPlayState> ? outcome.violation : null;

TrickPlayState stateOf(CommandOutcome<TrickPlayState> outcome) {
  expect(outcome, isA<CommandAccepted<TrickPlayState>>());
  return (outcome as CommandAccepted<TrickPlayState>).state;
}

void main() {
  group('rejection of illegal commands', () {
    test('a seat cannot play out of turn', () {
      final TrickPlayState state = openingState();
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: 2, card: c(Suit.hearts, Rank.queen)),
      );
      expect(violationOf(outcome)?.code, RuleViolationCode.notYourTurn);
    });

    test('a seat cannot play a card it does not hold', () {
      final TrickPlayState state = openingState();
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: 0, card: c(Suit.spades, Rank.ace)),
      );
      expect(violationOf(outcome)?.code, RuleViolationCode.cardNotInHand);
    });

    test('a seat must follow suit', () {
      TrickPlayState state = openingState();
      state = stateOf(
        engine.apply(
          state,
          PlayCardCommand(seat: 0, card: c(Suit.hearts, Rank.ace)),
        ),
      );
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: 1, card: c(Suit.spades, Rank.three)),
      );
      expect(violationOf(outcome)?.code, RuleViolationCode.mustFollowSuit);
    });

    test('a non-play command is rejected as the wrong phase', () {
      final TrickPlayState state = openingState();
      final CommandOutcome<TrickPlayState> outcome =
          engine.apply(state, const PlaceBidCommand(seat: 0, tricks: 5));
      expect(violationOf(outcome)?.code, RuleViolationCode.wrongPhase);
    });

    test('a rejected command leaves the state untouched', () {
      final TrickPlayState state = openingState();
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: 3, card: c(Suit.hearts, Rank.jack)),
      );
      expect(outcome, isA<CommandRejected<TrickPlayState>>());
      expect(state.handOf(3), hasLength(2));
      expect(state.currentTrick.plays, isEmpty);
      expect(state.turnSeat, 0);
    });
  });

  group('accepted plays', () {
    test('the card leaves the hand and joins the trick', () {
      final TrickPlayState next = stateOf(
        engine.apply(
          openingState(),
          PlayCardCommand(seat: 0, card: c(Suit.hearts, Rank.ace)),
        ),
      );
      expect(next.handOf(0), hasLength(1));
      expect(next.handOf(0), isNot(contains(c(Suit.hearts, Rank.ace))));
      expect(next.currentTrick.plays, hasLength(1));
      expect(next.turnSeat, 1);
    });

    test('turn order follows the seating plan', () {
      TrickPlayState state = openingState(leadSeat: 2);
      expect(state.turnSeat, 2);
      state = stateOf(
        engine.apply(
          state,
          PlayCardCommand(seat: 2, card: c(Suit.hearts, Rank.queen)),
        ),
      );
      expect(state.turnSeat, 3);
    });

    test('a completed trick is resolved and its winner leads next', () {
      TrickPlayState state = openingState();
      const List<(int, Suit, Rank)> plays = <(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.ace),
        (1, Suit.hearts, Rank.king),
        (2, Suit.hearts, Rank.queen),
        (3, Suit.hearts, Rank.jack),
      ];
      for (final (int seat, Suit suit, Rank rank) in plays) {
        state = stateOf(
          engine.apply(state, PlayCardCommand(seat: seat, card: c(suit, rank))),
        );
      }
      expect(state.completedTricks, hasLength(1));
      expect(state.completedTricks.single.winnerSeat, 0);
      expect(state.turnSeat, 0);
      expect(state.currentTrick.plays, isEmpty);
      expect(state.tricksWon, <int>[1, 0, 0, 0]);
    });

    test('playing trump sets trumpBroken', () {
      TrickPlayState state = openingState(leadSeat: 1);
      expect(state.trumpBroken, isFalse);
      state = stateOf(
        engine.apply(
          state,
          PlayCardCommand(seat: 1, card: c(Suit.spades, Rank.three)),
        ),
      );
      expect(state.trumpBroken, isTrue);
    });
  });

  group('engine contract', () {
    test('every generated legal command is accepted', () {
      final TrickPlayState state = openingState();
      for (final GameCommand command in engine.legalCommands(state, 0)) {
        expect(
          engine.apply(state, command),
          isA<CommandAccepted<TrickPlayState>>(),
          reason: '$command was generated but rejected',
        );
      }
    });

    test('no legal commands are offered to a seat that is not to act', () {
      expect(engine.legalCommands(openingState(), 1), isEmpty);
    });

    test('seatToAct matches turnSeat until the hand ends', () {
      expect(engine.seatToAct(openingState(leadSeat: 3)), 3);
    });
  });
}
