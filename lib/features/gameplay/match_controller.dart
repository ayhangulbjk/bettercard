import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_decision_service.dart';
import '../../core/ai/ai_difficulty.dart';
import '../../core/ai/ai_policy.dart';
import '../../core/ai/seat_observation.dart';
import '../../core/cards/playing_card.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/trick/trick.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/game_engine/trick/trick_resolver.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_violation.dart';
import '../../games/spades_batak/spades_batak_engine.dart';
import '../../games/spades_batak/spades_batak_match_state.dart';
import 'match_pacing.dart';
import 'match_session.dart';

/// The live match, or null when no table is open.
final NotifierProvider<MatchController, MatchSession?> matchProvider =
    NotifierProvider<MatchController, MatchSession?>(MatchController.new);

/// Drives a Koz Maca match: feeds the player's taps and the opponents' answers
/// to the engine, and paces what the table shows.
///
/// It owns no rules. Every state change is a [PlayCardCommand] handed to
/// [SpadesBatakEngine], which re-validates it, so a bug here can produce a
/// rejection but never an illegal game. What it does own is scheduling: the
/// pause that lets a finished trick be read, the opponents' thinking delay,
/// and cancelling in-flight AI work when the player leaves the table.
///
/// The UI thread is never blocked on a decision. Today's policies answer in
/// microseconds, but they are still awaited through [AiDecisionService], so
/// the search-based levels drop in behind the same seam.
final class MatchController extends Notifier<MatchSession?> {
  static const SpadesBatakEngine _engine = SpadesBatakEngine();

  /// The opponents at this table. Empty when no match is open.
  OpponentRoster _opponents = OpponentRoster.empty;

  /// Bumped whenever the table is replaced or closed, so an async step that
  /// was already in flight can tell that its match is gone and stop.
  int _generation = 0;

  Object? _pendingRequest;

  @override
  MatchSession? build() {
    ref.onDispose(_cancelPending);
    return null;
  }

  /// Opens a table for [profile] and starts play.
  ///
  /// [seed] is accepted so a match can be replayed exactly; when it is null a
  /// fresh one is taken from the clock. Reading the clock is deliberate here
  /// and impossible in `lib/core`, which stays time-free: the domain must
  /// replay identically, so the one moment of ambient non-determinism lives in
  /// the layer that starts a match.
  void start({
    required RuleProfile profile,
    required AiDifficulty difficulty,
    int humanSeat = 0,
    int? seed,
  }) {
    final int matchSeed = seed ?? _seedFromClock();
    final SpadesBatakMatchState match = SpadesBatakEngine.start(
      profile: profile,
      seed: matchSeed,
    );

    _cancelPending();
    _generation++;
    _opponents = OpponentRoster.forMatch(
      difficulty: difficulty,
      matchSeed: matchSeed,
      seatCount: match.seatCount,
      humanSeat: humanSeat,
    );

    state = MatchSession(
      match: match,
      phase: _phaseFor(match, humanSeat),
      humanSeat: humanSeat,
      difficulty: difficulty,
    );
    unawaited(_drive(_generation));
  }

