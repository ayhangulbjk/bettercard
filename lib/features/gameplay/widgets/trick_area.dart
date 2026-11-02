import 'package:flutter/material.dart';

import '../../../core/game_engine/trick/trick.dart';
import 'playing_card_view.dart';
import 'table_layout.dart';

/// The cards played to the current trick, piled in the middle of the table.
///
/// Each card is thrown towards the seat that played it, taking its position
/// and tilt from [TableGeometry], so the pile says who contributed what
/// without anything having to be labelled. The cards overlap, the way thrown
/// cards do, but only on their inner halves: every card keeps the outer half
/// that carries its corner index.
///
/// Painted in play order, so the card just played lands on top.
final class TrickArea extends StatelessWidget {
  const TrickArea({
    required this.trick,
    this.cardWidth = 54,
    super.key,
  });

  final Trick trick;

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final double cardHeight = cardWidth * PlayingCardView.aspectRatio;
    final int seats = trick.expectedPlays;

    return SizedBox(
      width: cardWidth * 2,
      height: cardHeight * 1.9,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final PlayedCard play in trick.plays)
            if (play.seat < seats)
              Transform.translate(
                offset: Offset(
                  TableGeometry.cardOffset(play.seat, seats).dx * cardWidth,
                  TableGeometry.cardOffset(play.seat, seats).dy * cardHeight,
                ),
                child: Transform.rotate(
                  angle: TableGeometry.cardTilt(play.seat, seats),
                  child: PlayingCardView(
                    card: play.card,
                    width: cardWidth,
                    isPlayable: false,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
