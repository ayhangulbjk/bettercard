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
import 'package:batak_king/core/ai/ai_difficulty.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/rules/game_mode.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/features/gameplay/match_controller.dart';
import 'package:batak_king/features/gameplay/match_session.dart';
import 'package:batak_king/features/gameplay/match_turn.dart';
import 'package:batak_king/games/spades_batak/spades_batak_engine.dart';
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
    this.tapIcon,
    this.drive,
    this.thenRoute,
  });

  final String name;

  /// Pushed through the real [AppRoutes.onGenerateRoute]; null stays on home.
  final String? route;
  final Object? arguments;

  /// Requested system text scale. The app clamps it to 1.35, so a value above
  /// that exercises the ceiling rather than the raw preference.
  final double textScale;

  /// An icon to tap once the screen is in state, for a capture that lives
  /// behind a button rather than on the screen itself.
  final IconData? tapIcon;

  /// Pushed after [drive] has run, so a capture can show what a finished
  /// match leaves behind on another screen.
  final String? thenRoute;

  /// Runs after the route is pushed, to put the screen into a given state.
  ///
  /// This is what makes the live table capturable: it starts a match on the
  /// real controller and plays it forward, so the capture shows the table as
  /// the engine and the opponents actually leave it rather than a mock-up.
  final Future<void> Function(WidgetTester tester, ProviderContainer container)?
      drive;
}

const List<_Shot> _shots = <_Shot>[
  _Shot('01-home'),
  // The home screen no longer scrolls, so there is nothing to drag. What is
  // worth a second look is the table at a larger system font, where four
  // seats and a card pile compete for the same felt.
  _Shot(
    '02-match-large-text',
    route: AppRoutes.match,
    drive: _driveToPlayerTurn,
    textScale: 1.4,
  ),
  _Shot('03-home-large-text', textScale: 2),
  _Shot(
    '04-game-setup-koz-maca',
    route: AppRoutes.gameSetup,
    arguments: GameMode.spadesBatak,
  ),
  // The same screen at the text-scale ceiling, where the list genuinely does
  // not fit: what this capture is for is the start button, which is pinned
  // below the scroll area and so has to be on screen either way.
  _Shot(
    '04b-game-setup-large-text',
    route: AppRoutes.gameSetup,
    arguments: GameMode.spadesBatak,
    textScale: 1.4,
  ),
  _Shot(
    '05-table-preview-koz-maca',
    route: AppRoutes.tablePreview,
    arguments: GameMode.spadesBatak,
  ),
  // The declaration round, which is the first thing a hand now shows.
  _Shot(
    '05b-match-declaring',
    route: AppRoutes.match,
    drive: _driveToDeclaration,
  ),
  _Shot('06-settings', route: AppRoutes.settings),
  _Shot('07-statistics', route: AppRoutes.statistics),
  _Shot('08-rules', route: AppRoutes.rules),
  _Shot('09-ai-lab', route: AppRoutes.aiLab),
  _Shot(
    '10-match-mid-trick',
    route: AppRoutes.match,
    drive: _driveToPlayerTurn,
  ),
  // A finished trick, lying still with all four cards face up. This is the
  // beat that answers "who took it, and with what", so it is worth a capture
  // of its own.
  _Shot(
    '10c-match-trick-won',
    route: AppRoutes.match,
    drive: _driveToTrickWon,
  ),
  // The scoreboard, which now lives behind the app bar's button.
  _Shot(
    '10b-match-scoreboard',
    route: AppRoutes.match,
    drive: _driveToPlayerTurn,
    tapIcon: Icons.leaderboard_rounded,
  ),
  _Shot(
    '11-match-hand-summary',
    route: AppRoutes.match,
    drive: _driveToHandSummary,
  ),
  _Shot(
    '12-match-over',
    route: AppRoutes.match,
    drive: _driveToMatchOver,
  ),
  // The two screens that only have anything on them once a match has been
  // played: the statistics report, and the home screen's resume card.
  _Shot(
    '13-statistics',
    route: AppRoutes.match,
    drive: _driveToMatchOver,
    thenRoute: AppRoutes.statistics,
  ),
  _Shot(
    '14-home-resume',
    route: AppRoutes.match,
    drive: _driveToPlayerTurn,
    thenRoute: AppRoutes.home,
  ),
];

/// Starts a Koz Maca match on the real controller.
///
/// A fixed seed, so the captures are comparable between runs: a table that
/// dealt a different hand every time would make a layout regression invisible.
Future<void> _startMatch(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(matchProvider.notifier).start(
        profile: RulePresets.defaultFor(GameMode.spadesBatak),
        difficulty: AiDifficulty.normal,
        seed: 20260202,
      );
  await tester.pumpAndSettle();
}

