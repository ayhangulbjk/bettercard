import 'package:meta/meta.dart';

import '../cards/suit.dart';
import '../rules/trick_rules.dart';

/// Parameters for a headless batch of trick-play hands.
///
/// Everything that influences the outcome is in here and is seeded, so a run
/// is fully reproducible from this object alone. That is the property that
/// makes benchmark numbers comparable between machines and between commits.
@immutable
class SimulationConfig {
  const SimulationConfig({
    required this.handCount,
    required this.playerCount,
    this.baseSeed = 1,
    this.trump = Suit.spades,
    this.rules = TrickRules.batakStandard,
    this.handSize,
    this.rotateSeats = true,
    this.checkInvariants = true,
    this.failOnIllegalMove = true,
  });

  /// How many hands to play.
  final int handCount;

  /// Seats at the table.
  final int playerCount;

  /// Seed for hand 0. Hand `i` uses a stream forked from `baseSeed + i`, so
  /// extending a run never changes the hands an earlier run produced.
  final int baseSeed;

  /// Trump suit for every hand, or null for no-trump.
  final Suit? trump;

  final TrickRules rules;

  /// Cards per seat. Defaults to an even split of the 52-card deck.
  final int? handSize;

  /// Whether to rotate which agent sits in which seat across repeats of the
  /// same deal.
  ///
  /// Paired deals with rotated seats are how the benchmark removes the luck of
  /// the deal from a comparison: both agents play the same cards from every
  /// position, so a difference in result is a difference in play.
  final bool rotateSeats;

  /// Whether to assert state invariants after every command. On for
  /// correctness runs, off when measuring throughput.
  final bool checkInvariants;

  /// Whether an illegal command aborts the run.
  ///
  /// True for correctness runs, where an illegal move is a defect and should
  /// stop everything. False for measurement runs that want to report an
  /// illegal-move rate across a batch rather than halt on the first one.
  final bool failOnIllegalMove;

  /// Effective cards per seat.
  int get effectiveHandSize => handSize ?? 52 ~/ playerCount;

  /// Cards actually dealt.
  int get dealtCardCount => effectiveHandSize * playerCount;
}
