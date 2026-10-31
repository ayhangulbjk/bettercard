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
}

/// Thrown when a policy is asked to move from a position with no legal play.
/// That is an engine bug, so it fails loudly rather than guessing.
class NoLegalMoveError extends StateError {
  NoLegalMoveError(int seat)
      : super('Seat $seat was asked to play with no legal move available');
}
