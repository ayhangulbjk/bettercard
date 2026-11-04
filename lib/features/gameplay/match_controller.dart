import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_decision_service.dart';
import '../../core/ai/ai_difficulty.dart';
import '../../core/ai/ai_policy.dart';
import '../../core/ai/auction_policy.dart';
import '../../core/ai/policies/partnership_auction_policy.dart';
import '../../core/ai/seat_observation.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/persistence/saved_match.dart';
import '../../core/rules/rule_profile.dart';
import 'match_pacing.dart';
import 'match_persistence.dart';
import 'match_restore.dart';
import 'match_runtime.dart';
import 'match_session.dart';
import 'match_turn.dart';

/// The live match, or null when no table is open.
final NotifierProvider<MatchController, MatchSession?> matchProvider =
    NotifierProvider<MatchController, MatchSession?>(MatchController.new);

/// Drives a match: feeds the player's taps and the opponents' answers to the
/// engine, and paces what the table shows.
///
/// Which game is on the table is [MatchRuntime]'s business, not this class's.
/// A bid, a declaration, a named trump and a card are all just decisions it
/// schedules, asks a policy for, and hands on.
///
/// It owns no rules. Every state change is a command handed through the
/// runtime to the game's own engine, which re-validates it, so a bug here can
/// produce a rejection but never an illegal game. What it does own is
/// scheduling: the pause that lets a finished trick be read, the opponents'
/// thinking delay, and cancelling in-flight AI work when the player leaves
/// the table.
///
/// The UI thread is never blocked on a decision. Today's policies answer in
/// microseconds, but they are still awaited through [AiDecisionService], so
/// the search-based levels drop in behind the same seam.
final class MatchController extends Notifier<MatchSession?> {
  /// The auction player for the match on the table.
  ///
  /// Stateless, so it is built per match rather than held: unlike a card
  /// policy it carries no generator, because a bid is a function of the hand,
  /// the calls already made and the scoreboard rather than of a random draw.
  ///
  /// Which one depends on the mode, and the difference is not cosmetic: a
  /// team contract is bid for two hands, one of them unseen, and passing can
  /// mean handing the contract to a partner. A solo bidder in that seat would
  /// read its partner's bid as a number to beat.
  AuctionPolicy get _auction {
    final MatchSession? session = state;
    final AiDifficulty difficulty = _opponents.difficulty;
    if (session != null && session.profile.partnershipScoringRules.enabled) {
      return PartnershipAuctionPolicy(difficulty: difficulty);
    }
    return HeuristicAuctionPolicy(difficulty: difficulty);
  }

  /// The opponents at this table. Empty when no match is open.
  OpponentRoster _opponents = OpponentRoster.empty;

  /// Every card played this match, in order. This is what gets saved: the
  /// position is whatever replaying it through the engine produces.
  final List<int> _moves = <int>[];

  late final MatchPersistence _persistence = MatchPersistence(ref);

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
    final MatchRuntime match =
        MatchRuntime.start(profile: profile, seed: matchSeed);

    _cancelPending();
    _generation++;
    _opponents = OpponentRoster.forMatch(
      difficulty: difficulty,
      profile: profile,
      matchSeed: matchSeed,
      seatCount: match.seatCount,
      humanSeat: humanSeat,
    );

