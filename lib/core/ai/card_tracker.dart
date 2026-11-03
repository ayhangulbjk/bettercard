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
/// * which seats have shown themselves void in which suits,
/// * what the strongest card a seat can still hold in a suit is, where a
///   compulsory raise has proved a ceiling.
///
/// Every conclusion here is legally inferable, so this is not cheating. A void
/// is recorded only when a seat failed to follow a suit it was obliged to
/// follow, which proves it held none; a ceiling only when a seat was obliged
/// to play higher and did not, which proves it could not.
///
/// Every inference is one-sided: it rules possibilities out, never in. Being
/// wrong would be worse than knowing nothing, because a policy would then
/// trust a card placement that cannot happen, so the soundness of all of this
/// is asserted directly against the real hidden hands in
/// `test/simulation/card_tracker_soundness_test.dart`.
final class CardTracker {
  CardTracker._({
    required this.observerSeat,
    required this.playerCount,
    required Set<PlayingCard> playedCards,
    required Set<PlayingCard> unseenCards,
    required List<Set<Suit>> knownVoids,
    required List<Map<Suit, int>> knownCeilings,
  })  : playedCards = Set<PlayingCard>.unmodifiable(playedCards),
        unseenCards = Set<PlayingCard>.unmodifiable(unseenCards),
        knownVoids = List<Set<Suit>>.unmodifiable(
          knownVoids.map(Set<Suit>.unmodifiable),
        ),
        knownCeilings = List<Map<Suit, int>>.unmodifiable(
          knownCeilings.map(Map<Suit, int>.unmodifiable),
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

    final int players = observation.seating.playerCount;
    final List<Set<Suit>> voids = List<Set<Suit>>.generate(
      players,
      (_) => <Suit>{},
      growable: false,
    );
    final List<Map<Suit, int>> ceilings = List<Map<Suit, int>>.generate(
      players,
      (_) => <Suit, int>{},
      growable: false,
    );
    for (final CompletedTrick completed in observation.trickHistory) {
      _readTrick(completed.trick, observation, voids, ceilings);
    }
    _readTrick(observation.currentTrick, observation, voids, ceilings);

    return CardTracker._(
      observerSeat: observation.seat,
      playerCount: players,
      playedCards: played,
      unseenCards: unseen,
      knownVoids: voids,
      knownCeilings: ceilings,
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

  /// The highest strength each seat can still hold per suit, where it has
  /// proved a ceiling by declining to raise. Absent means no ceiling known.
  ///
  /// This inference only exists because raising is compulsory: when a seat
  /// must beat the best card of the lead suit and plays under it instead, it
  /// has told the table it holds nothing above that card. At a table without
  /// the rule the same play says nothing, which is why the flag is checked
  /// before anything is recorded.
  final List<Map<Suit, int>> knownCeilings;

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

  /// The strongest card [seat] can still hold in [suit], or null when nothing
  /// has been proved about it.
  int? ceilingOf(int seat, Suit suit) => knownCeilings[seat][suit];

  /// Whether [card] could still be in [seat]'s hand, as far as the public
  /// record shows.
  ///
  /// This is the single question a sampler needs to ask, and keeping it in one
  /// place is what stops a sampler honouring voids but quietly ignoring
  /// ceilings.
  bool couldHold(int seat, PlayingCard card) {
    if (isKnownVoid(seat, card.suit)) {
      return false;
    }
    final int? ceiling = knownCeilings[seat][card.suit];
    return ceiling == null || card.strength <= ceiling;
  }

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

  /// Reads one trick for everything it proves, play by play in order.
  ///
  /// Order matters: what a play proves depends on what was already on the
  /// table when it was made. A card under the best one proves a ceiling only
  /// if the raise was still compulsory at that moment, and it was not if an
  /// earlier player had already cut the trick.
  static void _readTrick(
    Trick trick,
    SeatObservation observation,
    List<Set<Suit>> voids,
    List<Map<Suit, int>> ceilings,
  ) {
    final Suit? leadSuit = trick.leadSuit;
    if (leadSuit == null || !observation.rules.mustFollowSuit) {
      return;
    }
    final Suit? trump = observation.trump;
    int bestOfLead = 0;
    int bestTrump = 0;
    bool cut = false;

    for (final PlayedCard play in trick.plays) {
      final PlayingCard card = play.card;
      final bool mine = play.seat == observation.seat;

      if (card.suit == leadSuit) {
        if (!mine &&
            !cut &&
            observation.rules.mustBeatLeadSuitWhenPossible &&
            card.strength < bestOfLead) {
          // It was obliged to beat bestOfLead and did not, so it holds
          // nothing in this suit above that card.
          _lowerCeiling(ceilings, play.seat, leadSuit, bestOfLead);
        }
      } else {
        if (!mine) {
          voids[play.seat].add(leadSuit);

          // Under a compulsory-trump rule, discarding something that is
          // neither the lead suit nor trump additionally proves no trump.
          if (observation.rules.mustPlayTrumpWhenVoid &&
              trump != null &&
              card.suit != trump) {
            voids[play.seat].add(trump);
          }

          // Cutting under a trump already in the trick proves the same
          // ceiling in trump that declining to raise proves in a plain suit.
          if (trump != null &&
              card.suit == trump &&
              observation.rules.mustOvertrumpWhenPossible &&
              card.strength < bestTrump) {
            _lowerCeiling(ceilings, play.seat, trump, bestTrump);
          }
        }
      }

      if (card.suit == leadSuit && card.strength > bestOfLead) {
        bestOfLead = card.strength;
      }
      if (trump != null && card.suit == trump) {
        if (card.strength > bestTrump) {
          bestTrump = card.strength;
        }
        if (leadSuit != trump) {
          cut = true;
        }
      }
    }
  }

  /// Records that [seat] holds nothing in [suit] above [strength], keeping the
  /// tightest bound seen.
  static void _lowerCeiling(
    List<Map<Suit, int>> ceilings,
    int seat,
    Suit suit,
    int strength,
  ) {
    final int? current = ceilings[seat][suit];
    if (current == null || strength < current) {
      ceilings[seat][suit] = strength;
    }
  }
}
