import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/rules/game_mode.dart';
import '../../core/statistics/match_record.dart';
import '../../core/statistics/match_statistics.dart';
import '../gameplay/widgets/felt_background.dart';
import 'widgets/statistics_panel.dart';

/// Match statistics, derived from the stored history.
///
/// Every number here comes from finished matches the player actually played.
/// Nothing is estimated, nothing is sampled, and an empty history says so
/// rather than showing a chart of invented data.
final class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final AsyncValue<List<MatchRecord>> history =
        ref.watch(matchHistoryProvider);

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(strings.statisticsTitle),
          actions: <Widget>[
            if ((history.valueOrNull ?? const <MatchRecord>[]).isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: strings.statisticsReset,
                onPressed: () => _confirmReset(context, ref, strings),
              ),
          ],
        ),
        body: SafeArea(
          child: switch (history) {
            AsyncData<List<MatchRecord>>(value: final List<MatchRecord> rows)
                when rows.isEmpty =>
              _Empty(strings: strings),
            AsyncData<List<MatchRecord>>(value: final List<MatchRecord> rows) =>
              _Report(strings: strings, records: rows),
            AsyncError<List<MatchRecord>>() => _Empty(strings: strings),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final bool? reset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(strings.statisticsReset),
        content: Text(strings.statisticsResetConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.statisticsReset),
          ),
        ],
      ),
    );
    if (reset ?? false) {
      await ref.read(matchHistoryRepositoryProvider).clear();
      ref.invalidate(matchHistoryProvider);
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.insights_rounded,
                size: 48,
                color: AppColors.goldDim,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                strings.statisticsEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

class _Report extends StatelessWidget {
  const _Report({required this.strings, required this.records});

  final AppStrings strings;
  final List<MatchRecord> records;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final MatchStatistics overall = MatchStatistics.fromRecords(records);
    final Map<String, MatchStatistics> byMode = MatchStatistics.byMode(records);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.thumbZoneReserve,
      ),
      children: <Widget>[
        Text(strings.statisticsOverall, style: text.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        StatisticsPanel(strings: strings, statistics: overall),
        if (byMode.length > 1) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(strings.statisticsByMode, style: text.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final MapEntry<String, MatchStatistics> entry in byMode.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: StatisticsPanel(
                strings: strings,
                statistics: entry.value,
                title: _modeName(entry.key),
                compact: true,
              ),
            ),
        ],
      ],
    );
  }

  /// Mode ids are stored rather than enum indices, so a record can outlive a
  /// reordering -- and an id this build no longer knows is shown as itself
  /// instead of crashing the screen.
  static String _modeName(String modeId) {
    for (final GameMode mode in GameMode.values) {
      if (mode.id == modeId) {
        return mode.turkishShortName;
      }
    }
    return modeId;
  }
}