/// A trick in progress with the player to move: cards already on the table,
/// the legal ones in hand highlighted. The state the table spends most of its
/// time in, and the one worth checking the layout against.
Future<void> _driveToPlayerTurn(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _startMatch(tester, container);
  await _advance(
    tester,
    container,
    (MatchSession session) =>
        session.phase == MatchPhase.awaitingHuman &&
        !(session.hand?.currentTrick.isEmpty ?? true),
  );
}

/// Runs the table on until it is waiting on a person rather than on a clock.
///
/// Called after the image has been written, not before: a capture is allowed
/// to stop on a timed phase -- a finished trick being shown is exactly such a
/// phase, and is worth photographing -- but the test framework fails a test
/// that ends with a timer still pending.
Future<void> _settleTimers(
  WidgetTester tester,
  ProviderContainer container,
) =>
    _advance(
      tester,
      container,
      (MatchSession session) =>
          session.phase == MatchPhase.awaitingHuman ||
          session.phase == MatchPhase.awaitingDeclaration ||
          session.phase == MatchPhase.handSummary ||
          session.phase == MatchPhase.matchOver,
    );

/// A completed trick, still lying face up before it is collected.
Future<void> _driveToTrickWon(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _startMatch(tester, container);
  await _advance(
    tester,
    container,
    (MatchSession session) => session.phase == MatchPhase.trickPause,
  );
}

/// The player's own declaration prompt, before any card is played.
Future<void> _driveToDeclaration(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _startMatch(tester, container);
  await _advance(
    tester,
    container,
    (MatchSession session) => session.isAwaitingDeclaration,
  );
}

Future<void> _driveToHandSummary(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _startMatch(tester, container);
  await _advance(
    tester,
    container,
    (MatchSession session) => session.phase == MatchPhase.handSummary,
  );
}

Future<void> _driveToMatchOver(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _startMatch(tester, container);
  await _advance(
    tester,
    container,
    (MatchSession session) => session.isOver,
  );
}

/// Plays the table forward until [done], answering for the human seat.
///
/// It plays the first legal card rather than a chosen one: the point is to
/// reach a state worth photographing, and any legal card gets there. The step
/// cap is a guard, not a budget -- if the loop ever hits it, the table is
/// stuck and the capture should fail loudly.
Future<void> _advance(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(MatchSession session) done, {
  int maxSteps = 1200,
}) async {
  const SpadesBatakEngine engine = SpadesBatakEngine();
  for (int step = 0; step < maxSteps; step++) {
    final MatchSession? session = container.read(matchProvider);
    if (session == null || done(session)) {
      return;
    }
    switch (session.phase) {
      case MatchPhase.awaitingHuman:
        final List<PlayingCard> legal =
            engine.legalCards(session.match, session.humanSeat);
        container.read(matchProvider.notifier).playCard(legal.first);
        await tester.pumpAndSettle();
      case MatchPhase.awaitingDeclaration:
        // The middle of the range: a number the hand can plausibly make, so
        // the captures do not all show a seat that has already lost.
        final List<int> options = MatchTurn.legalDeclarations(session);
        container
            .read(matchProvider.notifier)
            .declare(options[options.length ~/ 3]);
        await tester.pumpAndSettle();
      case MatchPhase.handSummary:
        container.read(matchProvider.notifier).continueAfterHand();
        await tester.pumpAndSettle();
      case MatchPhase.opponentDeclaring:
      case MatchPhase.opponentThinking:
      case MatchPhase.trickPause:
      case MatchPhase.trickGather:
      case MatchPhase.matchOver:
        // The table is on a timer: an opponent thinking or a finished trick
        // being shown. One long pump elapses it, where pumpAndSettle would
        // crawl forward in its default 100ms steps and spend the step budget
        // on a single hand.
        await tester.pump(const Duration(seconds: 1));
    }
  }
  throw StateError(
    'the table never reached the requested state in $maxSteps steps',
  );
}

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

  if (shot.drive != null) {
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(BatakKingApp)),
      listen: false,
    );
    await shot.drive!(tester, container);
  }

  if (shot.thenRoute != null) {
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    if (shot.thenRoute == AppRoutes.home) {
      // Back to the screen underneath rather than a second copy of it, so the
      // capture shows the home screen the player would actually return to.
      navigator.pop();
    } else {
      unawaitedPush(navigator, shot.thenRoute!, null);
    }
    await tester.pumpAndSettle();
  }

  if (shot.tapIcon != null) {
    await tester.tap(find.byIcon(shot.tapIcon!));
    await tester.pumpAndSettle();
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

  if (shot.drive != null) {
    await _settleTimers(
      tester,
      ProviderScope.containerOf(
        tester.element(find.byType(BatakKingApp)),
        listen: false,
      ),
    );
  }
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
