import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../game_engine/trick/trick.dart';
import '../../game_engine/trick/trick_resolver.dart';
import '../card_tracker.dart';
import '../seat_observation.dart';

/// Card comparisons a trick policy keeps asking.
///
/// Separated from the policy because none of it is a decision: these are the
/// questions ("which of these is highest?", "would this card be winning?",
/// "can anybody still ruff this suit?") that the decisions are expressed in.
/// Keeping them apart stops the policy file from being half tactics and half
/// arithmetic, and lets a second policy ask them without inheriting one.
///
/// [wouldLead] consults [TrickResolver] rather than comparing cards itself,
/// so a policy can never disagree with the engine about who is winning.

/// The strongest card in [candidates] whose suit every opponent might still
/// have to follow, or null when each candidate can be ruffed.
PlayingCard? bestUnrufflable(
  List<PlayingCard> candidates,
  SeatObservation observation,
  CardTracker tracker,
) {
  PlayingCard? best;
  for (final PlayingCard card in candidates) {
    if (_anyOpponentKnownVoid(card.suit, observation, tracker)) {
      continue;
    }
    if (best == null || card.strength > best.strength) {
      best = card;
    }
  }
  return best;
}

bool _anyOpponentKnownVoid(
  Suit suit,
  SeatObservation observation,
  CardTracker tracker,
) {
  for (int seat = 0; seat < observation.seating.playerCount; seat++) {
    if (seat == observation.seat || observation.isTeammate(seat)) {
      continue;
    }
    if (tracker.isKnownVoid(seat, suit)) {
      return true;
    }
  }
  return false;
}

/// Whether playing [card] would put us in front of the trick right now.
///
/// Asked by building the trick and consulting [TrickResolver], so the policy
/// cannot disagree with the engine about who is winning.
bool wouldLead(PlayingCard card, SeatObservation observation) {
  final Trick candidate = observation.currentTrick.withPlay(
    PlayedCard(seat: observation.seat, card: card),
  );
  return TrickResolver.winnerSeat(candidate, trump: observation.trump) ==
      observation.seat;
}

PlayingCard highestOf(List<PlayingCard> cards) {
  PlayingCard best = cards.first;
  for (final PlayingCard card in cards) {
    if (card.strength > best.strength) {
      best = card;
    }
  }
  return best;
}

PlayingCard lowestOf(List<PlayingCard> cards) {
  PlayingCard best = cards.first;
  for (final PlayingCard card in cards) {
    if (card.strength < best.strength) {
      best = card;
    }
  }
  return best;
}

/// The lowest card in [candidates], breaking ties towards the suit we hold
/// fewest of, because shedding a short suit is what creates a ruffing void.
PlayingCard lowestOfShortestSuit(
  List<PlayingCard> candidates,
  List<PlayingCard> hand,
) {
  PlayingCard best = candidates.first;
  int bestLength = suitLength(hand, best.suit);
  for (final PlayingCard card in candidates) {
    final int length = suitLength(hand, card.suit);
    if (card.strength < best.strength ||
        (card.strength == best.strength && length < bestLength)) {
      best = card;
      bestLength = length;
    }
  }
  return best;
}

int suitLength(List<PlayingCard> hand, Suit suit) {
  int count = 0;
  for (final PlayingCard card in hand) {
    if (card.suit == suit) {
      count++;
    }
  }
  return count;
}
