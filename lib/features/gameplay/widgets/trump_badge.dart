import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/cards/suit.dart';
import 'suit_pip.dart';

/// The hand's trump, as a pip in a round badge on the felt.
///
/// A line of text at the top of the screen said the same thing and was read
/// once, at the start of the hand, and then ignored. A pip beside the table
/// is read the way a player checks the turned card at a real table: by
/// glancing, mid-trick, without leaving the cards. The Turkish name goes to
/// the semantics label, so a screen reader still says "Koz: Maca".
final class TrumpBadge extends StatelessWidget {
  const TrumpBadge({
    required this.trump,
    required this.label,
    this.size = 44,
    super.key,
  });

  /// The trump suit, or null in a no-trump contract.
  final Suit? trump;

  /// `Koz: Maca`, or the no-trump label. Semantics only.
  final String label;

  final double size;

  @override
  Widget build(BuildContext context) {
    final Suit? suit = trump;
    return Semantics(
      label: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceElevated,
          border: Border.all(color: AppColors.goldDim, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x4D000000), blurRadius: 6),
          ],
        ),
        child: suit == null
            // A no-trump hand is a fact worth stating, not an empty badge.
            ? Icon(
                Icons.block_rounded,
                size: size * 0.46,
                color: AppColors.textMuted,
              )
            : SuitPip(
                suit: suit,
                size: size * 0.52,
                color: suit.isRed ? AppColors.cardRed : AppColors.textPrimary,
              ),
      ),
    );
  }
}
