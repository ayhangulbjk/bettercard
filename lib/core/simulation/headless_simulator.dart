import '../ai/match_context.dart';
import '../ai/policies/random_legal_policy.dart';
import '../ai/seat_observation.dart';
import '../cards/deck.dart';
import '../cards/playing_card.dart';
import '../game_engine/game_command.dart';
import '../game_engine/game_engine.dart';
import '../game_engine/seating.dart';
import '../game_engine/trick/trick_play_engine.dart';
import '../game_engine/trick/trick_play_state.dart';
import '../rules/declaration_rules.dart';
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

/// Picks a declaration for a seat, synchronously.
///
/// [options] is handed in rather than derived by the agent, for the same
/// reason `observation.legalMoves` is: what may be declared is a rule, and
/// rules have one authority.
typedef SeatDeclarer = int Function(
  SeatObservation observation,
  List<int> options,
);

/// Runs trick-play hands with no UI, no I/O and no clock dependence.
///
/// This is the foundation the AI benchmark harness is built on. What it does
/// today is real and useful: it deals seeded hands, drives the authoritative
/// engine, verifies that no agent ever produces an illegal command, checks
/// state invariants after every ply, and reports latency and per-seat results
/// with confidence intervals.
///
/// With a declaring profile it also runs the declaration round and scores the
/// hand through [DeclarationRules.scoreFor] -- the same authority that pays a
/// real hand -- so a batch reports points, not only tricks. That distinction
/// is the whole point: under a bust threshold the two measurements disagree,
/// and an agent tuned on tricks per hand is tuned on the wrong number.
///
/// What it does NOT do yet is simulate the auction modes end to end: the
/// auction, contract selection and burying lifecycles do not exist yet, so
/// there is no match-level win rate to report for them. See docs/ROADMAP.md.
final class HeadlessSimulator {
  const HeadlessSimulator({this.engine = const TrickPlayEngine()});

  final TrickPlayEngine engine;

  /// Plays [config.handCount] hands, one decider per seat.
  ///
  /// [deciders] must have one entry per seat. Supplying the same decider for
  /// every seat measures that agent against itself, which is the right shape
  /// for a sanity run; supplying different ones measures a matchup.
  /// [declarers] must be supplied when the config has a declaration round,
  /// one per seat, and must be absent when it does not. A declaring profile
  /// played without declarers would score every hand as a missed word, which
  /// is a silently wrong benchmark rather than a loud one.
  SimulationReport run({
    required SimulationConfig config,
    required List<SeatDecider> deciders,
    List<SeatDeclarer>? declarers,
  }) {
    if (deciders.length != config.playerCount) {
      throw ArgumentError(
        'Expected ${config.playerCount} deciders, got ${deciders.length}',
      );
    }
    if (config.declarationRules.enabled) {
      if (declarers == null || declarers.length != config.playerCount) {
        throw ArgumentError(
          'A declaring profile needs ${config.playerCount} declarers, got '
          '${declarers?.length}',
        );
      }
    } else if (declarers != null) {
      throw ArgumentError(
        'Declarers were supplied for a profile with no declaration round',
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
          declarers: declarers,
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
      pointsPerSeat: !config.declarationRules.enabled
          ? const <ConfidenceInterval>[]
          : <ConfidenceInterval>[
              for (int seat = 0; seat < config.playerCount; seat++)
                ConfidenceInterval.ofSamples(<double>[
                  for (final HandResult result in hands)
                    result.points[seat].toDouble(),
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
    required List<SeatDeclarer>? declarers,
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

    final List<int?> declarations = declarers == null
        ? List<int?>.filled(config.playerCount, null)
        : _runDeclarationRound(
            config: config,
            declarers: declarers,
            state: state,
            latencyMicros: latencyMicros,
            decisionClock: decisionClock,
          );
    decisions += declarers == null ? 0 : config.playerCount;

    while (!engine.isTerminal(state)) {
      final int seat = state.turnSeat;
      final SeatObservation observation = SeatObservation.fromState(
        state,
        seat,
        match: _contextFor(config, declarations),
      );

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

    final List<int> tricks = state.tricksWon;
    return HandResult(
      seed: seed,
      tricksWon: tricks,
      decisionCount: decisions,
      illegalAttempts: illegal,
      declarations: declarations,
      points: <int>[
        for (int seat = 0; seat < config.playerCount; seat++)
          declarations[seat] == null
              ? 0
              : config.declarationRules.scoreFor(
                  declaration: declarations[seat]!,
                  tricksTaken: tricks[seat],
                ),
      ],
    );
  }

  /// Collects one declaration per seat, in turn order from the opening lead.
  ///
  /// Each seat sees only the declarations spoken before its own, which is what
  /// a real table gives it: speaking first is a worse position than speaking
  /// last, and a benchmark that handed everyone the full set would be
  /// measuring a game nobody plays.
  List<int?> _runDeclarationRound({
    required SimulationConfig config,
    required List<SeatDeclarer> declarers,
    required TrickPlayState state,
    required List<int> latencyMicros,
    required Stopwatch decisionClock,
  }) {
    final List<int?> declarations = List<int?>.filled(config.playerCount, null);
    final List<int> options = config.legalDeclarations;
    for (int step = 0; step < config.playerCount; step++) {
      final int seat = (state.turnSeat + step) % config.playerCount;
      final SeatObservation observation = SeatObservation.fromState(
        state,
        seat,
        match: _contextFor(config, declarations),
      );
      decisionClock
        ..reset()
        ..start();
      final int declared = declarers[seat](observation, options);
      decisionClock.stop();
      latencyMicros.add(decisionClock.elapsedMicroseconds);
      if (!options.contains(declared)) {
        throw StateError(
          'Seat $seat declared $declared, which is not among $options',
        );
      }
      declarations[seat] = declared;
    }
    return declarations;
  }

  static MatchContext _contextFor(
    SimulationConfig config,
    List<int?> declarations,
  ) =>
      MatchContext(
        declarationRules: config.declarationRules,
        declarations: declarations,
        // One hand at a time: there is no running match, so every seat is
        // level. Reporting a fabricated total would be worse than none.
        totalScores: List<int>.filled(config.playerCount, 0),
      );
}
