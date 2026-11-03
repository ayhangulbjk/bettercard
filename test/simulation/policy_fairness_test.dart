// A seat must not be able to tell one hidden world from another.
//
// `ai_information_filter_test.dart` checks that an observation holds no card
// it should not. This checks the stronger property, and the one a player
// actually cares about: two positions that agree on everything this seat may
// legally know must look identical to it and must be answered identically.
//
// It works by replacing the other seats' real cards with a world sampled from
// the public record, leaving the trick, the history, the trick counts and the
// turn exactly as they were. Nothing the seat is entitled to see has changed.
// If any field of the observation moves, the funnel leaked. If the field
// survive and the decision still moves, the policy reached around it.
//
// Reading the real hands to build the permutation is allowed for the same
// reason the soundness test may: nothing is fed back into a policy, and the
// sampled world is built from public information alone.

import 'package:batak_king/core/ai/card_tracker.dart';
import 'package:batak_king/core/ai/hidden_hand_sampler.dart';
import 'package:batak_king/core/ai/match_context.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/deck.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_engine.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/declaration_rules.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:batak_king/core/util/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

const int _handCount = 20;
const int _players = 4;
const int _worldsPerPly = 3;

/// Two seats have spoken and two have not. The policy reads these, and they
/// are public, so they are held identical across worlds.
final MatchContext _context = MatchContext(
  declarationRules: DeclarationRules.kozMacaStandard,
  declarations: const <int?>[4, 3, null, null],
  totalScores: const <int>[0, 0, 0, 0],
);

void main() {
  group('policy fairness', () {
    test('the observation is identical in every indistinguishable world', () {
      int worlds = 0;
      _forEachPermutedPly((
        SeatObservation real,
        SeatObservation permuted,
        int seat,
      ) {
        worlds++;
        expect(permuted.hand, equals(real.hand));
        expect(permuted.legalMoves, equals(real.legalMoves));
        expect(permuted.handSizes, equals(real.handSizes));
        expect(permuted.tricksWon, equals(real.tricksWon));
        expect(permuted.trumpBroken, equals(real.trumpBroken));
        expect(permuted.trump, equals(real.trump));
        expect(
          permuted.publiclyPlayedCards,
          equals(real.publiclyPlayedCards),
          reason: 'seat $seat sees a different public record between two '
              'worlds it cannot distinguish',
        );
      });
      expect(worlds, greaterThan(100));
    });

    test('the decision is the same in every indistinguishable world', () {
      _forEachPermutedPly((
        SeatObservation real,
        SeatObservation permuted,
        int seat,
      ) {
        // A fresh policy per call, so a shared generator cannot make two runs
        // differ for a reason that is not the cards.
        expect(
          HeuristicPolicy(seed: 5).chooseCardSync(permuted),
          equals(HeuristicPolicy(seed: 5).chooseCardSync(real)),
          reason: 'seat $seat changed its card between two worlds it cannot '
              'distinguish',
        );
      });
    });
  });
}

/// Plays Koz Maca hands and, at every ply, hands [check] the real observation
/// for the seat to act plus observations taken from worlds that differ only
/// behind that seat's back.
void _forEachPermutedPly(
  void Function(SeatObservation real, SeatObservation permuted, int seat) check,
) {
  const TrickPlayEngine engine = TrickPlayEngine();
  const HiddenHandSampler sampler = HiddenHandSampler();

  for (int hand = 0; hand < _handCount; hand++) {
    final int seed = 777000 + hand;
    final Deal dealt = Deck.shuffleAndDeal(
      seed: seed,
      handCount: _players,
      handSize: 52 ~/ _players,
    );
    TrickPlayState state = TrickPlayState.opening(
      hands: dealt.hands,
      seating: SeatingPlan.individual(_players),
      rules: TrickRules.kozMaca,
      trump: Suit.spades,
      leadSeat: seed % _players,
    );

    while (!engine.isTerminal(state)) {
      final int seat = state.turnSeat;
      final SeatObservation real = SeatObservation.fromState(
        state,
        seat,
        match: _context,
      );
      final CardTracker tracker = CardTracker.fromObservation(real);
      final SeededRandom random = SeededRandom(seed * 31 + seat);

      for (final SampledDeal world in sampler.sampleMany(
        observation: real,
        tracker: tracker,
        random: random,
        count: _worldsPerPly,
      )) {
        check(
          real,
          SeatObservation.fromState(
            _withHands(state, world.hands),
            seat,
            match: _context,
          ),
          seat,
        );
      }

      final PlayingCard card = HeuristicPolicy(seed: 5).chooseCardSync(real);
      state = switch (engine.apply(
        state,
        PlayCardCommand(seat: seat, card: card),
      )) {
        CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
          next,
        CommandRejected<TrickPlayState>() =>
          throw StateError('Illegal move in hand $seed'),
      };
    }
  }
}

/// The same position with different cards behind the backs of the players.
///
/// Everything public is carried over untouched, which is what makes the two
/// states indistinguishable to the seat on turn.
TrickPlayState _withHands(
  TrickPlayState state,
  List<List<PlayingCard>> hands,
) =>
    TrickPlayState(
      hands: hands,
      seating: state.seating,
      rules: state.rules,
      trump: state.trump,
      turnSeat: state.turnSeat,
      currentTrick: state.currentTrick,
      completedTricks: List<CompletedTrick>.of(state.completedTricks),
      trumpBroken: state.trumpBroken,
    );
