import 'dart:convert';

import 'app_settings.dart';

/// Reads and writes player preferences.
///
/// An interface rather than a concrete class because milestone 1 has no
/// generated native host folders yet (`flutter create .` produces them), so no
/// storage plugin can be registered. The in-memory implementation below keeps
/// the whole settings pipeline -- model, codec, provider, UI -- real and
/// testable now, and the disk-backed implementation drops in behind the same
/// interface with no change above it. See docs/ROADMAP.md milestone 2.
abstract interface class SettingsRepository {
  /// Loads stored settings, or defaults when nothing is stored.
  Future<AppSettings> load();

  /// Persists [settings].
  Future<void> save(AppSettings settings);

  /// Removes stored settings.
  Future<void> clear();
}

/// Encodes settings to and from a JSON string.
///
/// Kept separate from the repository so the on-disk format is testable without
/// any storage backend, and so the same codec serves whichever backend ships.
abstract final class SettingsCodec {
  static String encode(AppSettings settings) => jsonEncode(settings.toJson());

  /// Decodes [raw]. Returns defaults when [raw] is not usable, because losing
  /// preferences is a far better outcome than failing to start the app.
  static AppSettings decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return AppSettings.fromJson(decoded);
      }
    } on FormatException {
      // Fall through to defaults.
    }
    return AppSettings.defaults;
  }
}

/// Process-lifetime settings store.
///
/// Explicitly NOT persistent: settings survive navigation but not an app
/// restart. Labelled here rather than silently pretending to save, so nobody
/// mistakes it for the real thing.
final class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([AppSettings? initial])
      : _stored = initial == null ? null : SettingsCodec.encode(initial);

  String? _stored;

  @override
  Future<AppSettings> load() async =>
      _stored == null ? AppSettings.defaults : SettingsCodec.decode(_stored!);

  @override
  Future<void> save(AppSettings settings) async {
    _stored = SettingsCodec.encode(settings);
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}
