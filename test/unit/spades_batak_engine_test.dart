import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/core/rules/rule_violation.dart';
import 'package:batak_king/core/rules/scoring_rules.dart';
import 'package:batak_king/games/spades_batak/spades_batak_engine.dart';
import 'package:batak_king/games/spades_batak/spades_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies one legal command for whichever seat is to act.
///
/// Declarations and cards go through the same call because they are the same
/// kind of thing to the engine: a command from the seat to act. Keeping one
/// step function is what stops a test helper drifting out of step with the
/// hand lifecycle -- which is exactly what happened when the declaration round
/// landed and only one of the two helpers knew about it.
SpadesBatakMatchState advance(
  SpadesBatakMatchState state,
  SpadesBatakEngine engine,
) {
  final int seat = engine.seatToAct(state)!;
  final GameCommand command;
  if (state.isDeclaring) {
    final List<int> options = engine.legalDeclarations(state);
    expect(options, isNotEmpty, reason: 'seat $seat had nothing to declare');
    // The lowest non-nil number. Declaring nil every hand is legal but
    // pathological: every seat would break it and no score would ever rise,
    // so a match played to a target would never end.
    command = PlaceBidCommand(
      seat: seat,
      tricks: options.firstWhere(
        (int value) => value >= 1,
        orElse: () => options.first,
      ),
    );
  } else {
    final List<PlayingCard> legal = engine.legalCards(state, seat);
    expect(legal, isNotEmpty, reason: 'seat $seat had no legal card');
    command = PlayCardCommand(seat: seat, card: legal.first);
  }
  final CommandOutcome<SpadesBatakMatchState> outcome =
      engine.apply(state, command);
  return switch (outcome) {
    CommandAccepted<SpadesBatakMatchState>(
      state: final SpadesBatakMatchState next
    ) =>
      next,
    CommandRejected<SpadesBatakMatchState>(violation: final RuleViolation v) =>
      fail('Engine rejected its own legal command for seat $seat: $v'),
  };
}

/// Plays [state] to the end by always choosing the first legal option.
///
/// Deliberately not random: a fixed choice makes a failure reproducible from
/// the seed alone. Every ply is checked for invariants, so a lifecycle bug
/// surfaces at the ply that caused it rather than at the end.
///
/// Declarations go through the same loop as cards, because they are the same
/// kind of thing to the engine: a command from the seat to act.
SpadesBatakMatchState playOut(
  SpadesBatakMatchState start, {
  SpadesBatakEngine engine = const SpadesBatakEngine(),
  int plyLimit = 5000,
}) {
  SpadesBatakMatchState state = start;
  int plies = 0;
  while (!engine.isTerminal(state)) {
    if (++plies > plyLimit) {
      fail('Match did not finish within $plyLimit plies: $state');
    }
    state = advance(state, engine);
    state.checkInvariants();
  }
  return state;
}

