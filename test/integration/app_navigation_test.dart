import 'package:batak_king/app/app.dart';
import 'package:batak_king/core/rules/game_mode.dart';
import 'package:batak_king/features/home/widgets/game_mode_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget harness() => const ProviderScope(child: BatakKingApp());

/// Pumps the app at a realistic portrait phone size.
///
/// The product is locked to `portraitUp` in main.dart, so the default 800x600
/// landscape test viewport is a shape it never runs at -- and one that changes
/// which widgets a lazy list builds. 1080x2340 physical at DPR 3 gives 360x780
/// logical, a common phone.
Future<void> pumpPortraitApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();
}

/// Brings [finder]'s widget on screen, building it first if necessary.
///
/// Screens here are lazy `ListView`/`CustomScrollView`s: a widget below the
/// fold has never been built, so no finder can see it and `ensureVisible`
/// cannot reach it. Dragging is what puts it in the tree.
///
/// Two traps are guarded. A `.first`-narrowed finder throws `Bad state: No
/// element` instead of reporting empty, so callers pass a bare finder and the
/// narrowing happens only once a match exists. And some screens have no
/// scrollable at all (statistics is a plain `Center`), so scrolling is skipped
/// rather than crashing -- the caller's expectation then reports the truth.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    return;
  }
  final Finder scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) {
    return;
  }
  await tester.scrollUntilVisible(finder, 120, scrollable: scrollables.first);
  await tester.pumpAndSettle();
}

/// [reveal] then tap the first match.
Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the home screen lists all five game modes', (
    WidgetTester tester,
  ) async {
    await pumpPortraitApp(tester);

    for (final GameMode mode in GameMode.values) {
      await reveal(tester, find.text(mode.turkishName));
      expect(
        find.text(mode.turkishName),
        findsOneWidget,
        reason: '${mode.id} is missing from the home screen',
      );
    }
  });

  testWidgets('each mode is badged according to its own lifecycle', (
    WidgetTester tester,
  ) async {
    await pumpPortraitApp(tester);

    // Checked card by card rather than by counting badges: scrolling to the
    // last mode disposes the first ones, so all five are never in the tree at
    // once on a phone-sized viewport.
    //
    // This assertion follows GameMode.isPlayable rather than hard-coding the
    // list, but the point of the test is unchanged: a mode without a finished
    // lifecycle must say so on the card. Koz Maca lost its badge when its
    // lifecycle shipped; the other four keep theirs until theirs do.
    for (final GameMode mode in GameMode.values) {
      await reveal(tester, find.text(mode.turkishName));
      expect(
        find.descendant(
          of: find.widgetWithText(GameModeCard, mode.turkishName),
          matching: find.text('Hazır değil'),
        ),
        mode.isPlayable ? findsNothing : findsOneWidget,
        reason: mode.isPlayable
            ? '${mode.id} is playable and must not be badged'
            : '${mode.id} must be badged as not ready',
      );
    }
  });

  testWidgets('tapping a mode opens setup with the rule audit', (
    WidgetTester tester,
  ) async {
    await pumpPortraitApp(tester);

    await revealAndTap(tester, find.text(GameMode.auctionBatak.turkishName));

    await reveal(tester, find.text('Kural Denetimi'));
    expect(find.text('Kural Denetimi'), findsOneWidget);

    // All six shipped presets validate clean, so the audit must say so.
    await reveal(tester, find.text('Kural seti tutarlı.'));
    expect(find.text('Kural seti tutarlı.'), findsOneWidget);
  });

  testWidgets('setup leads to the table preview, clearly labelled', (
    WidgetTester tester,
  ) async {
    await pumpPortraitApp(tester);

    await revealAndTap(tester, find.text(GameMode.auctionBatak.turkishName));
    await revealAndTap(
      tester,
      find.widgetWithText(FilledButton, 'Masa Önizlemesi'),
    );

    expect(find.textContaining('Masa Önizlemesi'), findsWidgets);
  });

  testWidgets('the AI lab runs a real baseline batch and reports it', (
    WidgetTester tester,
  ) async {
    await pumpPortraitApp(tester);

    await revealAndTap(tester, find.text('Yapay Zeka Laboratuvarı'));

    // Narrowed to the chip: the report text can contain the same number.
    await revealAndTap(tester, find.widgetWithText(ChoiceChip, '50'));
    await revealAndTap(tester, find.text('Temel çizgiyi çalıştır'));

    await reveal(tester, find.text('Kural dışı hamle yok'));
    expect(find.text('Kural dışı hamle yok'), findsOneWidget);
    expect(find.textContaining('Hands:'), findsOneWidget);
    expect(find.textContaining('Illegal:'), findsOneWidget);
  });

  // Registered as one test per destination rather than a loop inside a single
  // test. `harness()` returns a const widget, so pumping it again in a loop
  // reuses the same element tree and the Navigator keeps the stack from the
  // previous iteration -- the second label would be looked for on the first
  // label's screen. A separate test gets a fresh binding.
  for (final String label in <String>[
    'Ayarlar',
    'Kurallar',
    'İstatistikler',
    'Yapay Zeka Laboratuvarı',
  ]) {
    testWidgets('the $label screen opens from the home screen', (
      WidgetTester tester,
    ) async {
      await pumpPortraitApp(tester);

      await revealAndTap(tester, find.text(label));

      expect(
        find.text(label),
        findsWidgets,
        reason: 'the $label screen did not open',
      );
    });
  }
}
