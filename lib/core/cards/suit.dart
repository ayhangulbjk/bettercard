/// The four French suits.
///
/// Declaration order is the project's canonical suit order and is relied upon
/// by [PlayingCard.id], so it must not be reordered without a persistence
/// schema migration.
enum Suit {
  clubs('Sinek', '♣'),
  diamonds('Karo', '♦'),
  hearts('Kupa', '♥'),
  spades('Maca', '♠');

  const Suit(this.turkishName, this.symbol);

  /// Turkish display name, e.g. `Maca`.
  final String turkishName;

  /// Unicode pip, e.g. `♠`.
  final String symbol;

  /// Whether the suit is conventionally printed in red.
  bool get isRed => this == hearts || this == diamonds;
}
