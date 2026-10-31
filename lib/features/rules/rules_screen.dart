import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/rules/game_mode.dart';
import '../gameplay/widgets/felt_background.dart';
import 'widgets/mode_rules_section.dart';

/// Reference for the implemented rule profiles.
///
/// Reads the shipped presets rather than restating them in prose, so the
/// screen cannot drift from what the engine actually enforces. The open
/// questions are listed too: where Turkish tables disagree, this app says so
/// instead of presenting one custom as the rule.
final class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  /// Rule ambiguities carried as explicit open questions. Full discussion in
  /// docs/RULE_PROFILES.md.
  static const List<String> openQuestions = <String>[
    'B-1: İhaleyi tutan fazla el alırsa fazlası puan yazar mı?',
    'B-2: İhale batarsa ceza ihale kadar mı, iki katı mı?',
    'B-3: Koz kesme zorunluluğu her masada var mı?',
    'B-4: Üçlü gömmeli Batak oyununda kaç kart gömülür, gömülen kime yazar?',
    'K-1: King partisinde her oyuncu kaç sözleşme seçer?',
    'K-2: Rıfkı ve Son İki sözleşmeleri standart partiye dahil mi?',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(strings.rulesTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.thumbZoneReserve,
            ),
            children: <Widget>[
              for (final GameMode mode in GameMode.values)
                ModeRulesSection(mode: mode),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.rulesOpenQuestionsTitle, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String question in openQuestions)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(question, style: text.bodyMedium),
                            ),
                          ],
                        ),
                      ),
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
