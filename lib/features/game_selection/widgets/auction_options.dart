import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/auction_scoring_rules.dart';
import '../../../core/rules/bidding_rules.dart';
import '../../../core/rules/rule_profile.dart';
import 'option_chips.dart';

/// The settings that only a single-contract auction has.
///
/// Three questions, and each is a real disagreement between Turkish tables
/// rather than a preference: who is stuck with a passed-out hand, whether a
/// defender that takes no tricks pays for it, and how long a match runs. Each
/// is frozen into the match's profile when it starts, so changing one here
/// cannot alter a game in progress.
///
/// The scoring *shape* -- classic, Gamyun, per-trick -- is not here. It is a
/// different rule set rather than a setting on one, so it is chosen in the
/// rule-profile list above like any other preset.
final class AuctionOptions extends StatelessWidget {
  const AuctionOptions({
    required this.profile,
    required this.strings,
    required this.onChanged,
    super.key,
  });

  final RuleProfile profile;
  final AppStrings strings;
  final void Function(RuleProfile profile) onChanged;

  /// Hand counts worth offering. Odd numbers, so a match cannot end level on
  /// hands alone.
  static const List<int> _roundOptions = <int>[5, 7, 9, 11, 13];

  static const List<PassOutRule> _passOutOptions = <PassOutRule>[
    PassOutRule.openerMustBid,
    PassOutRule.dealerMustBid,
    PassOutRule.redeal,
  ];

  static const List<DefenderNilPenalty> _nilOptions = <DefenderNilPenalty>[
    DefenderNilPenalty.contractValue,
    DefenderNilPenalty.flat,
    DefenderNilPenalty.none,
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OptionChips<int>(
            title: strings.setupRoundCount,
            options: _roundOptions,
            selected: profile.scoringRules.roundCount,
            labelOf: strings.roundCountOption,
            onChanged: (int rounds) => onChanged(
              profile.copyWith(
                scoringRules: profile.scoringRules.copyWith(roundCount: rounds),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OptionChips<PassOutRule>(
            title: strings.setupPassOutTitle,
            options: _passOutOptions,
            selected: profile.biddingRules.passOutRule,
            labelOf: strings.passOutOption,
            hint: strings.setupPassOutHint(
              profile.biddingRules.effectiveForcedBid,
            ),
            onChanged: (PassOutRule rule) => onChanged(
              profile.copyWith(
                biddingRules: profile.biddingRules.copyWith(passOutRule: rule),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OptionChips<DefenderNilPenalty>(
            title: strings.setupDefenderNilTitle,
            options: _nilOptions,
            selected: profile.auctionScoringRules.defenderNilPenalty,
            labelOf: (DefenderNilPenalty penalty) => strings.defenderNilOption(
              penalty,
              profile.auctionScoringRules.flatNilPenalty,
            ),
            hint: strings.setupDefenderNilHint,
            onChanged: (DefenderNilPenalty penalty) => onChanged(
              profile.copyWith(
                auctionScoringRules: profile.auctionScoringRules
                    .copyWith(defenderNilPenalty: penalty),
              ),
            ),
          ),
        ],
      );
}
