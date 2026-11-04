import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/playing_card.dart';
import 'felt_background.dart';
import 'hand_fan.dart';

/// The open hand, drawn at the seat it belongs to.
///
/// In acik esli Batak the declarer's partner lays its thirteen cards face up
/// and the declarer plays them. They are drawn across the far edge of the
/// table rather than anywhere else for one reason: they are that seat's
/// cards, and a player has to be able to tell at a glance which hand a card
/// is coming out of. Putting them in a second fan next to the player's own
/// would make the two indistinguishable at the moment it matters most.
///
/// Small cards, one row. Thirteen cards at this width still show their corner
/// index, which is the only thing that has to survive -- the player is reading
/// the hand, not admiring it, and the felt below needs the space.
///
/// It is tappable only when the person at the device is the one choosing for
/// this hand. When a bot is the declarer the same cards are shown and nothing
/// responds, which is correct and is why [caption] exists to say so.
final class DummyHandView extends StatelessWidget {
  const DummyHandView({
    required this.cards,
    required this.caption,
    this.legalCards = const <PlayingCard>{},
    this.onCardTap,
    this.showHints = true,
    super.key,
  });

  /// One entry per slot the hand was dealt; null where the card is gone.
  ///
  /// Slots rather than a plain list for the same reason the player's own fan
  /// uses them: a hand that re-flowed after every trick would move the card
  /// the player was about to tap.
  final List<PlayingCard?> cards;

  /// `Eşiniz Defne - açık el` or `Siz - kartlarınızı Defne oynuyor`.
  final String caption;

  /// Cards that may legally be played from this hand right now. Empty when it
  /// is not this hand's turn, or when the player is not the one choosing.
  final Set<PlayingCard> legalCards;

  final void Function(PlayingCard card)? onCardTap;

  final bool showHints;

  /// Card width for the open hand.
  ///
  /// Narrower than the player's own fan. Thirteen of these fit one row on a
  /// portrait phone with every index legible, which keeps the open hand to a
  /// single band across the far edge.
  static const double cardWidth = 38;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      accent: onCardTap != null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            caption,
            style: text.labelSmall?.copyWith(
              color: onCardTap != null
                  ? AppColors.goldBright
                  : AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          HandFan(
            cards: cards,
            cardWidth: cardWidth,
            legalCards: legalCards,
            showHints: showHints,
            onCardTap: onCardTap,
          ),
        ],
      ),
    );
  }
}
