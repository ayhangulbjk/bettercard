import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/playing_card.dart';
import 'suit_pip.dart';

/// A single card face or back, drawn with widgets rather than from a bitmap.
///
/// Procedural rendering is a deliberate milestone-1 choice: it keeps the app
/// asset-free (so nothing has to be downloaded, ever), scales crisply to any
/// density, and lets card fronts and backs be themed by changing colours
/// rather than shipping a new sprite sheet. Real illustrated faces can replace
/// this later behind the same widget API.
final class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.card,
    this.width = 64,
    this.faceUp = true,
    this.isPlayable = true,
    this.dimmed = false,
    this.elevated = false,
    super.key,
  });

  /// A face-down card.
  const PlayingCardView.back({double width = 64, Key? key})
      : this(card: null, width: width, faceUp: false, key: key);

  /// The card to show. Null renders a back.
  final PlayingCard? card;

  final double width;
  final bool faceUp;

  /// Whether this card is a legal play. Drives the highlight ring.
  final bool isPlayable;

  /// Whether to veil the card because it cannot be played now.
  final bool dimmed;

  /// Whether to lift the card, used for the card under the cursor.
  final bool elevated;

  /// Standard playing-card proportion.
  static const double aspectRatio = 1.45;

  double get height => width * aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, elevated ? -10 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: <BoxShadow>[
          BoxShadow(
            // Literal ARGB rather than withOpacity/withValues: the former is
            // deprecated on new Flutter, the latter absent on older ones.
            color: elevated ? const Color(0x73000000) : const Color(0x4D000000),
            blurRadius: elevated ? 12 : 6,
            offset: Offset(0, elevated ? 6 : 3),
          ),
        ],
        border: isPlayable && faceUp
            ? Border.all(color: AppColors.legalMoveGlow, width: 1.5)
            : Border.all(color: Colors.black26, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (faceUp && card != null) _Face(card: card!, width: width),
            if (!faceUp || card == null) const _Back(),
            if (dimmed) const ColoredBox(color: AppColors.illegalMoveVeil),
          ],
        ),
      ),
    );
  }
}

/// The face: a watermark pip in the middle and the index in both corners.
///
/// The index is printed twice, upright at the top left and turned around at
/// the bottom right, exactly as a real card is. On a table that is a
/// convenience; here it is a requirement, because a card thrown into the
/// middle is overlapped by the ones thrown after it and only one of its two
/// corners survives. With a single index, whichever card lands underneath
/// becomes unreadable.
class _Face extends StatelessWidget {
  const _Face({required this.card, required this.width});

  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Color ink = card.suit.isRed ? AppColors.cardRed : AppColors.cardBlack;
    final double centreSize = width * 0.58;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.cardFace, AppColors.cardFaceShadow],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.06),
        child: Stack(
          children: <Widget>[
            // Behind both indices, so neither is ever veiled by it.
            Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.16,
                child: SuitPip(
                  suit: card.suit,
                  size: centreSize,
                  color: ink,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: _Index(card: card, width: width, ink: ink),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.rotate(
                angle: math.pi,
                child: _Index(card: card, width: width, ink: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rank over pip: one corner index.
class _Index extends StatelessWidget {
  const _Index({required this.card, required this.width, required this.ink});

  final PlayingCard card;
  final double width;
  final Color ink;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            card.rank.shortLabel,
            style: TextStyle(
              fontSize: width * 0.32,
              height: 1,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          SuitPip(suit: card.suit, size: width * 0.24, color: ink),
        ],
      );
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.cardBackPrimary,
              AppColors.cardBackPattern,
              AppColors.cardBackPrimary,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.diamond_outlined,
            color: AppColors.goldDim,
            size: 20,
          ),
        ),
      );
}
