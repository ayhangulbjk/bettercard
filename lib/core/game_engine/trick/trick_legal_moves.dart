import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../rules/rule_violation.dart';
import '../../rules/trick_rules.dart';
import 'trick.dart';

/// Generates the legal cards a seat may play, and explains refusals.
///
/// This is the single authority on card legality. The engine, the UI's
/// "playable card" highlighting and every AI policy all call it, so they can
/// never disagree about what is allowed. It is pure and allocation-light: no
/// state, no randomness, no clock.
abstract final class TrickLegalMoves {
  /// The subset of [hand] that may legally be played right now.
  ///
  /// [trick] is null (or empty) when the seat is on lead. [trumpBroken] records
  /// whether any trump has been played this hand, which only matters under
  /// [TrumpLeadRule.onlyAfterBroken].
  ///
  /// The result is never empty for a non-empty hand: every restriction below is
  /// applied only when the seat can actually satisfy it.
  static List<PlayingCard> forHand({
    required List<PlayingCard> hand,
    required Trick? trick,
    required Suit? trump,
    required TrickRules rules,
    required bool trumpBroken,
  }) {
    if (hand.isEmpty) {
      return const <PlayingCard>[];
    }
    if (trick == null || trick.isEmpty) {
      return _leadOptions(
        hand: hand,
        trump: trump,
        rules: rules,
        trumpBroken: trumpBroken,
      );
    }
    return _followOptions(
      hand: hand,
      trick: trick,
      trump: trump,
      rules: rules,
    );
  }

  /// Whether [card] is legal, with the reason when it is not.
  ///
  /// Returns null when the play is legal. The engine uses this so a rejection
  /// carries a specific code instead of a generic "illegal move".
  static RuleViolation? validate({
    required PlayingCard card,
    required List<PlayingCard> hand,
    required Trick? trick,
    required Suit? trump,
    required TrickRules rules,
    required bool trumpBroken,
  }) {
    if (!hand.contains(card)) {
      return RuleViolation(RuleViolationCode.cardNotInHand, detail: '$card');
    }
    final List<PlayingCard> legal = forHand(
      hand: hand,
      trick: trick,
      trump: trump,
      rules: rules,
      trumpBroken: trumpBroken,
    );
    if (legal.contains(card)) {
      return null;
    }
    return RuleViolation(
      _explain(
        card: card,
        hand: hand,
        trick: trick,
        trump: trump,
        rules: rules,
      ),
      detail: '$card',
    );
  }

  static List<PlayingCard> _leadOptions({
    required List<PlayingCard> hand,
    required Suit? trump,
    required TrickRules rules,
    required bool trumpBroken,
  }) {
    final bool restricted = trump != null &&
        rules.trumpLeadRule == TrumpLeadRule.onlyAfterBroken &&
        !trumpBroken;
    if (!restricted) {
      return List<PlayingCard>.unmodifiable(hand);
    }
    final List<PlayingCard> nonTrump = hand
        .where((PlayingCard card) => card.suit != trump)
        .toList(growable: false);
    // Holding nothing but trump forces the lead; the restriction yields.
    return List<PlayingCard>.unmodifiable(nonTrump.isEmpty ? hand : nonTrump);
  }

  static List<PlayingCard> _followOptions({
    required List<PlayingCard> hand,
    required Trick trick,
    required Suit? trump,
    required TrickRules rules,
  }) {
    final Suit leadSuit = trick.leadSuit!;
    final List<PlayingCard> ofLeadSuit = hand
        .where((PlayingCard card) => card.suit == leadSuit)
        .toList(growable: false);

    if (rules.mustFollowSuit && ofLeadSuit.isNotEmpty) {
      if (!rules.mustBeatLeadSuitWhenPossible) {
        return List<PlayingCard>.unmodifiable(ofLeadSuit);
      }
      final int bestSoFar = _highestStrengthOfSuit(trick, leadSuit);
      final List<PlayingCard> beating = ofLeadSuit
          .where((PlayingCard card) => card.strength > bestSoFar)
          .toList(growable: false);
      return List<PlayingCard>.unmodifiable(
        beating.isEmpty ? ofLeadSuit : beating,
      );
    }

    // Void in the lead suit (or following is not mandatory).
    final List<PlayingCard> trumps = trump == null
        ? const <PlayingCard>[]
        : hand.where((PlayingCard card) => card.suit == trump).toList(
              growable: false,
            );

    if (trump == null || trumps.isEmpty) {
      return List<PlayingCard>.unmodifiable(hand);
    }

    if (!rules.mustPlayTrumpWhenVoid) {
      return List<PlayingCard>.unmodifiable(hand);
    }

    // Trump is compulsory. If the trick already holds trump and overtrumping is
    // compulsory too, only trumps that beat it qualify -- unless none do, in
    // which case any trump is accepted (the seat cannot be left with no move).
    if (rules.mustOvertrumpWhenPossible) {
      final int bestTrump = _highestStrengthOfSuit(trick, trump);
      if (bestTrump > 0) {
        final List<PlayingCard> overtrumps = trumps
            .where((PlayingCard card) => card.strength > bestTrump)
            .toList(growable: false);
        if (overtrumps.isNotEmpty) {
          return List<PlayingCard>.unmodifiable(overtrumps);
        }
      }
    }
    return List<PlayingCard>.unmodifiable(trumps);
  }

  /// Highest strength of [suit] present in [trick], or 0 when absent.
  static int _highestStrengthOfSuit(Trick trick, Suit suit) {
    int best = 0;
    for (final PlayedCard play in trick.plays) {
      if (play.card.suit == suit && play.card.strength > best) {
        best = play.card.strength;
      }
    }
    return best;
  }

  /// Picks the most specific code explaining why [card] was refused.
  static RuleViolationCode _explain({
    required PlayingCard card,
    required List<PlayingCard> hand,
    required Trick? trick,
    required Suit? trump,
    required TrickRules rules,
  }) {
    if (trick == null || trick.isEmpty) {
      return RuleViolationCode.trumpNotBroken;
    }
    final Suit leadSuit = trick.leadSuit!;
    final bool holdsLeadSuit = hand.any((PlayingCard c) => c.suit == leadSuit);
    if (holdsLeadSuit && card.suit != leadSuit) {
      return RuleViolationCode.mustFollowSuit;
    }
    if (holdsLeadSuit) {
      return RuleViolationCode.mustBeatLeadSuit;
    }
    final bool holdsTrump =
        trump != null && hand.any((PlayingCard c) => c.suit == trump);
    if (holdsTrump && card.suit != trump) {
      return RuleViolationCode.mustPlayTrump;
    }
    if (holdsTrump && rules.mustOvertrumpWhenPossible) {
      return RuleViolationCode.mustOvertrump;
    }
    return RuleViolationCode.mustFollowSuit;
  }
}