void main() {
  const SpadesBatakEngine engine = SpadesBatakEngine();
  final RuleProfile kozMaca = RulePresets.kozMacaStandard();

  group('a full Koz Maca match', () {
    test('plays eight hands and then ends', () {
      final SpadesBatakMatchState end = playOut(
        SpadesBatakEngine.start(profile: kozMaca, seed: 4242),
      );

      expect(end.isOver, isTrue);
      expect(engine.seatToAct(end), isNull);
      expect(end.handsPlayed, kozMaca.scoringRules.roundCount);
      expect(end.history.length, 8);
    });

    test('every hand distributes exactly thirteen tricks', () {
      final SpadesBatakMatchState end = playOut(
        SpadesBatakEngine.start(profile: kozMaca, seed: 99),
      );
      for (final HandScore score in end.history) {
        expect(score.totalTricks, 13);
      }
    });

    test('totals equal the sum of the history', () {
      final SpadesBatakMatchState end = playOut(
        SpadesBatakEngine.start(profile: kozMaca, seed: 1234),
      );
      for (int seat = 0; seat < 4; seat++) {
        final int summed = end.history.fold(
          0,
          (int acc, HandScore s) => acc + s.pointsOf(seat),
        );
        expect(end.totals[seat], summed);
      }
      // No fixed table total any more: with declarations the hand pays each
      // seat its own promise, so what the match sums to depends on who kept
      // theirs. The invariant that matters is the one above.
    });

    test('the lead rotates so no seat always starts', () {
      SpadesBatakMatchState state =
          SpadesBatakEngine.start(profile: kozMaca, seed: 7);
      final Set<int> leaders = <int>{};
      while (!engine.isTerminal(state)) {
        leaders.add(state.hand!.currentTrick.leadSeat);
        state = playOneHand(state, engine);
      }
      expect(leaders.length, greaterThan(1),
          reason: 'the opening lead never moved');
    });

    test('the same seed replays identically', () {
      final a = playOut(SpadesBatakEngine.start(profile: kozMaca, seed: 808));
      final b = playOut(SpadesBatakEngine.start(profile: kozMaca, seed: 808));
      expect(a.totals, b.totals);
      for (int i = 0; i < a.history.length; i++) {
        expect(a.history[i].tricks, b.history[i].tricks);
      }
    });

    test('different seeds produce different matches', () {
      final a = playOut(SpadesBatakEngine.start(profile: kozMaca, seed: 808));
      final b = playOut(SpadesBatakEngine.start(profile: kozMaca, seed: 809));
      expect(a.totals, isNot(b.totals));
    });
  });

  group('rejections', () {
    test('a card from the wrong seat is rejected and changes nothing', () {
      final SpadesBatakMatchState state =
          SpadesBatakEngine.start(profile: kozMaca, seed: 5);
      final int turn = state.hand!.turnSeat;
      final int other = (turn + 1) % 4;

      final CommandOutcome<SpadesBatakMatchState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: other, card: state.hand!.handOf(other).first),
      );

      expect(outcome, isA<CommandRejected<SpadesBatakMatchState>>());
      expect(state.hand!.handSizes, <int>[13, 13, 13, 13]);
      expect(state.handsPlayed, 0);
    });

    test('playing into a finished match is rejected as wrong phase', () {
      final SpadesBatakMatchState end = playOut(
        SpadesBatakEngine.start(profile: kozMaca, seed: 31),
      );
      final CommandOutcome<SpadesBatakMatchState> outcome = engine.apply(
        end,
        PlayCardCommand(seat: 0, card: PlayingCard.fromId(0)),
      );
      expect(
        outcome,
        isA<CommandRejected<SpadesBatakMatchState>>().having(
          (CommandRejected<SpadesBatakMatchState> r) => r.violation.code,
          'code',
          RuleViolationCode.wrongPhase,
        ),
      );
      expect(engine.legalCommands(end, 0), isEmpty);
      expect(engine.legalCards(end, 0), isEmpty);
    });
  });

  group('the target-score end condition', () {
    test('stops as soon as a seat reaches the target', () {
      final RuleProfile toTarget = kozMaca.copyWith(
        scoringRules: const BatakScoringRules(
          pointsPerTrickForOthers: 1,
          endCondition: MatchEndCondition.targetScore,
          // Low, because a seat that declares one trick a hand earns at most
          // one point a hand; a higher target would simply run the match out.
          targetScore: 5,
        ),
      );
      final SpadesBatakMatchState end = playOut(
        SpadesBatakEngine.start(profile: toTarget, seed: 606),
      );
      expect(end.isOver, isTrue);
      expect(end.bestTotal, greaterThanOrEqualTo(5));
      // It must not have run the full eight-hand default.
      expect(end.handsPlayed, lessThan(8));
    });
  });
}

/// Plays exactly one hand of [state] and returns the state afterwards.
SpadesBatakMatchState playOneHand(
  SpadesBatakMatchState state,
  SpadesBatakEngine engine,
) {
  final int startIndex = state.handsPlayed;
  SpadesBatakMatchState current = state;
  while (!engine.isTerminal(current) && current.handsPlayed == startIndex) {
    current = advance(current, engine);
  }
  return current;
}
