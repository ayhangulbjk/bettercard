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
///
/// When [winnerSeat] is set the whole pile gathers up and slides to that
/// seat's edge, which is how the table answers "who took that?" without a
/// label or a sound. The controller holds the trick on screen for a moment
/// first (`MatchPacing.trickPause`), so the slide reads as the winner
/// collecting the cards rather than as the trick vanishing.
final class TrickArea extends StatelessWidget {
  const TrickArea({
    required this.trick,
    this.winnerSeat,
    this.cardWidth = 54,
    super.key,
  });

  final Trick trick;

  /// The seat collecting this trick, while it is being shown.
  final int? winnerSeat;

  final double cardWidth;

  /// How far towards the winner the pile travels, in card widths. Short of the
  /// seat panel itself: the cards are meant to be read on their way, not
  /// hidden behind a badge.
  static const double _gatherDistance = 2.1;

  /// Long enough to follow with the eye, short enough not to hold the hand up.
  static const Duration _gatherDuration = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final double cardHeight = cardWidth * PlayingCardView.aspectRatio;
    final int seats = trick.expectedPlays;
    final int? winner = winnerSeat;

    // Towards the winner's own edge, reusing the seat geometry so the cards
    // travel to where that player is actually sitting.
    final Offset gather = winner == null
        ? Offset.zero
        : Offset(
            TableGeometry.cardOffset(winner, seats).dx *
                cardWidth *
                _gatherDistance,
            TableGeometry.cardOffset(winner, seats).dy *
                cardHeight *
                _gatherDistance,
          );

    return SizedBox(
      width: cardWidth * 2,
      height: cardHeight * 1.9,
      child: AnimatedSlide(
        duration: _gatherDuration,
        curve: Curves.easeInCubic,
        offset: Offset(
          gather.dx / (cardWidth * 2),
          gather.dy / (cardHeight * 1.9),
        ),
        child: AnimatedScale(
          duration: _gatherDuration,
          curve: Curves.easeInCubic,
          // The pile shrinks as it goes, which reads as distance and keeps it
          // from covering the seat it is travelling to.
          scale: winner == null ? 1 : 0.66,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (final PlayedCard play in trick.plays)
                if (play.seat < seats)
                  AnimatedSlide(
                    duration: _gatherDuration,
                    curve: Curves.easeInCubic,
                    // Each card slides back to the middle as the pile leaves,
                    // so what travels is one bundle rather than a loose cross.
                    offset: winner == null
                        ? Offset(
                            TableGeometry.cardOffset(play.seat, seats).dx,
                            TableGeometry.cardOffset(play.seat, seats).dy,
                          )
                        : Offset.zero,
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
        ),
      ),
    );
  }
}
