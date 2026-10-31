# Game-mode lifecycles

Each subdirectory owns one mode's round lifecycle: the auction or contract
selection, the deal and any burying, the transition into card play, and
scoring.

They are **empty on purpose** in milestone 1. The shared trick core
(`lib/core/game_engine/trick/`) is implemented and tested; the per-mode
lifecycles are not, and stub files that compiled but did nothing would make the
modes look further along than they are. `GameMode.isPlayable` returns `false`
everywhere, and the UI labels every mode accordingly.

Each mode will add, behind `GameEngine<S>`:

| File | Responsibility |
|---|---|
| `<mode>_state.dart` | Immutable round state: phase, bids, contract, scores |
| `<mode>_engine.dart` | Command validation and phase transitions |
| `<mode>_scorer.dart` | Hand and match scoring from the rule profile |

See `docs/ROADMAP.md` for the order they land in and `docs/RULE_PROFILES.md`
for the rule decisions each one must honour.
