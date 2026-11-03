import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/persistence/saved_match.dart';
import 'match_runtime.dart';

/// Rebuilds a table from its move log, whichever game it was.
///
/// Every move goes back through the game's own engine, so a restored match is
/// a position the rules produced rather than one a file claimed. That is the
/// whole argument for storing a log: a snapshot could describe an impossible
/// position and nothing would notice.
///
/// The log is replayed against the seat the engine says is on turn, never
/// against a seat recorded in the file. A log that disagrees with the rules
/// is refused at the move where it first disagrees, which is a far more
/// useful failure than a plausible-looking wrong position.
abstract final class MatchRestore {
  /// Replays [save], or returns null when it cannot be replayed.
  ///
  /// Null rather than an exception because a damaged save is not something
  /// the player can act on: the app offers no resume and starts clean. The
  /// reason is handed to [onProblem] for logging, which stays empty in the
  /// product.
  static MatchRuntime? replay(
    SavedMatch save, {
    void Function(String problem)? onProblem,
  }) {
    MatchRuntime runtime;
    try {
      runtime = MatchRuntime.start(
        profile: save.ruleProfile,
        seed: save.dealSeed,
      );
    } on ArgumentError catch (error) {
      onProblem?.call('the saved rule profile is not playable: $error');
      return null;
    }

    for (int index = 0; index < save.moves.length; index++) {
      final int? seat = runtime.seatToAct;
      if (seat == null) {
        onProblem?.call('move $index arrives after the match ended');
        return null;
      }
      final GameCommand? command = _commandFor(save.moves[index], seat);
      if (command == null) {
        onProblem?.call('move $index is not a move this build understands');
        return null;
      }
      final MatchRuntimeOutcome outcome = runtime.apply(command);
      final MatchRuntime? next = outcome.runtime;
      if (next == null) {
        onProblem?.call('move $index was refused: ${outcome.rejection?.name}');
        return null;
      }
      runtime = next;
    }
    return runtime;
  }

  /// The command one logged move stands for.
  static GameCommand? _commandFor(int move, int seat) {
    if (move >= 0) {
      if (move >= 52) {
        return null;
      }
      return PlayCardCommand(seat: seat, card: PlayingCard.fromId(move));
    }
    if (move == SavedMatch.passMove) {
      return PassBidCommand(seat: seat);
    }
    final int? bid = SavedMatch.decodeBid(move);
    if (bid != null) {
      return PlaceBidCommand(seat: seat, tricks: bid);
    }
    final int? suitIndex = SavedMatch.decodeTrump(move);
    if (suitIndex != null) {
      if (suitIndex < 0 || suitIndex >= Suit.values.length) {
        return null;
      }
      return DeclareTrumpCommand(seat: seat, trump: Suit.values[suitIndex]);
    }
    final int? declaration = SavedMatch.decodeDeclaration(move);
    if (declaration != null) {
      return PlaceBidCommand(seat: seat, tricks: declaration);
    }
    return null;
  }
}
