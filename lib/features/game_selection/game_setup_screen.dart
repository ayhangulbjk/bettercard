import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/ai/ai_difficulty.dart';
import '../../core/rules/declaration_rules.dart';
import '../../core/rules/game_mode.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/rule_validation.dart';
import '../gameplay/match_controller.dart';
import '../gameplay/widgets/felt_background.dart';
import '../gameplay/widgets/placeholder_banner.dart';
import 'widgets/difficulty_selector.dart';
import 'widgets/overtrick_bust_selector.dart';
import 'widgets/rule_issue_list.dart';
import 'widgets/rule_profile_option.dart';

/// Pre-match configuration: rule profile, difficulty, and a rule audit.
///
/// The rule audit is shown, not hidden: the product requirement is that only
/// logically consistent rule combinations are playable, so the validator's
/// verdict belongs in front of the player rather than in a log.
final class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  RuleProfile? _selected;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final List<RuleProfile> presets =
        ref.watch(rulePresetsProvider(widget.mode));
    final RuleProfile profile = _selected ?? presets.first;
    final List<RuleIssue> issues = RuleProfileValidator.validate(profile);
    final bool consistent = !issues.any((RuleIssue issue) => issue.isError);
    final TextTheme text = Theme.of(context).textTheme;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.mode.turkishName)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.thumbZoneReserve,
            ),
            children: <Widget>[
              if (!widget.mode.isPlayable) ...<Widget>[
                PlaceholderBanner(
                  title: strings.modeNotPlayableBadge,
                  message: strings.modeNotPlayableExplanation,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text(strings.setupRuleProfile, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              ...presets.map(
                (RuleProfile preset) => RuleProfileOption(
                  profile: preset,
                  selected: preset.id == profile.id,
                  onSelect: () => setState(() => _selected = preset),
                ),
              ),
              if (profile.declarationRules.enabled) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                OvertrickBustSelector(
                  value: profile.declarationRules.overtrickBustThreshold,
                  strings: strings,
                  onChanged: (int? extras) => setState(
                    () => _selected = profile.copyWith(
                      declarationRules: profile.declarationRules.copyWith(
                        overtrickBustThreshold: extras,
                        clearOvertrickBustThreshold: extras == null,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _ProfileFacts(profile: profile, strings: strings),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.setupDifficulty, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              const DifficultySelector(),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.setupRuleIssuesTitle, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              RuleIssueList(
                issues: issues,
                emptyMessage: strings.setupNoIssues,
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                // A playable mode opens a real table; the rest can only be
                // previewed, and the button says which one you are getting.
                onPressed: consistent ? () => unawaited(_open(profile)) : null,
                child: Text(
                  widget.mode.isPlayable
                      ? strings.setupStart
                      : strings.previewTableTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Derived facts about the selected profile, so the player can see what the
/// rule set actually implies before starting.
extension on _GameSetupScreenState {
  /// Starts the match, or opens the preview for a mode that has no lifecycle
  /// yet.
  ///
  /// The match is started before navigating so the table screen needs no
  /// arguments and so the rule profile it freezes is exactly the one audited
  /// on this screen.
  Future<void> _open(RuleProfile profile) async {
    if (!widget.mode.isPlayable) {
      await Navigator.of(context).pushNamed(
        AppRoutes.tablePreview,
        arguments: widget.mode,
      );
      return;
    }

    // Starting a match overwrites the autosave, and the half-finished match it
    // replaces is the player's, not ours to discard quietly.
    if (ref.read(savedMatchProvider).valueOrNull != null &&
        !await _confirmOverwrite()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final AiDifficulty difficulty = ref.read(settingsProvider).aiDifficulty;
    ref.read(matchProvider.notifier).start(
          profile: profile,
          difficulty: difficulty,
        );
    await Navigator.of(context).pushNamed(AppRoutes.match);
  }

  Future<bool> _confirmOverwrite() async {
    final AppStrings strings = ref.read(stringsProvider);
    final bool? overwrite = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(strings.setupOverwriteTitle),
        content: Text(strings.setupOverwriteMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.setupOverwriteAction),
          ),
        ],
      ),
    );
    return overwrite ?? false;
  }
}

class _ProfileFacts extends StatelessWidget {
  const _ProfileFacts({required this.profile, required this.strings});

  final RuleProfile profile;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row(text, strings.setupPlayerCount, '${profile.playerCount}'),
          _row(text, strings.setupTricksPerHand, '${profile.tricksPerHand}'),
          _row(
            text,
            strings.gameplayTrumpLabel,
            profile.fixedTrump?.turkishName ??
                (profile.biddingRules.declarerNamesTrump
                    ? 'İhaleyi alan seçer'
                    : strings.gameplayNoTrump),
          ),
          if (profile.biddingRules.hasAuction)
            _row(
              text,
              'İhale aralığı',
              '${profile.biddingRules.minimumBid} - '
                  '${profile.biddingRules.maximumBid}',
            ),
          if (profile.declarationRules.enabled) ...<Widget>[
            _row(
              text,
              strings.setupDeclarationStake,
              '${profile.declarationRules.pointsPerDeclaredTrick}',
            ),
            _row(
              text,
              strings.setupOvertrickValue,
              profile.declarationRules.overtrickRule == OvertrickRule.scored
                  ? '${profile.declarationRules.pointsPerOvertrick}'
                  : '0',
            ),
            _row(
              text,
              strings.setupOvertrickBustTitle,
              profile.declarationRules.overtrickBustThreshold == null
                  ? strings.setupOvertrickBustNever
                  : strings.overtrickBustOption(
                      profile.declarationRules.overtrickBustThreshold!,
                    ),
            ),
          ],
          if (profile.buryRules.enabled)
            _row(text, 'Gömülecek kart', '${profile.buryRules.cardsToBury}'),
          if (profile.kingRules != null)
            _row(text, 'Toplam el', '${profile.kingRules!.totalHands}'),
        ],
      ),
    );
  }

  Widget _row(TextTheme text, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: text.bodyMedium)),
            Text(value, style: text.titleMedium),
          ],
        ),
      );
}
