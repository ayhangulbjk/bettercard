import 'playing_card.dart';
import 'suit.dart';

/// Hand presentation helpers.
///
/// Sorting is a display concern only: the engine never depends on the order of
/// cards within a hand, so changing these comparators can never change a legal
/// move set or a trick outcome.
abstract final class CardSorting {
  /// The order suits are laid out in a hand, left to right.
  ///
  /// Sinek, karo, maca, kupa -- the order a Turkish player expects to pick a
  /// hand up in. It deliberately alternates black and red so two adjacent
  /// suits never read as one block, and it is NOT [Suit]'s declaration order,
  /// which is a persistence concern and must not be reordered.
  static const List<Suit> displayOrder = <Suit>[
    Suit.clubs,
    Suit.diamonds,
    Suit.spades,
    Suit.hearts,
  ];

  /// Groups by suit in [displayOrder], strongest card first within each suit.
  ///
  /// This is also how the player's fan is drawn, whatever the trump is: the
  /// hand must not rearrange itself between modes or when a declarer names a
  /// suit, because a player reaches for a card by remembered position. Trump
  /// is marked on the card and on the table, not by moving it.
  static List<PlayingCard> bySuitStrongestFirst(Iterable<PlayingCard> cards) {
    final List<PlayingCard> sorted = cards.toList()
      ..sort((PlayingCard a, PlayingCard b) {
        final int suitOrder = displayOrder
            .indexOf(a.suit)
            .compareTo(displayOrder.indexOf(b.suit));
        return suitOrder != 0 ? suitOrder : b.strength.compareTo(a.strength);
      });
    return sorted;
  }
}
