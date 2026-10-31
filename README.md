# Batak & King

Offline Turkish card games for Android and iOS. Flutter, Dart, Riverpod.
Portrait only, free, no ads, no accounts, no network.

Five modes planned: Herkes Tek Ihaleli Batak, Esli Ihaleli Batak, Koz Maca,
Uclu Gommeli Batak, King.

## Status: milestone 1, foundation only

**No game mode is playable yet.** This repository contains the domain
foundation, the AI information architecture, the Turkish UI shell and the test
and benchmark harness. `GameMode.isPlayable` is `false` for every mode and the
app labels them accordingly.

| Area | State |
|---|---|
| Card model, seeded dealing | Implemented, tested |
| Shared trick core (legality, resolution, engine) | Implemented, tested |
| Rule profiles for all five modes, with validation | Implemented, tested |
| AI no-cheating boundary, card tracker, hand sampler | Implemented, tested |
| Legal-random baseline policy | Implemented, tested |
| Headless simulator and benchmark CLI | Implemented, tested |
| Turkish UI shell (7 screens) | Implemented |
| Per-mode lifecycles (auction, contract, bury, scoring) | **Not started** |
| AI above the baseline | **Not started** |
| Disk persistence, sound, animation | **Not started** |

See `docs/ROADMAP.md` for what comes next and `docs/DECISIONS.md` for why
things are the way they are.

## Setup

Flutter 3.47.9 (Dart 3.13.7) was used to verify this code. Install Flutter
from <https://docs.flutter.dev/get-started/install>, then:

```bash
# Generate the native host folders (not committed).
flutter create . --platforms=android,ios --project-name batak_king

flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

> Verified on Flutter 3.47.9 / Dart 3.13.7 (Windows, 2026-10-31):
> `dart format .` leaves no diff, `flutter analyze` reports no issues, and
> `flutter test` passes 138 tests. The 2000-hand baseline benchmark reports
> zero illegal commands with all invariants holding. See `docs/DECISIONS.md`
> D-1 for the toolchain and D-13 for the layout defects this surfaced.

## Benchmarks

```bash
dart run tool/benchmarks/run_baseline.dart --hands 2000 --players 4
dart run tool/benchmarks/run_baseline.dart --hands 2000 --rules kozmaca
dart run tool/benchmarks/run_baseline.dart --hands 2000 --rules notrump
```

This measures correctness (zero illegal commands, invariants hold every ply)
and throughput. It is **not** a strength benchmark: the only agent implemented
is the legal-random baseline. See `docs/AI_BENCHMARKS.md`.

## Documentation

| File | Contents |
|---|---|
| `CLAUDE.md` | Permanent project instructions and architecture rules |
| `docs/ARCHITECTURE.md` | Layering, determinism, command model, AI boundary |
| `docs/RULE_PROFILES.md` | Rule variants, presets, and the open rule questions |
| `docs/AI_STRATEGY.md` | No-cheating guarantee, inference, difficulty design |
| `docs/AI_BENCHMARKS.md` | Measurement protocol and the no-claims-without-evidence rule |
| `docs/ROADMAP.md` | Milestones |
| `docs/DECISIONS.md` | Decision log |

## Principles

1. Offline at runtime. No network, ever.
2. The AI never sees hidden information.
3. No invented rules: variants are documented and configurable.
4. No fake functionality: incomplete features are labelled in the product.
5. No strength claims without benchmark evidence.
