import '../../core/cards/playing_card.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/trick/trick.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/game_engine/trick/trick_resolver.dart';
import '../../core/rules/rule_violation.dart';
import '../../games/spades_batak/spades_batak_engine.dart';
import '../../games/spades_batak/spades_batak_match_state.dart';
import 'match_session.dart';

/// What one card play does to the table.
///
/// Pure: a session and a play in, a new session out. Separated from the
/// controller because it answers a different question -- the controller
/// decides *when* a play happens and what waits around it, this decides what
/// the table looks like afterwards -- and because a pure function is the part
/// worth reasoning about carefully.
///
/// It decides no rules. The play goes to [SpadesBatakEngine], which
/// re-validates it, and the winner of a finished trick comes from
/// [TrickResolver], the same authority the engine uses.
abstract final class MatchTurn {
  static const SpadesBatakEngine engine = SpadesBatakEngine();

  /// Applies [card] from [seat].
  static MatchTurnResult apply(
      MatchSession session, int seat, PlayingCard card) {
    final SpadesBatakMatchState before = session.match;
    final TrickPlayState? hand = before.hand;
    if (hand == null) {
      return MatchTurnResult(session: session, accepted: false);
    }

    // Captured before the command: a hand that ends here is replaced by the
    // next deal, and its last trick would otherwise be unrecoverable.
    final CompletedTrick? finished = trickAfter(hand, seat, card);

    final CommandOutcome<SpadesBatakMatchState> outcome = engine.apply(
      before,
      PlayCardCommand(seat: seat, card: card),
    );

    return switch (outcome) {
      CommandRejected<SpadesBatakMatchState>(
        violation: final RuleViolation violation
      ) =>
        MatchTurnResult(
          session: session.copyWith(rejection: violation.code),
          accepted: false,
        ),
      CommandAccepted<SpadesBatakMatchState>(
        state: final SpadesBatakMatchState after
      ) =>
        MatchTurnResult(
          session: _fold(session, before, after, finished),
          accepted: true,
        ),
    };
  }

  static MatchSession _fold(
    MatchSession session,
    SpadesBatakMatchState before,
    SpadesBatakMatchState after,
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
  static MatchPhase phaseFor(SpadesBatakMatchState match, int humanSeat) {
    if (match.isOver) {
      return MatchPhase.matchOver;
    }
    return match.hand!.turnSeat == humanSeat
        ? MatchPhase.awaitingHuman
        : MatchPhase.opponentThinking;
  }
}

/// The session after a play, and whether the engine took it.
///
/// A rejection still produces a session -- one carrying the violation, so the
/// table can say why -- which is why this is a pair rather than a nullable.
final class MatchTurnResult {
  const MatchTurnResult({required this.session, required this.accepted});

  final MatchSession session;
  final bool accepted;
}
