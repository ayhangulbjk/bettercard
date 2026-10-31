# Architecture

## Layering

```
                     +-----------------------------+
  Flutter widgets    |  lib/features/, lib/app/    |
                     +--------------+--------------+
                                    | reads state, sends commands
                     +--------------v--------------+
  Mode lifecycles    |  lib/games/<mode>/          |   (milestone 2+)
                     +--------------+--------------+
                                    |
   +----------------+ +-------------v-------------+ +------------------+
   | lib/core/ai/   | |  lib/core/game_engine/    | | lib/core/rules/  |
   | observation,   | |  commands, trick core,    | | profiles,        |
   | trackers,      | |  seating                  | | presets,         |
   | samplers,      | +-------------+-------------+ | validation       |
   | policies       |               |               +------------------+
   +----------------+ +-------------v-------------+
                      | lib/core/cards/, util/    |
                      | deck, seeded random       |
                      +---------------------------+
```

Dependencies point downward only. `lib/core/` never imports Flutter; it is
compiled and tested with no renderer, no device and no clock.

## Why the domain is Flutter-free

Three concrete payoffs, not purity for its own sake:

1. **The AI can be benchmarked.** Thousands of hands run in a plain Dart
   process in milliseconds. A domain that touched widgets could not.
2. **Replay works.** A state snapshot plus a command list reproduces a match
   exactly, which is what makes a bug report actionable and a save file
   trustworthy.
3. **Search can move to an isolate.** Isolates cannot share Flutter objects.
   A domain that is already plain data crosses that boundary unchanged.

Enforced by review plus the import rule in `CLAUDE.md`. No first-party lint
expresses layer boundaries, so this is a convention with teeth rather than a
build failure.

## Determinism

Three rules make every run reproducible:

- All randomness comes from `SeededRandom` (xorshift64*, owned by this
  project). `dart:math` `Random` is banned because its algorithm is an SDK
  implementation detail that may change between releases, which would silently
  invalidate saved matches and benchmark baselines.
- No engine code reads a clock. Timestamps enter as parameters
  (`SavedMatch.savedAtEpochMillis`), never from `DateTime.now()` inside the
  domain.
- Hand `i` of a simulation batch is seeded from `baseSeed + i`, so extending a
  benchmark never changes the hands an earlier run produced.

`SeededRandom.fork(salt)` derives independent sub-streams, so the deal, each
AI seat's sampling and the benchmark harness cannot interfere. Changing the
number of Monte Carlo samples must not change which cards were dealt.

## The command model

Every intent is a `GameCommand`. Applying one returns a `CommandOutcome`:

```dart
switch (engine.apply(state, command)) {
  case CommandAccepted<S>(state: final next): state = next;
  case CommandRejected<S>(violation: final v): show(v.code);
}
```

Contract for every engine:

| Property | Why it matters |
|---|---|
| `apply` is pure in `(state, command)` | Replay, isolates, tests |
| `apply` never mutates its input | Snapshot history stays valid |
| Illegal input returns `CommandRejected` | A buggy UI or AI cannot corrupt a game |
| Broken invariants throw | Programming errors must be loud, not absorbed |
| `legalCommands` agrees with `apply` | The UI can never highlight a rejected move |

`RuleViolation` carries a code, not a sentence: the domain stays free of
presentation, the UI maps codes to Turkish, and benchmarks can count
violations. Any non-zero count is a defect, never bad luck.

## The shared trick core

All five modes differ in their auction, contract and scoring, and share their
card play. So card play is implemented once:

| Component | Role |
|---|---|
| `Trick`, `CompletedTrick` | Public record of a trick |
| `TrickResolver` | Who won: highest trump, else highest of the lead suit |
| `TrickLegalMoves` | The single authority on card legality |
| `TrickPlayState` | Immutable snapshot of the card-play phase |
| `TrickPlayEngine` | Validates and applies `PlayCardCommand` |

`TrickLegalMoves` reads `TrickRules`, which is where regional variation lives:
compulsory trump when void, compulsory overtrump, the trump-lead restriction,
and the must-beat-lead-suit option. No table's custom is hard-coded.

Each mode will wrap this core with its own lifecycle under `lib/games/<mode>/`.
Those directories are empty in milestone 1 by design; see
`lib/games/README.md`.

## Rule profiles

A `RuleProfile` is the complete, immutable rule set for a match: trick rules,
bidding, scoring, bury, King contracts, fixed trump, deck exclusions, plus a
`schemaVersion`.

Two properties matter:

- **Validated.** `RuleProfileValidator` returns typed issues, and the UI keeps
  the start button disabled while any error remains. This is how "only expose
  logically consistent combinations" is actually enforced, including for a
  profile loaded from an old save file.
- **Frozen per match.** `SavedMatch` stores the profile in full rather than by
  id, so changing settings or shipping new defaults cannot change the scoring
  of a hand already in progress.

Derived quantities are computed, never declared, so they cannot drift:

```
playableCardCount = deckSize - cardsSetAside
tricksPerHand     = playableCardCount / playerCount
```

A bury profile is *expected* to start from a deck that does not divide evenly;
the surplus is exactly what the bury resolves. The validator checks
`deckSize - playerCount * tricksPerHand == cardsSetAside`.

## The AI boundary

```
TrickPlayState  --- SeatObservation.fromState(state, seat) --->  SeatObservation
(holds hidden hands)        (the ONLY funnel)              (public + own hand only)
                                                                      |
                                                                      v
                                            CardTracker  ----->  HiddenHandSampler
                                        (proven inferences)      (consistent worlds)
                                                                      |
                                                                      v
                                                                  AiPolicy
```

A policy's signature is the guarantee: `chooseCard(SeatObservation, budget)`.
There is no path from a policy back to the authoritative state.

- `CardTracker` derives only provable facts: which cards are gone, which remain
  unseen, and which seats are *proved* void, meaning they failed to follow a
  suit they were obliged to follow. Tested against the real deal: every
  recorded void must be a real void.
- `HiddenHandSampler` invents hidden hands consistent with the observation:
  correct hand sizes, no already-played card, no inferred void violated. This
  is how a Monte Carlo policy reasons about hidden information without peeking.
- The test harness may read true hidden state to *score* an outcome. It must
  never feed it back into a policy.

## Presentation

Pure Flutter widgets, no game-loop engine. Cards are drawn procedurally from
gradients, text and borders, so the app ships with no bitmap assets at all:
nothing to download, crisp at any density, and fronts and backs are themeable
by changing colours. `Flame` is deliberately not a dependency; see
`docs/DECISIONS.md` D-2.

Riverpod owns app state; the domain owns game state. A screen reads an
immutable snapshot and sends commands, and never mutates game state directly.

Portrait-only, with the human at seat 0 (bottom of the screen). `HandFan`
computes its own overlap from the available width, so 13 or 17 cards fit a
narrow phone without horizontal scrolling. Text scaling is honoured up to
1.35x and clamped there, so a very large system font cannot push the table off
screen.

## Simulation

`HeadlessSimulator` drives the authoritative engine with one `SeatDecider` per
seat, verifies invariants after every ply, and reports per-seat results with
95% intervals plus decision latency p50/p95. It takes a synchronous callback
rather than the async `AiPolicy` because awaiting a future per card would
dominate the measurement at these volumes.

What it does today is real: correctness and throughput over the shared trick
core. What it cannot do yet is report a match win rate, because no mode has a
scoring lifecycle. See `docs/AI_BENCHMARKS.md`.
