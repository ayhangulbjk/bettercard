import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/persistence/saved_match.dart';
import '../../gameplay/match_controller.dart';
import '../../gameplay/widgets/felt_background.dart';

/// "Devam Et": the match waiting on disk, if there is one.
///
/// Shows nothing at all when there is no save, rather than a disabled button.
/// A control that is present but dead invites the question of what is wrong
/// with it; absence answers it.
final class ResumeCard extends ConsumerWidget {
  const ResumeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SavedMatch?> saved = ref.watch(savedMatchProvider);
    final SavedMatch? match = saved.valueOrNull;
    if (match == null) {
      // Also the loading case: the card appearing a frame late is better than
      // the list jumping around a placeholder.
      return const SizedBox.shrink();
    }

    final AppStrings strings = ref.watch(stringsProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppPanel(
        accent: true,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _resume(context, ref, match),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppColors.goldBright,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.homeContinueMatch,
                        style: text.titleMedium?.copyWith(
                          color: AppColors.goldBright,
                        ),
                      ),
                      Text(
                        strings.resumeSummary(
                          match.ruleProfile.mode.turkishShortName,
                          match.handsPlayed + 1,
                          match.scores.isEmpty ||
                                  match.humanSeat >= match.scores.length
                              ? 0
                              : match.scores[match.humanSeat],
                        ),
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  /// Opens the table, unless the save turns out not to replay.
  ///
  /// A save that fails validation is dropped by the controller, which
  /// invalidates the provider, so the card removes itself rather than
  /// bouncing the player to an empty table.
  void _resume(BuildContext context, WidgetRef ref, SavedMatch match) {
    if (ref.read(matchProvider.notifier).resume(match)) {
      Navigator.of(context).pushNamed(AppRoutes.match);
    }
  }
}
