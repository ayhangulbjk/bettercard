import '../../core/cards/playing_card.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/persistence/saved_match.dart';
import 'spades_batak_engine.dart';
import 'spades_batak_match_state.dart';

/// Rebuilds a Koz Maca match from its move log.
///
/// Every move goes back through [SpadesBatakEngine], so a restored match is a
/// position the rules produced rather than one a file claimed. That is the
/// whole argument for storing a log: a snapshot could describe an impossible
/// position and nothing would notice.
abstract final class SpadesBatakRestore {
  /// Replays [save], or returns null when it cannot be replayed.
  ///
  /// Null rather than an exception because a damaged save is not something the
  /// player can act on: the app offers no resume and starts clean. The reason
  /// is handed to [onProblem] for logging, which stays empty in the product.
  static SpadesBatakMatchState? replay(
    SavedMatch save, {
    void Function(String problem)? onProblem,
  }) {
    const SpadesBatakEngine engine = SpadesBatakEngine();

    SpadesBatakMatchState state;
    try {
      state = SpadesBatakEngine.start(
        profile: save.ruleProfile,
        seed: save.dealSeed,
      );
    } on ArgumentError catch (error) {
      onProblem?.call('the saved rule profile is not playable: $error');
      return null;
    }

    for (int index = 0; index < save.moves.length; index++) {
      final int? seat = engine.seatToAct(state);
      if (seat == null) {
        onProblem?.call('move $index arrives after the match ended');
        return null;
      }

      final int move = save.moves[index];
      final int? declared = SavedMatch.decodeDeclaration(move);

      final GameCommand command;
      final String description;
      if (declared != null) {
        command = PlaceBidCommand(seat: seat, tricks: declared);
        description = 'declaration of $declared';
      } else {
        final PlayingCard card;
        try {
          card = PlayingCard.fromId(move);
        } on ArgumentError {
          onProblem?.call('move $index is not a card id: $move');
          return null;
        }
        command = PlayCardCommand(seat: seat, card: card);
        description = '$card';
      }

      final CommandOutcome<SpadesBatakMatchState> outcome =
          engine.apply(state, command);
      switch (outcome) {
        case CommandAccepted<SpadesBatakMatchState>(
            state: final SpadesBatakMatchState next
          ):
          state = next;
        case CommandRejected<SpadesBatakMatchState>():
          onProblem?.call(
            'move $index ($description by seat $seat) is illegal',
          );
          return null;
      }
    }

    // The denormalised fields exist for the home screen, which draws the
    // resume card without replaying. If they disagree with the replay, the
    // file was edited or truncated, and the safe reading is "no save".
    if (state.handsPlayed != save.handsPlayed) {
      onProblem?.call(
        'replay produced ${state.handsPlayed} hands, the save claims '
        '${save.handsPlayed}',
      );
      return null;
    }
    for (int seat = 0; seat < state.seatCount; seat++) {
      if (seat >= save.scores.length ||
          state.totals[seat] != save.scores[seat]) {
        onProblem
            ?.call('replay disagrees with the stored score for seat $seat');
        return null;
      }
    }
    return state;
  }
}
