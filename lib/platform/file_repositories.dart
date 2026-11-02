import 'dart:convert';

import '../core/persistence/app_settings.dart';
import '../core/persistence/saved_match.dart';
import '../core/persistence/settings_repository.dart';
import '../core/statistics/match_record.dart';
import 'json_file_store.dart';

/// Preferences, on disk.
final class FileSettingsRepository implements SettingsRepository {
  const FileSettingsRepository(this._store);

  static const String fileName = 'settings.json';

  final JsonFileStore _store;

  @override
  Future<AppSettings> load() async {
    final String? raw = await _store.readString(fileName);
    return raw == null ? AppSettings.defaults : SettingsCodec.decode(raw);
  }

  @override
  Future<void> save(AppSettings settings) =>
      _store.writeString(fileName, SettingsCodec.encode(settings));

  @override
  Future<void> clear() => _store.delete(fileName);
}

/// The match in progress, on disk.
final class FileMatchArchive implements MatchArchive {
  const FileMatchArchive(this._store);

  static const String fileName = 'match_in_progress.json';

  final JsonFileStore _store;

  @override
  Future<SavedMatch?> load() async {
    final Map<String, Object?>? json = await _store.readJson(fileName);
    if (json == null) {
      return null;
    }
    try {
      return SavedMatch.fromJson(json);
    } on Object {
      // A save this build cannot read -- truncated, hand-edited, or written by
      // an older schema -- is treated as no save. Caught broadly on purpose:
      // every failure here has the same remedy, and none of them should stop
      // the app from opening.
      return null;
    }
  }

  @override
  Future<void> save(SavedMatch match) =>
      _store.writeJson(fileName, match.toJson());

  @override
  Future<void> clear() => _store.delete(fileName);
}

/// Finished matches, on disk.
///
/// One file holding the whole list rather than a file per match: the list is
/// read as a whole on the statistics screen and never queried, and a few
/// hundred records is tens of kilobytes.
final class FileMatchHistoryRepository implements MatchHistoryRepository {
  const FileMatchHistoryRepository(this._store);

  static const String fileName = 'match_history.json';

  /// Records kept. Old matches fall off the end rather than letting the file
  /// grow without bound on a device nobody ever clears. Chosen to be far more
  /// than the statistics screen shows and far less than a size worth paging.
  static const int maxRecords = 500;

  final JsonFileStore _store;

  @override
  Future<List<MatchRecord>> load() async {
    final String? raw = await _store.readString(fileName);
    if (raw == null) {
      return const <MatchRecord>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <MatchRecord>[];
      }
      return <MatchRecord>[
        for (final Object? entry in decoded)
          if (entry is Map<String, Object?>) MatchRecord.fromJson(entry),
      ];
    } on Object {
      // Same reasoning as the archive: statistics are a convenience, so a
      // damaged file reads as "nothing recorded yet".
      return const <MatchRecord>[];
    }
  }

  @override
  Future<void> append(MatchRecord record) async {
    final List<MatchRecord> records = <MatchRecord>[
      ...await load(),
      record,
    ];
    final List<MatchRecord> kept = records.length > maxRecords
        ? records.sublist(records.length - maxRecords)
        : records;
    await _store.writeString(
      fileName,
      jsonEncode(<Object?>[
        for (final MatchRecord entry in kept) entry.toJson(),
      ]),
    );
  }

  @override
  Future<void> clear() => _store.delete(fileName);
}
