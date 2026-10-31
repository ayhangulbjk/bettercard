# AI strategy

The product's competitive advantage is meant to be strong, fair, challenging
opponents. Two words in that sentence do the heavy lifting: **fair** (the AI
never sees hidden information) and **challenging** (strength is measured, not
asserted).

## Status

| Module | State |
|---|---|
| `SeatObservation` + `fromState` filter | Implemented, tested |
| `TrickLegalMoves` (legal move generator) | Implemented, tested |
| `CardTracker` | Implemented, tested |
| `HiddenHandSampler` | Implemented, tested |
| `AiPolicy` interface, `AiComputeBudget` | Implemented |
| `RandomLegalPolicy` (baseline) | Implemented, tested |
| `AiDecisionService` (same-isolate) | Implemented |
| `HeuristicPolicy` | Not started |
| `MonteCarloPolicy` | Not started |
| `BidEvaluator`, `ContractSelector` | Not started |
| `OpponentModel` | Not started |
| `PartnershipStrategy` | Not started |
| `EndgameSolver` | Not started |
| Isolate-backed `AiDecisionService` | Not started |

**There is no strong AI yet.** Milestone 1 ships the information plumbing and
a baseline. No claim of expert play is made anywhere in the product or the
code, and the difficulty selector is labelled accordingly.

## The no-cheating guarantee

A policy sees a `SeatObservation` and nothing else:

- its own hand,
- the trick in progress and the full trick history with winners,
- the trump suit and whether trump is broken,
- the rule profile in force,
- public hand counts and trick counts,
- its pre-computed legal moves.

It cannot reach another seat's cards, buried cards, undealt cards, or the
seeded generator's state. `SeatObservation.fromState` is the only sanctioned
way to build one, so there is exactly one place to audit.

Monte Carlo policies are allowed to **invent** hidden hands consistent with
that information. They are never allowed to read the real ones. The test
harness may inspect true hidden state to score an outcome, but must never feed
it back into a policy. `test/unit/ai_information_filter_test.dart` asserts the
boundary directly: across many plies and every seat, the set of cards
reachable through an observation never intersects another seat's real hand.

## Inference, which is not cheating

`CardTracker` derives from public information only:

- **Played cards**: everything in the trick history and current trick.
- **Unseen cards**: the deck minus played cards minus the observer's hand.
- **Proved voids**: a seat that failed to follow a suit it was *obliged* to
  follow cannot hold that suit. Under a compulsory-trump rule, discarding
  something that is neither the lead suit nor trump additionally proves it
  holds no trump.
- **Master cards**: a card stronger than every unseen card of its suit.

Every one of these is something an attentive human would know. The test suite
checks each inference against the real deal, because an AI reasoning from a
false premise is worse than one reasoning from less.

## Sampling hidden hands

`HiddenHandSampler` turns an observation into complete plausible deals. Every
sample satisfies, exactly:

1. the observer's own hand is unchanged,
2. no sampled hand holds an already-played card,
3. each seat gets exactly as many cards as it publicly holds,
4. no seat gets a suit it has proved it is void in.

Assignment is most-constrained-first: a card only one seat could hold is placed
before cards that fit anywhere, otherwise the flexible cards fill that seat and
the assignment dead-ends. A tight void pattern can still fail, so attempts are
bounded (`maxAttempts`) and failure returns null rather than spinning, which
keeps sampling inside the compute budget.

Sampling is seeded, so a rollout batch is reproducible and a benchmark is
comparable across machines and commits.

## Difficulty levels

Difficulty is an **algorithmic** difference. It is never a longer thinking
delay. The planned ladder:

| Level | Algorithm | Budget shape |
|---|---|---|
| Beginner | Heuristics with deliberate blind spots: ignores the card tracker, does not count trump, no partner signalling | No search |
| Normal | Full heuristic policy: follow-suit tactics, trump management, master-card awareness, basic partner awareness | No search |
| Hard | Heuristic plus shallow sampling: a handful of worlds, greedy playout, pick the best average | ~10-30 worlds |
| Expert | Perfect-information Monte Carlo over sampled worlds, heuristic playouts, exact endgame solver for the last few tricks | ~100-300 worlds, bounded ms |
| Legendary | As Expert, plus opponent modelling from observed play, larger budget, deeper exact endgame | ~500+ worlds, deeper solver |

Beginner is weakened by *removing information it is allowed to use*, never by
making it play illegally or by giving the human secret help.

`AiComputeBudget` carries both a wall-clock limit and work-unit caps. Both
exist because they serve different purposes: benchmarks pin work units so
results compare across machines, while the shipping app pins wall-clock so a
slow device stays responsive. A policy that exceeds its budget must return its
best answer so far.

## Planned module responsibilities

| Module | Responsibility |
|---|---|
| `HeuristicPolicy` | Rule-based card choice from the observation and tracker |
| `MonteCarloPolicy` | Sample worlds, evaluate each legal move, pick the best average |
| `BidEvaluator` | Estimate tricks a hand can take for a given trump |
| `ContractSelector` | Choose a bid or a King contract from the evaluation and quota |
| `OpponentModel` | Infer tendencies from observed play; public information only |
| `PartnershipStrategy` | Partner-aware play: signalling, not overtaking, finessing through |
| `EndgameSolver` | Exact search when few tricks remain and the branching is small |

## Threading

Search must never run on the UI isolate: a long synchronous search drops
frames, and the product targets 60 fps with headroom for 120.

`AiDecisionService` owns scheduling, with cancellation and timeouts, so
policies stay pure and testable. Milestone 1 binds
`DirectAiDecisionService`, which runs on the calling isolate. That is correct
for the cheap baseline and for the headless simulator, and explicitly wrong for
the search levels; the isolate-backed implementation lands with the first
search policy, behind the same interface.

The domain being plain data is what makes that swap cheap: isolates cannot
share Flutter objects, but `TrickPlayState` and `SeatObservation` cross the
boundary unchanged.
