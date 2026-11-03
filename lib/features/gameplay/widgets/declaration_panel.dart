import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// The number the player promises for this hand.
///
/// Deliberately bare: a heading and the numbers. Every legal number is a round
/// chip rather than a stepper or a wheel, because a promise is a one-shot
/// choice out of about fourteen and a chip grid makes all of them reachable in
/// one tap, where a stepper would make promising eleven cost eleven taps. The
/// explanatory sentence that used to sit under the heading is gone: it said
/// the same thing every hand, and the hand is what the player is trying to
/// look at.
///
/// "El almaz" is a wide button under the grid instead of a chip inside it. It
/// is the one promise that is not a count, so it does not belong in a row of
/// counts.
final class DeclarationPanel extends StatelessWidget {
  const DeclarationPanel({
    required this.options,
    required this.strings,
    required this.onDeclare,
    super.key,
  });

  /// The legal numbers, straight from the engine.
  final List<int> options;

  final AppStrings strings;

  final void Function(int tricks) onDeclare;

  /// Chips per row. Five keeps 1-13 to three rows on a portrait phone while
  /// each chip stays above the minimum tap target.
  static const int _perRow = 5;

  static const double _chipSize = 52;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<int> counts =
        options.where((int value) => value > 0).toList(growable: false);
    final bool allowNil = options.contains(0);

    return AppPanel(
      accent: true,
      borderRadius: AppRadius.sheet,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.gameplayDeclarePrompt,
            style: text.titleMedium?.copyWith(color: AppColors.goldBright),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          for (int start = 0; start < counts.length; start += _perRow)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final int value in counts.skip(start).take(_perRow))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: _DeclarationChip(
                        label: '$value',
                        onTap: () => onDeclare(value),
                      ),
                    ),
                ],
              ),
            ),
          if (allowNil) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: _chipSize * _perRow + AppSpacing.sm * _perRow,
              child: OutlinedButton(
                onPressed: () => onDeclare(0),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
                  side: const BorderSide(color: AppColors.goldDim),
                  shape: const StadiumBorder(),
                ),
                child: Text(strings.gameplayNilLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeclarationChip extends StatelessWidget {
  const _DeclarationChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceSunken,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.goldDim, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: DeclarationPanel._chipSize,
            height: DeclarationPanel._chipSize,
            // Centred through the text rather than through the container's
            // alignment: an aligned container inside a flexible parent has no
            // width to align within and takes the whole row.
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );
}
