import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/rule_profile.dart';
import '../../gameplay/widgets/felt_background.dart';

/// A mode's how-to-play guide, as expandable questions.
///
/// Collapsed by default, and that is the point: a player who already knows
/// Batak should see a list of questions they can ignore, not three screens of
/// prose between them and the rule summaries. A player who does not know the
/// mode gets the whole thing one question at a time.
///
/// The answers come from [AppStrings.partnershipGuide] and are written against
/// the [profile] in force, so a guide can never describe a rule the engine is
/// not enforcing -- the numbers in the sentences are read off the profile
/// rather than typed into them.
final class HowToPlaySection extends StatelessWidget {
  const HowToPlaySection({
    required this.title,
    required this.entries,
    super.key,
  });

  /// The guide for Esli Ihaleli Batak under [profile].
  factory HowToPlaySection.partnership({
    required AppStrings strings,
    required RuleProfile profile,
  }) =>
      HowToPlaySection(
        title: strings.rulesHowToPlayTitle,
        entries: strings.partnershipGuide(profile),
      );

  final String title;
  final List<RuleGuideEntry> entries;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppPanel(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Theme(
          // The default divider under every tile turns a twenty-entry list
          // into a ruled ledger; the felt palette reads better without them.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(title, style: text.titleMedium),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            iconColor: AppColors.gold,
            collapsedIconColor: AppColors.textMuted,
            children: <Widget>[
              for (final RuleGuideEntry entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.question,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.goldBright,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(entry.answer, style: text.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
