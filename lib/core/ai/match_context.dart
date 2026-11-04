import 'package:meta/meta.dart';

import '../game_engine/auction/auction_state.dart';
import '../rules/auction_scoring_rules.dart';
import '../rules/declaration_rules.dart';
import '../rules/partnership_scoring_rules.dart';

/// The match-level facts a seat may legally know, beyond the cards.
///
/// A trick-play state knows how the cards are going; it does not know what
/// anybody promised or what the scoreboard says. Both are public at a real
/// table -- declarations are spoken aloud and the score sheet is on the table
/// -- and both change what a competent player does with a card, so a policy
/// that cannot see them cannot play the game it is in.
///
/// This is deliberately a separate object rather than more fields on the
/// trick state: the trick engine is shared by five games and has no business
/// knowing about declarations, while the match state that does know is
/// game-specific. Joining the two happens once, where the observation is
/// built.
///
/// Everything here is public information. Nothing in it narrows down a hidden
/// hand except by the inference any player at the table could make.
@immutable
class MatchContext {
  MatchContext({
    required this.declarationRules,
    required List<int?> declarations,
    required List<int> totalScores,
    this.auctionScoringRules = AuctionScoringRules.none,
    this.partnershipScoringRules = PartnershipScoringRules.none,
    List<int> teamOfSeat = const <int>[],
    this.auction,
    this.declarerSeat,
    this.contractBid,
  })  : declarations = List<int?>.unmodifiable(declarations),
        totalScores = List<int>.unmodifiable(totalScores),
        teamOfSeat = List<int>.unmodifiable(teamOfSeat);

  /// A mode with no declaration round and no score to read yet.
  static final MatchContext none = MatchContext(
    declarationRules: DeclarationRules.none,
    declarations: const <int?>[],
    totalScores: const <int>[],
  );

  /// The payoff in force for this hand, frozen with the match's profile.
  ///
  /// Carried rather than assumed because it is what makes a trick good or
  /// bad: the same extra trick is worth +1 at one table and -50 at another.
  final DeclarationRules declarationRules;

  /// What each seat has declared so far, null where a seat has not spoken.
  ///
  /// Nulls are information too, and honest ones: a seat that declares before
  /// the others genuinely does not know their numbers.
  final List<int?> declarations;

  /// Running match totals per seat, as shown on the scoreboard.
  final List<int> totalScores;

  /// The payoff for a single-contract hand, when the mode plays one.
  ///
  /// A mode has this or [declarationRules], never both: four independent
  /// promises and one contract are different games, and a policy that read
  /// the wrong one would be optimising a payoff nobody is being paid.
  final AuctionScoringRules auctionScoringRules;

  /// The payoff for a two-team contract hand, when the mode plays one.
  ///
  /// At most one of the three payoffs is enabled; the rule validator refuses
  /// a profile with more, so a policy never has to decide which to believe.
  final PartnershipScoringRules partnershipScoringRules;

  /// Team id per seat, empty in a mode where every seat plays for itself.
  ///
  /// Needed because a team payoff is a function of the *side's* tricks, not
  /// of one seat's, so the mapping has to travel with the payoff.
  final List<int> teamOfSeat;

  /// The auction as it stands, or null in a mode without one.
  ///
  /// Entirely public: every call is spoken aloud at the table, and who has
  /// passed is the thing a player most needs to remember. A bidding policy
  /// reads the standing bid, who holds it and who is out of it from here
  /// rather than inferring them from its own legal options, which is both
  /// more honest and the only way to tell an opponent's bid from a partner's.
  final AuctionState? auction;

  /// Who won the contract, or null in a mode with no auction or before one
  /// is settled. Public: the auction is spoken aloud.
  final int? declarerSeat;

  /// What the contract is for, or null when there is none yet.
  final int? contractBid;

  /// Whether this hand is one contract against the rest of the table.
  bool get hasContract =>
      auctionScoringRules.enabled &&
      declarerSeat != null &&
      contractBid != null;

  /// Whether this hand is one contract between two teams.
  bool get hasTeamContract =>
      partnershipScoringRules.enabled &&
      teamOfSeat.isNotEmpty &&
      declarerSeat != null &&
      contractBid != null;

  /// Team id of [seat], or the seat itself when there are no teams.
  int teamOf(int seat) => seat < teamOfSeat.length ? teamOfSeat[seat] : seat;

