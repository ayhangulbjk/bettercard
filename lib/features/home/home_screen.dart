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

/// The main menu: the title, the match in progress, the five games, and the
/// four secondary destinations.
///
/// Deliberately not scrollable. The menu is a choice between five things, and
/// a menu that scrolls hides part of that choice -- so the five rows share
/// whatever height the device has instead, each one line tall. That costs the
/// rows their taglines, which is the point: nothing on this screen is here to
/// be read, only to be tapped.
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _Masthead(),
                const ResumeCard(),
                // Expanded per row, so the list fits any height without a
                // scrollbar and without an overflow stripe.
                for (final GameMode mode in GameMode.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: GameModeCard(
                        mode: mode,
                        notPlayableLabel: strings.modeNotPlayableBadge,
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.gameSetup,
                          arguments: mode,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                _SecondaryActions(strings: strings),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Masthead extends ConsumerWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.appTitle, style: text.displaySmall),
        const SizedBox(height: AppSpacing.md),
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
      ],
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      );
}
