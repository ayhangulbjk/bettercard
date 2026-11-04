import 'package:meta/meta.dart';

import '../../core/ai/match_context.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/auction/auction_state.dart';
import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/partnership_rules.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/scoring_rules.dart';
import '../spades_batak/spades_batak_scorer.dart' show HandScore;

/// Where a hand of Esli Ihaleli Batak has got to.
///
/// A hand runs through four phases and the phase is **derived**, never
/// stored: the auction is unfinished; it is finished and no trump has been
/// named; the trump is named, which is also the moment the open hand becomes
/// visible; or the cards are being played. Deriving it is what makes a flag
/// disagreeing with the data impossible, and it is what guarantees the one
/// rule most easily got wrong -- that the open hand stays hidden through the
/// deal, the auction and the trump choice -- because "revealed" and "a trump
/// exists" are the same fact rather than two that have to be kept in step.
///
/// ### Card ownership and who decides
///
/// Three things that a solo mode can treat as one are kept apart here:
///
/// * [TrickPlayState.turnSeat] -- the seat whose **turn** it is, which is
///   also the seat the card is played **from** and credited to;
/// * [controllerOf] -- the seat that **chooses** that card, which for the
///   open hand is the declarer;
/// * [visibleHandsFor] -- the hands whoever is choosing may legally read.
///
/// Cards never move between hands. When the declarer plays for its partner,
/// the card leaves the partner's hand, the trick records the partner's seat,
/// and a trick the partner wins is led next by the partner's seat. All the
/// declarer supplies is the decision.
@immutable
final class PartnershipBatakMatchState {
  PartnershipBatakMatchState({
    required this.profile,
    required this.baseSeed,
    required this.handIndex,
    required this.auction,
    required this.hand,
    required List<int> teamTotals,
    required List<HandScore> history,
    this.trump,
    this.instantWinnerTeam,
  })  : teamTotals = List<int>.unmodifiable(teamTotals),
        history = List<HandScore>.unmodifiable(history);

  final RuleProfile profile;

  /// Seed the match was dealt from; hand `i` forks from `baseSeed + i`.
  final int baseSeed;

  /// Which hand of the match is in play. Also the dealer rotation counter.
  final int handIndex;

  /// The auction for the hand in play, finished or not. Null once the match
  /// is over, like [hand].
  final AuctionState? auction;

  /// The cards. Present from the deal, because a seat has to see its hand
  /// before it can bid on it.
  final TrickPlayState? hand;

  /// The trump the contract winner named, or null before it has.
  ///
  /// Also the gate on the open hand: it is named first and the partner's
  /// cards go face up afterwards, never the other way round, so the declarer
  /// cannot choose a trump knowing what is opposite it.
  final Suit? trump;

  /// Cumulative points, indexed by team id. Two entries.
  final List<int> teamTotals;

  final List<HandScore> history;

  /// A team that won the match outright on a KING or a sweep, whatever the
  /// totals say. Null in the ordinary case.
  final int? instantWinnerTeam;

  int get seatCount => profile.playerCount;

  /// The two partnerships: 0+2 against 1+3, partners facing each other.
  ///
  /// Read from the live hand when there is one so the seating a hand is being
  /// played under and the seating this state reports can never differ.
  SeatingPlan get seating => hand?.seating ?? SeatingPlan.partnership4();

  PartnershipRules get partnershipRules => profile.partnershipRules;

  /// The seat that dealt this hand. Deal rotates every hand, so no seat keeps
  /// the positional advantage of opening the auction.
  int get dealerSeat => handIndex % seatCount;

  /// The dealer's right-hand neighbour, who speaks first.
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

  /// The declaring side's team id, or null before the auction settles.
  int? get declarerTeam {
    final int? declarer = declarerSeat;
    return declarer == null ? null : seating.teamOf(declarer);
  }

  /// The defending side's team id, or null before the auction settles.
  int? get defendingTeam {
    final int? team = declarerTeam;
    return team == null ? null : 1 - team;
  }

  /// The declarer's partner: the open hand in acik esli.
  ///
  /// Not null merely because the mode is closed -- the partner exists either
  /// way, and whether its cards are shown is [isDummyRevealed].
  int? get dummySeat {
    final int? declarer = declarerSeat;
    return declarer == null ? null : seating.partnerOf(declarer);
  }

