import '../../core/cards/deck.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/auction/auction_state.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_engine.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_violation.dart';
import '../spades_batak/spades_batak_scorer.dart' show HandScore;
import 'auction_batak_match_state.dart';
import 'auction_batak_scorer.dart';

/// Herkes Tek Ihaleli Batak, end to end: deal, auction, name trump, play
/// thirteen tricks, score, deal again.
///
/// Card play is delegated to the shared [TrickPlayEngine], so following suit,
/// raising, cutting and the trump-lead restriction have exactly one authority
/// (`TrickLegalMoves`) across the whole product. What this engine owns is the
/// part that is genuinely different from the other modes: an open auction for
/// a single contract, a named trump, and a payoff with one declarer and three
/// defenders.
///
/// Three things it deliberately does not do:
///
/// * it does not reuse Koz Maca's declaration round or its scorer -- four
///   independent promises and one contract are different games;
/// * it does not let the trick engine see a hand before a trump is named,
///   because the trump decides what is legal;
/// * it does not advance the hand anywhere except inside [apply], so a
///   half-finished transition is not expressible.
final class AuctionBatakEngine implements GameEngine<AuctionBatakMatchState> {
  const AuctionBatakEngine({this.trickEngine = const TrickPlayEngine()});

  final TrickPlayEngine trickEngine;

