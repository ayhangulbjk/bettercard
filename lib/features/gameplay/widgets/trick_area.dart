import 'package:flutter/material.dart';

import '../../../core/game_engine/trick/trick.dart';
import 'playing_card_view.dart';
import 'table_layout.dart';

/// The cards played to the current trick, piled in the middle of the table.
///
/// Each card is thrown towards the seat that played it, taking its position
/// and tilt from [TableGeometry], so the pile says who contributed what
/// without anything having to be labelled. The cards overlap, the way thrown
/// cards do; a buried card still reads because every card carries its index
/// in both corners (see [PlayingCardView]).
///
/// Painted in play order, so the card just played lands on top.
///
/// A finished trick is shown in two beats, which is the whole point of the
/// widget taking [winnerSeat] and [gathering] separately. First it sits
/// still, face up, long enough to see what took it. Then [gathering] turns on
/// and the pile bundles up, shrinks and travels to the winner's edge. Running
/// those together -- which is what happened while the winner alone drove the
/// animation -- meant the cards started leaving the instant the last one
/// landed, and nobody could tell who had won.
final class TrickArea extends StatelessWidget {
  const TrickArea({
    required this.trick,
    this.winnerSeat,
    this.gathering = false,
    this.gatherDuration = const Duration(milliseconds: 620),
    super.key,
  });

  final Trick trick;

  /// The seat collecting this trick, while it is being shown.
  final int? winnerSeat;

  /// Whether the pile is travelling to [winnerSeat] right now.
  final bool gathering;

  /// How long the travel takes. Driven by the player's animation-speed
  /// setting, so "yavas" really is slower.
  final Duration gatherDuration;

  /// How far towards the winner the pile travels, in card widths. Far enough
  /// to land on that seat's rail, so the cards are seen arriving somewhere
  /// rather than merely drifting.
  static const double _gatherDistance = 6.0;

  /// Card width as a fraction of the space the middle of the table has.
  /// Bounded so the pile neither disappears on a small phone nor swamps the
  /// felt on a large one.
  static const double _widthFraction = 0.30;
  static const double _minCardWidth = 58;
  static const double _maxCardWidth = 92;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double cardWidth = (constraints.maxWidth * _widthFraction)
              .clamp(_minCardWidth, _maxCardWidth);
          return _pile(cardWidth);
        },
      );

  Widget _pile(double cardWidth) {
    final double cardHeight = cardWidth * PlayingCardView.aspectRatio;
    final int seats = trick.expectedPlays;
    final int? winner = winnerSeat;
    final bool travelling = gathering && winner != null;

    // Towards the winner's own edge, reusing the seat geometry so the cards
    // travel to where that player is actually sitting.
    final Offset direction =
        winner == null ? Offset.zero : TableGeometry.cardOffset(winner, seats);

    final double boxWidth = cardWidth * 2;
    final double boxHeight = cardHeight * 1.9;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: AnimatedSlide(
        duration: gatherDuration,
        curve: Curves.easeInOutCubic,
        offset: travelling
            ? Offset(
                direction.dx * cardWidth * _gatherDistance / boxWidth,
                direction.dy * cardHeight * _gatherDistance / boxHeight,
              )
            : Offset.zero,
        child: AnimatedScale(
          duration: gatherDuration,
          curve: Curves.easeInOutCubic,
          // The pile shrinks as it goes, which reads as distance and keeps it
          // from covering the seat it is travelling to.
          scale: travelling ? 0.40 : 1,
          child: AnimatedRotation(
            duration: gatherDuration,
            curve: Curves.easeInOutCubic,
            // A quarter of a turn's worth of twist: enough to read as a
            // bundle being swept up rather than a picture being moved.
            turns: travelling ? 0.08 : 0,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                for (final PlayedCard play in trick.plays)
                  if (play.seat < seats)
                    AnimatedSlide(
                      duration: gatherDuration,
                      curve: Curves.easeInOutCubic,
                      // Each card slides back to the middle as the pile
                      // leaves, so what travels is one bundle rather than a
                      // loose cross.
                      offset: travelling
                          ? Offset.zero
                          : TableGeometry.cardOffset(play.seat, seats),
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
      ),
    );
  }
}
