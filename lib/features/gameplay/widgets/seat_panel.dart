import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// One seat: name, avatar initial, how the hand is going for it, and whether
/// it is to move.
///
/// Compact by necessity. In portrait there is no room for a full avatar per
/// seat, so the seat reads as a small badge and the eye stays on the trick in
/// the middle of the table.
///
/// Under the name goes one number: tricks taken. The remaining card count used
/// to sit beside it and was dropped -- it is the same for everyone until
/// somebody runs short, so it cost a line to say nothing. When the mode has a
/// declaration round the line becomes `taken / declared`, because the promise
/// is what the tricks now mean and a player cannot follow the hand without
/// seeing everyone's.
///
/// A side seat is about 80 logical pixels wide, so the name is capped at one
/// line and ellipsised rather than overflowing. That is why the text column
/// sits in an [Expanded] instead of sizing to its natural width.
///
/// [vertical] stacks the badge above the name instead of beside it, which is
/// what the three opponent seats of a four-player table need: side by side
/// there is no width left for a horizontal badge and a readable name (T-1 in
/// docs/ROADMAP.md).
final class SeatPanel extends StatelessWidget {
  const SeatPanel({
    required this.name,
    required this.tricksWon,
    this.isActive = false,
    this.declaration,
    this.awaitingDeclaration = false,
    this.contract,
    this.vertical = false,
    super.key,
  });

  final String name;
  final int tricksWon;

  /// Whether it is this seat's turn.
  final bool isActive;

  /// What this seat promised, or null in a mode without declarations or
  /// before it has spoken.
  final int? declaration;

  /// Whether this seat still owes a declaration, which is shown as a dash so
  /// an empty line does not read as "declared nothing".
  final bool awaitingDeclaration;

  /// Contract summary, when the mode has one.
  final String? contract;

  /// Whether to stack the badge above the name.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (vertical) {
      return _vertical(text);
    }
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
                  _statParts.join('  -  '),
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

  /// Badge above, name and stats below, centred.
  Widget _vertical(TextTheme text) => AppPanel(
        accent: isActive,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _badge(text),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              style: text.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // One stat per line. A side seat is about 80 pixels wide, which
            // is not enough for "0 el - 11 kart" on one line; joined, it
            // ellipsised away the card count.
            for (final String stat in _statParts)
              Text(
                stat,
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );

  Widget _badge(TextTheme text) => Container(
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
      );

  /// The line under the name: tricks taken, against the promise when there is
  /// one.
  List<String> get _statParts => <String>[
        if (declaration != null)
          '$tricksWon / $declaration'
        else if (awaitingDeclaration)
          '-'
        else
          '$tricksWon el',
        if (contract != null) contract!,
      ];
}
