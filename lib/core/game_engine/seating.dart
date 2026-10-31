import 'package:meta/meta.dart';

/// How seats are arranged around a table and which of them are partners.
///
/// Seats are plain `int`s in `0..playerCount-1`, numbered clockwise, with the
/// human player conventionally at seat 0 (rendered at the bottom of the
/// screen). Using `int` rather than a wrapper class is deliberate: seat values
/// are compared and indexed in the innermost loops of the AI search, and a
/// wrapper there would mean millions of short-lived allocations per decision.
@immutable
class SeatingPlan {
  const SeatingPlan._({
    required this.playerCount,
    required this.teamOfSeat,
  });

  /// Everyone plays for themselves (auction Batak, Koz Maca, King, 3-player).
  factory SeatingPlan.individual(int playerCount) {
    if (playerCount < 2) {
      throw ArgumentError.value(playerCount, 'playerCount', 'must be >= 2');
    }
    return SeatingPlan._(
      playerCount: playerCount,
      teamOfSeat: List<int>.unmodifiable(
        List<int>.generate(playerCount, (int seat) => seat),
      ),
    );
  }

  /// Four seats in two partnerships: 0+2 against 1+3, i.e. partners sit
  /// opposite each other, which is the arrangement Esli Batak uses.
  factory SeatingPlan.partnership4() => const SeatingPlan._(
        playerCount: 4,
        teamOfSeat: <int>[0, 1, 0, 1],
      );

  /// Number of seats at the table.
  final int playerCount;

  /// Team id per seat. For individual play each seat is its own team, so
  /// partnership-aware code needs no special case for solo modes.
  final List<int> teamOfSeat;

  /// Whether any two distinct seats share a team.
  bool get hasPartnerships => teamCount < playerCount;

  /// Number of distinct teams.
  int get teamCount => teamOfSeat.toSet().length;

  /// The seat to the left of [seat] (clockwise), i.e. the next to act.
  int next(int seat) => (_checked(seat) + 1) % playerCount;

  /// The seat to the right of [seat].
  int previous(int seat) => (_checked(seat) - 1 + playerCount) % playerCount;

  /// Team id of [seat].
  int teamOf(int seat) => teamOfSeat[_checked(seat)];

  /// Whether [a] and [b] are on the same team. A seat is its own partner-free
  /// team-mate, so this returns true for `a == b`.
  bool sameTeam(int a, int b) => teamOf(a) == teamOf(b);

  /// The single partner of [seat], or null when [seat] has no partner or more
  /// than one (which no supported mode uses, but the signature stays honest).
  int? partnerOf(int seat) {
    final List<int> mates = seatsOfTeam(teamOf(seat))
        .where((int other) => other != _checked(seat))
        .toList(growable: false);
    return mates.length == 1 ? mates.single : null;
  }

  /// Every seat belonging to [team], ascending.
  List<int> seatsOfTeam(int team) => List<int>.unmodifiable(
        <int>[
          for (int seat = 0; seat < playerCount; seat++)
            if (teamOfSeat[seat] == team) seat,
        ],
      );

  /// Seats in playing order starting at [leadSeat].
  List<int> orderFrom(int leadSeat) => List<int>.unmodifiable(
        <int>[
          for (int offset = 0; offset < playerCount; offset++)
            (_checked(leadSeat) + offset) % playerCount,
        ],
      );

  int _checked(int seat) {
    if (seat < 0 || seat >= playerCount) {
      throw RangeError.range(seat, 0, playerCount - 1, 'seat');
    }
    return seat;
  }

  @override
  bool operator ==(Object other) =>
      other is SeatingPlan &&
      other.playerCount == playerCount &&
      _listEquals(other.teamOfSeat, teamOfSeat);

  @override
  int get hashCode => Object.hash(playerCount, Object.hashAll(teamOfSeat));

  @override
  String toString() => 'SeatingPlan(players: $playerCount, teams: $teamOfSeat)';

  static bool _listEquals(List<int> a, List<int> b) {
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
