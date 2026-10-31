/// Card ranks, ordered weakest to strongest for trick-taking comparison.
///
/// Declaration order is canonical and feeds [PlayingCard.id]; reordering it is
/// a persistence-breaking change. Ace is high in every mode this app supports.
enum Rank {
  two(2, '2', 'İki'),
  three(3, '3', 'Üç'),
  four(4, '4', 'Dört'),
  five(5, '5', 'Beş'),
  six(6, '6', 'Altı'),
  seven(7, '7', 'Yedi'),
  eight(8, '8', 'Sekiz'),
  nine(9, '9', 'Dokuz'),
  ten(10, '10', 'On'),
  jack(11, 'J', 'Vale'),
  queen(12, 'Q', 'Kız'),
  king(13, 'K', 'Papaz'),
  ace(14, 'A', 'As');

  const Rank(this.strength, this.shortLabel, this.turkishName);

  /// Trick-taking strength, 2..14. Higher wins within the same suit.
  final int strength;

  /// Compact face label used on card art, e.g. `K`.
  final String shortLabel;

  /// Turkish display name, e.g. `Papaz`.
  final String turkishName;
}