  /// The declaring side's team id, or null when there is no team contract.
  int? get declarerTeam => hasTeamContract ? teamOf(declarerSeat!) : null;

  /// Whether the seats are grouped into teams at all.
  bool get hasTeams => teamOfSeat.isNotEmpty;

  /// Tricks per team, from a per-seat trick count.
  List<int> teamTricks(List<int> tricksBySeat) {
    final List<int> byTeam = List<int>.filled(2, 0);
    for (int seat = 0; seat < tricksBySeat.length; seat++) {
      byTeam[teamOf(seat)] += tricksBySeat[seat];
    }
    return List<int>.unmodifiable(byTeam);
  }

  /// Whether [seat] is defending the contract.
  ///
  /// False in a mode with no contract, where nobody is defending anything.
  bool isDefender(int seat) => hasContract && seat != declarerSeat;

  /// What [seat] would score on [tricksTaken], under whichever payoff this
  /// hand is actually using, or null when neither applies.
  ///
  /// The one place that chooses between the two scorers, so no policy has to
  /// remember which mode it is in.
  int? pointsFor({required int seat, required int tricksTaken}) {
    if (hasContract) {
      return auctionScoringRules.scoreFor(
        seat: seat,
        declarerSeat: declarerSeat!,
        bid: contractBid!,
        tricksTaken: tricksTaken,
      );
    }
    final int? declared = declarationOf(seat);
    if (declared == null || !declarationRules.enabled) {
      return null;
    }
    return declarationRules.scoreFor(
      declaration: declared,
      tricksTaken: tricksTaken,
    );
  }

  /// What [seat] scores if the hand ends with the seats on [tricksBySeat].
  ///
  /// The general form of [pointsFor], and the one a search should ask: a team
  /// payoff depends on the *side's* tricks, which a single-seat count cannot
  /// express. Null when the hand has no payoff beyond the tricks themselves.
  ///
  /// [tricksPerHand] is the length of the whole deal, not of what has been
  /// played. It matters because taking every trick pays a special figure, and
  /// a side three tricks into a thirteen-trick hand has not done that.
  ///
  /// The one place that chooses between the three scorers, so no policy has
  /// to remember which mode it is in.
  int? handPointsFor({
    required int seat,
    required List<int> tricksBySeat,
    required int tricksPerHand,
  }) {
    if (hasTeamContract) {
      return partnershipScoringRules
          .project(
            contractBid: contractBid!,
            declarerTeam: teamOf(declarerSeat!),
            teamTricks: teamTricks(tricksBySeat),
            tricksPerHand: tricksPerHand,
          )
          .teamPoints[teamOf(seat)];
    }
    return pointsFor(seat: seat, tricksTaken: tricksBySeat[seat]);
  }

  /// Whether this hand has a declaration round at all.
  bool get hasDeclarations => declarationRules.enabled;

  /// What [seat] declared, or null if it has not spoken or does not declare.
  int? declarationOf(int seat) =>
      seat < declarations.length ? declarations[seat] : null;

  /// The match total for [seat], or 0 before any hand has scored.
  int scoreOf(int seat) => seat < totalScores.length ? totalScores[seat] : 0;

  /// The highest contract offered so far, or null when nobody has bid.
  int? get standingBid => auction?.standingBid;

  /// The seat holding the standing bid, or null when nobody has bid.
  int? get standingBidder => auction?.standingBidder;

  /// Whether the standing bid belongs to [seat]'s own side.
  ///
  /// False with no bid on the table, and false in a mode without teams,
  /// where a seat has no side to share a bid with.
  /// Whether a pass by the seat on turn would end a silent auction.
  bool get passWouldForceContract => auction?.passWouldForceContract ?? false;

  /// The seat a pass-out would force the contract on, or null.
  int? get seatIfPassedOut => auction?.seatIfPassedOut;

  /// The contract a pass-out would force.
  int? get forcedBid => auction?.rules.effectiveForcedBid;

  bool standingBidIsOurs(int seat) {
    final int? bidder = standingBidder;
    return bidder != null && hasTeams && teamOf(bidder) == teamOf(seat);
  }

  @override
  String toString() => 'MatchContext(declarations: $declarations, '
      'totals: $totalScores, declarer: $declarerSeat, bid: $contractBid)';
}
