import 'package:flutter/material.dart';

/// Where each seat sits at the table, and where its played card lands.
///
/// One authority for the table's shape, so a seat's panel and the card it
/// plays can never drift apart: the card appears on the edge the player is
/// sitting on. Seat 0 is always the person at the device, at the bottom of the
/// screen, and the rest follow the engine's seating order anticlockwise --
/// which, seen from seat 0, reads left, across, right.
abstract final class TableGeometry {
  /// Where [seat]'s card lands, in multiples of the card's own width and
  /// height, measured from the middle of the table.
  ///
  /// Tight enough that the four cards overlap into a pile, as thrown cards
  /// do, and loose enough that each one's outer half -- the half carrying its
  /// corner index -- stays uncovered.
  static Offset cardOffset(int seat, int seatCount) {
    if (seatCount == 3) {
      return switch (seat) {
        0 => const Offset(0, 0.40),
        1 => const Offset(-0.36, -0.26),
        _ => const Offset(0.36, -0.26),
      };
    }
    return switch (seat) {
      0 => const Offset(0, 0.40),
      1 => const Offset(-0.34, 0),
      2 => const Offset(0, -0.40),
      _ => const Offset(0.34, 0),
    };
  }

  /// A slight tilt per seat, so a buried card's corner still peeks out.
  static double cardTilt(int seat, int seatCount) {
    if (seatCount == 3) {
      return switch (seat) {
        0 => -0.04,
        1 => -0.08,
        _ => 0.08,
      };
    }
    return switch (seat) {
      1 => -0.08,
      2 => 0.05,
      3 => 0.08,
      _ => -0.04,
    };
  }

  /// Width allowed a side seat's panel. Narrow by necessity: the two side
  /// seats and the trick share a portrait phone's width.
  static const double sideSeatWidth = 82;

  /// Width allowed the seat across the table, which has the full width to
  /// itself but should not stretch into one long bar.
  static const double farSeatWidth = 132;
}

/// The table itself: a seat on each edge, with the trick between them.
///
/// Laid out as rows and columns rather than a free [Stack] so that the middle
/// is what is left after the seats have taken their space. A stacked layout
/// looked identical at the default text size and then put the far seat's
/// panel on top of the cards once the system font grew; here the trick can
/// only shrink, never be covered.
///
/// Seat 0 is the player, along the bottom. With four seats the rest take the
/// left, far and right edges; with three, the other two share the far edge.
final class TableLayout extends StatelessWidget {
  const TableLayout({
    required this.seatCount,
    required this.seatBuilder,
    required this.center,
    super.key,
  });

  final int seatCount;

  /// Builds the panel for one seat. Seat 0 is the player.
  final Widget Function(int seat) seatBuilder;

  /// What goes in the middle, normally the trick.
  final Widget center;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          _farEdge(),
          Expanded(
            child: Row(
              children: <Widget>[
                _sideSeat(1),
                Expanded(child: Center(child: center)),
                _sideSeat(3),
              ],
            ),
          ),
          seatBuilder(0),
        ],
      );

  /// The seat (or, at a three-handed table, the two seats) across the felt.
  Widget _farEdge() {
    if (seatCount == 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: TableGeometry.farSeatWidth, child: seatBuilder(1)),
          SizedBox(width: TableGeometry.farSeatWidth, child: seatBuilder(2)),
        ],
      );
    }
    return SizedBox(
      width: TableGeometry.farSeatWidth,
      child: seatBuilder(2),
    );
  }

  /// A left or right seat, vertically centred on its edge. A three-handed
  /// table has none, so the trick gets the whole width.
  Widget _sideSeat(int seat) {
    if (seatCount < 4) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: TableGeometry.sideSeatWidth,
      child: Center(child: seatBuilder(seat)),
    );
  }
}