  /// Whether the open hand's cards are face up.
  ///
  /// True exactly when the table plays acik esli and a trump has been named.
  /// Through the deal, the auction and the trump choice this is false, which
  /// is the fairness rule stated as a single expression.
  bool get isDummyRevealed =>
      partnershipRules.revealsDummy && trump != null && hand != null;

  /// The open hand's cards, or empty while they are not open.
  ///
  /// The only way the dummy's cards leave this state, and it answers with
  /// nothing until the reveal, so a caller cannot read them early even by
  /// mistake.
  List<PlayingCard> get dummyHand {
    final int? dummy = dummySeat;
    if (!isDummyRevealed || dummy == null) {
      return const <PlayingCard>[];
    }
    return hand!.handOf(dummy);
  }

  /// The seat waiting on a decision, or null when the match is over.
  ///
  /// Always the seat the card comes **from**, which during the open hand's
  /// turn is the open hand itself. [controllerOf] says who chooses it.
  int? get seatToAct {
    if (isAuctioning) {
      return auction!.seatToAct;
    }
    if (isChoosingTrump) {
      return declarerSeat;
    }
    return hand?.turnSeat;
  }

  /// The seat that chooses for [seat].
  ///
  /// Itself, except for a revealed open hand, which the declarer plays. The
  /// player-facing override in [PartnershipRules.humanDummyControlOverride]
  /// is deliberately not applied here: this layer does not know which seat
  /// the person at the device is sitting in, and the engine's validation is
  /// the same either way, so the session applies it.
  int controllerOf(int seat) {
    if (!isDummyRevealed) {
      return seat;
    }
    return seat == dummySeat ? declarerSeat! : seat;
  }

  /// The seat that chooses the next card, or null when the match is over.
  int? get controllerToAct {
    final int? seat = seatToAct;
    return seat == null ? null : controllerOf(seat);
  }

  /// The hands [decider] may legally read while choosing.
  ///
  /// Its own, always. The open hand as well, once it is face up -- for every
  /// seat, defenders included, because that is what face up means. Nothing
  /// else, ever: in the closed mode this is a seat's own hand and no more,
  /// and the two defenders never see each other's cards in either mode.
  Set<int> visibleHandsFor(int decider) => <int>{
        decider,
        ...publicOpenHands,
      };

  /// The hands that are face up to **everybody**.
  ///
  /// The open hand, once it is open, and nothing else. Separate from
  /// [visibleHandsFor] because a declarer reading its own cards while playing
  /// for its partner is not the same thing as a card lying face up on the
  /// table, and a search that confuses the two would hand the declarer's hand
  /// to the defenders.
  Set<int> get publicOpenHands =>
      isDummyRevealed ? <int>{dummySeat!} : const <int>{};

  /// Tricks taken in this hand, indexed by team id.
  List<int> get teamTricks {
    final List<int> byTeam = List<int>.filled(2, 0);
    final TrickPlayState? cards = hand;
    if (cards == null) {
      return List<int>.unmodifiable(byTeam);
    }
    final List<int> bySeat = cards.tricksWon;
    for (int seat = 0; seat < bySeat.length; seat++) {
      byTeam[seating.teamOf(seat)] += bySeat[seat];
    }
    return List<int>.unmodifiable(byTeam);
  }

  /// Hand number as a player counts them, from one.
  int get displayHandNumber => handIndex + 1;

  int get handsPlayed => history.length;

  /// Whether the match has finished.
  bool get isOver => hand == null && auction == null;

  /// Cumulative points per *seat*, both partners carrying their side's total.
  ///
  /// The scoreboard, the score sheet and the match-over panel are all written
  /// against a per-seat list, and in a team game the honest per-seat answer
  /// is the team's number: that is what each of the two players has scored.
  List<int> get seatTotals => List<int>.unmodifiable(<int>[
        for (int seat = 0; seat < seatCount; seat++)
          teamTotals[seating.teamOf(seat)],
      ]);

  /// Whether the match has reached its end condition.
  ///
  /// A match to a target needs a *single* side at or past it: two sides level
  /// on the target play another hand, which is the rule Turkish tables use
  /// and the reason the hand count is also checked. That count is not the
  /// match length here but the backstop on an endless tie.
  bool get hasReachedEnd {
    if (instantWinnerTeam != null) {
      return true;
    }
    return switch (profile.scoringRules.endCondition) {
      MatchEndCondition.fixedRounds =>
        history.length >= profile.scoringRules.roundCount,
      MatchEndCondition.targetScore =>
        (teamTotals.any((int t) => t >= profile.scoringRules.targetScore) &&
                winningTeams.length == 1) ||
            history.length >= profile.scoringRules.roundCount,
    };
  }

