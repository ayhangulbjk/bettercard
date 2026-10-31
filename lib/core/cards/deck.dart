import '../util/seeded_random.dart';
import 'playing_card.dart';
import 'rank.dart';
import 'suit.dart';

/// Deck construction and seeded dealing.
///
/// Every function here is pure: given the same seed and arguments it returns
/// the same cards, which is what makes matches replayable and AI benchmarks
/// comparable across runs and across machines.
abstract final class Deck {
  /// A fresh deck in canonical order (clubs 2..A, diamonds 2..A, ...).
  static List<PlayingCard> standard52() => <PlayingCard>[
        for (final Suit suit in Suit.values)
          for (final Rank rank in Rank.values) PlayingCard(suit, rank),
      ];

  /// A deck shuffled with [seed].
  ///
  /// [excluded] removes specific cards before shuffling, which the three-player
  /// buried-Batak variants need (they play a reduced deck so that the cards
  /// divide evenly). Excluding cards is a rule decision and therefore the
  /// caller's, not the deck's.
  static List<PlayingCard> shuffled({
    required int seed,
    Set<PlayingCard> excluded = const <PlayingCard>{},
  }) {
    final List<PlayingCard> cards = standard52()
      ..removeWhere(excluded.contains);
    SeededRandom(seed).shuffleInPlace(cards);
    return cards;
  }

  /// Splits [cards] into [handCount] hands of [handSize] cards each, dealt in
  /// the order the cards appear.
  ///
  /// Returns the hands plus whatever cards are left over, which some variants
  /// keep face down as the "kitty"/buried pile. Throws if the deck cannot
  /// satisfy the request, so a misconfigured rule profile fails loudly at the
  /// deal instead of corrupting a match later.
  static Deal deal({
    required List<PlayingCard> cards,
    required int handCount,
    required int handSize,
  }) {
    if (handCount <= 0) {
      throw ArgumentError.value(handCount, 'handCount', 'must be positive');
    }
    if (handSize <= 0) {
      throw ArgumentError.value(handSize, 'handSize', 'must be positive');
    }
    final int needed = handCount * handSize;
    if (needed > cards.length) {
      throw ArgumentError(
        'Deal needs $needed cards but only ${cards.length} are available',
      );
    }
    final List<List<PlayingCard>> hands = <List<PlayingCard>>[
      for (int seat = 0; seat < handCount; seat++)
        List<PlayingCard>.unmodifiable(
          cards.sublist(seat * handSize, (seat + 1) * handSize),
        ),
    ];
    return Deal(
      hands: List<List<PlayingCard>>.unmodifiable(hands),
      remaining: List<PlayingCard>.unmodifiable(cards.sublist(needed)),
    );
  }

  /// Convenience: shuffle with [seed] and deal in one step.
  static Deal shuffleAndDeal({
    required int seed,
    required int handCount,
    required int handSize,
    Set<PlayingCard> excluded = const <PlayingCard>{},
  }) =>
      deal(
        cards: shuffled(seed: seed, excluded: excluded),
        handCount: handCount,
        handSize: handSize,
      );
}

/// The immutable result of a deal.
final class Deal {
  const Deal({required this.hands, required this.remaining});

  /// One unmodifiable hand per seat, indexed by seat number.
  final List<List<PlayingCard>> hands;

  /// Cards not dealt to any seat (kitty / buried pile candidates).
  final List<PlayingCard> remaining;
}
