import 'package:meta/meta.dart';

import '../../core/ai/match_context.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/auction/auction_state.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/scoring_rules.dart';
import '../spades_batak/spades_batak_scorer.dart' show HandScore;

/// Where a hand of Herkes Tek Ihaleli Batak has got to.
///
/// A hand runs through three phases and the phase is **derived**, never
/// stored: the auction is unfinished, or it is finished and no trump has been
/// named, or the cards are being played. Deriving it is what makes a flag
/// disagreeing with the data impossible.
@immutable
final class AuctionBatakMatchState {
  AuctionBatakMatchState({
    required this.profile,
    required this.baseSeed,
    required this.handIndex,
    required this.auction,
    required this.hand,
    required List<int> totals,
    required List<HandScore> history,
    this.trump,
  })  : totals = List<int>.unmodifiable(totals),
        history = List<HandScore>.unmodifiable(history);

  final RuleProfile profile;

  /// Seed the match was dealt from; hand `i` forks from `baseSeed + i`.
  final int baseSeed;

  /// Which hand of the match is in play. Also the dealer rotation counter.
  final int handIndex;

  /// The auction for the hand in play, finished or not.
  ///
  /// Null once the match is over, like [hand].
  final AuctionState? auction;

  /// The cards. Present from the deal, because a seat has to see its hand
  /// before it can bid on it.
  final TrickPlayState? hand;

  /// The trump the contract winner named, or null before it has.
  final Suit? trump;

  final List<int> totals;
  final List<HandScore> history;

  int get seatCount => profile.playerCount;

  /// The seat that dealt this hand. Deal rotates every hand, so no seat keeps
  /// the positional advantage of opening the auction.
  int get dealerSeat => handIndex % seatCount;

  /// The dealer's right-hand neighbour, who speaks first.
  ///
  /// Play runs anticlockwise, so the seat to the dealer's right is the next
  /// one in seat order. Turn order lives here and in [AuctionState] alone;
  /// the screen's idea of who sits where is presentation and never feeds back
  /// into it.
  int get openingSeat => (dealerSeat + 1) % seatCount;

  bool get isAuctioning => auction != null && !auction!.isComplete;

  /// Whether the contract is won and waiting for a trump to be named.
  bool get isChoosingTrump =>
      auction != null &&
      auction!.isComplete &&
      !auction!.needsRedeal &&
      trump == null &&
      profile.biddingRules.declarerNamesTrump;

  /// Whether cards may be played.
  bool get isPlaying =>
      hand != null && !isAuctioning && !isChoosingTrump && !isOver;

  /// Whether the auction passed out at a table that redeals.
  bool get needsRedeal => auction?.needsRedeal ?? false;

  int? get declarerSeat => auction?.winner;

  int? get contractBid => auction?.winningBid;

  bool get contractWasForced => auction?.wasForced ?? false;

  /// The seat waiting on a decision, or null when the match is over.
  int? get seatToAct {
    if (isAuctioning) {
      return auction!.seatToAct;
    }
    if (isChoosingTrump) {
      return declarerSeat;
    }
    return hand?.turnSeat;
  }

  /// Hand number as a player counts them, from one.
  int get displayHandNumber => handIndex + 1;

  /// Whether the match has finished.
  bool get isOver => hand == null && auction == null;

  bool get hasReachedEnd => switch (profile.scoringRules.endCondition) {
        MatchEndCondition.fixedRounds =>
          history.length >= profile.scoringRules.roundCount,
        MatchEndCondition.targetScore =>
          totals.any((int total) => total >= profile.scoringRules.targetScore),
      };

  int get bestTotal => totals.reduce((int a, int b) => a > b ? a : b);

  List<int> get winners {
    final int best = bestTotal;
    return <int>[
      for (int seat = 0; seat < totals.length; seat++)
        if (totals[seat] == best) seat,
    ];
  }

  /// What a seat may legally know beyond the cards.
  ///
  /// The contract, the scoreboard and the payoff in force are all on the
  /// table in front of the players, so a policy may read them. The hidden
  /// hands are not here and cannot be: this builds from public fields only.
  MatchContext get aiContext => MatchContext(
        declarationRules: profile.declarationRules,
        // Only the declarer promised anything. A defender's entry stays null,
        // which is exactly what the card policies read it as: no word to
        // keep, so every trick simply pays.
        declarations: <int?>[
          for (int seat = 0; seat < seatCount; seat++)
            seat == declarerSeat ? contractBid : null,
        ],
        totalScores: totals,
        auctionScoringRules: profile.auctionScoringRules,
        auction: auction,
        declarerSeat: declarerSeat,
        contractBid: contractBid,
      );

  AuctionBatakMatchState copyWith({
    int? handIndex,
    AuctionState? auction,
    TrickPlayState? hand,
    Suit? trump,
    List<int>? totals,
    List<HandScore>? history,
    bool clearHand = false,
    bool clearAuction = false,
    bool clearTrump = false,
  }) =>
      AuctionBatakMatchState(
        profile: profile,
        baseSeed: baseSeed,
        handIndex: handIndex ?? this.handIndex,
        auction: clearAuction ? null : (auction ?? this.auction),
        hand: clearHand ? null : (hand ?? this.hand),
        trump: clearTrump ? null : (trump ?? this.trump),
        totals: totals ?? this.totals,
        history: history ?? this.history,
      );

  /// Checks the things that must be true of any reachable state.
  ///
  /// These are invariants, not player input, so a breach throws: it means the
  /// engine built a position that cannot exist.
  void checkInvariants() {
    if (totals.length != seatCount) {
      throw StateError(
        'Totals hold ${totals.length} seats but the profile says $seatCount',
      );
    }
    if (!profile.auctionScoringRules.enabled) {
      throw StateError(
        'Profile ${profile.id} plays a contract but has no auction scoring',
      );
    }
    if (profile.declarationRules.enabled) {
      throw StateError(
        'Profile ${profile.id} has both a contract and a declaration round',
      );
    }
    final AuctionState? live = auction;
    if (live != null && live.isComplete && !live.needsRedeal) {
      if (live.winner == null || live.winningBid == null) {
        throw StateError('A finished auction produced no contract: $live');
      }
    }
    final TrickPlayState? cards = hand;
    if (cards != null && trump != null && cards.trump != trump) {
      throw StateError(
        'The hand is being played in ${cards.trump} but the contract named '
        '$trump',
      );
    }
    for (final HandScore score in history) {
      if (score.seatCount != seatCount) {
        throw StateError('A stored hand score has ${score.seatCount} seats');
      }
    }
  }

  @override
  String toString() => 'AuctionBatakMatchState(hand: $displayHandNumber, '
      'declarer: $declarerSeat, bid: $contractBid, trump: $trump, '
      'totals: $totals)';
}