  /// Teams tied for the lead, or the outright winner of a KING.
  List<int> get winningTeams {
    final int? instant = instantWinnerTeam;
    if (instant != null) {
      return <int>[instant];
    }
    final int best = teamTotals.reduce((int a, int b) => a > b ? a : b);
    return <int>[
      for (int team = 0; team < teamTotals.length; team++)
        if (teamTotals[team] == best) team,
    ];
  }

  /// Seats belonging to the winning side.
  List<int> get winningSeats => <int>[
        for (int seat = 0; seat < seatCount; seat++)
          if (winningTeams.contains(seating.teamOf(seat))) seat,
      ];

  /// What a seat may legally know beyond the cards.
  ///
  /// The contract, who holds it, which side that puts it on, the payoff in
  /// force and the scoreboard are all on the table in front of the players.
  /// The hidden hands are not here and cannot be: this builds from public
  /// fields only. The open hand travels separately, through
  /// [visibleHandsFor], so that the one piece of another seat's hand a policy
  /// may read has one gate rather than two.
  MatchContext get aiContext => MatchContext(
        declarationRules: profile.declarationRules,
        declarations: <int?>[
          for (int seat = 0; seat < seatCount; seat++)
            seat == declarerSeat ? contractBid : null,
        ],
        totalScores: seatTotals,
        partnershipScoringRules: profile.partnershipScoringRules,
        auction: auction,
        teamOfSeat: seating.teamOfSeat,
        declarerSeat: declarerSeat,
        contractBid: contractBid,
      );

  PartnershipBatakMatchState copyWith({
    int? handIndex,
    AuctionState? auction,
    TrickPlayState? hand,
    Suit? trump,
    List<int>? teamTotals,
    List<HandScore>? history,
    int? instantWinnerTeam,
    bool clearHand = false,
    bool clearAuction = false,
    bool clearTrump = false,
  }) =>
      PartnershipBatakMatchState(
        profile: profile,
        baseSeed: baseSeed,
        handIndex: handIndex ?? this.handIndex,
        auction: clearAuction ? null : (auction ?? this.auction),
        hand: clearHand ? null : (hand ?? this.hand),
        trump: clearTrump ? null : (trump ?? this.trump),
        teamTotals: teamTotals ?? this.teamTotals,
        history: history ?? this.history,
        instantWinnerTeam: instantWinnerTeam ?? this.instantWinnerTeam,
      );

  /// Checks the things that must be true of any reachable state.
  ///
  /// These are invariants, not player input, so a breach throws: it means the
  /// engine built a position that cannot exist.
  void checkInvariants() {
    if (teamTotals.length != 2) {
      throw StateError(
        'A partnership match has two teams, not ${teamTotals.length}',
      );
    }
    if (!profile.partnershipScoringRules.enabled) {
      throw StateError(
        'Profile ${profile.id} plays a team contract but has no team scoring',
      );
    }
    if (profile.declarationRules.enabled ||
        profile.auctionScoringRules.enabled) {
      throw StateError(
        'Profile ${profile.id} would pay the same hand twice',
      );
    }
    if (seating.teamCount != 2) {
      throw StateError('Seating $seating is not two partnerships');
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
    // The open hand must not be readable before its moment. Asserted rather
    // than assumed, because it is the one rule of this mode that no amount of
    // correct play would reveal as broken.
    if (dummyHand.isNotEmpty && trump == null) {
      throw StateError('The open hand is readable before a trump was named');
    }
    if (partnershipRules.mode == PartnershipMode.closedPartnership &&
        dummyHand.isNotEmpty) {
      throw StateError('A closed partnership revealed a hand');
    }
    final int? declarer = declarerSeat;
    if (declarer != null && dummySeat == declarer) {
      throw StateError('The declarer was made its own partner');
    }
    for (final HandScore score in history) {
      if (score.seatCount != seatCount) {
        throw StateError('A stored hand score has ${score.seatCount} seats');
      }
    }
  }

  @override
  String toString() => 'PartnershipBatakMatchState(hand: $displayHandNumber, '
      'declarer: $declarerSeat, bid: $contractBid, trump: $trump, '
      'dummy: ${isDummyRevealed ? dummySeat : 'hidden'}, '
      'totals: $teamTotals)';
}
