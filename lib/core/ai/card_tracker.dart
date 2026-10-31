import '../cards/playing_card.dart';
import '../cards/rank.dart';
import '../cards/suit.dart';
import '../game_engine/trick/trick.dart';
import 'seat_observation.dart';

/// Bookkeeping over public information.
///
/// Derives, from nothing but the trick record and the observer's own hand, the
/// facts a competent human player keeps in their head:
///
/// * which cards are gone,
/// * which cards are therefore still out there (the unseen set),
/// * which seats have shown themselves void in which suits.
///
/// Every conclusion here is legally inferable, so this is not cheating. A void
/// is recorded only when a seat failed to follow a suit it was obliged to
/// follow, which proves it held none.
final class CardTracker {
  CardTracker._({
    required this.observerSeat,
    required this.playerCount,
    required Set<PlayingCard> playedCards,
    required Set<PlayingCard> unseenCards,
    required List<Set<Suit>> knownVoids,
  })  : playedCards = Set<PlayingCard>.unmodifiable(playedCards),
        unseenCards = Set<PlayingCard>.unmodifiable(unseenCards),
        knownVoids = List<Set<Suit>>.unmodifiable(
          knownVoids.map(Set<Suit>.unmodifiable),
        );

  /// Builds a tracker from a seat's legal view of the game.
  ///
  /// [fullDeck] is the set of cards actually in play this hand, which matters
  /// for reduced-deck variants such as three-player buried Batak. Defaults to
  /// the standard 52.
  factory CardTracker.fromObservation(
    SeatObservation observation, {
    Set<PlayingCard>? fullDeck,
  }) {
    final Set<PlayingCard> played = observation.publiclyPlayedCards.toSet();
    final Set<PlayingCard> deck = fullDeck ?? standardDeck;

    final Set<PlayingCard> unseen = <PlayingCard>{
      for (final PlayingCard card in deck)
        if (!played.contains(card) && !observation.hand.contains(card)) card,
    };

    final List<Set<Suit>> voids = List<Set<Suit>>.generate(
      observation.seating.playerCount,
      (_) => <Suit>{},
      growable: false,
    );
    for (final CompletedTrick completed in observation.trickHistory) {
      _recordVoids(completed.trick, observation, voids);
    }
    _recordVoids(observation.currentTrick, observation, voids);

    return CardTracker._(
      observerSeat: observation.seat,
      playerCount: observation.seating.playerCount,
      playedCards: played,
      unseenCards: unseen,
      knownVoids: voids,
    );
  }

  /// The full 52-card deck as a set, built once.
  static final Set<PlayingCard> standardDeck = Set<PlayingCard>.unmodifiable(
    <PlayingCard>{
      for (final Suit suit in Suit.values)
        for (final Rank rank in Rank.values) PlayingCard(suit, rank),
    },
  );

  final int observerSeat;
  final int playerCount;

  /// Cards played to a trick this hand.
  final Set<PlayingCard> playedCards;

  /// Cards whose location the observer does not know: in another seat's hand,
  /// or buried.
  final Set<PlayingCard> unseenCards;

  /// Suits each seat has proved it cannot hold, indexed by seat. The
  /// observer's own entry stays empty, since it knows its hand exactly.
  final List<Set<Suit>> knownVoids;

  /// Unseen cards of [suit], ascending.
  List<PlayingCard> unseenOf(Suit suit) => <PlayingCard>[
        for (final PlayingCard card in unseenCards)
          if (card.suit == suit) card,
      ]..sort();

  /// How many cards of [suit] remain unaccounted for.
  int unseenCountOf(Suit suit) =>
      unseenCards.where((PlayingCard c) => c.suit == suit).length;

  /// Whether [seat] is known to hold no [suit].
  bool isKnownVoid(int seat, Suit suit) => knownVoids[seat].contains(suit);

  /// The strongest unseen card of [suit], or null when none remain.
  PlayingCard? highestUnseenOf(Suit suit) {
    PlayingCard? best;
    for (final PlayingCard card in unseenCards) {
      if (card.suit != suit) {
        continue;
      }
      if (best == null || card.strength > best.strength) {
        best = card;
      }
    }
    return best;
  }

  /// Whether [card] is the strongest outstanding card of its suit, counting
  /// only cards the observer cannot see. A master card, in other words, and
  /// the single most useful derived fact for a heuristic policy.
  bool isMaster(PlayingCard card) {
    final PlayingCard? best = highestUnseenOf(card.suit);
    return best == null || card.strength > best.strength;
  }

  /// Records voids proved by failures to follow suit in [trick].
  static void _recordVoids(
    Trick trick,
    SeatObservation observation,
    List<Set<Suit>> voids,
  ) {
    final Suit? leadSuit = trick.leadSuit;
    if (leadSuit == null || !observation.rules.mustFollowSuit) {
      return;
    }
    for (final PlayedCard play in trick.plays) {
      if (play.seat == observation.seat || play.card.suit == leadSuit) {
        continue;
      }
      voids[play.seat].add(leadSuit);

      // Under a compulsory-trump rule, discarding something that is neither
      // the lead suit nor trump additionally proves the seat holds no trump.
      final Suit? trump = observation.trump;
      if (observation.rules.mustPlayTrumpWhenVoid &&
          trump != null &&
          play.card.suit != trump) {
        voids[play.seat].add(trump);
      }
    }
  }
}
