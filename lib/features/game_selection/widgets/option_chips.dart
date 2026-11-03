import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';

/// A labelled row of mutually exclusive choices.
///
/// Extracted because the setup screen now asks several of these and they have
/// to look identical: a settings page where two questions of the same kind
/// are drawn differently reads as two unrelated things. It also keeps the
/// chip styling in one place, which is what stopped the Material default
/// green tint reappearing every time a selector was added.
final class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String title;
  final List<T> options;
  final T selected;

  /// What to write on the chip for one option.
  final String Function(T option) labelOf;

  final void Function(T option) onChanged;

  /// One short line under the chips, when the choice needs explaining.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: text.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final T option in options)
              ChoiceChip(
                label: Text(labelOf(option)),
                selected: option == selected,
                onSelected: (bool picked) {
                  if (picked) {
                    onChanged(option);
                  }
                },
                backgroundColor: AppColors.surfaceElevated,
                selectedColor: AppColors.goldDim,
                labelStyle: text.bodyMedium,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: option == selected
                      ? AppColors.goldBright
                      : AppColors.textMuted,
                  width: 0.6,
                ),
              ),
          ],
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(hint!, style: text.bodySmall),
        ],
      ],
    );
  }
}
