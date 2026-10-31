import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// One opponent seat: name, avatar initial, trick count and turn indicator.
///
/// Compact by necessity. In portrait there is no room for a full avatar per
/// seat, so the seat reads as a small badge and the eye stays on the trick in
/// the middle of the table.
///
/// Three opponent panels share a phone's width, which leaves each one roughly
/// 80 logical pixels, so the text must be allowed to shrink: the name and the
/// stat line are capped at one line and ellipsised rather than overflowing.
/// That is why the text column sits in an [Expanded] instead of sizing to its
/// natural width.
final class SeatPanel extends StatelessWidget {
  const SeatPanel({
    required this.name,
    required this.tricksWon,
    this.isActive = false,
    this.cardsRemaining,
    this.contract,
    super.key,
  });

  final String name;
  final int tricksWon;

  /// Whether it is this seat's turn.
  final bool isActive;

  /// Public card count. Null hides the row.
  final int? cardsRemaining;

  /// Contract summary, when the mode has one.
  final String? contract;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      accent: isActive,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.goldDim : AppColors.surfaceSunken,
              border: Border.all(
                color: isActive ? AppColors.goldBright : AppColors.textMuted,
                width: 0.8,
              ),
            ),
            child: Text(
              name.isEmpty ? '-' : name.substring(0, 1).toUpperCase(),
              style: text.labelLarge?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  <String>[
                    '$tricksWon el',
                    if (cardsRemaining != null) '$cardsRemaining kart',
                    if (contract != null) contract!,
                  ].join('  -  '),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
