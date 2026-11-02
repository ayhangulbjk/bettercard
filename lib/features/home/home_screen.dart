import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/rules/game_mode.dart';
import '../gameplay/widgets/felt_background.dart';
import 'widgets/game_mode_card.dart';
import 'widgets/resume_card.dart';

/// The main menu.
///
/// Five large mode selections dominate the screen; everything else is a small
/// row of secondary destinations at the bottom, inside thumb reach. The whole
/// screen scrolls so that a large system font or a short device cannot clip
/// the fifth mode.
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Masthead(strings: strings),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: ResumeCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                sliver: SliverList.separated(
                  itemCount: GameMode.values.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final GameMode mode = GameMode.values[index];
                    return GameModeCard(
                      mode: mode,
                      notPlayableLabel: strings.modeNotPlayableBadge,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.gameSetup,
                        arguments: mode,
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.thumbZoneReserve,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Shown only while something still carries the badge,
                      // so the footer stops claiming the whole app is
                      // unfinished once a mode is playable.
                      if (GameMode.values
                          .any((GameMode mode) => !mode.isPlayable))
                        Text(
                          strings.homeSomeModesNotReady,
                          style: text.bodySmall,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      _SecondaryActions(strings: strings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(strings.appTitle, style: text.displaySmall),
            ),
            const _OfflinePill(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(strings.appTagline, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.goldDim,
                Color(0x00000000),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(strings.homePlayTitle, style: text.labelSmall),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AppStrings strings = ref.watch(stringsProvider);
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.goldDim, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 12,
                  color: AppColors.goldDim,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  strings.homeOfflineBadge,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        },
      );
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _Chip(
            icon: Icons.settings_rounded,
            label: strings.homeSettings,
            route: AppRoutes.settings,
          ),
          _Chip(
            icon: Icons.menu_book_rounded,
            label: strings.homeRules,
            route: AppRoutes.rules,
          ),
          _Chip(
            icon: Icons.bar_chart_rounded,
            label: strings.homeStatistics,
            route: AppRoutes.statistics,
          ),
          _Chip(
            icon: Icons.science_rounded,
            label: strings.homeAiLab,
            route: AppRoutes.aiLab,
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pushNamed(route),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      );
}
