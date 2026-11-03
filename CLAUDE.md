# Batak & King - project instructions

Offline Turkish card game for Android and iOS. Flutter, Dart, Riverpod.
Portrait only. No network, ever.

## Non-negotiables

1. **Offline at runtime.** No registration, login, network permission, API
   call, analytics, ad, telemetry or cloud AI. If a change would add a network
   dependency, it is the wrong change.
2. **The AI does not cheat.** A decision policy receives a `SeatObservation`
   and nothing else. It cannot reach hidden hands, buried cards, or the
   generator's state. `SeatObservation.fromState` is the only sanctioned
   funnel; review every change to it.
3. **No invented rules.** Where Turkish tables disagree, add a documented
   `RuleProfile` option and an open question in `docs/RULE_PROFILES.md`. Never
   pick a custom silently.
4. **No fake functionality.** Incomplete features are labelled in the product,
   not just in the docs. `GameMode.isPlayable` gates anything that claims to
   be playable. No stub that compiles but does nothing.
5. **No strength claims without benchmark evidence.** "Expert" means a measured
   margin over a baseline on paired deals with rotated seats and a reported
   confidence interval. See `docs/AI_BENCHMARKS.md`.

## Architecture rules

- **`lib/core/` must not import Flutter.** No `package:flutter/*`, no
  `dart:ui`, no `dart:io`, no device APIs, no `DateTime.now()`, no ambient
  randomness. The domain is pure, deterministic and testable headlessly.
  `package:meta` is the only exception, for `@immutable`.
- **All randomness flows through `SeededRandom`.** Never `dart:math` `Random`:
  its algorithm may change between SDK releases and would break replay and
  benchmark reproducibility.
- **All state changes go through a `GameEngine` as a validated command.** The
  engine re-validates independently; a buggy UI or AI can produce a
  `CommandRejected`, never an illegal game. Illegal *player input* returns a
  rejection; broken *invariants* throw, because those are programming errors.
- **State snapshots are immutable.** `copyWith` returns a new snapshot;
  collections are wrapped unmodifiable at the boundary.
- **One authority per rule.** `TrickLegalMoves` is the only place that decides
  card legality. The engine, the UI highlight and every AI policy call it, so
  they cannot disagree.
- **A match freezes its `RuleProfile`.** Saves store the profile in full, not
  by id, so changing settings or shipping new defaults cannot alter a game in
  progress.
- **Never block the UI thread on AI work.** Search policies run through
  `AiDecisionService` with a budget, cancellation and a timeout.
- **Keep files focused.** Split a file that grows past roughly 300 lines or
  takes on a second responsibility.

## Turkish and English

**User-visible app text is Turkish** and goes through `AppStrings` - never a
literal in a widget.

**Code, comments, identifiers and commit messages are English.**

**Reader-facing docs are Turkish**, because the owner reads them:
`README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`. The remaining docs
(`RULE_PROFILES`, `AI_STRATEGY`, `AI_BENCHMARKS`, `DECISIONS`) are still
English; translate one when it is next substantially edited rather than in a
separate churn commit.

**Dart source stays ASCII-only.** Markdown may use full Turkish diacritics -
verified to round-trip as UTF-8. The original reason for ASCII-only Turkish
copy in `strings_tr.dart` (D-7) no longer holds and that file is queued for
diacritics; see `docs/ROADMAP.md`. Changing it also changes the text
assertions in `test/integration/app_navigation_test.dart`.

## Commands

```bash
flutter pub get                                    # resolve dependencies
dart format .                                      # format
flutter analyze                                    # lint and type-check
flutter test                                       # all tests
flutter test test/unit                              # domain tests only
flutter test test/simulation                        # simulation tests
dart run tool/benchmarks/run_baseline.dart --hands 2000
flutter run                                        # run on a device
```

First-time setup in a fresh clone also needs the native host folders, which
are generated rather than committed:

```bash
flutter create . --platforms=android,ios --project-name batak_king --org com.batakking
```

**Every `flutter create` run re-adds `test/widget_test.dart`**, a template test
for a counter app that does not exist here, so it fails to compile. Delete it
afterwards. `flutter create` also appends platform `exclude` entries to
`analysis_options.yaml` (keep those) and leaves `pubspec.yaml` and
`lib/main.dart` alone (verified).

It also writes Flutter's default launcher icon into the new host folders, so
the app icon has to be regenerated from the committed source every time:

```bash
dart run flutter_launcher_icons
```

The source is `assets/icon/app_icon.png`; the config is the
`flutter_launcher_icons:` block in `pubspec.yaml`. See `docs/DECISIONS.md`
D-25.

Only Android and iOS are targets. `web` and `windows` are not, and web
**cannot** work: the domain owns a 64-bit PRNG that JavaScript cannot
represent. See `docs/DECISIONS.md` D-14 before trying `-d chrome`.
