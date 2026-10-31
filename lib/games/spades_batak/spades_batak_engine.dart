import '../../core/cards/deck.dart';
import '../../core/cards/playing_card.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_engine.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_violation.dart';
import 'spades_batak_match_state.dart';
import 'spades_batak_scorer.dart';

/// Koz Maca, end to end: deal, play thirteen tricks, score, deal again.
///
/// The simplest of the five modes, because there is no auction. It wraps the
/// shared [TrickPlayEngine] rather than reimplementing card play, so the rules
/// about following suit, trumping and the trump-lead restriction have exactly
/// one authority (`TrickLegalMoves`) across the whole product.
///
/// Advancing to the next hand happens inside [apply], as part of accepting the
/// last card of a hand. That keeps the caller from having to remember a
/// separate "next hand" step and makes an incomplete transition impossible.
final class SpadesBatakEngine implements GameEngine<SpadesBatakMatchState> {
  const SpadesBatakEngine({this.trickEngine = const TrickPlayEngine()});

  final TrickPlayEngine trickEngine;

  /// Starts a match from [profile] and [seed].
  ///
  /// [profile] must be a Koz Maca profile; the caller is expected to have run
  /// `RuleProfileValidator` already, and an inconsistent profile throws rather
  /// than producing a half-valid match.
  static SpadesBatakMatchState start({
    required RuleProfile profile,
    required int seed,
  }) {
    if (profile.biddingRules.hasAuction) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Koz Maca has no auction; this profile configures one',
      );
    }
    if (profile.fixedTrump == null) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Koz Maca needs a fixed trump',
      );
    }
    final SpadesBatakMatchState state = SpadesBatakMatchState(
      profile: profile,
      baseSeed: seed,
      handIndex: 0,
      hand: _deal(profile: profile, seed: seed, handIndex: 0),
      totals: List<int>.filled(profile.playerCount, 0),
      history: const <HandScore>[],
    );
    state.checkInvariants();
    return state;
  }

  /// Deals hand [handIndex].
  ///
  /// The lead rotates with the hand index, so over a match no seat keeps the
  /// advantage of leading first. Rotation is procedure rather than a scoring
  /// rule, so it is not a `RuleProfile` option.
  static TrickPlayState _deal({
    required RuleProfile profile,
    required int seed,
    required int handIndex,
  }) {
    final Deal deal = Deck.shuffleAndDeal(
      seed: seed,
      handCount: profile.playerCount,
      handSize: profile.handSize,
      excluded: <PlayingCard>{
        for (final int id in profile.deckExclusions) PlayingCard.fromId(id),
      },
    );
    return TrickPlayState.opening(
      hands: deal.hands,
      seating: SeatingPlan.individual(profile.playerCount),
      rules: profile.trickRules,
      trump: profile.fixedTrump,
      leadSeat: handIndex % profile.playerCount,
    );
  }

  @override
  List<GameCommand> legalCommands(SpadesBatakMatchState state, int seat) {
    final TrickPlayState? hand = state.hand;
    if (hand == null) {
      return const <GameCommand>[];
    }
    return trickEngine.legalCommands(hand, seat);
  }

  /// The cards [seat] may legally play, without allocating a command per
  /// candidate. Search policies call this in their inner loop.
  List<PlayingCard> legalCards(SpadesBatakMatchState state, int seat) {
    final TrickPlayState? hand = state.hand;
    if (hand == null) {
      return const <PlayingCard>[];
    }
    return trickEngine.legalCards(hand, seat);
  }

  @override
  bool isTerminal(SpadesBatakMatchState state) => state.isOver;

  @override
  int? seatToAct(SpadesBatakMatchState state) => state.hand?.turnSeat;

  @override
  CommandOutcome<SpadesBatakMatchState> apply(
    SpadesBatakMatchState state,
    GameCommand command,
  ) {
    final TrickPlayState? hand = state.hand;
    if (hand == null) {
      return const CommandRejected<SpadesBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the match is over',
        ),
      );
    }

    // Card legality is not re-decided here. Delegating keeps one authority.
    final CommandOutcome<TrickPlayState> outcome =
        trickEngine.apply(hand, command);
    return switch (outcome) {
      CommandRejected<TrickPlayState>(violation: final RuleViolation v) =>
        CommandRejected<SpadesBatakMatchState>(v),
      CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
        CommandAccepted<SpadesBatakMatchState>(_afterPlay(state, next)),
    };
  }

  /// Folds an accepted card play back into the match, closing the hand and
  /// opening the next one when the thirteenth trick lands.
  SpadesBatakMatchState _afterPlay(
    SpadesBatakMatchState state,
    TrickPlayState next,
  ) {
    if (!next.isComplete) {
      return state.copyWith(hand: next);
    }

    final HandScore score = SpadesBatakScorer.scoreHand(
      next,
      state.profile.scoringRules,
    );
    final List<int> totals = <int>[
      for (int seat = 0; seat < state.seatCount; seat++)
        state.totals[seat] + score.pointsOf(seat),
    ];
    final List<HandScore> history = <HandScore>[...state.history, score];

    final SpadesBatakMatchState scored = state.copyWith(
      hand: next,
      totals: totals,
      history: history,
    );

    // The end condition is derived from the score, so it is asked after the
    // hand is folded in, never before.
    if (scored.hasReachedEnd) {
      final SpadesBatakMatchState over = scored.copyWith(clearHand: true);
      over.checkInvariants();
      return over;
    }

    final int nextIndex = state.handIndex + 1;
    final SpadesBatakMatchState dealt = scored.copyWith(
      handIndex: nextIndex,
      hand: _deal(
        profile: state.profile,
        seed: state.seedForHand(nextIndex),
        handIndex: nextIndex,
      ),
    );
    dealt.checkInvariants();
    return dealt;
  }
}
