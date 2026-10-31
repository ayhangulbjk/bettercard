# AI benchmarks

## The rule

**No strength claim without evidence.** "Expert" is a measurement, not a label.
A claim that agent A is stronger than agent B is only made when:

- the comparison ran on **paired deals** (both agents played the same cards),
- with **rotated seats** (each agent played every position),
- over a sample large enough that the **confidence interval excludes zero**,
- from a **recorded seed**, so anyone can reproduce it.

If the interval includes zero, the correct statement is "no difference
detected at this sample size", not "slightly better".

## Current results

**None.** There is nothing to compare: the only policy implemented is
`RandomLegalPolicy`, and no game mode has a scoring lifecycle, so there is no
match win rate or contract success rate to measure.

What can be measured today, and is:

| Metric | Source | Status |
|---|---|---|
| Illegal commands | `SimulationReport.totalIllegalAttempts` | Must be 0; asserted in tests |
| Positions with no legal move | Simulator reaching a dead end | None observed; asserted in tests |
| State invariants per ply | `TrickPlayState.checkInvariants` | Checked on every ply |
| Deal reproducibility | Same config, same results | Asserted in tests |
| Decision latency p50/p95 | `LatencySummary` | Reported, no target yet |
| Per-seat trick distribution | `ConfidenceInterval` | Reported; symmetric as expected for self-play |

Run it:

```bash
dart run tool/benchmarks/run_baseline.dart --hands 2000 --players 4
dart run tool/benchmarks/run_baseline.dart --hands 2000 --rules kozmaca
dart run tool/benchmarks/run_baseline.dart --hands 2000 --rules notrump
flutter test test/simulation
```

The AI lab screen inside the app runs the same batch and states plainly that
the result is not a strength claim.

## Protocol for a real comparison

Once a second policy exists, a matchup runs like this.

### 1. Pair the deals

Both agents play hand `i` from seed `baseSeed + i`. Comparing agents on
different deals measures the deal, not the play: the variance of a Batak hand
dwarfs the skill difference between two competent agents, so unpaired
comparison needs orders of magnitude more samples for the same resolution.

### 2. Rotate the seats

For a four-seat table, run each deal with the agent under test in each of the
four seats. Position matters: the seat that leads first, and the seat sitting
after the declarer, have real positional advantages. Rotation removes them.

### 3. Report the paired difference

Compute the per-deal difference `scoreA - scoreB`, then the mean and 95%
interval **of those differences**. A paired interval is far tighter than the
difference of two independent means, which is the whole point of pairing.

`ConfidenceInterval.ofSamples` provides the interval and `excludesZero` the
verdict. It is a normal approximation, which is adequate at the sample sizes
used here and is labelled as an approximation rather than an exact bound.

### 4. Required metrics

| Metric | Definition |
|---|---|
| Win rate | Matches won, with interval |
| Mean score margin | Paired per-deal difference, with interval |
| Contract success rate | Declared contracts made / declared |
| Mean tricks vs contract | Overtricks and undertricks |
| Illegal moves | Must be exactly 0 |
| Decision latency | p50, p95, max per decision |
| Partnership metrics | Per-team results for partnership modes |

### 5. Baselines

Every agent is reported against both:

- **Legal random** (`RandomLegalPolicy`): the floor. An agent that cannot beat
  it decisively is broken.
- **Heuristic**: the real bar. Beating random is not evidence of strength.

### 6. Sample size

Report the sample size and the resulting interval; do not pick a sample size
that happens to produce the answer you wanted. As a practical starting point,
a few thousand paired deals typically resolves a margin of a few points per
hand in these games, but the interval is the authority, not a rule of thumb.

## Latency targets

Not yet measured against a device, so these are **targets, not results**:

| Level | p50 target | p95 target |
|---|---|---|
| Beginner / Normal | < 5 ms | < 15 ms |
| Hard | < 40 ms | < 120 ms |
| Expert | < 150 ms | < 400 ms |
| Legendary | < 400 ms | < 900 ms |

All on a background isolate, so the UI never waits regardless. Budgets are
enforced by `AiComputeBudget`, and a policy that overruns must return its best
answer so far rather than exceed it.

## Reporting template

```
Agent:        <id>            Opponent:     <id>
Mode:         <game mode>     Rule profile: <profile id>
Deals:        <n> paired, seats rotated
Base seed:    <seed>          Commit:       <sha>
Device:       <model / dart vm>

Win rate:         xx.x% [xx.x, xx.x]
Score margin:     +x.xx [+x.xx, +x.xx] per hand
Contract success: xx.x% [xx.x, xx.x]
Illegal moves:    0
Latency:          p50 xx ms, p95 xx ms, max xx ms
Verdict:          <stronger / no difference detected> at 95%
```

An entry with a missing seed, commit or sample size is not a result.
