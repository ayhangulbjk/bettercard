import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';
import 'table_layout.dart';

/// One seat: its name, how the hand is going for it, and whether it is to
/// move.
///
/// Compact by necessity. In portrait there is no room for a full avatar per
/// seat, so a seat is its name and its trick count and nothing else, and the
/// eye stays on the trick in the middle of the table. An initial in a circle
/// used to sit in front of the name; it was removed because it repeated the
/// first letter of the word next to it.
///
/// Under the name goes one number: tricks taken. The remaining card count used
/// to sit beside it and was dropped -- it is the same for everyone until
/// somebody runs short, so it cost a line to say nothing. When the mode has a
/// declaration round the line becomes `taken / declared`, because the promise
/// is what the tricks now mean and a player cannot follow the hand without
/// seeing everyone's.
///
/// [edge] decides the shape. The bottom and top seats are horizontal pills.
/// The two side seats are narrow rails whose content is turned a quarter turn
/// so the name reads along the edge: side by side with the trick, a
/// horizontal panel wide enough for a Turkish name would take a third of a
/// portrait phone's width away from the cards (T-1 in docs/ROADMAP.md).
final class SeatPanel extends StatelessWidget {
  const SeatPanel({
    required this.name,
    required this.tricksWon,
    required this.edge,
    this.isActive = false,
    this.declaration,
    this.awaitingDeclaration = false,
    this.contract,
    this.isPartner = false,
    super.key,
  });

  final String name;
  final int tricksWon;

  /// Which edge of the table this seat sits on.
  final SeatEdge edge;

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

  /// Whether this seat is the player's partner.
  ///
  /// A partnership table has to be readable at a glance -- which of the three
  /// other chairs is on my side -- and in portrait there is no room for a
  /// label saying so. A tint on the name is enough, and it costs nothing the
  /// solo modes would notice, since nobody is a partner there.
  final bool isPartner;

  bool get _isRail => edge == SeatEdge.left || edge == SeatEdge.right;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return _isRail ? _rail(text) : _pill(text);
  }

  /// A thin vertical rail, read a quarter turn round.
  ///
  /// The left rail reads bottom to top and the right one top to bottom, so
  /// both run away from the player and towards the far edge, the way the
  /// names on a real table face the person sitting there.
  Widget _rail(TextTheme text) => SizedBox(
        height: TableGeometry.sideSeatHeight,
        child: AppPanel(
          accent: isActive,
          borderRadius: AppRadius.pill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.md,
          ),
          child: RotatedBox(
            quarterTurns: edge == SeatEdge.left ? 3 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    name,
                    style: text.bodyMedium?.copyWith(color: _nameColour),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _statParts.join('  '),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );

  /// A horizontal pill, for the player's own seat and the one across.
  Widget _pill(TextTheme text) => AppPanel(
        accent: isActive,
        borderRadius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                name,
                style: text.titleMedium?.copyWith(color: _nameColour),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _statParts.join('  '),
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  /// The seat's name colour: lit while it is to move, tinted for a partner,
  /// plain otherwise.
  Color get _nameColour {
    if (isActive) {
      return AppColors.goldBright;
    }
    return isPartner ? AppColors.legalMoveGlow : AppColors.textPrimary;
  }

  /// The line beside the name: tricks taken, against the promise when there
  /// is one.
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
