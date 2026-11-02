import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/ai/ai_difficulty.dart';
import '../../../core/persistence/app_settings.dart';

/// Difficulty chips.
///
/// Only the levels a policy actually implements can be picked. Baslangic and
/// Normal are the heuristic policy, with and without a documented blunder
/// rate; Zor, Uzman and Efsane need search and have no benchmark entry, so
/// they are shown disabled rather than quietly mapped onto a weaker opponent.
/// See [AiDifficulty.isImplemented] and docs/ROADMAP.md milestone 4.
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
        final bool available = level.isImplemented;
        return ChoiceChip(
          label: Text(level.turkishName),
          selected: selected && available,
          onSelected: available
              ? (bool _) => ref.read(settingsProvider.notifier).update(
                    (AppSettings s) => s.copyWith(aiDifficulty: level),
                  )
              : null,
          backgroundColor: AppColors.surfaceElevated,
          disabledColor: AppColors.surfaceSunken,
          selectedColor: AppColors.goldDim,
          side: BorderSide(
            color: !available
                ? AppColors.textMuted.withValues(alpha: 0.4)
                : (selected ? AppColors.goldBright : AppColors.textMuted),
            width: 0.6,
          ),
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: available ? null : AppColors.textMuted,
              ),
        );
      }).toList(growable: false),
    );
  }
}
