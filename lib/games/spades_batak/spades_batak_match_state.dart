import 'package:meta/meta.dart';

import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/scoring_rules.dart';
import 'spades_batak_scorer.dart';

/// A full Koz Maca match: a sequence of hands plus the running score.
///
/// Immutable, like every other snapshot in the domain. The deal for hand `i`
/// is derived from [baseSeed] rather than drawn from a live generator, so
/// `apply` stays pure: the same state and command always produce the same next
/// state, which is what makes replay and headless testing possible. See
/// docs/ARCHITECTURE.md, "Determinizm".
@immutable
final class SpadesBatakMatchState {
  SpadesBatakMatchState({
    required this.profile,
    required this.baseSeed,
    required this.handIndex,
    required this.hand,
    required List<int> totals,
    required List<HandScore> history,
    List<int?>? declarations,
  })  : totals = List<int>.unmodifiable(totals),
        history = List<HandScore>.unmodifiable(history),
        declarations = List<int?>.unmodifiable(
          declarations ?? List<int?>.filled(totals.length, null),
        );

  /// The rule set this match started with, stored in full and never swapped.
  final RuleProfile profile;

  /// Seed the whole match derives from. Hand `i` is dealt from
  /// `baseSeed + i`, so extending a match never changes an earlier hand.
  final int baseSeed;

  /// Zero-based index of the hand in [hand].
  final int handIndex;

  /// Card play for the current hand. Null once the match is over.
  final TrickPlayState? hand;

  /// Cumulative points, indexed by seat.
  final List<int> totals;

  /// One entry per completed hand, oldest first.
  final List<HandScore> history;

  /// What each seat has declared for the hand in play, null until it does.
  ///
  /// Reset at every deal. In a profile with no declaration round every entry
  /// stays null and [isDeclaring] is always false, so the phase costs nothing.
  final List<int?> declarations;

  int get seatCount => totals.length;

  /// Whether the hand is still waiting for declarations.
  bool get isDeclaring =>
      hand != null &&
      profile.declarationRules.enabled &&
      declarations.any((int? value) => value == null);

  /// The seat that must declare next, or null when none must.
  ///
  /// Declaring runs in seating order from whoever leads the first trick, so
  /// the seat that speaks first is also the seat that plays first -- the order
  /// at a real table.
  int? get declaringSeat {
    if (!isDeclaring) {
      return null;
    }
    final int first = hand!.turnSeat;
    for (int step = 0; step < seatCount; step++) {
      final int seat = (first + step) % seatCount;
      if (declarations[seat] == null) {
        return seat;
      }
    }
    return null;
  }

  /// Declarations for the hand in play, once every seat has spoken.
  List<int>? get completedDeclarations {
    if (declarations.any((int? value) => value == null)) {
      return null;
    }
    return List<int>.unmodifiable(declarations.cast<int>());
  }

  /// The declarations plus whatever each seat has taken so far, which is what
  /// the table shows under each name while a hand runs.
  int? declarationOf(int seat) => declarations[seat];

  /// Seed for hand [index].
  int seedForHand(int index) => baseSeed + index;

  /// Hands completed so far.
  int get handsPlayed => history.length;

  /// Whether the match has finished and no further hand will be dealt.
  bool get isOver => hand == null;

  /// Whether the current hand has run out of cards.
  bool get isHandComplete => hand?.isComplete ?? false;

  /// The leading total. Meaningful at any point, not just at the end.
  int get bestTotal => totals.reduce((int a, int b) => a > b ? a : b);

  /// Seats tied for the lead. More than one entry means a draw so far.
  List<int> get leadingSeats {
    final int best = bestTotal;
    return List<int>.unmodifiable(<int>[
      for (int seat = 0; seat < totals.length; seat++)
        if (totals[seat] == best) seat,
    ]);
  }

  /// Whether the scoring rules say this match should stop now.
  ///
  /// Evaluated from [history] and [totals] rather than stored, so it cannot
  /// drift out of step with the score.
  bool get hasReachedEnd {
    final BatakScoringRules rules = profile.scoringRules;
    return switch (rules.endCondition) {
      MatchEndCondition.fixedRounds => handsPlayed >= rules.roundCount,
      MatchEndCondition.targetScore => bestTotal >= rules.targetScore,
    };
  }

  SpadesBatakMatchState copyWith({
    int? handIndex,
    TrickPlayState? hand,
    bool clearHand = false,
    List<int>? totals,
    List<HandScore>? history,
    List<int?>? declarations,
  }) =>
      SpadesBatakMatchState(
        profile: profile,
        baseSeed: baseSeed,
        handIndex: handIndex ?? this.handIndex,
        hand: clearHand ? null : (hand ?? this.hand),
        totals: totals ?? this.totals,
        history: history ?? this.history,
        declarations: declarations ?? this.declarations,
      );

  /// Throws [StateError] if the snapshot is internally inconsistent.
  ///
  /// Broken invariants are programming errors, so they throw rather than
  /// returning a rejection. Illegal *player input* is a rejection; this is
  /// not that.
  void checkInvariants() {
    if (totals.length != profile.playerCount) {
      throw StateError(
        'Totals hold ${totals.length} seats but the profile says '
        '${profile.playerCount}',
      );
    }
    if (declarations.length != profile.playerCount) {
      throw StateError(
        'Declarations hold ${declarations.length} seats but the profile says '
        '${profile.playerCount}',
      );
    }
    if (!profile.declarationRules.enabled &&
        declarations.any((int? value) => value != null)) {
      throw StateError(
        'A profile with no declaration round holds declarations '
        '$declarations',
      );
    }
    for (final int? declared in declarations) {
      if (declared != null &&
          !profile.declarationRules.isInRange(
            declared,
            tricksPerHand: profile.tricksPerHand,
          )) {
        throw StateError('Declaration $declared is out of range');
      }
    }
    if (handIndex < 0) {
      throw StateError('Negative hand index: $handIndex');
    }
    if (handsPlayed > handIndex + 1) {
      throw StateError(
        'History holds $handsPlayed hands but the current index is $handIndex',
      );
    }
    for (final HandScore score in history) {
      if (score.seatCount != profile.playerCount) {
        throw StateError(
          'A history entry holds ${score.seatCount} seats, expected '
          '${profile.playerCount}',
        );
      }
    }
    final List<int> recomputed = List<int>.filled(profile.playerCount, 0);
    for (final HandScore score in history) {
      for (int seat = 0; seat < recomputed.length; seat++) {
        recomputed[seat] += score.pointsOf(seat);
      }
    }
    for (int seat = 0; seat < recomputed.length; seat++) {
      if (recomputed[seat] != totals[seat]) {
        throw StateError(
          'Total for seat $seat is ${totals[seat]} but the history sums to '
          '${recomputed[seat]}',
        );
      }
    }
    hand?.checkInvariants();
  }

  @override
  String toString() => 'SpadesBatakMatchState(hand ${handIndex + 1}, '
      'played $handsPlayed, totals $totals, declarations $declarations, '
      'over $isOver)';
}
