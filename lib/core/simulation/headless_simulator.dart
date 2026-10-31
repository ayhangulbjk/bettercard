import '../ai/policies/random_legal_policy.dart';
import '../ai/seat_observation.dart';
import '../cards/deck.dart';
import '../cards/playing_card.dart';
import '../game_engine/game_command.dart';
import '../game_engine/game_engine.dart';
import '../game_engine/seating.dart';
import '../game_engine/trick/trick_play_engine.dart';
import '../game_engine/trick/trick_play_state.dart';
import '../rules/rule_violation.dart';
import 'simulation_config.dart';
import 'simulation_report.dart';
import 'statistics.dart';

/// Picks a card for a seat, synchronously.
///
/// The simulator runs millions of decisions, so it takes this narrow callback
/// rather than the async AiPolicy interface: awaiting a future per card would
/// dominate the measurement. Policies that can answer synchronously expose a
/// `chooseCardSync`; search policies get a dedicated isolate harness instead.
typedef SeatDecider = PlayingCard Function(SeatObservation observation);

/// Runs trick-play hands with no UI, no I/O and no clock dependence.
///
/// This is the foundation the AI benchmark harness is built on. What it does
/// today is real and useful: it deals seeded hands, drives the authoritative
/// engine, verifies that no agent ever produces an illegal command, checks
/// state invariants after every ply, and reports latency and per-seat results
/// with confidence intervals.
///
/// What it does NOT do yet is simulate any of the five games end to end: the
/// auction, contract selection, burying and scoring lifecycles do not exist
/// yet, so there is no match-level win rate to report. See docs/ROADMAP.md.
final class HeadlessSimulator {
  const HeadlessSimulator({this.engine = const TrickPlayEngine()});

  final TrickPlayEngine engine;

  /// Plays [config.handCount] hands, one decider per seat.
  ///
  /// [deciders] must have one entry per seat. Supplying the same decider for
  /// every seat measures that agent against itself, which is the right shape
  /// for a sanity run; supplying different ones measures a matchup.
  SimulationReport run({
    required SimulationConfig config,
    required List<SeatDecider> deciders,
  }) {
    if (deciders.length != config.playerCount) {
      throw ArgumentError(
        'Expected ${config.playerCount} deciders, got ${deciders.length}',
      );
    }
    final Stopwatch batchClock = Stopwatch()..start();
    final List<HandResult> hands = <HandResult>[];
    final List<int> latencies = <int>[];

    for (int hand = 0; hand < config.handCount; hand++) {
      hands.add(
        _playHand(
          config: config,
          deciders: deciders,
          seed: config.baseSeed + hand,
          latencyMicros: latencies,
        ),
      );
    }
    batchClock.stop();

    return SimulationReport(
      hands: hands,
      latency: LatencySummary.ofMicros(latencies),
      elapsed: batchClock.elapsed,
      tricksPerSeat: <ConfidenceInterval>[
        for (int seat = 0; seat < config.playerCount; seat++)
          ConfidenceInterval.ofSamples(<double>[
            for (final HandResult result in hands)
              result.tricksWon[seat].toDouble(),
          ]),
      ],
    );
  }

  /// Convenience: every seat plays the legal-random baseline.
  ///
  /// Each seat gets its own generator stream derived from the config seed, so
  /// seats do not accidentally make correlated choices.
  SimulationReport runRandomBaseline(SimulationConfig config) => run(
        config: config,
        deciders: <SeatDecider>[
          for (int seat = 0; seat < config.playerCount; seat++)
            _syncDecider(
              RandomLegalPolicy(seed: config.baseSeed * 1000 + seat),
            ),
        ],
      );

  static SeatDecider _syncDecider(RandomLegalPolicy policy) =>
      policy.chooseCardSync;

  HandResult _playHand({
    required SimulationConfig config,
    required List<SeatDecider> deciders,
    required int seed,
    required List<int> latencyMicros,
  }) {
    final SeatingPlan seating = SeatingPlan.individual(config.playerCount);
    final Deal deal = Deck.shuffleAndDeal(
      seed: seed,
      handCount: config.playerCount,
      handSize: config.effectiveHandSize,
    );

    TrickPlayState state = TrickPlayState.opening(
      hands: deal.hands,
      seating: seating,
      rules: config.rules,
      trump: config.trump,
      // abs() so a negative base seed cannot produce an out-of-range seat.
      leadSeat: seed.abs() % config.playerCount,
    );

    int decisions = 0;
    int illegal = 0;
    final Stopwatch decisionClock = Stopwatch();

    while (!engine.isTerminal(state)) {
      final int seat = state.turnSeat;
      final SeatObservation observation =
          SeatObservation.fromState(state, seat);

      decisionClock
        ..reset()
        ..start();
      final PlayingCard card = deciders[seat](observation);
      decisionClock.stop();
      latencyMicros.add(decisionClock.elapsedMicroseconds);
      decisions++;

      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: seat, card: card),
      );
      switch (outcome) {
        case CommandAccepted<TrickPlayState>(state: final TrickPlayState next):
          state = next;
        case CommandRejected<TrickPlayState>(
            violation: final RuleViolation violation
          ):
          {
            // An agent produced an illegal move. Substituting a legal card
            // silently would hide exactly the defect this harness exists to
            // catch, so the default is to fail the run outright.
            illegal++;
            if (config.failOnIllegalMove) {
              throw StateError(
                'Seat $seat played an illegal card $card in hand $seed: '
                '$violation',
              );
            }
            // Measurement mode: record the attempt and continue with the first
            // legal card so the batch can report an illegal-move rate.
            final List<PlayingCard> legal = engine.legalCards(state, seat);
            state = switch (engine.apply(
              state,
              PlayCardCommand(seat: seat, card: legal.first),
            )) {
              CommandAccepted<TrickPlayState>(state: final TrickPlayState s) =>
                s,
              CommandRejected<TrickPlayState>() => throw StateError(
                  'Engine rejected its own legal move for seat $seat',
                ),
            };
          }
      }

      if (config.checkInvariants) {
        state.checkInvariants(expectedTotalCards: config.dealtCardCount);
      }
    }

    return HandResult(
      seed: seed,
      tricksWon: state.tricksWon,
      decisionCount: decisions,
      illegalAttempts: illegal,
    );
  }
}
