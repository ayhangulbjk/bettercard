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

Run on commit `bb7f496`, seed 1, Dart VM on Windows. Every line below is a
paired comparison on the same deals with the agent rotated through all four
seats, scored in **points**, with a 95% interval. Reproduce with the command
shown; an entry without a seed, a commit and a sample size is not a result.

### Koz Maca, soz x10 / yan 1 / 3 yan batar

| Agent | Opponent | Deals | Margin (points/hand) | Verdict |
|---|---|---|---|---|
| `heuristic` | `random` | 1500 | **+67.49** +/- 0.87 | stronger |
| `heuristic` | `greedy` | 1500 | **+1.48** +/- 0.50 | stronger |
| `beginner` | `heuristic` | 1000 | **-29.67** +/- 1.56 | weaker, as intended |
| `mc` (6 worlds) | `heuristic` | 500 | **+4.03** +/- 0.80 | stronger |
| `mc` (8 worlds, solver depth 4) | `mc` (8 worlds) | 80 | -0.49 +/- 2.06 | **no difference detected** |

### The same agents at a table that busts on two extras

| Agent | Opponent | Deals | Margin (points/hand) | Verdict |
|---|---|---|---|---|
| `heuristic` | `greedy` | 1000 | **+3.24** +/- 0.75 | stronger |

The margin over `greedy` more than doubles when the bust line tightens, which
is the point of carrying the rule in the observation: `greedy` plays a 2-yan
table exactly as it plays a 3-yan one.

### Declaration quality

Measured on the same runs. Missing the word and drowning in extras are
different mistakes, and a policy can trade one for the other, so they are
counted apart.

| Agent | Word kept | Missed it | Sank on extras | Mean error |
|---|---|---|---|---|
| `random` | 17.1% | - | - | - |
| `greedy` | 74.9% | 20.1% | 5.0% | 1.17 tricks |
| `heuristic` | 79.6% | 15.8% | 4.6% | 0.96 tricks |
| `mc` (6 worlds) | 84.3% | 14.0% | 1.7% | 1.05 tricks |

### What the agent names mean

| Name | What it is |
|---|---|
| `random` | Uniformly random legal card. The floor. |
| `greedy` | `HeuristicPolicy.trickGreedy`: the control. Promises the rounded hand valuation, never nil, then takes every trick it can. This is what the policy did before it knew what a declaration was, kept as a flag so the comparison is against what shipped rather than a remembered version of it. |
| `beginner` | The heuristic with a 40% blunder rate. Measured weaker on purpose: a difficulty level that is not actually easier would be a lie too. |
| `heuristic` | Score-aware heuristic. The Normal level. |
| `mc` | `MonteCarloPolicy`. The Zor level. |

### Latency

Measured, not targeted, on the runs above.

| Agent | p50 | p95 |
|---|---|---|
| `heuristic` | 6us | 14us |
| `mc` (6 worlds) | 10us | 12.9ms |
| `mc` (8 worlds, solver depth 4) | 4.3ms | 47.8ms |

The p50 for a sampling policy is far below its p95 because most positions
have one legal card and never reach the search at all.

### Tuned constants, and what tuned them

Three numbers in `HeuristicPolicy` were measured rather than chosen. Each is
recorded here because a constant with no recorded measurement behind it is a
guess with a decimal point.

| Constant | Value | How it was set |
|---|---|---|
| `capacityBias` | 0.6 | Swept 0.0-3.2 in self-play. The hand valuation undercounts what a hand takes when it is chased; the peak is flat between 0.3 and 0.9 and falls away sharply above 1.2. |
| `declarationSpread` | 1.3 | Swept 0.7-1.45. Nearly flat: with a three-wide payoff window the best word barely moves with the spread. Kept at the measured error width rather than tuned to the benchmark. |
| `duckEffectiveness` | 0.0 | Swept 0.0-0.9 and left off. Modelling the leak pushed the word down, which measurement says is the wrong direction; `capacityBias` already carries the correction and two parameters fighting each other is worse than one. |

**`capacityBias` must be calibrated in self-play, not against a weak
opponent.** Tuned against `random` it landed at 1.8, which looked right until
the same setting was measured against a competent table and undershot 48% of
its words: a hand's capacity depends on who else is at the table, and random
opponents hand over tricks that real ones keep. The app seats three copies of
one policy, so self-play is the table that matters.

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

Measured p95 on the desktop VM is 12.9ms for Zor at six worlds, inside its
target. **It is not yet on a background isolate**: `DirectAiDecisionService`
runs the policy on the calling isolate, so a Zor decision does occupy the UI
thread for that long. It is bounded by `AiComputeBudget.timeLimit` and lands
inside the opponent's think delay, so it is not visible today, but the
isolate-backed service is still owed before any level with a larger budget
ships. Budgets are enforced by `AiComputeBudget`, and a policy that overruns
must return its best
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
