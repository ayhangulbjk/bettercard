import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'platform/json_file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, per the product requirement. Locked here rather than in the
  // native manifests so the single Dart declaration is authoritative for both
  // platforms and cannot drift.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        if (await _storage() case final JsonFileStore store)
          fileStoreProvider.overrideWithValue(store),
      ],
      child: const BatakKingApp(),
    ),
  );
}

/// The directory the app stores its files in, or null if it has none.
///
/// Application *support*, not documents: these are the app's own files --
/// preferences, the match in progress, the match history -- and not content
/// the player manages, so they do not belong in a folder a file browser
/// shows.
///
/// A null means the app runs with memory-only storage rather than refusing to
/// start. Nothing stored here is content the player created, so losing it on
/// exit is a degraded app, not a damaged one.
Future<JsonFileStore?> _storage() async {
  try {
    final Directory directory = await getApplicationSupportDirectory();
    return JsonFileStore(directory.path);
  } on Object {
    return null;
  }
}