  /// Plays [card] from the player's hand. Ignored unless it is their turn.
  void playCard(PlayingCard card) {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingHuman) {
      return;
    }
    _submit(session.humanSeat, card);
    unawaited(_drive(_generation));
  }

  /// Dismisses the hand score sheet and starts the hand the engine has already
  /// dealt.
  void continueAfterHand() {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.handSummary) {
      return;
    }
    state = session.copyWith(
      phase: _phaseFor(session.match, session.humanSeat),
      clearLastHandScore: true,
      clearLastTrick: true,
    );
    unawaited(_drive(_generation));
  }

  /// Starts a fresh match under the same rules and difficulty.
  void rematch() {
    final MatchSession? session = state;
    if (session == null) {
      return;
    }
    start(
      profile: session.profile,
      difficulty: session.difficulty,
      humanSeat: session.humanSeat,
    );
  }

  /// Closes the table and drops any decision still in flight.
  void leave() {
    _cancelPending();
    _generation++;
    _opponents = OpponentRoster.empty;
    state = null;
  }

  /// Runs the table forward until it needs the player again.
  ///
  /// One loop rather than a chain of callbacks, so the order of pauses and
  /// decisions is readable in one place. Every await is followed by a
  /// generation check: the player may have left the table while it was
  /// pending.
  Future<void> _drive(int generation) async {
    while (generation == _generation) {
      final MatchSession? session = state;
      if (session == null) {
        return;
      }
      switch (session.phase) {
        case MatchPhase.awaitingHuman:
        case MatchPhase.handSummary:
        case MatchPhase.matchOver:
          // Waiting on the person at the device.
          return;

        case MatchPhase.trickPause:
          await MatchPacing.wait(_pacing.trickPause);
          if (generation != _generation || state == null) {
            return;
          }
          state = state!.copyWith(
            phase: _phaseFor(state!.match, state!.humanSeat),
            clearLastTrick: true,
          );

        case MatchPhase.opponentThinking:
          final TrickPlayState? hand = session.hand;
          if (hand == null) {
            return;
          }
          final int seat = hand.turnSeat;
          await MatchPacing.wait(_pacing.thinkDelay);
          if (generation != _generation || state == null) {
            return;
          }
          final PlayingCard? card = await _decide(seat, hand);
          if (card == null || generation != _generation || state == null) {
            return;
          }
          _submit(seat, card);
      }
    }
  }

  /// Hands one card play to the engine and folds the result into the session.
  void _submit(int seat, PlayingCard card) {
    final MatchSession session = state!;
    final SpadesBatakMatchState before = session.match;
    final TrickPlayState? hand = before.hand;
    if (hand == null) {
      return;
    }

    // Captured before the command, because a hand that ends here is replaced
    // by the next deal and its last trick would otherwise be unrecoverable.
    final CompletedTrick? finished = _trickAfter(hand, seat, card);

    final CommandOutcome<SpadesBatakMatchState> outcome = _engine.apply(
      before,
      PlayCardCommand(seat: seat, card: card),
    );

    switch (outcome) {
      case CommandRejected<SpadesBatakMatchState>(
          violation: final RuleViolation violation
        ):
        state = session.copyWith(rejection: violation.code);

      case CommandAccepted<SpadesBatakMatchState>(
          state: final SpadesBatakMatchState after
        ):
        final bool handEnded = after.handsPlayed > before.handsPlayed;
        state = session.copyWith(
          match: after,
          lastTrick: finished,
          clearLastTrick: finished == null,
          lastHandScore: handEnded ? after.history.last : null,
          clearLastHandScore: !handEnded,
          phase: handEnded
              ? MatchPhase.handSummary
              : (finished != null
                  ? MatchPhase.trickPause
                  : _phaseFor(after, session.humanSeat)),
          clearRejection: true,
        );
    }
  }

  /// The trick [card] would complete, or null when the trick stays open.
  ///
  /// The winner comes from [TrickResolver], the same authority the engine
  /// uses, so the table can never disagree with the score about who took a
  /// trick.
  CompletedTrick? _trickAfter(TrickPlayState hand, int seat, PlayingCard card) {
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

  /// Asks [seat]'s policy for a card, through the decision service.
  Future<PlayingCard?> _decide(int seat, TrickPlayState hand) async {
    final AiPolicy? policy = _opponents.policyFor(seat);
    if (policy == null) {
      return null;
    }
    final Object requestId = Object();
    _pendingRequest = requestId;
    try {
      return await ref.read(aiDecisionServiceProvider).decide(
            policy: policy,
            observation: SeatObservation.fromState(hand, seat),
            // The heuristic levels search nothing, so there is no budget to
            // spend. The search levels pass a real one; see milestone 4.
            budget: AiComputeBudget.none,
            requestId: requestId,
          );
    } on AiDecisionCancelled {
      return null;
    } finally {
      if (_pendingRequest == requestId) {
        _pendingRequest = null;
      }
    }
  }

  void _cancelPending() {
    final Object? pending = _pendingRequest;
    if (pending != null) {
      ref.read(aiDecisionServiceProvider).cancel(pending);
      _pendingRequest = null;
    }
  }

  MatchPacing get _pacing => MatchPacing(ref.read(settingsProvider));

  /// Whose move it is, as a phase.
  static MatchPhase _phaseFor(SpadesBatakMatchState match, int humanSeat) {
    if (match.isOver) {
      return MatchPhase.matchOver;
    }
    return match.hand!.turnSeat == humanSeat
        ? MatchPhase.awaitingHuman
        : MatchPhase.opponentThinking;
  }

  static int _seedFromClock() =>
      DateTime.now().microsecondsSinceEpoch & 0x3FFFFFFF;
}
