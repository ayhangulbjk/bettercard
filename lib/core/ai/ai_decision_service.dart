import '../cards/playing_card.dart';
import 'ai_difficulty.dart';
import 'ai_policy.dart';
import 'seat_observation.dart';

/// The seam between the UI and AI computation.
///
/// Why an interface rather than calling a policy directly: the shipping app
/// must run strong policies on a background isolate so that a long search
/// cannot drop a frame, and must be able to cancel a decision when the player
/// leaves the table or restarts the hand. Both of those are properties of the
/// *service*, not of any one policy, so the policies stay pure and testable
/// while the service owns scheduling.
abstract interface class AiDecisionService {
  /// Asks [policy] for a card for [observation] under [budget].
  ///
  /// [requestId] lets the caller cancel this specific request.
  Future<PlayingCard> decide({
    required AiPolicy policy,
    required SeatObservation observation,
    required AiComputeBudget budget,
    required Object requestId,
  });

  /// Asks [policy] for a trick declaration, under the same cancellation and
  /// budget contract as [decide].
  Future<int> decideDeclaration({
    required AiPolicy policy,
    required SeatObservation observation,
    required List<int> options,
    required AiComputeBudget budget,
    required Object requestId,
  });

  /// Cancels a pending request. Safe to call for an unknown or finished id.
  void cancel(Object requestId);

  /// Releases any resources (isolates, ports).
  Future<void> dispose();
}

/// Runs the policy on the calling isolate.
///
/// Correct and adequate for cheap policies and for the headless simulator.
/// It is NOT what the app should use for the search-based levels: a long
/// synchronous search here would block the frame pipeline. The isolate-backed
/// implementation arrives with the first search policy (see docs/ROADMAP.md).
final class DirectAiDecisionService implements AiDecisionService {
  DirectAiDecisionService();

  final Set<Object> _cancelled = <Object>{};

  @override
  Future<PlayingCard> decide({
    required AiPolicy policy,
    required SeatObservation observation,
    required AiComputeBudget budget,
    required Object requestId,
  }) async {
    _cancelled.remove(requestId);
    final PlayingCard card = await policy.chooseCard(observation, budget);
    if (_cancelled.remove(requestId)) {
      throw AiDecisionCancelled(requestId);
    }
    return card;
  }

  @override
  Future<int> decideDeclaration({
    required AiPolicy policy,
    required SeatObservation observation,
    required List<int> options,
    required AiComputeBudget budget,
    required Object requestId,
  }) async {
    _cancelled.remove(requestId);
    final int declaration =
        await policy.chooseDeclaration(observation, options, budget);
    if (_cancelled.remove(requestId)) {
      throw AiDecisionCancelled(requestId);
    }
    return declaration;
  }

  @override
  void cancel(Object requestId) => _cancelled.add(requestId);

  @override
  Future<void> dispose() async => _cancelled.clear();
}

/// Thrown when a decision is cancelled before it could be delivered.
class AiDecisionCancelled implements Exception {
  const AiDecisionCancelled(this.requestId);

  final Object requestId;

  @override
  String toString() => 'AiDecisionCancelled($requestId)';
}
