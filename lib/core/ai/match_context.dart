import 'package:meta/meta.dart';

import '../rules/auction_scoring_rules.dart';
import '../rules/declaration_rules.dart';

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
    this.declarerSeat,
    this.contractBid,
  })  : declarations = List<int?>.unmodifiable(declarations),
        totalScores = List<int>.unmodifiable(totalScores);

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

  /// Whether this hand has a declaration round at all.
  bool get hasDeclarations => declarationRules.enabled;

  /// What [seat] declared, or null if it has not spoken or does not declare.
  int? declarationOf(int seat) =>
      seat < declarations.length ? declarations[seat] : null;

  /// The match total for [seat], or 0 before any hand has scored.
  int scoreOf(int seat) => seat < totalScores.length ? totalScores[seat] : 0;

  @override
  String toString() => 'MatchContext(declarations: $declarations, '
      'totals: $totalScores, declarer: $declarerSeat, bid: $contractBid)';
}
