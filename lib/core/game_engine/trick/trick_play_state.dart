import 'package:meta/meta.dart';

import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../rules/trick_rules.dart';
import '../seating.dart';
import 'trick.dart';

/// Immutable snapshot of the card-play phase of a hand.
///
/// This is the shared trick-play core. Each of the five game modes wraps it
/// with its own auction / contract / scoring lifecycle, but none of them
/// reimplements following suit, trumping or trick winning.
///
/// Deliberately free of Flutter, device APIs and wall-clock time, and free of
/// any ambient randomness: a snapshot plus a command list replays exactly.
@immutable
class TrickPlayState {
  TrickPlayState({
    required List<List<PlayingCard>> hands,
    required this.seating,
    required this.rules,
    required this.trump,
    required this.turnSeat,
    required this.currentTrick,
    required List<CompletedTrick> completedTricks,
    required this.trumpBroken,
  })  : hands = List<List<PlayingCard>>.unmodifiable(
          hands.map(List<PlayingCard>.unmodifiable),
        ),
        completedTricks = List<CompletedTrick>.unmodifiable(completedTricks) {
    if (hands.length != seating.playerCount) {
      throw ArgumentError(
        'Expected ${seating.playerCount} hands, got ${hands.length}',
      );
    }
  }

  /// Starts card play from a deal.
  factory TrickPlayState.opening({
    required List<List<PlayingCard>> hands,
    required SeatingPlan seating,
    required TrickRules rules,
    required Suit? trump,
    required int leadSeat,
  }) =>
      TrickPlayState(
        hands: hands,
        seating: seating,
        rules: rules,
        trump: trump,
        turnSeat: leadSeat,
        currentTrick: Trick.empty(
          leadSeat: leadSeat,
          expectedPlays: seating.playerCount,
        ),
        completedTricks: const <CompletedTrick>[],
        trumpBroken: false,
      );

  /// Cards still held, indexed by seat.
  ///
  /// This is the hidden state of the game. It lives here because the engine is
  /// authoritative, and it is exactly what the AI observation layer must strip
  /// out before any decision policy sees the position.
  final List<List<PlayingCard>> hands;

  final SeatingPlan seating;
  final TrickRules rules;

  /// The trump suit, or null for a no-trump contract.
  final Suit? trump;

  /// The seat due to play.
  final int turnSeat;

  /// The trick in progress.
  final Trick currentTrick;

  /// Finished tricks in play order. Public information.
  final List<CompletedTrick> completedTricks;

  /// Whether trump has been played this hand (gates `onlyAfterBroken` leads).
  final bool trumpBroken;

  /// Card play is over once no seat holds a card.
  bool get isComplete => hands.every((List<PlayingCard> h) => h.isEmpty);

  /// Number of tricks finished so far.
  int get trickNumber => completedTricks.length;

  /// Cards remaining in [seat]'s hand.
  List<PlayingCard> handOf(int seat) => hands[seat];

  /// Public card counts per seat. Safe to expose to every seat.
  List<int> get handSizes => List<int>.unmodifiable(
        hands.map((List<PlayingCard> h) => h.length),
      );

  /// Tricks won per seat.
  List<int> get tricksWon {
    final List<int> counts = List<int>.filled(seating.playerCount, 0);
    for (final CompletedTrick trick in completedTricks) {
      counts[trick.winnerSeat]++;
    }
    return List<int>.unmodifiable(counts);
  }

  /// Tricks won per team id.
  Map<int, int> get tricksWonByTeam {
    final Map<int, int> byTeam = <int, int>{};
    for (final CompletedTrick trick in completedTricks) {
      final int team = seating.teamOf(trick.winnerSeat);
      byTeam[team] = (byTeam[team] ?? 0) + 1;
    }
    return Map<int, int>.unmodifiable(byTeam);
  }

  TrickPlayState copyWith({
    List<List<PlayingCard>>? hands,
    int? turnSeat,
    Trick? currentTrick,
    List<CompletedTrick>? completedTricks,
    bool? trumpBroken,
  }) =>
      TrickPlayState(
        hands: hands ?? this.hands,
        seating: seating,
        rules: rules,
        trump: trump,
        turnSeat: turnSeat ?? this.turnSeat,
        currentTrick: currentTrick ?? this.currentTrick,
        completedTricks: completedTricks ?? this.completedTricks,
        trumpBroken: trumpBroken ?? this.trumpBroken,
      );

  /// Asserts the invariants an engine must preserve.
  ///
  /// Called by tests and by the simulator after every command, so that a
  /// regression surfaces at the step that caused it rather than many plies
  /// later. Throws [StateError] on violation; these are programming errors,
  /// not player mistakes.
  void checkInvariants({int? expectedTotalCards}) {
    final List<PlayingCard> seen = <PlayingCard>[
      for (final List<PlayingCard> hand in hands) ...hand,
      ...currentTrick.plays.map((PlayedCard p) => p.card),
      for (final CompletedTrick trick in completedTricks) ...trick.cards,
    ];
    final Set<PlayingCard> unique = seen.toSet();
    if (unique.length != seen.length) {
      throw StateError(
          'Duplicate card in play: ${seen.length - unique.length}');
    }
    if (expectedTotalCards != null && seen.length != expectedTotalCards) {
      throw StateError(
        'Card count drifted: expected $expectedTotalCards, found ${seen.length}',
      );
    }
    if (turnSeat < 0 || turnSeat >= seating.playerCount) {
      throw StateError('turnSeat $turnSeat is out of range');
    }
    if (currentTrick.isComplete) {
      throw StateError('A complete trick must be moved to completedTricks');
    }
    // Within a trick, every seat that has already played holds one fewer card
    // than every seat that has not. Catches a hand/trick desynchronisation.
    final int played = currentTrick.plays.length;
    if (played > 0 && !isComplete) {
      final List<int> order = seating.orderFrom(currentTrick.leadSeat);
      final int yetToPlay = hands[order[played % seating.playerCount]].length;
      final int alreadyPlayed = hands[order[0]].length;
      if (yetToPlay < alreadyPlayed) {
        throw StateError('Hand sizes inconsistent with trick progress');
      }
    }
    if (!trumpBroken && trump != null) {
      final bool trumpSeen = completedTricks.any(
            (CompletedTrick t) =>
                t.cards.any((PlayingCard c) => c.suit == trump),
          ) ||
          currentTrick.plays.any((PlayedCard p) => p.card.suit == trump);
      if (trumpSeen) {
        throw StateError('trumpBroken is false but trump has been played');
      }
    }
  }

  @override
  String toString() => 'TrickPlayState(trick: $trickNumber, turn: $turnSeat, '
      'trump: ${trump?.name ?? 'none'})';
}
