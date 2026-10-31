import '../../cards/suit.dart';
import 'trick.dart';

/// Decides who wins a trick.
///
/// This is the one piece of logic every one of the five game modes shares
/// unchanged, including King's penalty contracts: who *takes* a trick is
/// always the same question, only what taking it is worth differs.
abstract final class TrickResolver {
  /// The winning play of a complete trick.
  ///
  /// Highest trump wins; with no trump in the trick, the highest card of the
  /// lead suit wins. Cards that are neither trump nor lead suit can never win,
  /// which is why a discard is safe.
  ///
  /// [trump] is null for no-trump contracts (King's penalty hands).
  static PlayedCard winningPlay(Trick trick, {required Suit? trump}) {
    if (trick.isEmpty) {
      throw StateError('An empty trick has no winner');
    }
    final Suit leadSuit = trick.leadSuit!;
    PlayedCard? best;
    for (final PlayedCard play in trick.plays) {
      if (!_canWin(play, leadSuit: leadSuit, trump: trump)) {
        continue;
      }
      if (best == null || _beats(play, best, trump: trump)) {
        best = play;
      }
    }
    // The lead card always satisfies `_canWin`, so `best` is never null.
    return best!;
  }

  /// The seat that wins a complete trick.
  static int winnerSeat(Trick trick, {required Suit? trump}) =>
      winningPlay(trick, trump: trump).seat;

  static bool _canWin(
    PlayedCard play, {
    required Suit leadSuit,
    required Suit? trump,
  }) =>
      play.card.suit == leadSuit || play.card.suit == trump;

  static bool _beats(PlayedCard candidate, PlayedCard incumbent,
      {required Suit? trump}) {
    final bool candidateIsTrump = trump != null && candidate.card.suit == trump;
    final bool incumbentIsTrump = trump != null && incumbent.card.suit == trump;
    if (candidateIsTrump != incumbentIsTrump) {
      return candidateIsTrump;
    }
    return candidate.card.strength > incumbent.card.strength;
  }
}
