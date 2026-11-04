import 'package:meta/meta.dart';

import '../../core/ai/ai_difficulty.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/auction/auction_state.dart';
import '../../core/game_engine/trick/trick.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_violation.dart';
import '../../games/spades_batak/spades_batak_scorer.dart';
import 'match_runtime.dart';
import 'match_turn.dart';

/// What the table is doing right now.
///
/// This is a presentation concern, not a rule: the domain knows only whose
/// turn it is. The phases exist because a finished trick has to stay on the
/// table long enough to be read, and a finished hand has to be acknowledged
/// before the next one starts.
enum MatchPhase {
  /// The player must bid or pass in an open auction.
  awaitingBid,

  /// An opponent is deciding what to bid.
  opponentBidding,

  /// The player won the contract and must name a trump.
  awaitingTrump,

  /// An opponent won the contract and is choosing a trump.
  opponentChoosingTrump,

  /// The player must say how many tricks they will take.
  awaitingDeclaration,

  /// An opponent is deciding what to declare.
  opponentDeclaring,

  /// The player must choose a card.
  awaitingHuman,

  /// An opponent is deciding.
  opponentThinking,

  /// A trick just completed and is lying face up, still, so it can be read.
  trickPause,

  /// The same trick, now travelling to the seat that took it.
  ///
  /// A separate phase from [trickPause] because the two beats have different
  /// lengths and different meanings: one is a hold, the other an animation
  /// whose duration the player's speed setting controls.
  trickGather,

  /// A hand just finished; its score sheet is up.
  handSummary,

  /// The match reached its end condition.
  matchOver,
}

/// The live table: a match snapshot plus everything the screen needs that the
/// domain deliberately does not carry.
///
/// Immutable, like the domain snapshots it wraps. [copyWith] takes explicit
/// clear flags for the nullable fields rather than relying on null-coalescing,
/// which cannot express "set this back to null"; see docs/DECISIONS.md D-15.
@immutable
final class MatchSession {
  const MatchSession({
    required this.matchId,
    required this.dealSeed,
    required this.match,
    required this.phase,
    required this.humanSeat,
    required this.difficulty,
    this.lastTrick,
    this.lastHandScore,
    this.rejection,
  });

  /// Identifies this match in the save file and in the history.
  final String matchId;

  /// The seed the match was dealt from. Kept here so a save can be written
  /// without asking the engine to hand back what it started with.
  final int dealSeed;

  /// Authoritative match state, whichever game is on the table.
  final MatchRuntime match;

  final MatchPhase phase;

  /// The seat the person at the device plays.
  final int humanSeat;

  /// Difficulty the opponents were created with. Frozen for the match, like
  /// the rule profile: swapping opponents mid-hand would change the game
  /// underneath the player.
  final AiDifficulty difficulty;

  /// The trick that just completed, kept so the table can show it after the
  /// engine has already moved on.
  final CompletedTrick? lastTrick;

  /// Score of the hand that just finished, or null while a hand is running.
  final HandScore? lastHandScore;

  /// Why the engine refused the last command, if it did. The screen maps the
  /// code to Turkish; the domain never carries presentation text.
  ///
  /// It should stay null in normal play: the table only offers legal cards.
  /// Surfacing it rather than swallowing it means a disagreement between the
  /// UI and the engine becomes visible instead of silent.
  final RuleViolationCode? rejection;

  RuleProfile get profile => match.profile;

  /// Card play for the current hand, or null once the match is over.
  TrickPlayState? get hand => match.hand;

  bool get isHumanTurn => phase == MatchPhase.awaitingHuman;

  /// The seat the next card is played **from**, or null when no card is due.
  ///
  /// Not the same as who chooses it: in acik esli Batak the declarer chooses
  /// for its partner's open hand, and the card still comes from the partner.
  int? get seatToPlay => isPlayingCards ? match.seatToAct : null;

  /// The seat that chooses for [seat].
  int deciderFor(int seat) => MatchTurn.deciderFor(match, humanSeat, seat);

  /// Whether the player is choosing from their own hand right now.
  bool get isPlayingOwnHand => isHumanTurn && seatToPlay == humanSeat;

  /// Whether the player is choosing from the open hand opposite right now.
  bool get isPlayingDummyHand =>
      isHumanTurn && dummySeat != null && seatToPlay == dummySeat;

  /// The declarer's partner, whose hand is the open one. Null outside a
  /// partnership contract.
  int? get dummySeat => match.dummySeat;

  /// Whether the open hand's cards are face up.
  bool get isDummyRevealed => match.isDummyRevealed;

