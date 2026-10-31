import 'package:meta/meta.dart';

import '../../cards/playing_card.dart';
import '../../cards/suit.dart';

/// One card played by one seat.
@immutable
class PlayedCard {
  const PlayedCard({required this.seat, required this.card});

  final int seat;
  final PlayingCard card;

  @override
  bool operator ==(Object other) =>
      other is PlayedCard && other.seat == seat && other.card == card;

  @override
  int get hashCode => Object.hash(seat, card);

  @override
  String toString() => 'PlayedCard(seat: $seat, card: $card)';
}

/// A trick in progress.
///
/// A trick is public information: every seat may see every card in it, so this
/// object is safe to hand to an AI observation unchanged.
@immutable
class Trick {
  /// Creates a trick led by [leadSeat] that completes after [expectedPlays]
  /// cards.
  Trick({
    required this.leadSeat,
    required this.expectedPlays,
    List<PlayedCard> plays = const <PlayedCard>[],
  }) : plays = List<PlayedCard>.unmodifiable(plays);

  /// An empty trick to be led by [leadSeat].
  Trick.empty({required int leadSeat, required int expectedPlays})
      : this(leadSeat: leadSeat, expectedPlays: expectedPlays);

  final int leadSeat;

  /// Number of cards the trick holds once complete, i.e. the player count.
  final int expectedPlays;

  /// Cards played so far, in play order starting with [leadSeat].
  final List<PlayedCard> plays;

  /// The suit that must be followed, or null while the trick is empty.
  Suit? get leadSuit => plays.isEmpty ? null : plays.first.card.suit;

  bool get isEmpty => plays.isEmpty;

  bool get isComplete => plays.length >= expectedPlays;

  /// The card [seat] contributed to this trick, if any.
  PlayingCard? cardOf(int seat) {
    for (final PlayedCard play in plays) {
      if (play.seat == seat) {
        return play.card;
      }
    }
    return null;
  }

  /// Returns a new trick with [play] appended.
  ///
  /// Throws if the trick is already complete or the seat has already played;
  /// these are engine invariants, not user-facing rule violations, so they fail
  /// loudly rather than returning a rejection.
  Trick withPlay(PlayedCard play) {
    if (isComplete) {
      throw StateError('Cannot add a play to a complete trick');
    }
    if (cardOf(play.seat) != null) {
      throw StateError('Seat ${play.seat} has already played in this trick');
    }
    return Trick(
      leadSeat: leadSeat,
      expectedPlays: expectedPlays,
      plays: <PlayedCard>[...plays, play],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Trick &&
      other.leadSeat == leadSeat &&
      other.expectedPlays == expectedPlays &&
      _playsEqual(other.plays, plays);

  @override
  int get hashCode =>
      Object.hash(leadSeat, expectedPlays, Object.hashAll(plays));

  @override
  String toString() => 'Trick(lead: $leadSeat, plays: $plays)';

  static bool _playsEqual(List<PlayedCard> a, List<PlayedCard> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// A finished trick together with the seat that won it.
@immutable
class CompletedTrick {
  const CompletedTrick({required this.trick, required this.winnerSeat});

  final Trick trick;
  final int winnerSeat;

  /// Every card in the trick, in play order.
  List<PlayingCard> get cards =>
      trick.plays.map((PlayedCard p) => p.card).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      other is CompletedTrick &&
      other.trick == trick &&
      other.winnerSeat == winnerSeat;

  @override
  int get hashCode => Object.hash(trick, winnerSeat);

  @override
  String toString() => 'CompletedTrick(winner: $winnerSeat, $trick)';
}
