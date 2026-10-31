import '../../cards/playing_card.dart';
import '../../rules/rule_violation.dart';
import '../game_command.dart';
import '../game_engine.dart';
import 'trick.dart';
import 'trick_legal_moves.dart';
import 'trick_play_state.dart';
import 'trick_resolver.dart';

/// The authoritative engine for the card-play phase.
///
/// Stateless and pure. The same instance can serve the UI, a background
/// isolate running Monte Carlo rollouts and the benchmark harness at once.
final class TrickPlayEngine implements GameEngine<TrickPlayState> {
  const TrickPlayEngine();

  @override
  List<GameCommand> legalCommands(TrickPlayState state, int seat) {
    if (isTerminal(state) || state.turnSeat != seat) {
      return const <GameCommand>[];
    }
    return List<GameCommand>.unmodifiable(
      legalCards(state, seat).map(
        (PlayingCard card) => PlayCardCommand(seat: seat, card: card),
      ),
    );
  }

  /// The cards [seat] may legally play from [state].
  ///
  /// Exposed separately from [legalCommands] because AI policies and the card
  /// highlighting in the UI want cards, not command wrappers, and allocating a
  /// command per candidate inside a search loop would be wasteful.
  List<PlayingCard> legalCards(TrickPlayState state, int seat) =>
      TrickLegalMoves.forHand(
        hand: state.handOf(seat),
        trick: state.currentTrick,
        trump: state.trump,
        rules: state.rules,
        trumpBroken: state.trumpBroken,
      );

  @override
  CommandOutcome<TrickPlayState> apply(
    TrickPlayState state,
    GameCommand command,
  ) {
    if (command is! PlayCardCommand) {
      return CommandRejected<TrickPlayState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: '${command.runtimeType} during card play',
        ),
      );
    }
    if (isTerminal(state)) {
      return const CommandRejected<TrickPlayState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'card play is over',
        ),
      );
    }
    if (command.seat != state.turnSeat) {
      return CommandRejected<TrickPlayState>(
        RuleViolation(
          RuleViolationCode.notYourTurn,
          detail: 'seat ${command.seat}, expected ${state.turnSeat}',
        ),
      );
    }

    final RuleViolation? violation = TrickLegalMoves.validate(
      card: command.card,
      hand: state.handOf(command.seat),
      trick: state.currentTrick,
      trump: state.trump,
      rules: state.rules,
      trumpBroken: state.trumpBroken,
    );
    if (violation != null) {
      return CommandRejected<TrickPlayState>(violation);
    }

    return CommandAccepted<TrickPlayState>(_play(state, command));
  }

  @override
  bool isTerminal(TrickPlayState state) => state.isComplete;

  @override
  int? seatToAct(TrickPlayState state) =>
      isTerminal(state) ? null : state.turnSeat;

  TrickPlayState _play(TrickPlayState state, PlayCardCommand command) {
    final List<List<PlayingCard>> hands = <List<PlayingCard>>[
      for (int seat = 0; seat < state.seating.playerCount; seat++)
        seat == command.seat
            ? (state.handOf(seat).toList()..remove(command.card))
            : state.handOf(seat),
    ];

    final Trick trick = state.currentTrick.withPlay(
      PlayedCard(seat: command.seat, card: command.card),
    );
    final bool trumpBroken =
        state.trumpBroken || command.card.suit == state.trump;

    if (!trick.isComplete) {
      return state.copyWith(
        hands: hands,
        currentTrick: trick,
        turnSeat: state.seating.next(command.seat),
        trumpBroken: trumpBroken,
      );
    }

    final int winner = TrickResolver.winnerSeat(trick, trump: state.trump);
    return state.copyWith(
      hands: hands,
      currentTrick: Trick.empty(
        leadSeat: winner,
        expectedPlays: state.seating.playerCount,
      ),
      completedTricks: <CompletedTrick>[
        ...state.completedTricks,
        CompletedTrick(trick: trick, winnerSeat: winner),
      ],
      turnSeat: winner,
      trumpBroken: trumpBroken,
    );
  }
}