  /// The open hand's cards, empty until they are face up.
  List<PlayingCard> get dummyHand => match.dummyHand;

  /// Whether it is the player's own hand that is lying face up.
  ///
  /// The deal that needs explaining: a bot won the contract, the player is
  /// its partner, and the bot is playing the player's cards. The table says
  /// so rather than leaving a hand that will not respond to a tap.
  bool get humanIsDummy => isDummyRevealed && dummySeat == humanSeat;

  /// Whether the player holds the contract and therefore plays both hands.
  bool get humanIsDeclarer => match.declarerSeat == humanSeat;

  /// Whether this mode scores two sides rather than four seats.
  bool get hasTeams => profile.partnershipRules.enabled;

  /// Cumulative points per side; equal to [totals] where every seat is its
  /// own side.
  List<int> get teamTotals => match.teamTotals;

  /// The side [seat] plays for.
  int teamOf(int seat) => match.seating.teamOf(seat);

  /// The player's own side.
  int get humanTeam => teamOf(humanSeat);

  /// The side holding the contract, or null before the auction settles.
  int? get declarerTeam {
    final int? declarer = declarerSeat;
    return declarer == null ? null : teamOf(declarer);
  }

  /// Whether the table is waiting for the player's declaration.
  bool get isAwaitingDeclaration => phase == MatchPhase.awaitingDeclaration;

  /// Whether the hand is still in its declaration round.
  bool get isDeclaring =>
      phase == MatchPhase.awaitingDeclaration ||
      phase == MatchPhase.opponentDeclaring;

  /// Whether the table is waiting for the player to bid or pass.
  bool get isAwaitingBid => phase == MatchPhase.awaitingBid;

  /// Whether an auction is running, whoever is speaking.
  bool get isBidding =>
      phase == MatchPhase.awaitingBid || phase == MatchPhase.opponentBidding;

  /// Whether the table is waiting for the player to name a trump.
  bool get isAwaitingTrump => phase == MatchPhase.awaitingTrump;

  /// Whether a contract is waiting for a trump, whoever holds it.
  bool get isChoosingTrump =>
      phase == MatchPhase.awaitingTrump ||
      phase == MatchPhase.opponentChoosingTrump;

  /// Whether the player should be looking at the table rather than a panel.
  bool get isPlayingCards =>
      !isBidding && !isChoosingTrump && !isDeclaring && !isOver;

  /// The calls made in the auction so far, oldest first.
  List<AuctionCall> get auctionCalls => match.auctionCalls;

  /// The highest contract offered so far, or null.
  int? get standingBid => match.standingBid;

  /// The seat holding the standing bid, or null.
  int? get standingBidder => match.standingBidder;

  /// The contracts the player may offer right now.
  List<int> get legalBids => match.legalBids(humanSeat);

  /// The trumps the player may name right now.
  List<Suit> get legalTrumps => match.legalTrumps;

  /// Who holds the contract for the hand on screen, or null.
  ///
  /// Read from the finished hand's score sheet while that is up, for the same
  /// reason the trick counts are: the engine has already dealt the next hand
  /// underneath.
  int? get declarerSeat {
    if (!isShowingFinishedHand) {
      return match.declarerSeat;
    }
    for (int seat = 0; seat < seatCount; seat++) {
      if (lastHandScore!.declarationOf(seat) != null) {
        return seat;
      }
    }
    return null;
  }

  /// The contract for the hand on screen, or null.
  int? get contractBid => isShowingFinishedHand
      ? (declarerSeat == null
          ? null
          : lastHandScore!.declarationOf(declarerSeat!))
      : match.contractBid;

  /// Whether the contract was forced by a passed-out auction.
  bool get contractWasForced => match.contractWasForced;

  /// The trump in force, or null before one is known.
  Suit? get trump => match.trump;

  /// What each seat has declared for the hand on screen, null where a seat has
  /// not spoken yet.
  ///
  /// Once a hand is scored the table shows the finished hand's numbers, for
  /// the same reason its trick counts come from the score sheet: the engine
  /// has already dealt the next hand underneath.
  List<int?> get declarations =>
      isShowingFinishedHand ? lastHandScore!.declarations : match.declarations;

  bool get isOver => phase == MatchPhase.matchOver;

  /// One-based hand number, for display.
  int get handNumber => match.handIndex + 1;

  /// The player's remaining cards, unsorted. The widget decides the order.
  List<PlayingCard> get humanHand =>
      hand?.handOf(humanSeat) ?? const <PlayingCard>[];

