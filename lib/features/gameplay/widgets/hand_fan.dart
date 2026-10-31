import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/cards/playing_card.dart';
import 'playing_card_view.dart';

/// The player's hand, as an overlapping fan along the bottom edge.
///
/// Overlap is computed from the available width so that 13 or 17 cards fit on
/// a narrow phone without horizontal scrolling: the fan tightens instead of
/// clipping. The right-hand card is always fully visible, which is where the
/// trump sits after sorting.
final class HandFan extends StatelessWidget {
  const HandFan({
    required this.cards,
    this.legalCards = const <PlayingCard>{},
    this.onCardTap,
    this.cardWidth = 62,
    super.key,
  });

  final List<PlayingCard> cards;

  /// Cards that may legally be played. Cards outside this set are veiled.
  /// An empty set means "not this seat's turn", so nothing is highlighted.
  final Set<PlayingCard> legalCards;

  /// Tap handler. Null makes the fan display-only, which is what the preview
  /// screen uses so it cannot pretend to accept a move.
  final void Function(PlayingCard card)? onCardTap;

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool anyLegal = legalCards.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth - 2 * AppSpacing.lg;
        // Spacing between card left edges. Never wider than the card itself
        // (that would leave gaps) and never so tight that the rank is hidden.
        final double step = cards.length == 1
            ? cardWidth
            : ((available - cardWidth) / (cards.length - 1))
                .clamp(cardWidth * 0.34, cardWidth);
        final double totalWidth = cardWidth + step * (cards.length - 1);

        return SizedBox(
          height: cardWidth * PlayingCardView.aspectRatio + AppSpacing.md,
          child: Center(
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (int index = 0; index < cards.length; index++)
                    Positioned(
                      left: index * step,
                      bottom: 0,
                      child: _FanCard(
                        card: cards[index],
                        width: cardWidth,
                        isLegal: legalCards.contains(cards[index]),
                        dimmed: anyLegal && !legalCards.contains(cards[index]),
                        onTap: onCardTap,
                      ),
                    ),
                ],
              ),
            ),
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
    required this.dimmed,
    required this.onTap,
  });

  final PlayingCard card;
  final double width;
  final bool isLegal;
  final bool dimmed;
  final void Function(PlayingCard card)? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget view = PlayingCardView(
      card: card,
      width: width,
      isPlayable: isLegal,
      dimmed: dimmed,
      elevated: isLegal,
    );
    if (onTap == null) {
      return Semantics(label: card.turkishName, child: view);
    }
    return Semantics(
      button: true,
      label: card.turkishName,
      child: GestureDetector(
        onTap: isLegal ? () => onTap!(card) : null,
        child: view,
      ),
    );
  }
}
