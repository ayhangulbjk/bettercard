import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/suit.dart';
import '../../../core/rules/game_mode.dart';
import '../../gameplay/widgets/suit_pip.dart';

/// One of the five mode buttons on the home screen.
///
/// One line, one name. The menu's job is to get out of the way: a player who
/// opens the app knows which game they want, so a tagline and a player count
/// on every row would be text to skip past rather than information. What the
/// row keeps is the suit motif and accent, which is what makes the five read
/// as distinct without reading any of them.
///
/// The name is the mode's short name, the one a player says out loud. The
/// formal name ("Herkes Tek Ihaleli Batak") does not fit a phone's width
/// beside a badge, and a name cut off mid-word is worse than a shorter one;
/// the setup screen that opens from here carries the full name.
///
/// A mode with no table yet is drawn dimmed as well as badged. The badge
/// says it, but a row that looks exactly like the playable ones invites the
/// tap anyway; dimming answers the question before it is asked. It stays
/// tappable, because the setup screen behind it still shows the rules and a
/// table preview -- it is unfinished, not off limits.
final class GameModeCard extends StatelessWidget {
  const GameModeCard({
    required this.mode,
    required this.notPlayableLabel,
    required this.onTap,
    super.key,
  });

  final GameMode mode;

  /// Badge text shown while the mode's lifecycle is unimplemented.
  final String notPlayableLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final _ModeStyle style = _ModeStyle.of(mode);
    final bool ready = mode.isPlayable;

    return Semantics(
      button: true,
      enabled: ready,
      label: '${mode.turkishName}. ${mode.turkishTagline}',
      child: Opacity(
        // Dimmed, not disabled: the row still opens its rules and preview.
        opacity: ready ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.panel),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[style.tint, AppColors.surfaceElevated],
                ),
                border: Border.all(color: const Color(0x26FFFFFF), width: 0.6),
              ),
              child: Row(
                children: <Widget>[
                  _Motif(suit: style.suit, color: style.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      mode.turkishShortName,
                      style: text.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!mode.isPlayable) ...<Widget>[
                    _Badge(label: notPlayableLabel),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.goldDim,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Motif extends StatelessWidget {
  const _Motif({required this.suit, required this.color});

  /// The mode's emblem. Painted rather than typed, for the reason in
  /// docs/DECISIONS.md D-16: the Unicode pips are not in every font.
  final Suit suit;

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceSunken,
          border: Border.all(color: color, width: 1),
        ),
        child: SuitPip(suit: suit, size: 17, color: color),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x33D9A441),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.warning, width: 0.6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.warning,
          ),
        ),
      );
}

/// Per-mode visual identity.
class _ModeStyle {
  const _ModeStyle({
    required this.suit,
    required this.accent,
    required this.tint,
  });

  final Suit suit;
  final Color accent;
  final Color tint;

  static _ModeStyle of(GameMode mode) => switch (mode) {
        GameMode.auctionBatak => const _ModeStyle(
            suit: Suit.spades,
            accent: AppColors.goldBright,
            tint: Color(0xFF1C4436),
          ),
        GameMode.partnershipBatak => const _ModeStyle(
            suit: Suit.clubs,
            accent: AppColors.success,
            tint: Color(0xFF17463A),
          ),
        GameMode.spadesBatak => const _ModeStyle(
            suit: Suit.spades,
            accent: AppColors.info,
            tint: Color(0xFF17364A),
          ),
        GameMode.buriedBatak => const _ModeStyle(
            suit: Suit.diamonds,
            accent: AppColors.warning,
            tint: Color(0xFF3D3320),
          ),
        GameMode.king => const _ModeStyle(
            suit: Suit.hearts,
            accent: AppColors.danger,
            tint: Color(0xFF42222A),
          ),
      };
}
