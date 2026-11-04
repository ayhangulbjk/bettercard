import 'package:flutter/material.dart';

/// Which edge of the table a seat sits on.
///
/// The seat panel draws itself differently per edge -- the two side seats are
/// narrow rails with their text turned a quarter turn -- so the edge is part
/// of the geometry rather than something each caller works out again.
enum SeatEdge {
  /// The person at the device.
  bottom,

  /// Across the felt.
  top,

  /// The seat to the player's left on screen.
  left,

  /// The seat to the player's right on screen.
  right,
}

/// Where each seat sits at the table, and where its played card lands.
///
/// One authority for the table's shape, so a seat's panel and the card it
/// plays can never drift apart: the card appears on the edge the player is
/// sitting on. Seat 0 is always the person at the device, at the bottom of the
/// screen.
///
/// **Play passes to the right.** The engine's seating order is 0, 1, 2, 3, so
/// seat 1 -- the next to act after the player -- is drawn on the **right** of
/// the table and seat 3 on the left. Drawing seat 1 on the left would make the
/// turn appear to travel anticlockwise, which is not how these games are
/// dealt or played at a Turkish table.
abstract final class TableGeometry {
  /// Which edge [seat] sits on.
  static SeatEdge edgeOf(int seat, int seatCount) {
    if (seat == 0) {
      return SeatEdge.bottom;
    }
    if (seatCount == 3) {
      return seat == 1 ? SeatEdge.right : SeatEdge.left;
    }
    return switch (seat) {
      1 => SeatEdge.right,
      2 => SeatEdge.top,
      _ => SeatEdge.left,
    };
  }

  /// Where [seat]'s card lands, in multiples of the card's own width and
  /// height, measured from the middle of the table.
  ///
  /// Tight enough that the four cards overlap into a pile, as thrown cards
  /// do, and loose enough that each one keeps one of its two corner indices
  /// uncovered.
  static Offset cardOffset(int seat, int seatCount) {
    if (seatCount == 3) {
      return switch (seat) {
        0 => const Offset(0, 0.40),
        1 => const Offset(0.36, -0.26),
        _ => const Offset(-0.36, -0.26),
      };
    }
    return switch (seat) {
      0 => const Offset(0, 0.40),
      1 => const Offset(0.34, 0),
      2 => const Offset(0, -0.40),
      _ => const Offset(-0.34, 0),
    };
  }

  /// A slight tilt per seat, so a buried card's corner still peeks out.
  static double cardTilt(int seat, int seatCount) {
    if (seatCount == 3) {
      return switch (seat) {
        0 => -0.04,
        1 => 0.08,
        _ => -0.08,
      };
    }
    return switch (seat) {
      1 => 0.08,
      2 => 0.05,
      3 => -0.08,
      _ => -0.04,
    };
  }

  /// Width allowed a side seat's rail.
  ///
  /// Deliberately thin. The two side seats and the trick share a portrait
  /// phone's width, and the trick is what the player is actually reading, so
  /// the side seats turn their text a quarter turn and give the felt the rest.
  static const double sideSeatWidth = 42;

  /// Height a side rail stands, centred on its edge.
  static const double sideSeatHeight = 164;

  /// Most the seat across the table may take. It has the full width to
  /// itself but should not stretch into one long bar; within that cap the
  /// pill shrink-wraps, so a short name does not get a long badge and a long
  /// one is not ellipsised before it has to be.
  static const double farSeatWidth = 230;
}

/// The table itself: a seat on each edge, with the trick between them.
///
/// Laid out as rows and columns rather than a free [Stack] so that the middle
/// is what is left after the seats have taken their space. A stacked layout
/// looked identical at the default text size and then put the far seat's
/// panel on top of the cards once the system font grew; here the trick can
/// only shrink, never be covered.
///
/// Seat 0 is the player, along the bottom. Play passes to the right, so seat 1
/// sits on the right, seat 2 across and seat 3 on the left; with three seats,
/// the other two share the far edge, seat 1 on the right.
final class TableLayout extends StatelessWidget {
  const TableLayout({
    required this.seatCount,
    required this.seatBuilder,
    required this.center,
    this.overlay,
    this.farEdge,
    super.key,
  });

  final int seatCount;

  /// Builds the panel for one seat. Seat 0 is the player.
  final Widget Function(int seat, SeatEdge edge) seatBuilder;

  /// What goes in the middle, normally the trick.
  final Widget center;

  /// Drawn over the felt in the bottom-right corner, for the trump badge.
  /// Kept out of the middle column so it cannot push the trick around.
  final Widget? overlay;

  /// Replaces the far edge, for acik esli Batak's open hand.
  ///
  /// The open hand belongs to the seat across the felt, so it is drawn there
  /// instead of that seat's panel rather than somewhere else on the screen:
  /// a player has to be able to tell which hand a card came out of, and two
  /// fans side by side at the bottom would make that impossible. The middle
  /// shrinks to fit, which is the point of laying this out in rows rather
  /// than stacking it -- the trick can get smaller but can never be covered.
  final Widget? farEdge;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          _farEdge(),
          Expanded(
            child: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _sideSeat(3),
                    Expanded(child: Center(child: center)),
                    _sideSeat(1),
                  ],
                ),
                if (overlay != null)
                  Positioned(right: 0, bottom: 0, child: overlay!),
              ],
            ),
          ),
          seatBuilder(0, SeatEdge.bottom),
        ],
      );

  /// The seat (or, at a three-handed table, the two seats) across the felt,
  /// or whatever has been given to stand in its place.
  Widget _farEdge() {
    final Widget? replacement = farEdge;
    if (replacement != null) {
      return replacement;
    }
    if (seatCount == 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TableGeometry.farSeatWidth,
            ),
            child: seatBuilder(2, SeatEdge.left),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TableGeometry.farSeatWidth,
            ),
            child: seatBuilder(1, SeatEdge.right),
          ),
        ],
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TableGeometry.farSeatWidth,
        ),
        child: seatBuilder(2, SeatEdge.top),
      ),
    );
  }

  /// A left or right rail, vertically centred on its edge. A three-handed
  /// table has none, so the trick gets the whole width.
  Widget _sideSeat(int seat) {
    if (seatCount < 4) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: TableGeometry.sideSeatWidth,
      child: Center(
        child: seatBuilder(seat, TableGeometry.edgeOf(seat, seatCount)),
      ),
    );
  }
}
