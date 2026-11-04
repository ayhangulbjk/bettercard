import 'package:meta/meta.dart';

import '../../core/ai/match_context.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/auction/auction_state.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_violation.dart';
import '../../games/auction_batak/auction_batak_engine.dart';
import '../../games/auction_batak/auction_batak_match_state.dart';
import '../../games/partnership_batak/partnership_batak_engine.dart';
import '../../games/partnership_batak/partnership_batak_match_state.dart';
import '../../games/spades_batak/spades_batak_engine.dart';
import '../../games/spades_batak/spades_batak_match_state.dart';
import '../../games/spades_batak/spades_batak_scorer.dart';

/// What a match is waiting for, across every mode that has a table.
///
/// Deliberately coarser than either game's own phases: the screen needs to
/// know which question is on the table, not how the engine decided that.
enum MatchStep {
  /// An open auction is running.
  bidding,

  /// The contract is won and the winner must name a trump.
  choosingTrump,

  /// Every seat owes a trick declaration before the first card.
  declaring,

  /// Cards.
  playing,

  /// The match reached its end condition.
  finished,
}

/// One table, whichever game is on it.
///
/// This is the seam between the screen and the games. The table screen, the
/// controller and the save layer all ask a match the same questions -- whose
/// turn, what may be played, what does the scoreboard say -- and the answers
/// differ only in how each engine works them out. Without this they would
/// each need a branch per mode, and a mode added later would have to be
/// threaded through all three.
///
/// It owns no rules. Every question is forwarded to the game's own engine and
/// every answer comes back from it, so a runtime cannot disagree with the
/// authority it wraps.
@immutable
sealed class MatchRuntime {
  const MatchRuntime();

  /// Starts a match in whichever mode [profile] names.
  ///
  /// The one place that maps a mode to an engine. A mode with no table yet
  /// throws rather than falling back to another game's engine, which is how
  /// an unplayable mode used to reach a table that refused its profile.
  static MatchRuntime start({
    required RuleProfile profile,
    required int seed,
  }) {
    if (profile.partnershipScoringRules.enabled) {
      return PartnershipBatakRuntime(
        PartnershipBatakEngine.start(profile: profile, seed: seed),
      );
    }
    if (profile.auctionScoringRules.enabled) {
      return AuctionBatakRuntime(
        AuctionBatakEngine.start(profile: profile, seed: seed),
      );
    }
    if (profile.declarationRules.enabled || profile.fixedTrump != null) {
      return SpadesBatakRuntime(
        SpadesBatakEngine.start(profile: profile, seed: seed),
      );
    }
    throw ArgumentError.value(
      profile.id,
      'profile',
      'no table exists for this rule profile yet',
    );
  }

  RuleProfile get profile;

  /// Card play for the hand on screen, or null once the match is over.
  TrickPlayState? get hand;

  /// What the match is waiting for.
  MatchStep get step;

  /// The seat that owes the next decision, or null when the match is over.
  int? get seatToAct;

  List<int> get totals;
  List<HandScore> get history;

  int get seatCount;
  int get handIndex;
  int get handsPlayed;
  bool get isOver;

  /// Seats tied for the lead.
  List<int> get leadingSeats;

  /// How the seats are grouped, so a caller can ask who is partners with whom
  /// without knowing which game is on the table.
  SeatingPlan get seating => hand?.seating ?? SeatingPlan.individual(seatCount);

  /// Cumulative points per side. Equal to [totals] where every seat is its
  /// own side, which is every mode but Esli Ihaleli.
  List<int> get teamTotals => totals;

  /// The seat that **chooses** the card [seat] plays.
  ///
  /// Itself in every mode but acik esli Batak, where the declarer plays its
  /// partner's open hand. Separate from [seatToAct], which stays the seat the
  /// card is played from and credited to.
  int controllerOf(int seat) => seat;

  /// The declarer's partner, whose hand is the open one. Null outside a
  /// partnership contract.
  int? get dummySeat => null;

  /// Whether the open hand's cards are face up.
  bool get isDummyRevealed => false;

  /// The open hand's cards, empty until they are face up.
  List<PlayingCard> get dummyHand => const <PlayingCard>[];

  /// The hands [decider] may legally read while choosing a card.
  ///
  /// Handed to `SeatObservation.fromState`, which is the only funnel another
  /// seat's cards can travel through, so this is the one place per mode that
  /// decides what a decision is allowed to see.
  Set<int> visibleHandsFor(int decider) => <int>{decider};

  /// The hands that are face up to every seat at the table.
  Set<int> get publicOpenHands => const <int>{};

  /// What a seat may legally know beyond the cards.
  MatchContext get aiContext;

