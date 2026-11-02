import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/ai_decision_service.dart';
import '../core/persistence/app_settings.dart';
import '../core/persistence/saved_match.dart';
import '../core/persistence/settings_repository.dart';
import '../core/rules/game_mode.dart';
import '../core/rules/rule_presets.dart';
import '../core/rules/rule_profile.dart';
import '../core/statistics/match_record.dart';
import '../core/statistics/match_statistics.dart';
import '../platform/file_repositories.dart';
import '../platform/json_file_store.dart';
import 'l10n/app_strings.dart';
import 'l10n/strings_tr.dart';

/// Where the app may write files, or null for memory-only storage.
///
/// `main` overrides this with the platform's application-support directory.
/// It stays null everywhere else, which is deliberate: a widget test, a
/// screenshot capture or a headless run then touches no disk at all and cannot
/// inherit state from a previous run.
final Provider<JsonFileStore?> fileStoreProvider =
    Provider<JsonFileStore?>((ref) => null);

/// Where preferences are stored.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) {
  final JsonFileStore? store = ref.watch(fileStoreProvider);
  return store == null
      ? InMemorySettingsRepository()
      : FileSettingsRepository(store);
});

/// Where the match in progress is stored.
final Provider<MatchArchive> matchArchiveProvider =
    Provider<MatchArchive>((ref) {
  final JsonFileStore? store = ref.watch(fileStoreProvider);
  return store == null ? InMemoryMatchArchive() : FileMatchArchive(store);
});

/// Where finished matches are stored.
final Provider<MatchHistoryRepository> matchHistoryRepositoryProvider =
    Provider<MatchHistoryRepository>((ref) {
  final JsonFileStore? store = ref.watch(fileStoreProvider);
  return store == null
      ? InMemoryMatchHistoryRepository()
      : FileMatchHistoryRepository(store);
});

/// The match waiting to be resumed, if any.
///
/// Invalidated by the match controller whenever it writes or clears a save, so
/// the home screen's resume card follows the real file rather than a guess.
final FutureProvider<SavedMatch?> savedMatchProvider =
    FutureProvider<SavedMatch?>(
  (ref) => ref.watch(matchArchiveProvider).load(),
);

/// Every finished match, oldest first.
final FutureProvider<List<MatchRecord>> matchHistoryProvider =
    FutureProvider<List<MatchRecord>>(
  (ref) => ref.watch(matchHistoryRepositoryProvider).load(),
);

/// Aggregated statistics over [matchHistoryProvider].
final FutureProvider<MatchStatistics> statisticsProvider =
    FutureProvider<MatchStatistics>((ref) async {
  final List<MatchRecord> records =
      await ref.watch(matchHistoryProvider.future);
  return MatchStatistics.fromRecords(records);
});

/// Current preferences.
final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Owns the settings value and writes every change through to storage.
///
/// The initial value is the defaults, replaced once the asynchronous load
/// completes. Starting from defaults rather than a loading state keeps the
/// first frame instant, which is what the low-perceived-latency requirement
/// asks for on a cold start.
final class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    unawaited(_hydrate());
    return AppSettings.defaults;
  }

  Future<void> _hydrate() async {
    final AppSettings loaded =
        await ref.read(settingsRepositoryProvider).load();
    if (loaded != state) {
      state = loaded;
    }
  }

  /// Applies [change] and persists the result.
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final AppSettings next = change(state);
    if (next == state) {
      return;
    }
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

/// Localised copy for the active locale.
///
/// Only Turkish exists today. The switch is the extension point: adding
/// English means one more arm and one more implementation of AppStrings.
final Provider<AppStrings> stringsProvider = Provider<AppStrings>((ref) {
  final String locale = ref.watch(
    settingsProvider.select((AppSettings settings) => settings.localeCode),
  );
  return switch (locale) {
    'tr' => const TurkishStrings(),
    _ => const TurkishStrings(),
  };
});

/// Rule presets available for a game mode.
final rulePresetsProvider = Provider.family<List<RuleProfile>, GameMode>(
  (ref, GameMode mode) => RulePresets.forMode(mode),
);

/// The AI scheduling seam.
///
/// Bound to the same-isolate implementation while the only policy is the cheap
/// baseline. It is replaced by the isolate-backed service when the first
/// search policy lands, with no change at the call sites.
final Provider<AiDecisionService> aiDecisionServiceProvider =
    Provider<AiDecisionService>((ref) {
  final DirectAiDecisionService service = DirectAiDecisionService();
  ref.onDispose(service.dispose);
  return service;
});
