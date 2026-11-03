import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// The number the player promises for this hand.
///
/// Shown over the hand rather than over the table: the decision is made by
/// looking at the cards, so the cards stay visible and the picker sits
/// directly above them, inside thumb reach.
///
/// Every legal number is a chip rather than a stepper or a wheel. A promise is
/// a one-shot decision out of about fourteen options, and a chip grid makes
/// all of them reachable in one tap; a stepper would make promising eleven
/// cost eleven taps.
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

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppPanel(
      accent: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.gameplayDeclarePrompt,
            style: text.titleMedium?.copyWith(color: AppColors.goldBright),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.gameplayDeclareHint,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final int value in options)
                _DeclarationChip(
                  // Nil is the one promise that is not a count, so it is
                  // labelled rather than numbered.
                  label: value == 0 ? strings.gameplayNilLabel : '$value',
                  isNil: value == 0,
                  onTap: () => onDeclare(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeclarationChip extends StatelessWidget {
  const _DeclarationChip({
    required this.label,
    required this.isNil,
    required this.onTap,
  });

  final String label;
  final bool isNil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            constraints: BoxConstraints(
              minWidth: isNil ? 0 : AppSpacing.minTapTarget,
              minHeight: AppSpacing.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: AppColors.surfaceSunken,
              border: Border.all(color: AppColors.goldDim, width: 0.8),
            ),
            // Centred through the text rather than through the container's
            // alignment: an aligned container inside a [Wrap] has no width to
            // align within, so it takes the whole row and every chip lands on
            // a line of its own.
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
}
