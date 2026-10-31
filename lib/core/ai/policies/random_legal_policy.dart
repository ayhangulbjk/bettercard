import '../../cards/playing_card.dart';
import '../../util/seeded_random.dart';
import '../ai_difficulty.dart';
import '../ai_policy.dart';
import '../seat_observation.dart';

/// Plays a uniformly random legal card.
///
/// This is the project's baseline agent, and it exists for measurement rather
/// than for play: every strength claim about a stronger policy is stated as a
/// margin over this one, on paired deals with rotated seats. It doubles as the
/// cheapest possible check that the engine never reaches a position with no
/// legal move.
///
/// It is deliberately the only policy shipped in milestone 1. Mapping the
/// higher difficulty levels onto it would make the difficulty selector a lie.
final class RandomLegalPolicy implements AiPolicy {
  RandomLegalPolicy({required int seed}) : _random = SeededRandom(seed);

  final SeededRandom _random;

  @override
  String get id => 'random-legal';

  @override
  String get displayName => 'Rastgele (temel cizgi)';

  @override
  Future<PlayingCard> chooseCard(
    SeatObservation observation,
    AiComputeBudget budget,
  ) async =>
      chooseCardSync(observation);

  /// Synchronous variant used by the headless simulator, which runs millions
  /// of decisions and should not pay for a future per card.
  PlayingCard chooseCardSync(SeatObservation observation) {
    final List<PlayingCard> legal = observation.legalMoves;
    if (legal.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    return legal[_random.nextInt(legal.length)];
  }
}
