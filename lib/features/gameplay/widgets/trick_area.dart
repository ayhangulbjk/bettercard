import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/game_engine/trick/trick.dart';
import 'felt_background.dart';
import 'playing_card_view.dart';

/// The middle of the table: the cards played to the current trick.
///
/// Cards are laid out by the seat that played them rather than by play order,
/// so a glance tells you who contributed what. In portrait the table is taller
/// than it is wide, so the layout is a compact cross rather than a circle.
final class TrickArea extends StatelessWidget {
  const TrickArea({
    required this.trick,
    required this.trumpTitle,
    required this.trumpLabel,
    required this.progressLabel,
    this.cardWidth = 54,
    super.key,
  });

  final Trick trick;

  /// Localised word for trump, e.g. `Koz`.
  final String trumpTitle;

  /// The trump suit's name, or the no-trump label.
  final String trumpLabel;

  /// `El 3 / 13`.
  final String progressLabel;

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: _TrickStatus(
            trumpTitle: trumpTitle,
            trumpLabel: trumpLabel,
            progressLabel: progressLabel,
          ),
        ),
        Center(
          child: trick.isEmpty
              ? const SizedBox.shrink()
              : _PlayedCards(
                  trick: trick,
                  cardWidth: cardWidth,
                ),
        ),
      ],
    );
  }
}

class _TrickStatus extends StatelessWidget {
  const _TrickStatus({
    required this.trumpTitle,
    required this.trumpLabel,
    required this.progressLabel,
  });

  final String trumpTitle;
  final String trumpLabel;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.pill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(progressLabel, style: text.labelSmall),
          const SizedBox(width: AppSpacing.md),
          Container(width: 1, height: 14, color: AppColors.goldDim),
          const SizedBox(width: AppSpacing.md),
          Text('$trumpTitle: ', style: text.bodySmall),
          Text(
            trumpLabel,
            style: text.titleMedium?.copyWith(color: AppColors.goldBright),
          ),
        ],
      ),
    );
  }
}

/// Positions each played card towards the seat that played it.
class _PlayedCards extends StatelessWidget {
  const _PlayedCards({required this.trick, required this.cardWidth});

  final Trick trick;
  final double cardWidth;

  /// Offsets per seat for a four-seat table, in multiples of the card size:
  /// seat 0 below, 1 left, 2 above, 3 right. Seat 0 is the human, at the
  /// bottom of the screen.
  static const List<Offset> _fourSeatOffsets = <Offset>[
    Offset(0, 0.55),
    Offset(-0.78, 0),
    Offset(0, -0.55),
    Offset(0.78, 0),
  ];

  /// Three-seat table: the human below, the other two above left and right.
  static const List<Offset> _threeSeatOffsets = <Offset>[
    Offset(0, 0.55),
    Offset(-0.78, -0.3),
    Offset(0.78, -0.3),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Offset> offsets =
        trick.expectedPlays == 3 ? _threeSeatOffsets : _fourSeatOffsets;
    final double height = cardWidth * PlayingCardView.aspectRatio;

    return SizedBox(
      width: cardWidth * 3.2,
      height: height * 2.3,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final PlayedCard play in trick.plays)
            if (play.seat < offsets.length)
              Transform.translate(
                offset: Offset(
                  offsets[play.seat].dx * cardWidth * 1.3,
                  offsets[play.seat].dy * height * 1.1,
                ),
                child: PlayingCardView(
                  card: play.card,
                  width: cardWidth,
                  isPlayable: false,
                ),
              ),
        ],
      ),
    );
  }
}
