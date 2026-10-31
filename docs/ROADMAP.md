# Roadmap

## Milestone 1 - foundation (this iteration)

Shipped:

- Pure-Dart card model, deterministic `SeededRandom`, seeded dealing.
- Seating with partnership support.
- Shared trick core: trick, resolver, legal move generator, immutable state,
  authoritative engine with command validation.
- Rule profiles for all five modes with validation and documented presets.
- AI information boundary: seat observation filter, card tracker, hidden hand
  sampler, policy interface, legal-random baseline, decision service seam.
- Headless simulator with latency and confidence-interval reporting.
- Settings model, JSON codecs, saved-match model with a frozen rule profile.
- Turkish UI through an `AppStrings` seam: home with five modes, game setup
  with a live rule audit, labelled table preview, settings, rules, statistics,
  AI lab.
- Unit, integration and simulation tests; benchmark CLI.

Not shipped, and labelled as such in the product:

- No mode is playable. `GameMode.isPlayable` is false everywhere.
- No auction, contract selection, burying or scoring lifecycle.
- No AI above the legal-random baseline.
- No disk persistence (in-memory repository only).
- No sound, haptics or card animation.
- No native host folders (`flutter create .` generates them).

## Milestone 2 - the first playable mode

Goal: **Koz Maca end to end.** It is the simplest mode (no auction), so it
exercises the whole vertical slice without the bidding lifecycle.

1. `lib/games/spades_batak/`: round state, engine, scorer.
2. Match controller: deal, play, score, next hand, match end.
3. Wire the table to live state; tap and drag to play; trick animations at the
   configured speed.
4. `HeuristicPolicy` for Normal, with a weakened variant for Beginner.
5. Disk persistence: `flutter create .`, then `shared_preferences` or a JSON
   file behind `SettingsRepository`; autosave and quick resume.
6. First real benchmark entry: heuristic vs random, paired deals, rotated
   seats.

Done when a full Koz Maca match can be played and resumed, and the heuristic
policy beats random with an interval excluding zero.

## Milestone 3 - the auction modes

1. Auction lifecycle: bid, pass, pass-out resolution, trump declaration.
2. `lib/games/auction_batak/` and `lib/games/partnership_batak/`.
3. `BidEvaluator` and `ContractSelector`.
4. `PartnershipStrategy` for Esli Batak.
5. Auction UI: bid ladder, trump picker, contract display.
6. Benchmarks: contract success rate per difficulty.

## Milestone 4 - search and real difficulty

1. Isolate-backed `AiDecisionService` with cancellation and timeouts.
2. `MonteCarloPolicy` over `HiddenHandSampler` worlds.
3. `EndgameSolver` for the last few tricks.
4. Expert and Legendary wired to real budgets.
5. Latency measurement on a representative mid-range Android device.
6. Benchmark entries for every level, against both baselines.

Expert and Legendary stay unavailable in the UI until their benchmark entries
exist.

## Milestone 5 - the remaining modes

1. `lib/games/buried_batak/`: three seats, surplus, bury UI and restrictions.
2. `lib/games/king/`: contract selection against quotas, per-contract scoring,
   long-match state.
3. King-specific AI: penalty-contract play differs fundamentally from trick
   taking and needs its own evaluation.
4. Resolve open questions B-4, K-1 and K-2 with players.

## Milestone 6 - polish

1. Statistics: per-mode history, contract success, streaks.
2. Customisation: table themes, card backs, avatars, names, layout.
3. Sound and haptics.
4. Animation polish, skip-animation and quick-play paths.
5. Accessibility: screen reader labels, contrast, scaling audit.
6. Performance pass: 60 fps on a mid-range device, 120 fps where supported.
7. English localisation (a second `AppStrings` implementation plus a locale
   switch; move to ARB if a third locale appears).
8. Illustrated card art, if it beats the procedural rendering.

## Deliberately out of scope

Online multiplayer, accounts, ads, in-app purchases, analytics, cloud AI,
landscape layout. Each would violate a stated product requirement.
