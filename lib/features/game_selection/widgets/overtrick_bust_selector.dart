import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';

/// Picks how many tricks above a kept word sink the hand.
///
/// This is a genuine disagreement between Turkish tables -- some bust on two
/// extras, some on three, some never -- which is why it is a setting on the
/// rule profile rather than a constant, and why it is offered here instead of
/// being chosen for the player. The match freezes whatever is picked, so a
/// later change cannot alter a game in progress.
final class OvertrickBustSelector extends StatelessWidget {
  const OvertrickBustSelector({
    required this.value,
    required this.strings,
    required this.onChanged,
    super.key,
  });

  /// The number of extras that busts, or null for a table that never busts.
  final int? value;

  final AppStrings strings;

  final void Function(int? extras) onChanged;

  /// The thresholds worth offering. Busting on one extra would make a made
  /// word almost unplayable, so it is not among them.
  static const List<int?> _options = <int?>[2, 3, 4, null];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.setupOvertrickBustTitle, style: text.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final int? option in _options)
              ChoiceChip(
                label: Text(
                  option == null
                      ? strings.setupOvertrickBustNever
                      : strings.overtrickBustOption(option),
                ),
                selected: option == value,
                onSelected: (bool selected) {
                  if (selected) {
                    onChanged(option);
                  }
                },
                // Sized and styled like the difficulty chips rather than left
                // to the Material default: the default padding made four
                // short options take three rows, and the default selected
                // tint is a green that fights the felt.
                backgroundColor: AppColors.surfaceElevated,
                selectedColor: AppColors.goldDim,
                labelStyle: text.bodyMedium,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: option == value
                      ? AppColors.goldBright
                      : AppColors.textMuted,
                  width: 0.6,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(strings.setupOvertrickBustHint, style: text.bodySmall),
      ],
    );
  }
}