    _moves.clear();
    state = MatchSession(
      matchId: _matchIdFor(matchSeed),
      dealSeed: matchSeed,
      match: match,
      phase: MatchTurn.phaseFor(match, humanSeat),
      humanSeat: humanSeat,
      difficulty: difficulty,
    );
    // Saved before the first card, so a match that is opened and abandoned at
    // once still offers to resume rather than vanishing.
    _save();
    unawaited(_drive(_generation));
  }

  /// Reopens the stored match, or returns false when it cannot be replayed.
  ///
  /// A save that fails to replay is dropped here rather than left on disk to
  /// fail again on the next launch.
  bool resume(SavedMatch save) {
    final MatchRuntime? restored = MatchRestore.replay(save);
    if (restored == null) {
      unawaited(_persistence.clear());
      return false;
    }

    _cancelPending();
    _generation++;
    _opponents = OpponentRoster.forMatch(
      difficulty: save.difficulty,
      profile: save.ruleProfile,
      matchSeed: save.dealSeed,
      seatCount: restored.seatCount,
      humanSeat: save.humanSeat,
    );
    _moves
      ..clear()
      ..addAll(save.moves);

    state = MatchSession(
      matchId: save.matchId,
      dealSeed: save.dealSeed,
      match: restored,
      phase: MatchTurn.phaseFor(restored, save.humanSeat),
      humanSeat: save.humanSeat,
      difficulty: save.difficulty,
    );
    unawaited(_drive(_generation));
    return true;
  }

  /// Records the player's declaration. Ignored unless the table is waiting
  /// for one.
  void declare(int tricks) {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingDeclaration) {
      return;
    }
    _submitDeclaration(session.humanSeat, tricks);
    unawaited(_drive(_generation));
  }

  /// Offers [tricks] in the auction. Ignored unless it is the player's turn
  /// to speak.
  void bid(int tricks) {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingBid) {
      return;
    }
    _submitBid(session.humanSeat, tricks);
    unawaited(_drive(_generation));
  }

  /// Withdraws the player from the auction, for good.
  void pass() {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingBid) {
      return;
    }
    _submitPass(session.humanSeat);
    unawaited(_drive(_generation));
  }

  /// Names [trump] for the hand. Ignored unless the player holds the
  /// contract and has not named one.
  void chooseTrump(Suit trump) {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingTrump) {
      return;
    }
    _submitTrump(session.humanSeat, trump);
    unawaited(_drive(_generation));
  }

  /// Plays [card]. Ignored unless the player is the one choosing right now.
  ///
  /// The card leaves whichever hand is on turn, which is not always the
  /// player's own: a declarer playing the open hand opposite taps a card
  /// there, and it is played from that seat. Looking the seat up here rather
  /// than assuming the player's own is what makes the two cases one method.
  void playCard(PlayingCard card) {
    final MatchSession? session = state;
    if (session == null || session.phase != MatchPhase.awaitingHuman) {
      return;
    }
    final int? owner = session.seatToPlay;
    if (owner == null) {
      return;
    }
    _submit(owner, card);
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
      phase: MatchTurn.phaseFor(session.match, session.humanSeat),
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
        case MatchPhase.awaitingDeclaration:
        case MatchPhase.awaitingBid:
        case MatchPhase.awaitingTrump:
        case MatchPhase.handSummary:
        case MatchPhase.matchOver:
          // Waiting on the person at the device.
          return;

        case MatchPhase.opponentDeclaring:
          final MatchRuntime match = session.match;
          final int? seat = match.seatToAct;
          final TrickPlayState? hand = match.hand;
          if (seat == null || hand == null) {
            return;
          }
          await MatchPacing.wait(_pacing.thinkDelay);
          if (generation != _generation || state == null) {
            return;
          }
          final int? declaration = await _decideDeclaration(seat, match, hand);
          if (declaration == null ||
              generation != _generation ||
              state == null) {
            return;
          }
          _submitDeclaration(seat, declaration);

        case MatchPhase.opponentBidding:
          final MatchRuntime auctioning = session.match;
          final int? bidder = auctioning.seatToAct;
          final TrickPlayState? cards = auctioning.hand;
          if (bidder == null || cards == null) {
            return;
          }
          await MatchPacing.wait(_pacing.thinkDelay);
          if (generation != _generation || state == null) {
            return;
          }
          final int? offer = _auction.chooseBid(
            SeatObservation.fromState(
              cards,
              bidder,
              match: auctioning.aiContext,
              visibleHands: auctioning.visibleHandsFor(bidder),
              publicHands: auctioning.publicOpenHands,
            ),
            auctioning.legalBids(bidder),
          );
          if (generation != _generation || state == null) {
            return;
          }
          if (offer == null) {
            _submitPass(bidder);
          } else {
            _submitBid(bidder, offer);
          }

        case MatchPhase.opponentChoosingTrump:
          final MatchRuntime naming = session.match;
          final int? winner = naming.seatToAct;
          final TrickPlayState? held = naming.hand;
          if (winner == null || held == null) {
            return;
          }
          await MatchPacing.wait(_pacing.thinkDelay);
          if (generation != _generation || state == null) {
            return;
          }
          _submitTrump(
            winner,
            _auction.chooseTrump(
              SeatObservation.fromState(
                held,
                winner,
                match: naming.aiContext,
                // The open hand is NOT in this set: it goes face up after the
                // trump is named, which is the rule that stops a declarer
                // choosing a trump already knowing what is opposite it. The
                // match state is what enforces the ordering; this call just
                // asks it.
                visibleHands: naming.visibleHandsFor(winner),
                publicHands: naming.publicOpenHands,
              ),
              naming.legalTrumps,
            ),
          );

        case MatchPhase.trickPause:
          // Beat one: the four cards lie still so the player can read them.
          await MatchPacing.wait(_pacing.trickPause);
          if (generation != _generation || state == null) {
            return;
          }
          state = state!.copyWith(phase: MatchPhase.trickGather);

        case MatchPhase.trickGather:
          // Beat two: the pile travels to the winner. The wait matches the
          // animation in TrickArea, which is handed the same duration, so the
          // next card is never dealt onto cards still in flight.
          await MatchPacing.wait(_pacing.trickGather);
          if (generation != _generation || state == null) {
            return;
          }
          state = state!.copyWith(
            phase: MatchTurn.phaseFor(state!.match, state!.humanSeat),
            clearLastTrick: true,
          );

        case MatchPhase.opponentThinking:
          final TrickPlayState? hand = session.hand;
          if (hand == null) {
            return;
          }
          final MatchRuntime playing = session.match;
          // The seat the card comes from, and the seat that chooses it. The
          // two differ for an open hand, and getting them the wrong way round
          // would play the declarer's card out of its partner's seat.
          final int owner = hand.turnSeat;
          final int decider = session.deciderFor(owner);
          await MatchPacing.wait(_pacing.thinkDelay);
          if (generation != _generation || state == null) {
            return;
          }
          final PlayingCard? card =
              await _decide(owner, decider, playing, hand);
          if (card == null || generation != _generation || state == null) {
            return;
          }
          _submit(owner, card);
      }
    }
  }

  /// Hands one card play to the engine and folds the result into the table.
  void _submit(int seat, PlayingCard card) {
    final MatchSession session = state!;
    final MatchTurnResult result = MatchTurn.apply(session, seat, card);
    state = result.session;
    if (!result.accepted) {
      return;
    }

    _moves.add(card.id);
    if (result.session.match.isOver) {
      unawaited(
        _persistence.recordFinished(
          MatchPersistence.recordOf(result.session, nowMillis: _nowMillis()),
        ),
      );
    } else {
      _save();
    }
  }

  /// Hands one declaration to the engine and folds the result into the table.
  void _submitDeclaration(int seat, int tricks) {
    final MatchSession session = state!;
    final MatchTurnResult result = MatchTurn.declare(session, seat, tricks);
    state = result.session;
    if (!result.accepted) {
      return;
    }
    // The log carries declarations alongside cards, so a resumed match knows
    // what everybody promised. A declaration never ends a match, so unlike a
    // card play there is no finished-match branch here.
    _moves.add(SavedMatch.encodeDeclaration(tricks));
    _save();
  }

  /// Hands one auction bid to the engine and folds the result into the table.
  void _submitBid(int seat, int tricks) {
    final MatchSession session = state!;
    final MatchTurnResult result = MatchTurn.bid(session, seat, tricks);
    state = result.session;
    if (!result.accepted) {
      return;
    }
    _moves.add(SavedMatch.encodeBid(tricks));
    _save();
  }

  /// Hands one pass to the engine.
  ///
  /// A pass can finish the auction, and a passed-out auction forces a
  /// contract, but neither ends a match, so this has no finished-match branch
  /// either.
  void _submitPass(int seat) {
    final MatchSession session = state!;
    final MatchTurnResult result = MatchTurn.pass(session, seat);
    state = result.session;
    if (!result.accepted) {
      return;
    }
    _moves.add(SavedMatch.passMove);
    _save();
  }

  /// Hands the named trump to the engine.
  void _submitTrump(int seat, Suit trump) {
    final MatchSession session = state!;
    final MatchTurnResult result = MatchTurn.chooseTrump(session, seat, trump);
    state = result.session;
    if (!result.accepted) {
      return;
    }
    _moves.add(SavedMatch.encodeTrump(trump.index));
    _save();
  }

  /// Writes the match in progress.
  void _save() {
    final MatchSession? session = state;
    if (session == null || session.match.isOver) {
      return;
    }
    _persistence.scheduleSave(
      MatchPersistence.saveOf(session, _moves, nowMillis: _nowMillis()),
    );
  }

  /// Asks [decider]'s policy for the card [owner] plays.
  ///
  /// The observation is built for [owner] -- its hand is the hand being
  /// played from, and its legal moves are the legal moves -- while which
  /// *other* hands the decision may read comes from [decider]. That is the
  /// whole of the open-hand mechanic on this side of the seam: the declarer
  /// decides, the partner plays, and the information boundary belongs to
  /// whoever is deciding.
  Future<PlayingCard?> _decide(
    int owner,
    int decider,
    MatchRuntime match,
    TrickPlayState hand,
  ) async {
    final AiPolicy? policy = _opponents.policyFor(decider);
    if (policy == null) {
      return null;
    }
    final Object requestId = Object();
    _pendingRequest = requestId;
    try {
      return await ref.read(aiDecisionServiceProvider).decide(
            policy: policy,
            observation: SeatObservation.fromState(
              hand,
              owner,
              match: match.aiContext,
              visibleHands: match.visibleHandsFor(decider),
              publicHands: match.publicOpenHands,
            ),
            // Per level, from the difficulty itself: the heuristic levels
            // spend nothing, the search levels get a bound they must return
            // their best answer within.
            budget: _opponents.difficulty.budget,
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

  /// Asks [seat]'s policy for a declaration, through the decision service.
  Future<int?> _decideDeclaration(
    int seat,
    MatchRuntime match,
    TrickPlayState hand,
  ) async {
    final AiPolicy? policy = _opponents.policyFor(seat);
    if (policy == null) {
      return null;
    }
    final Object requestId = Object();
    _pendingRequest = requestId;
    try {
      return await ref.read(aiDecisionServiceProvider).decideDeclaration(
            policy: policy,
            observation: SeatObservation.fromState(
              hand,
              seat,
              match: match.aiContext,
              visibleHands: match.visibleHandsFor(seat),
              publicHands: match.publicOpenHands,
            ),
            // From the engine, never from the policy: what may be declared is
            // a rule, and rules have one authority.
            options: match.legalDeclarations,
            budget: _opponents.difficulty.budget,
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

  static int _nowMillis() => DateTime.now().millisecondsSinceEpoch;

  static int _seedFromClock() =>
      DateTime.now().microsecondsSinceEpoch & 0x3FFFFFFF;

  static String _matchIdFor(int seed) =>
      'spades-$seed-${DateTime.now().millisecondsSinceEpoch}';
}