  /// The cards to draw in the middle of the table.
  ///
  /// During [MatchPhase.trickPause] and [MatchPhase.handSummary] that is the
  /// trick that just finished; otherwise it is the trick in progress.
  Trick? get tableTrick {
    if (lastTrick != null &&
        (phase == MatchPhase.trickPause ||
            phase == MatchPhase.trickGather ||
            phase == MatchPhase.handSummary ||
            phase == MatchPhase.matchOver)) {
      return lastTrick!.trick;
    }
    return hand?.currentTrick;
  }

  /// The seat that took [lastTrick], while it is still being shown.
  ///
  /// Set through both beats of a finished trick, so the winner's seat is lit
  /// while the cards are still lying there and stays lit as they arrive.
  int? get highlightedWinner =>
      phase == MatchPhase.trickPause || phase == MatchPhase.trickGather
          ? lastTrick?.winnerSeat
          : null;

  /// Whether the finished trick is travelling to its winner right now.
  bool get isGatheringTrick => phase == MatchPhase.trickGather;

  /// Whether the table is showing a hand that has already been scored.
  ///
  /// The engine deals the next hand as part of accepting the last card of the
  /// previous one, so while the score sheet is up `hand` is already the NEXT
  /// hand: full hands, no tricks taken, trick one. Everything on screen beside
  /// the sheet therefore has to come from the finished hand instead, or the
  /// table would contradict the score sheet sitting next to it.
  bool get isShowingFinishedHand =>
      lastHandScore != null &&
      (phase == MatchPhase.handSummary || phase == MatchPhase.matchOver);

  /// One-based hand number to display.
  int get displayHandNumber =>
      isShowingFinishedHand ? match.handsPlayed : handNumber;

  /// Tricks taken in the hand on screen, indexed by seat.
  List<int> get tricksThisHand => isShowingFinishedHand
      ? lastHandScore!.tricks
      : hand?.tricksWon ?? List<int>.filled(seatCount, 0);

  /// Cards still held, indexed by seat. All zero once the hand is scored.
  List<int> get cardsRemaining => isShowingFinishedHand
      ? List<int>.filled(seatCount, 0)
      : hand?.handSizes ?? List<int>.filled(seatCount, 0);

  int get seatCount => match.seatCount;

  /// Cumulative points, indexed by seat.
  List<int> get totals => match.totals;

  /// Seats tied for the lead at the end of the match.
  List<int> get winners => match.leadingSeats;

  /// Tricks the player has taken across every scored hand of the match.
  /// Tricks the player's side has taken in the hand on screen.
  int get humanTeamTricks {
    int total = 0;
    final List<int> tricks = tricksThisHand;
    for (int seat = 0; seat < tricks.length; seat++) {
      if (teamOf(seat) == humanTeam) {
        total += tricks[seat];
      }
    }
    return total;
  }

  /// Tricks the other side has taken in the hand on screen.
  int get opponentTeamTricks {
    int total = 0;
    final List<int> tricks = tricksThisHand;
    for (int seat = 0; seat < tricks.length; seat++) {
      if (teamOf(seat) != humanTeam) {
        total += tricks[seat];
      }
    }
    return total;
  }

  int get humanTricksTotal {
    int total = 0;
    for (final HandScore score in match.history) {
      total += score.tricksOf(humanSeat);
    }
    return total;
  }

  bool get humanWon => winners.contains(humanSeat);

  /// Tricks left to play in the hand on screen.
  int get tricksLeftThisHand =>
      profile.tricksPerHand -
      (isShowingFinishedHand ? profile.tricksPerHand : hand?.trickNumber ?? 0);

  MatchSession copyWith({
    MatchRuntime? match,
    MatchPhase? phase,
    CompletedTrick? lastTrick,
    bool clearLastTrick = false,
    HandScore? lastHandScore,
    bool clearLastHandScore = false,
    RuleViolationCode? rejection,
    bool clearRejection = false,
  }) =>
      MatchSession(
        matchId: matchId,
        dealSeed: dealSeed,
        match: match ?? this.match,
        phase: phase ?? this.phase,
        humanSeat: humanSeat,
        difficulty: difficulty,
        lastTrick: clearLastTrick ? null : (lastTrick ?? this.lastTrick),
        lastHandScore:
            clearLastHandScore ? null : (lastHandScore ?? this.lastHandScore),
        rejection: clearRejection ? null : (rejection ?? this.rejection),
      );

  @override
  String toString() => 'MatchSession(${phase.name}, hand $handNumber, '
      'totals ${match.totals})';
}
