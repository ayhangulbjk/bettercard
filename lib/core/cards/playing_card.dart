import 'package:meta/meta.dart';

import 'rank.dart';
import 'suit.dart';

/// An immutable French playing card.
///
/// Identity is the `(suit, rank)` pair, encoded as a dense [id] in `0..51`.
/// The dense id is what persistence, the network-free replay log and the AI's
/// bitset-style bookkeeping store, so it must stay stable across releases.
@immutable
class PlayingCard implements Comparable<PlayingCard> {
  /// Creates the card for [suit] and [rank].
  const PlayingCard(this.suit, this.rank);

  /// Decodes a card from its dense [id] in `0..51`.
  factory PlayingCard.fromId(int id) {
    if (id < 0 || id >= deckSize) {
      throw ArgumentError.value(id, 'id', 'must be in 0..${deckSize - 1}');
    }
    return PlayingCard(
      Suit.values[id ~/ Rank.values.length],
      Rank.values[id % Rank.values.length],
    );
  }

  /// Number of distinct cards in a standard French deck.
  static const int deckSize = 52;

  final Suit suit;
  final Rank rank;

  /// Dense stable identifier in `0..51`.
  int get id => suit.index * Rank.values.length + rank.index;

  /// Trick-taking strength within a suit, 2..14.
  int get strength => rank.strength;

  /// Display form used on card faces, e.g. `A♠`.
  String get label => '${rank.shortLabel}${suit.symbol}';

  /// Full Turkish name, e.g. `Maca Asi`.
  String get turkishName => '${suit.turkishName} ${rank.turkishName}';

  /// Canonical ordering: by suit declaration order, then ascending strength.
  @override
  int compareTo(PlayingCard other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => id;

  @override
  String toString() => label;
}
