// Screenshot harness: rasterises each screen headlessly and writes a PNG.
//
// Run with:
//   flutter test tool/screenshots/capture_test.dart
//
// Output: build/screenshots/*.png (build/ is already gitignored).
//
// Why this exists: the Windows development machine cannot run the app at all.
// The desktop target needs Visual Studio Build Tools (install blocked by
// machine policy), the web target is impossible (docs/DECISIONS.md D-14), and
// the Android emulator needs WHPX plus a reboot with administrator rights.
// The widget test harness, however, rasterises through real Skia, so layout
// can be reviewed as pixels on this machine with no device and no toolchain.
//
// This is a tool, not a test: it asserts nothing, and it lives outside `test/`
// so `flutter test` does not collect it and the suite count stays honest.
//
// It does NOT replace running on a device. Touch feel, scroll physics, the
// platform font and the real status bar are a device's business. What this
// does show is layout, overflow, truncation and glyph coverage.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_king/app/app.dart';
import 'package:batak_king/app/routes.dart';
import 'package:batak_king/core/rules/game_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reference portrait phone: 1080x2340 at 3x, i.e. 360x780 logical.
///
/// The same viewport the integration tests use. A landscape default was what
/// hid three real layout defects until the tests were moved to portrait, so
/// every capture here is portrait too.
const Size _physicalSize = Size(1080, 2340);
const double _devicePixelRatio = 3;

/// One screen to capture.
final class _Shot {
  const _Shot(
    this.name, {
    this.route,
    this.arguments,
    this.textScale = 1,
    this.scrollBy = 0,
  });

  final String name;

  /// Pushed through the real [AppRoutes.onGenerateRoute]; null stays on home.
  final String? route;
  final Object? arguments;

  /// Requested system text scale. The app clamps it to 1.35, so a value above
  /// that exercises the ceiling rather than the raw preference.
  final double textScale;

  /// Logical pixels to drag the first scrollable by, negative to scroll down.
  final double scrollBy;
}

const List<_Shot> _shots = <_Shot>[
  _Shot('01-home'),
  _Shot('02-home-scrolled', scrollBy: -500),
  _Shot('03-home-large-text', textScale: 2),
  _Shot(
    '04-game-setup-koz-maca',
    route: AppRoutes.gameSetup,
    arguments: GameMode.spadesBatak,
  ),
  _Shot(
    '05-table-preview-koz-maca',
    route: AppRoutes.tablePreview,
    arguments: GameMode.spadesBatak,
  ),
  _Shot('06-settings', route: AppRoutes.settings),
  _Shot('07-statistics', route: AppRoutes.statistics),
  _Shot('08-rules', route: AppRoutes.rules),
  _Shot('09-ai-lab', route: AppRoutes.aiLab),
];

void main() {
  setUpAll(_loadFonts);

  for (final _Shot shot in _shots) {
    testWidgets('capture ${shot.name}', (WidgetTester tester) async {
      await _capture(tester, shot);
    });
  }
}

Future<void> _capture(WidgetTester tester, _Shot shot) async {
  tester.view.physicalSize = _physicalSize;
  tester.view.devicePixelRatio = _devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = shot.textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // A fresh key per capture, so nothing is reused from a previous pump. A
  // const root widget once made `pumpWidget` reuse the element tree and keep
  // the previous screen's Navigator state, which silently invalidated an
  // integration test.
  final GlobalKey boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: const ProviderScope(child: BatakKingApp()),
    ),
  );
  await tester.pumpAndSettle();

  if (shot.route != null) {
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaitedPush(navigator, shot.route!, shot.arguments);
    await tester.pumpAndSettle();
  }

  if (shot.scrollBy != 0) {
    final Finder scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, Offset(0, shot.scrollBy));
      await tester.pumpAndSettle();
    }
  }

  final RenderRepaintBoundary boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  Uint8List? bytes;
  // toImage and toByteData do real asynchronous work, which a widget test's
  // fake async would never complete.
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(
      pixelRatio: _devicePixelRatio,
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    bytes = data?.buffer.asUint8List();
  });

  if (bytes == null) {
    throw StateError('rasterising ${shot.name} produced no bytes');
  }

  final Directory out = Directory('build/screenshots');
  out.createSync(recursive: true);
  final File file = File('${out.path}/${shot.name}.png');
  file.writeAsBytesSync(bytes!);
  stdout.writeln('wrote ${file.absolute.path} (${bytes!.length} bytes)');
}

/// Pushes a named route without awaiting its completion.
///
/// The route's future completes when the screen is popped, which never happens
/// here; awaiting it would hang the capture.
void unawaitedPush(NavigatorState navigator, String route, Object? arguments) {
  navigator.pushNamed<void>(route, arguments: arguments);
}

/// Loads the real text and icon fonts from the Flutter SDK.
///
/// Without these the test harness draws every glyph as a filled box, which
/// would make the captures useless for judging truncation or Turkish
/// diacritics, and would make every icon look like a missing-glyph bug that
/// does not exist in the product. The directory is found by walking up from
/// the running executable rather than hard-coded, so this works on the Mac too.
Future<void> _loadFonts() async {
  final String? fonts = _materialFontsDir();
  if (fonts == null) {
    throw StateError(
      'Could not find the Flutter material_fonts directory by walking up from '
      '${Platform.resolvedExecutable}. Without a real font every glyph would '
      'rasterise as a box.',
    );
  }

  // Family names must match what the framework asks for: the text theme
  // resolves to Roboto, and every IconData in the Material set names
  // 'MaterialIcons'.
  await _loadFamily(fonts, 'Roboto', <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await _loadFamily(fonts, 'MaterialIcons', <String>[
    'materialicons-regular.otf',
  ]);
}

Future<void> _loadFamily(
  String directory,
  String family,
  List<String> files,
) async {
  final FontLoader loader = FontLoader(family);
  bool any = false;
  for (final String name in files) {
    final File face = File('$directory/$name');
    if (!face.existsSync()) {
      continue;
    }
    any = true;
    loader.addFont(
      face.readAsBytes().then((Uint8List data) => ByteData.view(data.buffer)),
    );
  }
  if (!any) {
    throw StateError('no $family faces found in $directory');
  }
  await loader.load();
}

String? _materialFontsDir() {
  Directory dir = File(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 10; i++) {
    final Directory candidate =
        Directory('${dir.path}/artifacts/material_fonts');
    if (candidate.existsSync()) {
      return candidate.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
  return null;
}
