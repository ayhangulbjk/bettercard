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
import 'partnership_batak_match_state.dart';
import 'partnership_batak_scorer.dart';

/// Esli Ihaleli Batak, end to end: deal, auction, name trump, open the
/// partner's hand, play thirteen tricks, score both sides, deal again.
///
/// Card play is delegated to the shared [TrickPlayEngine], so following suit,
/// raising, cutting and overcutting have exactly one authority
/// (`TrickLegalMoves`) across the whole product -- including the open hand,
/// which gets no privilege whatever. The auction is the shared
/// [AuctionState], because bidding is the same shape here as in the solo
/// auction mode. What this engine owns is the part that is genuinely
/// different: a contract taken for a *side*, a partner's hand that goes face
/// up after the trump and not before, and a payoff with two teams.
///
/// Four things it deliberately does not do:
///
/// * it does not move the open hand's cards into the declarer's hand. They
///   stay where they were dealt, so a trick the partner wins is credited to
///   the partner and led next from the partner's seat;
/// * it does not let a trump be named before the auction settles, nor the
///   partner's hand be read before a trump is named;
/// * it does not reuse either of the other modes' scorers;
/// * it does not advance the hand anywhere except inside [apply], so a
///   half-finished transition is not expressible.
final class PartnershipBatakEngine
    implements GameEngine<PartnershipBatakMatchState> {
  const PartnershipBatakEngine({this.trickEngine = const TrickPlayEngine()});

  final TrickPlayEngine trickEngine;

  /// Starts a match from [profile] and [seed].
  ///
  /// The caller is expected to have run `RuleProfileValidator`; an
  /// inconsistent profile throws rather than producing a half-valid match.
  static PartnershipBatakMatchState start({
    required RuleProfile profile,
    required int seed,
  }) {
    if (!profile.biddingRules.hasAuction) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Esli Ihaleli Batak needs an auction',
      );
    }
    if (!profile.partnershipScoringRules.enabled ||
        !profile.partnershipRules.enabled) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'A partnership mode needs two teams and a team payoff',
      );
    }
    if (profile.playerCount != 4) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Esli Ihaleli Batak is four seats in two pairs',
      );
    }
    if (profile.fixedTrump != null) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'The contract winner names trump; this profile fixes one',
      );
    }
    final PartnershipBatakMatchState state = _dealHand(
      profile: profile,
      baseSeed: seed,
      handIndex: 0,
      teamTotals: List<int>.filled(2, 0),
      history: const <HandScore>[],
    );
    state.checkInvariants();
    return state;
  }

  /// Deals hand [handIndex] and opens its auction.
  ///
  /// The cards come first because a seat must see its hand before it can bid
  /// on it, and the trick state is dealt with no trump: it is not yet known,
  /// and inventing a placeholder would make illegal plays legal. Nothing is
  /// marked as open, either -- the partner's hand becomes visible from the
  /// trump, so dealing cannot leak it.
  static PartnershipBatakMatchState _dealHand({
    required RuleProfile profile,
    required int baseSeed,
    required int handIndex,
    required List<int> teamTotals,
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
    return PartnershipBatakMatchState(
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
        seating: SeatingPlan.partnership4(),
        rules: profile.trickRules,
        trump: null,
        // The contract winner opens the first trick, which is not known yet.
        // Until the auction settles this is a placeholder that no command can
        // act on, because card play is refused while the auction is live.
        leadSeat: opener,
      ),
      teamTotals: teamTotals,
      history: history,
    );
  }

  @override
  bool isTerminal(PartnershipBatakMatchState state) => state.isOver;

  @override
  int? seatToAct(PartnershipBatakMatchState state) => state.seatToAct;

  @override
  List<GameCommand> legalCommands(
    PartnershipBatakMatchState state,
    int seat,
  ) {
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
    // Always against the seat whose turn it is, never against the seat that
    // chooses: the open hand's legal cards are the open hand's, and the
    // declarer's own cards are no part of that calculation.
    return trickEngine.legalCommands(hand, seat);
  }

  /// The trumps the contract winner may name.
  ///
  /// All four suits. No-trump is off by default and is a separate rule, not a
  /// fifth option here: it changes the payoff as well as the play.
  List<Suit> legalTrumps(PartnershipBatakMatchState state) =>
      state.isChoosingTrump ? Suit.values : const <Suit>[];

  /// The contracts [seat] may offer, straight from the auction.
  ///
  /// Partnerships change nothing: a seat may raise its own partner if it
  /// genuinely wants the hand. Tables allow it, it is almost always a bad
  /// idea, and that is a judgement for the bidding AI rather than a rule to
  /// enforce here.
  List<int> legalBids(PartnershipBatakMatchState state, int seat) =>
      state.auction?.legalBids(seat) ?? const <int>[];

  /// The cards [seat] may play, without allocating a command per candidate.
  List<PlayingCard> legalCards(PartnershipBatakMatchState state, int seat) {
    final TrickPlayState? hand = state.hand;
    if (hand == null || !state.isPlaying) {
      return const <PlayingCard>[];
    }
    return trickEngine.legalCards(hand, seat);
  }

  @override
  CommandOutcome<PartnershipBatakMatchState> apply(
    PartnershipBatakMatchState state,
    GameCommand command,
  ) {
    if (state.isOver) {
      return const CommandRejected<PartnershipBatakMatchState>(
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
      // King. Neither has any meaning here, so both are refused explicitly
      // rather than caught by a wildcard: a command added later should fail
      // to compile here, not fall through.
      BuryCardsCommand() ||
      SelectContractCommand() =>
        const CommandRejected<PartnershipBatakMatchState>(
          RuleViolation(
            RuleViolationCode.wrongPhase,
            detail: 'this mode has no bury or contract-selection step',
          ),
        ),
    };
  }

  CommandOutcome<PartnershipBatakMatchState> _bid(
    PartnershipBatakMatchState state,
    PlaceBidCommand command,
  ) {
    if (!state.isAuctioning) {
      return const CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the auction is over',
        ),
      );
    }
    final AuctionState auction = state.auction!;
    if (auction.seatToAct != command.seat) {
      return CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.notYourTurn,
          detail: 'seat ${command.seat} bid out of order',
        ),
      );
    }
    if (!auction.legalBids(command.seat).contains(command.tricks)) {
      return CommandRejected<PartnershipBatakMatchState>(
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

  CommandOutcome<PartnershipBatakMatchState> _pass(
    PartnershipBatakMatchState state,
    PassBidCommand command,
  ) {
    if (!state.isAuctioning) {
      return const CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the auction is over',
        ),
      );
    }
    final AuctionState auction = state.auction!;
    if (!auction.canPass(command.seat)) {
      return CommandRejected<PartnershipBatakMatchState>(
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
  CommandOutcome<PartnershipBatakMatchState> _settle(
    PartnershipBatakMatchState state,
    AuctionState auction,
  ) {
    if (auction.needsRedeal) {
      // No score and no contract: the hand never happened. The hand index
      // does not advance either, so the dealer keeps the deal, which is what
      // a redeal means.
      final PartnershipBatakMatchState redealt = _dealHand(
        profile: state.profile,
        baseSeed: state.baseSeed,
        handIndex: state.handIndex,
        teamTotals: state.teamTotals,
        history: state.history,
        redealCount: state.history.length + auction.calls.length,
      );
      redealt.checkInvariants();
      return CommandAccepted<PartnershipBatakMatchState>(redealt);
    }

    PartnershipBatakMatchState next = state.copyWith(auction: auction);
    if (auction.isComplete && !state.profile.biddingRules.declarerNamesTrump) {
      // A table where the rules fix the trump rather than the winner naming
      // it. Not a shipped preset, but the flag exists, so it is honoured
      // rather than silently ignored.
      next = _withTrump(next, state.profile.fixedTrump);
    }
    next.checkInvariants();
    return CommandAccepted<PartnershipBatakMatchState>(next);
  }

  CommandOutcome<PartnershipBatakMatchState> _nameTrump(
    PartnershipBatakMatchState state,
    DeclareTrumpCommand command,
  ) {
    if (!state.isChoosingTrump) {
      return const CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'no contract is waiting for a trump',
        ),
      );
    }
    if (state.declarerSeat != command.seat) {
      return CommandRejected<PartnershipBatakMatchState>(
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
      return const CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.invalidBid,
          detail: 'no-trump contracts are not enabled',
        ),
      );
    }
    final PartnershipBatakMatchState next = _withTrump(state, trump);
    next.checkInvariants();
    return CommandAccepted<PartnershipBatakMatchState>(next);
  }

  /// Fixes [trump] for the hand and hands the lead to the contract winner.
  ///
  /// This is also the moment the partner's hand goes face up, and it is one
  /// step rather than two on purpose: "a trump has been named" and "the open
  /// hand is readable" are the same fact, so there is no window in which a
  /// declarer could choose a trump already knowing what is opposite it.
  ///
  /// The lead moves here rather than at the deal because it belongs to the
  /// winner of the auction, and that is not known until now.
  static PartnershipBatakMatchState _withTrump(
    PartnershipBatakMatchState state,
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

  CommandOutcome<PartnershipBatakMatchState> _play(
    PartnershipBatakMatchState state,
    PlayCardCommand command,
  ) {
    if (!state.isPlaying) {
      return const CommandRejected<PartnershipBatakMatchState>(
        RuleViolation(
          RuleViolationCode.wrongPhase,
          detail: 'the contract is not settled yet',
        ),
      );
    }
    // The command carries the seat the card comes **from**, which during the
    // open hand's turn is the open hand, not the declarer choosing for it.
    // Card legality is not re-decided here either: delegating keeps one
    // authority, and it is what makes a declarer trying to play its own card
    // on its partner's turn a plain "that card is not in this hand".
    final CommandOutcome<TrickPlayState> outcome =
        trickEngine.apply(state.hand!, command);
    return switch (outcome) {
      CommandRejected<TrickPlayState>(violation: final RuleViolation v) =>
        CommandRejected<PartnershipBatakMatchState>(v),
      CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
        CommandAccepted<PartnershipBatakMatchState>(_afterPlay(state, next)),
    };
  }

  /// Folds an accepted card play back in, closing the hand and opening the
  /// next one when the thirteenth trick lands.
  PartnershipBatakMatchState _afterPlay(
    PartnershipBatakMatchState state,
    TrickPlayState next,
  ) {
    if (!next.isComplete) {
      return state.copyWith(hand: next);
    }

    final PartnershipHandResult result = PartnershipBatakScorer.scoreHand(
      state: next,
      profile: state.profile,
      declarerSeat: state.declarerSeat,
      bid: state.contractBid,
    );
    final List<int> teamTotals = <int>[
      for (int team = 0; team < 2; team++)
        state.teamTotals[team] + result.outcome.teamPoints[team],
    ];
    final List<HandScore> history = <HandScore>[
      ...state.history,
      result.score,
    ];

    final PartnershipBatakMatchState scored = state.copyWith(
      hand: next,
      teamTotals: teamTotals,
      history: history,
      instantWinnerTeam: result.outcome.instantWinnerTeam,
    );

    // The end condition is derived from the score, so it is asked after the
    // hand is folded in, never before. A KING answers it on its own.
    if (scored.hasReachedEnd) {
      final PartnershipBatakMatchState over =
          scored.copyWith(clearHand: true, clearAuction: true);
      over.checkInvariants();
      return over;
    }

    final PartnershipBatakMatchState dealt = _dealHand(
      profile: state.profile,
      baseSeed: state.baseSeed,
      handIndex: state.handIndex + 1,
      teamTotals: teamTotals,
      history: history,
    );
    dealt.checkInvariants();
    return dealt;
  }
}
