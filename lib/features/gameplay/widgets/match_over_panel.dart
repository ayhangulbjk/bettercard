import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// The end of a match: who won, the final score, and what to do next.
///
/// Drawn over the table rather than on its own screen, so the last trick and
/// the final totals stay in view behind it.
final class MatchOverPanel extends StatelessWidget {
  const MatchOverPanel({
    required this.strings,
    required this.headline,
    required this.detail,
    required this.seatNames,
    required this.totals,
    required this.onRematch,
    required this.onLeave,
    super.key,
  });

  final AppStrings strings;

  /// `Kazandiniz!` or the neutral result line.
  final String headline;

  /// Who took the match, spelled out for every outcome including a tie.
  final String detail;

  final List<String> seatNames;
  final List<int> totals;
  final VoidCallback onRematch;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ColoredBox(
      color: const Color(0xB3000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppPanel(
            accent: true,
            borderRadius: AppRadius.sheet,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  strings.gameplayMatchOverTitle,
                  style: text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    color: AppColors.goldBright,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (int seat = 0; seat < totals.length; seat++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            seat < seatNames.length ? seatNames[seat] : '',
                            style: text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${totals[seat]}', style: text.titleMedium),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRematch,
                    child: Text(strings.gameplayRematch),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLeave,
                    child: Text(strings.commonBack),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
