import 'playing_card.dart';
import 'suit.dart';

/// Hand presentation helpers.
///
/// Sorting is a display concern only: the engine never depends on the order of
/// cards within a hand, so changing these comparators can never change a legal
/// move set or a trick outcome.
abstract final class CardSorting {
  /// Groups by suit in canonical order, strongest card first within each suit.
  static List<PlayingCard> bySuitStrongestFirst(Iterable<PlayingCard> cards) {
    final List<PlayingCard> sorted = cards.toList()
      ..sort((PlayingCard a, PlayingCard b) {
        final int suitOrder = a.suit.index.compareTo(b.suit.index);
        return suitOrder != 0 ? suitOrder : b.strength.compareTo(a.strength);
      });
    return sorted;
  }

  /// Like [bySuitStrongestFirst] but floats [trump] to the right-hand edge of
  /// the fan, which is where players expect to find it.
  static List<PlayingCard> forHandFan(
    Iterable<PlayingCard> cards, {
    Suit? trump,
  }) {
    if (trump == null) {
      return bySuitStrongestFirst(cards);
    }
    final List<PlayingCard> sorted = cards.toList()
      ..sort((PlayingCard a, PlayingCard b) {
        final int trumpOrder =
            (a.suit == trump ? 1 : 0).compareTo(b.suit == trump ? 1 : 0);
        if (trumpOrder != 0) {
          return trumpOrder;
        }
        final int suitOrder = a.suit.index.compareTo(b.suit.index);
        return suitOrder != 0 ? suitOrder : b.strength.compareTo(a.strength);
      });
    return sorted;
  }
}
