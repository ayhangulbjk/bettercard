import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/rules/game_mode.dart';
import '../../../core/rules/rule_presets.dart';
import '../../../core/rules/rule_profile.dart';
import '../../gameplay/widgets/felt_background.dart';

/// One mode's rule presets, summarised from the shipped profiles.
final class ModeRulesSection extends StatelessWidget {
  const ModeRulesSection({required this.mode, super.key});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<RuleProfile> presets = RulePresets.forMode(mode);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(mode.turkishName, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(mode.turkishTagline, style: text.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final RuleProfile profile in presets)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(profile.turkishName, style: text.titleMedium),
                    Text(_summarise(profile), style: text.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the summary line from the profile itself, so it cannot disagree
  /// with what the engine enforces.
  static String _summarise(RuleProfile profile) => <String>[
        '${profile.playerCount} oyuncu',
        '${profile.tricksPerHand} el',
        if (profile.biddingRules.hasAuction)
          'ihale ${profile.biddingRules.minimumBid}-'
              '${profile.biddingRules.maximumBid}',
        if (profile.fixedTrump != null)
          'koz ${profile.fixedTrump!.turkishName}',
        if (profile.trickRules.mustPlayTrumpWhenVoid) 'koz kesme zorunlu',
        if (profile.trickRules.mustOvertrumpWhenPossible) 'ustune koz zorunlu',
        if (profile.buryRules.enabled)
          '${profile.buryRules.cardsToBury} kart gomme',
        if (profile.kingRules != null)
          '${profile.kingRules!.totalHands} el parti',
      ].join('  -  ');
}
