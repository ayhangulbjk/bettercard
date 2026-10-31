import 'package:batak_king/core/cards/deck.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/game_engine/seating.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_engine.dart';
import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/trick_rules.dart';

/// Shared fixtures for engine and AI tests.
///
/// Positions are built by driving the real engine from a seeded deal rather
/// than by hand-assembling state, so a fixture can never describe a position
/// the rules would not permit.
abstract final class TestPositions {
  static const TrickPlayEngine engine = TrickPlayEngine();

  /// A four-seat deal advanced by [plies] legal plays.
  static TrickPlayState dealt({
    int seed = 777,
    int plies = 0,
    TrickRules rules = TrickRules.batakStandard,
    Suit? trump = Suit.spades,
    int leadSeat = 0,
  }) {
    final Deal deal =
        Deck.shuffleAndDeal(seed: seed, handCount: 4, handSize: 13);
    TrickPlayState state = TrickPlayState.opening(
      hands: deal.hands,
      seating: SeatingPlan.individual(4),
      rules: rules,
      trump: trump,
      leadSeat: leadSeat,
    );
    for (int ply = 0; ply < plies; ply++) {
      state = advanceOnePly(state);
    }
    return state;
  }

  /// Plays the first legal card for whichever seat is to act.
  static TrickPlayState advanceOnePly(TrickPlayState state) {
    final List<PlayingCard> legal = engine.legalCards(state, state.turnSeat);
    if (legal.isEmpty) {
      return state;
    }
    final CommandOutcome<TrickPlayState> outcome = engine.apply(
      state,
      PlayCardCommand(seat: state.turnSeat, card: legal.first),
    );
    if (outcome is CommandAccepted<TrickPlayState>) {
      return outcome.state;
    }
    throw StateError('Engine rejected a move it generated: $outcome');
  }

  /// Plays out an entire hand.
  static TrickPlayState playToCompletion(TrickPlayState state) {
    TrickPlayState current = state;
    while (!engine.isTerminal(current)) {
      current = advanceOnePly(current);
    }
    return current;
  }
}