  /// What each seat has promised for the hand on screen, null where a seat
  /// has promised nothing.
  ///
  /// In a contract mode only the declarer has an entry, which is the honest
  /// reading: the defenders promised nothing at all.
  List<int?> get declarations;

  /// The trump in force, or null before one is known.
  Suit? get trump;

  /// Who holds the contract, in a mode that has one.
  int? get declarerSeat => null;

  /// What the contract is for, in a mode that has one.
  int? get contractBid => null;

  /// Whether the contract was forced by a passed-out auction.
  bool get contractWasForced => false;

  /// The calls made in the auction so far. Empty in a mode without one.
  List<AuctionCall> get auctionCalls => const <AuctionCall>[];

  /// The highest contract offered so far, or null.
  int? get standingBid => null;

  /// The seat holding the standing bid, or null.
  int? get standingBidder => null;

  /// The contracts [seat] may offer right now.
  List<int> legalBids(int seat) => const <int>[];

  /// The trumps the contract winner may name.
  List<Suit> get legalTrumps => const <Suit>[];

  /// The numbers the seat on turn may declare.
  List<int> get legalDeclarations => const <int>[];

  /// The cards [seat] may play.
  List<PlayingCard> legalCards(int seat);

  /// Hands [command] to the engine.
  MatchRuntimeOutcome apply(GameCommand command);
}

/// The match after a command, or why the engine refused it.
@immutable
final class MatchRuntimeOutcome {
  const MatchRuntimeOutcome.accepted(this.runtime) : rejection = null;

  const MatchRuntimeOutcome.rejected(this.rejection) : runtime = null;

  final MatchRuntime? runtime;
  final RuleViolationCode? rejection;

  bool get accepted => runtime != null;
}

/// Koz Maca on a table.
@immutable
final class SpadesBatakRuntime extends MatchRuntime {
  const SpadesBatakRuntime(this.state);

  static const SpadesBatakEngine _engine = SpadesBatakEngine();

  final SpadesBatakMatchState state;

  @override
  RuleProfile get profile => state.profile;

  @override
  TrickPlayState? get hand => state.hand;

  @override
  MatchStep get step {
    if (state.isOver) {
      return MatchStep.finished;
    }
    return state.isDeclaring ? MatchStep.declaring : MatchStep.playing;
  }

  @override
  int? get seatToAct => _engine.seatToAct(state);

  @override
  List<int> get totals => state.totals;

  @override
  List<HandScore> get history => state.history;

  @override
  int get seatCount => state.seatCount;

  @override
  int get handIndex => state.handIndex;

  @override
  int get handsPlayed => state.handsPlayed;

  @override
  bool get isOver => state.isOver;

  @override
  List<int> get leadingSeats => state.leadingSeats;

  @override
  MatchContext get aiContext => state.aiContext;

  @override
  List<int?> get declarations => state.declarations;

  @override
  Suit? get trump => state.hand?.trump ?? profile.fixedTrump;

  @override
  List<int> get legalDeclarations => _engine.legalDeclarations(state);

  @override
  List<PlayingCard> legalCards(int seat) => _engine.legalCards(state, seat);

  @override
  MatchRuntimeOutcome apply(GameCommand command) =>
      switch (_engine.apply(state, command)) {
        CommandAccepted<SpadesBatakMatchState>(
          state: final SpadesBatakMatchState next
        ) =>
          MatchRuntimeOutcome.accepted(SpadesBatakRuntime(next)),
        CommandRejected<SpadesBatakMatchState>(
          violation: final RuleViolation violation
        ) =>
          MatchRuntimeOutcome.rejected(violation.code),
      };
}

/// Herkes Tek Ihaleli Batak on a table.
@immutable
final class AuctionBatakRuntime extends MatchRuntime {
  const AuctionBatakRuntime(this.state);

  static const AuctionBatakEngine _engine = AuctionBatakEngine();

  final AuctionBatakMatchState state;

  @override
  RuleProfile get profile => state.profile;

  @override
  TrickPlayState? get hand => state.hand;

  @override
  MatchStep get step {
    if (state.isOver) {
      return MatchStep.finished;
    }
    if (state.isAuctioning) {
      return MatchStep.bidding;
    }
    return state.isChoosingTrump ? MatchStep.choosingTrump : MatchStep.playing;
  }

  @override
  int? get seatToAct => state.seatToAct;

  @override
  List<int> get totals => state.totals;

  @override
  List<HandScore> get history => state.history;

  @override
  int get seatCount => state.seatCount;

  @override
  int get handIndex => state.handIndex;

  @override
  int get handsPlayed => state.history.length;

  @override
  bool get isOver => state.isOver;

  @override
  List<int> get leadingSeats => state.winners;

  @override
  MatchContext get aiContext => state.aiContext;

  @override
  List<int?> get declarations => <int?>[
        for (int seat = 0; seat < seatCount; seat++)
          seat == state.declarerSeat ? state.contractBid : null,
      ];

