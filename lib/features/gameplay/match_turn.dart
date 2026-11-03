import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/trick/trick.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/game_engine/trick/trick_resolver.dart';
import 'match_runtime.dart';
import 'match_session.dart';

/// What one decision does to the table.
///
/// Pure: a session and a command in, a new session out. Separated from the
/// controller because it answers a different question -- the controller
/// decides *when* something happens and what waits around it, this decides
/// what the table looks like afterwards -- and because a pure function is the
/// part worth reasoning about carefully.
///
/// It decides no rules. Every command goes through [MatchRuntime] to the
/// game's own engine, which re-validates it, and the winner of a finished
/// trick comes from [TrickResolver], the same authority the engine uses.
///
/// It knows nothing about which game is on the table either. That is the
/// point of the runtime seam: a bid and a card are the same shape of thing
/// here, and the mode decides what they mean.
abstract final class MatchTurn {
  /// Applies [card] from [seat].
  static MatchTurnResult apply(
    MatchSession session,
    int seat,
    PlayingCard card,
  ) {
    final TrickPlayState? hand = session.match.hand;
    if (hand == null) {
      return MatchTurnResult(session: session, accepted: false);
    }

    // Captured before the command: a hand that ends here is replaced by the
    // next deal, and its last trick would otherwise be unrecoverable.
    final CompletedTrick? finished = trickAfter(hand, seat, card);

    return _submit(
      session,
      PlayCardCommand(seat: seat, card: card),
      finished: finished,
    );
  }

  /// Applies [tricks] as [seat]'s declaration.
  static MatchTurnResult declare(MatchSession session, int seat, int tricks) =>
      _submit(session, PlaceBidCommand(seat: seat, tricks: tricks));

  /// Applies [tricks] as [seat]'s contract bid.
  ///
  /// The same command as a declaration, because at the engine level it is the
  /// same thing: a seat naming a number. What differs is the mode's rules
  /// about who may say what, and those belong to the engine.
  static MatchTurnResult bid(MatchSession session, int seat, int tricks) =>
      _submit(session, PlaceBidCommand(seat: seat, tricks: tricks));

  /// Withdraws [seat] from the auction.
  static MatchTurnResult pass(MatchSession session, int seat) =>
      _submit(session, PassBidCommand(seat: seat));

  /// Names [trump] for the hand.
  static MatchTurnResult chooseTrump(
    MatchSession session,
    int seat,
    Suit trump,
  ) =>
      _submit(session, DeclareTrumpCommand(seat: seat, trump: trump));

  /// Hands [command] to the engine and folds the answer into the session.
  static MatchTurnResult _submit(
    MatchSession session,
    GameCommand command, {
    CompletedTrick? finished,
  }) {
    final MatchRuntime before = session.match;
    final MatchRuntimeOutcome outcome = before.apply(command);
    final MatchRuntime? after = outcome.runtime;
    if (after == null) {
      return MatchTurnResult(
        session: session.copyWith(rejection: outcome.rejection),
        accepted: false,
      );
    }
    return MatchTurnResult(
      session: _fold(session, before, after, finished),
      accepted: true,
    );
  }

  static MatchSession _fold(
    MatchSession session,
    MatchRuntime before,
    MatchRuntime after,
    CompletedTrick? finished,
  ) {
    final bool handEnded = after.handsPlayed > before.handsPlayed;
    return session.copyWith(
      match: after,
      lastTrick: finished,
      clearLastTrick: finished == null,
      lastHandScore: handEnded ? after.history.last : null,
      clearLastHandScore: !handEnded,
      phase: handEnded
          ? MatchPhase.handSummary
          : (finished != null
              ? MatchPhase.trickPause
              : phaseFor(after, session.humanSeat)),
      clearRejection: true,
    );
  }

  /// The trick [card] would complete, or null when the trick stays open.
  static CompletedTrick? trickAfter(
    TrickPlayState hand,
    int seat,
    PlayingCard card,
  ) {
    final Trick candidate = hand.currentTrick.withPlay(
      PlayedCard(seat: seat, card: card),
    );
    if (!candidate.isComplete) {
      return null;
    }
    return CompletedTrick(
      trick: candidate,
      winnerSeat: TrickResolver.winnerSeat(candidate, trump: hand.trump),
    );
  }

  /// Whose move it is, as a phase.
  ///
  /// Asked of the runtime's step rather than of either game's internals, so a
  /// mode that adds a phase declares it once, where the step is derived.
  static MatchPhase phaseFor(MatchRuntime match, int humanSeat) {
    final int? seat = match.seatToAct;
    if (match.isOver || seat == null) {
      return MatchPhase.matchOver;
    }
    final bool mine = seat == humanSeat;
    return switch (match.step) {
      MatchStep.bidding =>
        mine ? MatchPhase.awaitingBid : MatchPhase.opponentBidding,
      MatchStep.choosingTrump =>
        mine ? MatchPhase.awaitingTrump : MatchPhase.opponentChoosingTrump,
      MatchStep.declaring =>
        mine ? MatchPhase.awaitingDeclaration : MatchPhase.opponentDeclaring,
      MatchStep.playing =>
        mine ? MatchPhase.awaitingHuman : MatchPhase.opponentThinking,
      MatchStep.finished => MatchPhase.matchOver,
    };
  }

  /// The numbers the player may declare right now.
  static List<int> legalDeclarations(MatchSession session) =>
      session.match.legalDeclarations;
}

/// The session after a decision, and whether the engine took it.
///
/// A rejection still produces a session -- one carrying the violation, so the
/// table can say why -- which is why this is a pair rather than a nullable.
final class MatchTurnResult {
  const MatchTurnResult({required this.session, required this.accepted});

  final MatchSession session;
  final bool accepted;
}
