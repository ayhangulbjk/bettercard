import 'package:meta/meta.dart';

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

  /// Whether this hand has a declaration round at all.
  bool get hasDeclarations => declarationRules.enabled;

  /// What [seat] declared, or null if it has not spoken or does not declare.
  int? declarationOf(int seat) =>
      seat < declarations.length ? declarations[seat] : null;

  /// The match total for [seat], or 0 before any hand has scored.
  int scoreOf(int seat) => seat < totalScores.length ? totalScores[seat] : 0;

  @override
  String toString() => 'MatchContext(declarations: $declarations, '
      'totals: $totalScores)';
}
