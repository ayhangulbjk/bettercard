import '../cards/playing_card.dart';
import 'ai_difficulty.dart';
import 'seat_observation.dart';

/// A card-play decision maker.
///
/// The signature is the no-cheating guarantee in code form: a policy is handed
/// a [SeatObservation] and a budget, and nothing else. It has no reference to
/// the authoritative state, to other seats' hands, or to the deal's generator.
///
/// Implementations must:
///
/// * return a card drawn from `observation.legalMoves` (never anything else),
/// * respect [AiComputeBudget], returning the best answer found so far rather
///   than overrunning,
/// * be pure with respect to ambient state: all randomness arrives through a
///   seeded generator the caller supplies, so a decision is reproducible.
abstract interface class AiPolicy {
  /// Stable identifier used in benchmark reports and save files.
  String get id;

  /// Human-readable Turkish label for the AI lab screen.
  String get displayName;

  /// Chooses a card to play.
  ///
  /// Asynchronous because stronger policies run in a background isolate; the
  /// cheap ones complete synchronously inside the returned future.
  Future<PlayingCard> chooseCard(
    SeatObservation observation,
    AiComputeBudget budget,
  );

  /// Chooses how many tricks this seat promises to take.
  ///
  /// [options] is the legal range, handed in by the engine for the same
  /// reason `observation.legalMoves` is: the policy must not decide for itself
  /// what the rules allow. The answer must be one of them.
  ///
  /// Called once per hand, before any card is played, in modes whose profile
  /// has a declaration round. In every other mode it is never called.
  Future<int> chooseDeclaration(
    SeatObservation observation,
    List<int> options,
    AiComputeBudget budget,
  );
}

/// A policy that can answer a card question without a future.
///
/// Exists so a search can roll a hand out with whichever policy actually
/// plays the mode in front of it, rather than being wired to one of them --
/// a trick-maximising rollout inside a team game would be measuring the wrong
/// objective. Also what the headless simulator and the benchmark CLIs call,
/// since they run millions of decisions and should not pay for a future per
/// card.
abstract interface class SyncCardPolicy {
  /// Chooses a card from `observation.legalMoves`.
  PlayingCard chooseCardSync(SeatObservation observation);
}

/// Thrown when a policy is asked to move from a position with no legal play.
/// That is an engine bug, so it fails loudly rather than guessing.
class NoLegalMoveError extends StateError {
  NoLegalMoveError(int seat)
      : super('Seat $seat was asked to play with no legal move available');
}
