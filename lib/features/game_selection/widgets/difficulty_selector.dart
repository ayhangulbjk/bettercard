import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/ai/ai_difficulty.dart';
import '../../../core/persistence/app_settings.dart';

/// Difficulty chips.
///
/// The levels are selectable and persisted, but milestone 1 ships only the
/// legal-random baseline policy, so the choice does not yet change how
/// opponents play. The AI lab screen states that plainly rather than letting
/// the selector imply strength that does not exist.
final class DifficultySelector extends ConsumerWidget {
  const DifficultySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AiDifficulty current = ref.watch(
      settingsProvider.select((AppSettings s) => s.aiDifficulty),
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: AiDifficulty.values.map((AiDifficulty level) {
        final bool selected = level == current;
        return ChoiceChip(
          label: Text(level.turkishName),
          selected: selected,
          onSelected: (bool _) => ref.read(settingsProvider.notifier).update(
                (AppSettings s) => s.copyWith(aiDifficulty: level),
              ),
          backgroundColor: AppColors.surfaceElevated,
          selectedColor: AppColors.goldDim,
          side: BorderSide(
            color: selected ? AppColors.goldBright : AppColors.textMuted,
            width: 0.6,
          ),
          labelStyle: Theme.of(context).textTheme.bodyMedium,
        );
      }).toList(growable: false),
    );
  }
}