  @override
  Suit? get trump => state.trump;

  @override
  int? get declarerSeat => state.declarerSeat;

  @override
  int? get contractBid => state.contractBid;

  @override
  bool get contractWasForced => state.contractWasForced;

  @override
  List<AuctionCall> get auctionCalls =>
      state.auction?.calls ?? const <AuctionCall>[];

  @override
  int? get standingBid => state.auction?.standingBid;

  @override
  int? get standingBidder => state.auction?.standingBidder;

  @override
  List<int> legalBids(int seat) => _engine.legalBids(state, seat);

  @override
  List<Suit> get legalTrumps => _engine.legalTrumps(state);

  @override
  List<PlayingCard> legalCards(int seat) => _engine.legalCards(state, seat);

  @override
  MatchRuntimeOutcome apply(GameCommand command) =>
      switch (_engine.apply(state, command)) {
        CommandAccepted<AuctionBatakMatchState>(
          state: final AuctionBatakMatchState next
        ) =>
          MatchRuntimeOutcome.accepted(AuctionBatakRuntime(next)),
        CommandRejected<AuctionBatakMatchState>(
          violation: final RuleViolation violation
        ) =>
          MatchRuntimeOutcome.rejected(violation.code),
      };
}

/// Esli Ihaleli Batak on a table.
///
/// The one runtime where the seat on turn and the seat deciding can differ:
/// see [controllerOf]. Everything else is forwarded to the engine as usual.
@immutable
final class PartnershipBatakRuntime extends MatchRuntime {
  const PartnershipBatakRuntime(this.state);

  static const PartnershipBatakEngine _engine = PartnershipBatakEngine();

  final PartnershipBatakMatchState state;

  @override
  RuleProfile get profile => state.profile;

  @override
  TrickPlayState? get hand => state.hand;

  @override
  MatchStep get step {
    if (state.isOver) {
      return MatchStep.finished;
    }
    if (state.isAuctioning) {
      return MatchStep.bidding;
    }
    return state.isChoosingTrump ? MatchStep.choosingTrump : MatchStep.playing;
  }

  @override
  int? get seatToAct => state.seatToAct;

  @override
  int controllerOf(int seat) => state.controllerOf(seat);

  @override
  int? get dummySeat => state.dummySeat;

  @override
  bool get isDummyRevealed => state.isDummyRevealed;

  @override
  List<PlayingCard> get dummyHand => state.dummyHand;

  @override
  Set<int> visibleHandsFor(int decider) => state.visibleHandsFor(decider);

  @override
  Set<int> get publicOpenHands => state.publicOpenHands;

  @override
  SeatingPlan get seating => state.seating;

  /// Per seat, each partner carrying its side's total: see
  /// `PartnershipBatakMatchState.seatTotals`.
  @override
  List<int> get totals => state.seatTotals;

  @override
  List<int> get teamTotals => state.teamTotals;

  @override
  List<HandScore> get history => state.history;

  @override
  int get seatCount => state.seatCount;

  @override
  int get handIndex => state.handIndex;

  @override
  int get handsPlayed => state.handsPlayed;

  @override
  bool get isOver => state.isOver;

  @override
  List<int> get leadingSeats => state.winningSeats;

  @override
  MatchContext get aiContext => state.aiContext;

  @override
  List<int?> get declarations => <int?>[
        for (int seat = 0; seat < seatCount; seat++)
          seat == state.declarerSeat ? state.contractBid : null,
      ];

  @override
  Suit? get trump => state.trump;

  @override
  int? get declarerSeat => state.declarerSeat;

  @override
  int? get contractBid => state.contractBid;

  @override
  bool get contractWasForced => state.contractWasForced;

  @override
  List<AuctionCall> get auctionCalls =>
      state.auction?.calls ?? const <AuctionCall>[];

  @override
  int? get standingBid => state.auction?.standingBid;

  @override
  int? get standingBidder => state.auction?.standingBidder;

  @override
  List<int> legalBids(int seat) => _engine.legalBids(state, seat);

  @override
  List<Suit> get legalTrumps => _engine.legalTrumps(state);

  @override
  List<PlayingCard> legalCards(int seat) => _engine.legalCards(state, seat);

  @override
  MatchRuntimeOutcome apply(GameCommand command) =>
      switch (_engine.apply(state, command)) {
        CommandAccepted<PartnershipBatakMatchState>(
          state: final PartnershipBatakMatchState next
        ) =>
          MatchRuntimeOutcome.accepted(PartnershipBatakRuntime(next)),
        CommandRejected<PartnershipBatakMatchState>(
          violation: final RuleViolation violation
        ) =>
          MatchRuntimeOutcome.rejected(violation.code),
      };
}
