import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/cards/playing_card.dart';
import 'playing_card_view.dart';

/// The player's hand, as overlapping rows of cards along the bottom edge.
///
/// Thirteen cards do not fit in one row on a portrait phone while each card
/// still shows its corner index. The index needs roughly 44% of the card width
/// -- the rank is drawn at 34% inside a 6% face padding, and "10" is the widest
/// rank -- so a single row has to overlap tighter than that and bury the rank.
/// It did: a captured screen printed the ten and the four of the same hand on
/// top of each other.
///
/// So the fan wraps into as many rows as it takes to keep every index legible,
/// the way a real hand is held in a fan rather than squeezed into a stack.
///
/// Paint order carries the readability. Within a row each card is drawn over
/// the one to its left, leaving that card's left edge -- where the index sits
/// -- visible. Each row is drawn over the row above it, so the row nearest the
/// player is whole.
final class HandFan extends StatelessWidget {
  const HandFan({
    required this.cards,
    this.legalCards = const <PlayingCard>{},
    this.onCardTap,
    this.showHints = true,
    this.allowDrag = false,
    this.cardWidth = 72,
    super.key,
  });

  final List<PlayingCard> cards;

  /// Cards that may legally be played. Cards outside this set are veiled.
  /// An empty set means "not this seat's turn", so nothing is highlighted.
  final Set<PlayingCard> legalCards;

  /// Tap handler. Null makes the fan display-only, which is what the preview
  /// screen uses so it cannot pretend to accept a move.
  final void Function(PlayingCard card)? onCardTap;

  /// Whether to mark the legal cards.
  ///
  /// Separate from [legalCards], which always gates what can be played: a
  /// player who turns the hints off is choosing to find the legal cards
  /// themselves, not to be allowed an illegal one.
  final bool showHints;

  /// Whether a card can be dragged to the table as well as tapped.
  final bool allowDrag;

  final double cardWidth;

  /// Fraction of a card that stays visible when its neighbour overlaps it.
  ///
  /// Enough for the corner index plus a hair of white between one index and
  /// the next card's edge. Lower this and ranks start colliding.
  static const double _minVisibleFraction = 0.46;

  /// Fraction of a card's height by which each row advances.
  ///
  /// Rows overlap so that a multi-row fan does not eat the table above it.
  static const double _rowStepFraction = 0.58;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool anyLegal = legalCards.isNotEmpty;
    final double cardHeight = cardWidth * PlayingCardView.aspectRatio;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth - 2 * AppSpacing.lg;
        final double minStep = cardWidth * _minVisibleFraction;

        // How many cards fit in one row while each still shows its index.
        int perRow =
            available <= cardWidth ? 1 : 1 + (available - cardWidth) ~/ minStep;
        if (perRow < 1) {
          perRow = 1;
        }
        if (perRow > cards.length) {
          perRow = cards.length;
        }

        // Spread the cards evenly instead of filling early rows and leaving a
        // lonely card on the last one.
        final int rowCount = (cards.length / perRow).ceil();
        final int rowLength = (cards.length / rowCount).ceil();

        final List<List<PlayingCard>> rows = <List<PlayingCard>>[
          for (int start = 0; start < cards.length; start += rowLength)
            cards.sublist(
              start,
              start + rowLength > cards.length
                  ? cards.length
                  : start + rowLength,
            ),
        ];

        // One step for every row, computed from the longest, so the rows line
        // up instead of each finding its own rhythm.
        final double step = rowLength == 1
            ? cardWidth
            : ((available - cardWidth) / (rowLength - 1))
                .clamp(minStep, cardWidth);
        final double rowStep = cardHeight * _rowStepFraction;

        return SizedBox(
          height: cardHeight + rowStep * (rows.length - 1) + AppSpacing.md,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int row = 0; row < rows.length; row++)
                Positioned(
                  top: row * rowStep,
                  left: 0,
                  right: 0,
                  height: cardHeight,
                  child: Center(
                    child: SizedBox(
                      width: cardWidth + step * (rows[row].length - 1),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          for (int i = 0; i < rows[row].length; i++)
                            Positioned(
                              left: i * step,
                              top: 0,
                              child: _FanCard(
                                card: rows[row][i],
                                width: cardWidth,
                                isLegal: legalCards.contains(rows[row][i]),
                                highlight: showHints &&
                                    legalCards.contains(rows[row][i]),
                                dimmed: anyLegal &&
                                    showHints &&
                                    !legalCards.contains(rows[row][i]),
                                allowDrag: allowDrag,
                                onTap: onCardTap,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.card,
    required this.width,
    required this.isLegal,
    required this.highlight,
    required this.dimmed,
    required this.allowDrag,
    required this.onTap,
  });

  final PlayingCard card;
  final double width;

  /// Whether the rules allow this card now. Gates both tap and drag.
  final bool isLegal;

  /// Whether to show it as legal. Off when the player turned hints off.
  final bool highlight;

  final bool dimmed;
  final bool allowDrag;
  final void Function(PlayingCard card)? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget view = PlayingCardView(
      card: card,
      width: width,
      isPlayable: highlight,
      dimmed: dimmed,
      elevated: highlight,
    );
    if (onTap == null) {
      return Semantics(label: card.turkishName, child: view);
    }

    final Widget tappable = Semantics(
      button: true,
      label: card.turkishName,
      child: GestureDetector(
        onTap: isLegal ? () => onTap!(card) : null,
        child: view,
      ),
    );
    if (!allowDrag || !isLegal) {
      return tappable;
    }

    // Dragging is an alternative to tapping, never the only way: the tap
    // handler stays live underneath, so the gesture is a convenience rather
    // than a dexterity requirement.
    return Draggable<PlayingCard>(
      data: card,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: Offset(-width / 2, -width * PlayingCardView.aspectRatio * 0.6),
        child: PlayingCardView(card: card, width: width, elevated: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: view),
      child: tappable,
    );
  }
}
