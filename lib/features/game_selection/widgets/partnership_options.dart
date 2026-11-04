import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/bidding_rules.dart';
import '../../../core/rules/partnership_rules.dart';
import '../../../core/rules/rule_profile.dart';
import '../../../core/rules/scoring_rules.dart';
import 'option_chips.dart';

/// The settings that only a two-team contract has.
///
/// Six questions, and every one of them is a real disagreement between
/// Turkish tables rather than a preference: open or closed partners, who is
/// stuck with a passed-out hand, how many tricks the defending side has to
/// take, where the match ends, and whether the two all-thirteen results are
/// played at all. Each is frozen into the match's profile when it starts, so
/// changing one here cannot alter a game in progress.
///
/// The seventh is not a table rule and is marked as such: letting the person
/// at the device keep their own cards when the deal makes them the open hand
/// is a departure from the classic rule, offered because watching a bot play
/// your thirteen cards is not what everybody wants from a card game.
final class PartnershipOptions extends StatelessWidget {
  const PartnershipOptions({
    required this.profile,
    required this.strings,
    required this.onChanged,
    super.key,
  });

  final RuleProfile profile;
  final AppStrings strings;
  final void Function(RuleProfile profile) onChanged;

  static const List<PartnershipMode> _modeOptions = <PartnershipMode>[
    PartnershipMode.openDummy,
    PartnershipMode.closedPartnership,
  ];

  /// Target scores worth offering, from a short session to a long one.
  static const List<int> _targetOptions = <int>[21, 31, 51, 101];

  static const List<int> _floorOptions = <int>[1, 2, 3];

  static const List<PassOutRule> _passOutOptions = <PassOutRule>[
    PassOutRule.openerMustBid,
    PassOutRule.dealerMustBid,
    PassOutRule.redeal,
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PartnershipRules partnership = profile.partnershipRules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OptionChips<PartnershipMode>(
          title: strings.setupPartnershipModeTitle,
          options: _modeOptions,
          selected: partnership.mode,
          labelOf: strings.partnershipModeOption,
          hint: strings.setupPartnershipModeHint,
          // The override only means anything when there is an open hand to
          // override, so switching to closed partners clears it rather than
          // leaving a setting that silently does nothing.
          onChanged: (PartnershipMode mode) => onChanged(
            profile.copyWith(
              partnershipRules: partnership.copyWith(
                mode: mode,
                humanDummyControlOverride: mode == PartnershipMode.openDummy &&
                    partnership.humanDummyControlOverride,
              ),
            ),
          ),
        ),
        if (partnership.revealsDummy) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            value: partnership.humanDummyControlOverride,
            onChanged: (bool on) => onChanged(
              profile.copyWith(
                partnershipRules:
                    partnership.copyWith(humanDummyControlOverride: on),
              ),
            ),
            title: Text(
              strings.setupDummyControlTitle,
              style: text.bodyMedium,
            ),
            subtitle: Text(
              strings.setupDummyControlHint,
              style: text.bodySmall,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        OptionChips<int>(
          title: strings.setupTargetScore,
          options: _targetOptions,
          selected: profile.scoringRules.targetScore,
          labelOf: strings.targetScoreOption,
          onChanged: (int target) => onChanged(
            profile.copyWith(
              scoringRules: profile.scoringRules.copyWith(
                endCondition: MatchEndCondition.targetScore,
                targetScore: target,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OptionChips<int>(
          title: strings.setupDefenderFloorTitle,
          options: _floorOptions,
          selected: profile.partnershipScoringRules.defenderMinimumTricks,
          labelOf: strings.defenderFloorOption,
          hint: strings.setupDefenderFloorHint,
          onChanged: (int floor) => onChanged(
            profile.copyWith(
              partnershipScoringRules: profile.partnershipScoringRules
                  .copyWith(defenderMinimumTricks: floor),
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
        Text(strings.setupSpecialResultsTitle, style: text.labelSmall),
        _switch(
          text,
          label: strings.setupKingLabel,
          value: profile.partnershipScoringRules.kingEnabled,
          onChanged: (bool on) => onChanged(
            profile.copyWith(
              partnershipScoringRules:
                  profile.partnershipScoringRules.copyWith(kingEnabled: on),
            ),
          ),
        ),
        if (profile.partnershipScoringRules.kingEnabled)
          _switch(
            text,
            label: strings.setupKingEndsMatchLabel,
            value: profile.partnershipScoringRules.kingEndsMatch,
            onChanged: (bool on) => onChanged(
              profile.copyWith(
                partnershipScoringRules:
                    profile.partnershipScoringRules.copyWith(kingEndsMatch: on),
              ),
            ),
          ),
        _switch(
          text,
          label: strings.setupSweepLabel,
          value: profile.partnershipScoringRules.sweepEnabled,
          onChanged: (bool on) => onChanged(
            profile.copyWith(
              partnershipScoringRules:
                  profile.partnershipScoringRules.copyWith(sweepEnabled: on),
            ),
          ),
        ),
      ],
    );
  }

  Widget _switch(
    TextTheme text, {
    required String label,
    required bool value,
    required void Function(bool on) onChanged,
  }) =>
      SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: text.bodyMedium),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
}