  /// Starts a match from [profile] and [seed].
  ///
  /// The caller is expected to have run `RuleProfileValidator`; an
  /// inconsistent profile throws rather than producing a half-valid match.
  static AuctionBatakMatchState start({
    required RuleProfile profile,
    required int seed,
  }) {
    if (!profile.biddingRules.hasAuction) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Herkes Tek Ihaleli Batak needs an auction',
      );
    }
    if (!profile.auctionScoringRules.enabled) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'A contract mode needs auction scoring',
      );
    }
    if (profile.fixedTrump != null) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'The contract winner names trump; this profile fixes one',
      );
    }
    final AuctionBatakMatchState state = _dealHand(
      profile: profile,
      baseSeed: seed,
      handIndex: 0,
      totals: List<int>.filled(profile.playerCount, 0),
      history: const <HandScore>[],
    );
    state.checkInvariants();
    return state;
  }

  /// Deals hand [handIndex] and opens its auction.
  ///
  /// The cards come first because a seat must see its hand before it can bid
  /// on it, and the trick state is dealt with no trump: it is not yet known,
  /// and inventing a placeholder would make illegal plays legal.
  static AuctionBatakMatchState _dealHand({
    required RuleProfile profile,
    required int baseSeed,
    required int handIndex,
    required List<int> totals,
    required List<HandScore> history,
    int redealCount = 0,
  }) {
    // A redeal must produce different cards or the table would pass out for
    // ever, so it forks the seed rather than repeating it.
    final int seed = baseSeed + handIndex + redealCount * 1000003;
    final Deal deal = Deck.shuffleAndDeal(
      seed: seed,
      handCount: profile.playerCount,
      handSize: profile.handSize,
      excluded: <PlayingCard>{
        for (final int id in profile.deckExclusions) PlayingCard.fromId(id),
      },
    );
    final int dealer = handIndex % profile.playerCount;
    final int opener = (dealer + 1) % profile.playerCount;
    return AuctionBatakMatchState(
      profile: profile,
      baseSeed: baseSeed,
      handIndex: handIndex,
      auction: AuctionState.opening(
        rules: profile.biddingRules,
        seatCount: profile.playerCount,
        openingSeat: opener,
        dealerSeat: dealer,
      ),
      hand: TrickPlayState.opening(
        hands: deal.hands,
        seating: SeatingPlan.individual(profile.playerCount),
        rules: profile.trickRules,
        trump: null,
        // The contract winner opens the first trick, which is not known yet.
        // Until the auction settles this is a placeholder that no command can
        // act on, because card play is refused while the auction is live.
        leadSeat: opener,
      ),
      totals: totals,
      history: history,
    );
  }

  @override
  bool isTerminal(AuctionBatakMatchState state) => state.isOver;

  @override
  int? seatToAct(AuctionBatakMatchState state) => state.seatToAct;

  @override
  List<GameCommand> legalCommands(AuctionBatakMatchState state, int seat) {
    if (state.isAuctioning) {
      final AuctionState auction = state.auction!;
      if (auction.seatToAct != seat) {
        return const <GameCommand>[];
      }
      return <GameCommand>[
        for (final int bid in auction.legalBids(seat))
          PlaceBidCommand(seat: seat, tricks: bid),
        PassBidCommand(seat: seat),
      ];
    }
    if (state.isChoosingTrump) {
      if (state.declarerSeat != seat) {
        return const <GameCommand>[];
      }
      return <GameCommand>[
        for (final Suit suit in legalTrumps(state))
          DeclareTrumpCommand(seat: seat, trump: suit),
      ];
    }
    final TrickPlayState? hand = state.hand;
    if (hand == null || !state.isPlaying) {
      return const <GameCommand>[];
    }
    return trickEngine.legalCommands(hand, seat);
  }

  /// The trumps the contract winner may name.
  ///
  /// All four suits. No-trump is off by default and is a separate rule, not a
  /// fifth option here: it changes the payoff as well as the play.
  List<Suit> legalTrumps(AuctionBatakMatchState state) =>
      state.isChoosingTrump ? Suit.values : const <Suit>[];

  /// The contracts [seat] may offer, straight from the auction.
  List<int> legalBids(AuctionBatakMatchState state, int seat) =>
      state.auction?.legalBids(seat) ?? const <int>[];

  /// The cards [seat] may play, without allocating a command per candidate.
  List<PlayingCard> legalCards(AuctionBatakMatchState state, int seat) {
    final TrickPlayState? hand = state.hand;
    if (hand == null || !state.isPlaying) {
      return const <PlayingCard>[];
    }
    return trickEngine.legalCards(hand, seat);
  }

  @override
  CommandOutcome<AuctionBatakMatchState> apply(
    AuctionBatakMatchState state,
    GameCommand command,
  ) {
    if (state.isOver) {
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the match is over',
        ),
      );
    }

    return switch (command) {
      PlaceBidCommand() => _bid(state, command),
      PassBidCommand() => _pass(state, command),
      DeclareTrumpCommand() => _nameTrump(state, command),
      PlayCardCommand() => _play(state, command),
      // Burying belongs to three-player Batak and contract selection to
      // King. Neither has any meaning in a single-contract auction, so both
      // are refused explicitly rather than caught by a wildcard: a command
      // added later should fail to compile here, not fall through.
      BuryCardsCommand() ||
      SelectContractCommand() =>
        const CommandRejected<AuctionBatakMatchState>(
          RuleViolation(
            RuleViolationCode.wrongPhase,
            detail: 'this mode has no bury or contract-selection step',
          ),
        ),
    };
  }

  CommandOutcome<AuctionBatakMatchState> _bid(
    AuctionBatakMatchState state,
    PlaceBidCommand command,
  ) {
    if (!state.isAuctioning) {
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the auction is over',
        ),
      );
    }
    final AuctionState auction = state.auction!;
    if (auction.seatToAct != command.seat) {
      return CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.notYourTurn,
          detail: 'seat ${command.seat} bid out of order',
        ),
      );
    }
    if (!auction.legalBids(command.seat).contains(command.tricks)) {
      return CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.invalidBid,
          detail: '${command.tricks} over ${auction.standingBid}',
        ),
      );
    }
    return _settle(
      state,
      auction.withCall(
        AuctionCall.bid(seat: command.seat, tricks: command.tricks),
      ),
    );
  }

  CommandOutcome<AuctionBatakMatchState> _pass(
    AuctionBatakMatchState state,
    PassBidCommand command,
  ) {
    if (!state.isAuctioning) {
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the auction is over',
        ),
      );
    }
    final AuctionState auction = state.auction!;
    if (!auction.canPass(command.seat)) {
      return CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.notYourTurn,
          detail: 'seat ${command.seat} passed out of order',
        ),
      );
    }
    return _settle(
      state,
      auction.withCall(AuctionCall.pass(seat: command.seat)),
    );
  }

  /// Folds an accepted call back in, redealing if the hand passed out at a
  /// table that redeals.
  CommandOutcome<AuctionBatakMatchState> _settle(
    AuctionBatakMatchState state,
    AuctionState auction,
  ) {
    if (auction.needsRedeal) {
      // No score and no contract: the hand never happened. The hand index
      // does not advance either, so the dealer keeps the deal, which is what
      // a redeal means.
      final AuctionBatakMatchState redealt = _dealHand(
        profile: state.profile,
        baseSeed: state.baseSeed,
        handIndex: state.handIndex,
        totals: state.totals,
        history: state.history,
        redealCount: state.history.length + auction.calls.length,
      );
      redealt.checkInvariants();
      return CommandAccepted<AuctionBatakMatchState>(redealt);
    }

    AuctionBatakMatchState next = state.copyWith(auction: auction);
    if (auction.isComplete && !state.profile.biddingRules.declarerNamesTrump) {
      // A table where the rules fix the trump rather than the winner naming
      // it. Not a shipped preset, but the flag exists, so it is honoured
      // rather than silently ignored.
      next = _withTrump(next, state.profile.fixedTrump);
    }
    next.checkInvariants();
    return CommandAccepted<AuctionBatakMatchState>(next);
  }

  CommandOutcome<AuctionBatakMatchState> _nameTrump(
    AuctionBatakMatchState state,
    DeclareTrumpCommand command,
  ) {
    if (!state.isChoosingTrump) {
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'no contract is waiting for a trump',
        ),
      );
    }
    if (state.declarerSeat != command.seat) {
      return CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.notYourTurn,
          detail: 'seat ${command.seat} does not hold the contract',
        ),
      );
    }
    final Suit? trump = command.trump;
    if (trump == null) {
      // No-trump is off by default and is not merely "no suit named": it
      // needs its own payoff. Refusing is better than inventing one.
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.invalidBid,
          detail: 'no-trump contracts are not enabled',
        ),
      );
    }
    final AuctionBatakMatchState next = _withTrump(state, trump);
    next.checkInvariants();
    return CommandAccepted<AuctionBatakMatchState>(next);
  }

  /// Fixes [trump] for the hand and hands the lead to the contract winner.
  ///
  /// The lead moves here rather than at the deal because it belongs to the
  /// winner of the auction, and that is not known until now. A seat leading
  /// because of where it sits is the bug this guards against.
  static AuctionBatakMatchState _withTrump(
    AuctionBatakMatchState state,
    Suit? trump,
  ) {
    final TrickPlayState hand = state.hand!;
    final int declarer = state.declarerSeat!;
    return state.copyWith(
      trump: trump,
      hand: TrickPlayState.opening(
        hands: hand.hands,
        seating: hand.seating,
        rules: hand.rules,
        trump: trump,
        leadSeat: declarer,
      ),
    );
  }

  CommandOutcome<AuctionBatakMatchState> _play(
    AuctionBatakMatchState state,
    PlayCardCommand command,
  ) {
    if (!state.isPlaying) {
      return const CommandRejected<AuctionBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the contract is not settled yet',
        ),
      );
    }
    // Card legality is not re-decided here. Delegating keeps one authority.
    final CommandOutcome<TrickPlayState> outcome =
        trickEngine.apply(state.hand!, command);
    return switch (outcome) {
      CommandRejected<TrickPlayState>(violation: final RuleViolation v) =>
        CommandRejected<AuctionBatakMatchState>(v),
      CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
        CommandAccepted<AuctionBatakMatchState>(_afterPlay(state, next)),
    };
  }

  /// Folds an accepted card play back in, closing the hand and opening the
  /// next one when the thirteenth trick lands.
  AuctionBatakMatchState _afterPlay(
    AuctionBatakMatchState state,
    TrickPlayState next,
  ) {
    if (!next.isComplete) {
      return state.copyWith(hand: next);
    }

    final HandScore score = AuctionBatakScorer.scoreHand(
      state: next,
      profile: state.profile,
      declarerSeat: state.declarerSeat,
      bid: state.contractBid,
    );
    final List<int> totals = <int>[
      for (int seat = 0; seat < state.seatCount; seat++)
        state.totals[seat] + score.pointsOf(seat),
    ];
    final List<HandScore> history = <HandScore>[...state.history, score];

    final AuctionBatakMatchState scored = state.copyWith(
      hand: next,
      totals: totals,
      history: history,
    );

    // The end condition is derived from the score, so it is asked after the
    // hand is folded in, never before.
    if (scored.hasReachedEnd) {
      final AuctionBatakMatchState over =
          scored.copyWith(clearHand: true, clearAuction: true);
      over.checkInvariants();
      return over;
    }

    final AuctionBatakMatchState dealt = _dealHand(
      profile: state.profile,
      baseSeed: state.baseSeed,
      handIndex: state.handIndex + 1,
      totals: totals,
      history: history,
    );
    dealt.checkInvariants();
    return dealt;
  }
}
