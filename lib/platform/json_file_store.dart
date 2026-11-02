import 'dart:convert';
import 'dart:io';

/// A directory of small JSON documents.
///
/// This is the only place in the app that touches the file system, and it is
/// outside `lib/core` for that reason: the domain is pure, deterministic and
/// headless, so it may not import `dart:io`. Everything above this class works
/// against the repository interfaces in `lib/core/persistence`, which makes
/// the storage backend swappable and the whole pipeline testable with no disk.
///
/// Writes are atomic by rename. A game that autosaves after every card will
/// one day be killed by the OS mid-write; without the rename it would leave a
/// half-written file where the save used to be, and the player would lose the
/// match they were in rather than one move of it.
final class JsonFileStore {
  const JsonFileStore(this.directory);

  /// Directory the documents live in. Supplied by the caller, which is what
  /// keeps this class free of `path_provider` and usable in tests with a
  /// temporary directory.
  final String directory;

  /// Reads [name], or null when it is absent or unreadable.
  ///
  /// Unreadable reads as absent on purpose: the caller's options are the same
  /// either way, and a corrupt preferences file must never stop the app from
  /// starting.
  Future<String?> readString(String name) async {
    try {
      final File file = _fileFor(name);
      if (!file.existsSync()) {
        return null;
      }
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Reads [name] as a JSON object, or null.
  Future<Map<String, Object?>?> readJson(String name) async {
    final String? raw = await readString(name);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Writes [contents] to [name], atomically.
  Future<void> writeString(String name, String contents) async {
    final Directory dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final File temporary = _fileFor('$name.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(_fileFor(name).path);
  }

  Future<void> writeJson(String name, Object? json) =>
      writeString(name, jsonEncode(json));

  /// Removes [name]. Absent is success, not an error.
  Future<void> delete(String name) async {
    try {
      final File file = _fileFor(name);
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing the caller can do, and nothing is lost that was not already
      // being discarded.
    }
  }

  File _fileFor(String name) =>
      File('$directory${Platform.pathSeparator}$name');
}
