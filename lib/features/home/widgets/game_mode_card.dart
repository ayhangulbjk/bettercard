import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/game_mode.dart';

/// One of the five large mode buttons on the home screen.
///
/// Each carries its own suit motif and accent so the five read as distinct at
/// a glance, which is what makes the menu usable one-handed without reading
/// every label.
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

    return Semantics(
      button: true,
      label: '${mode.turkishName}. ${mode.turkishTagline}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
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
                _Motif(symbol: style.symbol, color: style.accent),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              mode.turkishName,
                              style: text.titleLarge,
                            ),
                          ),
                          if (!mode.isPlayable) _Badge(label: notPlayableLabel),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(mode.turkishTagline, style: text.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${mode.playerCount} oyuncu'
                        '${mode.hasPartnerships ? '  -  esli' : ''}'
                        '${mode.hasAuction ? '  -  ihaleli' : ''}',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.goldDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Motif extends StatelessWidget {
  const _Motif({required this.symbol, required this.color});

  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceSunken,
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          symbol,
          style: TextStyle(fontSize: 22, color: color, height: 1),
        ),
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
    required this.symbol,
    required this.accent,
    required this.tint,
  });

  final String symbol;
  final Color accent;
  final Color tint;

  static _ModeStyle of(GameMode mode) => switch (mode) {
        GameMode.auctionBatak => const _ModeStyle(
            symbol: '♠',
            accent: AppColors.goldBright,
            tint: Color(0xFF1C4436),
          ),
        GameMode.partnershipBatak => const _ModeStyle(
            symbol: '♣',
            accent: AppColors.success,
            tint: Color(0xFF17463A),
          ),
        GameMode.spadesBatak => const _ModeStyle(
            symbol: '♠',
            accent: AppColors.info,
            tint: Color(0xFF17364A),
          ),
        GameMode.buriedBatak => const _ModeStyle(
            symbol: '♦',
            accent: AppColors.warning,
            tint: Color(0xFF3D3320),
          ),
        GameMode.king => const _ModeStyle(
            symbol: '♥',
            accent: AppColors.danger,
            tint: Color(0xFF42222A),
          ),
      };
}
