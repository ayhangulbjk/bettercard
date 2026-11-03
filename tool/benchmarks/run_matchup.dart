// Paired strength benchmark for Koz Maca, scored in points.
//
// Run with:
//   dart run tool/benchmarks/run_matchup.dart --hands 2000
//   dart run tool/benchmarks/run_matchup.dart --hands 800 --agent mc \
//       --opponent heuristic --worlds 24
//   dart run tool/benchmarks/run_matchup.dart --hands 800 --bust 2
//
// Agents: random, greedy (the trick-maximising control), beginner, heuristic,
// mc. Protocol, per docs/AI_BENCHMARKS.md: the same deals are replayed with
// the measured agent in every seat in turn, so seat order and deal luck
// cancel out instead of being averaged over.
//
// The reported number is **points per hand**, not tricks. Under Koz Maca's
// declaration scoring the two can point in opposite directions: an extra
// trick is worth +1 to a seat with room and -50 to a seat at its bust line.
// An agent tuned on tricks per hand is tuned on the wrong number, which is
// why this script stopped measuring them.
//
// The margin is the agent's points minus the mean points of the baseline
// seats at the same table, on the same deal. Comparing within the deal is
// what makes a few thousand hands enough: the variance of a Batak deal dwarfs
// the difference between two competent agents.

import 'dart:io';

import 'package:batak_king/core/ai/ai_difficulty.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/policies/monte_carlo_policy.dart';
import 'package:batak_king/core/ai/policies/random_legal_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/rules/declaration_rules.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:batak_king/core/simulation/headless_simulator.dart';
import 'package:batak_king/core/simulation/simulation_config.dart';
import 'package:batak_king/core/simulation/simulation_report.dart';
import 'package:batak_king/core/simulation/statistics.dart';

void main(List<String> args) {
  final Map<String, String> options = _parse(args);
  final int hands = int.tryParse(options['hands'] ?? '') ?? 1000;
  final int players = int.tryParse(options['players'] ?? '') ?? 4;
  final int seed = int.tryParse(options['seed'] ?? '') ?? 1;
  final String agent = options['agent'] ?? 'heuristic';
  final String opponent = options['opponent'] ?? 'random';
  // The bust threshold is a per-match setting in the product, so it is a flag
  // here: an agent that reads the rule should play a 2-yan table differently
  // from a 3-yan one, and that claim has to be measurable.
  final String bust = options['bust'] ?? '3';
  // For a sampling policy the budget IS the algorithm, so the difficulty
  // levels are picked off this curve rather than guessed.
  final int worlds =
      int.tryParse(options['worlds'] ?? '') ?? MonteCarloPolicy.defaultWorlds;
  final int? threshold = int.tryParse(bust);

  final SimulationConfig config = SimulationConfig(
    handCount: hands,
    playerCount: players,
    baseSeed: seed,
    trump: Suit.spades,
    rules: TrickRules.kozMaca,
    declarationRules: DeclarationRules.kozMacaStandard.copyWith(
      overtrickBustThreshold: threshold,
      clearOvertrickBustThreshold: threshold == null,
    ),
    // Off here: this run measures strength over many deals, and the
    // correctness harness (run_baseline.dart) is the one that checks every
    // ply. Illegal moves still fail the run.
    checkInvariants: false,
  );

  stdout.writeln('Batak & King - Koz Maca matchup benchmark');
  stdout.writeln(
    'agent=$agent vs $opponent  hands=$hands players=$players seed=$seed',
  );
  stdout.writeln(
    'payoff: soz x${config.declarationRules.pointsPerDeclaredTrick}, '
    'yan ${config.declarationRules.pointsPerOvertrick}, '
    'bust ${config.declarationRules.overtrickBustThreshold ?? "-"}'
    '   worlds=$worlds',
  );
  stdout.writeln('');

  const HeadlessSimulator simulator = HeadlessSimulator();
  final List<SimulationReport> rotations = <SimulationReport>[
    for (int underTest = 0; underTest < players; underTest++)
      _runRotation(
        simulator: simulator,
        config: config,
        agent: agent,
        opponent: opponent,
        seed: seed,
        underTest: underTest,
        players: players,
        worlds: worlds,
      ),
  ];

  // One paired sample per deal: the agent's points, averaged over the seats it
  // occupied, minus the baseline seats' mean points on the same deals.
  final List<double> margins = <double>[
    for (int hand = 0; hand < hands; hand++)
      _agentPoints(rotations, hand, players) -
          _baselinePoints(rotations, hand, players),
  ];
  final ConfidenceInterval margin = ConfidenceInterval.ofSamples(margins);

  final int illegal = rotations.fold<int>(
    0,
    (int sum, SimulationReport r) => sum + r.totalIllegalAttempts,
  );
  final int decisions = rotations.fold<int>(
    0,
    (int sum, SimulationReport r) => sum + r.totalDecisions,
  );

  stdout.writeln('deals             : $hands (x$players seat rotations)');
  stdout.writeln('decisions         : $decisions');
  stdout.writeln(
    'agent points      : '
    '${_meanOver(rotations, hands, players, _agentPoints).toStringAsFixed(3)}'
    ' /hand',
  );
  stdout.writeln(
    'baseline points   : '
    '${_meanOver(rotations, hands, players, _baselinePoints).toStringAsFixed(3)}'
    ' /hand',
  );
  stdout.writeln('margin            : ${_formatInterval(margin)}');
  stdout.writeln('');
  _writeDeclarationStats(rotations, players, agent, opponent);
  stdout.writeln(
    'latency (p50/p95) : ${rotations.first.latency.p50Micros}us / '
    '${rotations.first.latency.p95Micros}us',
  );
  stdout.writeln('');

  if (illegal > 0) {
    stderr.writeln('FAIL: $illegal illegal command(s) recorded.');
    exitCode = 1;
    return;
  }

  final double half = margin.z * margin.standardError;
  if (margin.mean - half > 0) {
    stdout.writeln('STRONGER than $opponent: the interval excludes zero.');
  } else if (margin.mean + half < 0) {
    stdout.writeln('WEAKER than $opponent: the interval excludes zero.');
  } else {
    stdout.writeln(
      'INCONCLUSIVE: the interval contains zero. No strength claim.',
    );
  }
}

SimulationReport _runRotation({
  required HeadlessSimulator simulator,
  required SimulationConfig config,
  required String agent,
  required String opponent,
  required int seed,
  required int underTest,
  required int players,
  required int worlds,
}) {
  // One policy object per seat, so the agent and the baselines never share a
  // generator stream and a rotation is reproducible from the base seed alone.
  final List<_Agent> seats = <_Agent>[
    for (int seat = 0; seat < players; seat++)
      _build(
        seat == underTest ? agent : opponent,
        seed: seed * 7919 + underTest * 31 + seat,
        worlds: worlds,
      ),
  ];
  return simulator.run(
    config: config,
    deciders: <SeatDecider>[for (final _Agent a in seats) a.play],
    declarers: <SeatDeclarer>[for (final _Agent a in seats) a.declare],
  );
}

/// The agent's mean points on one deal, across the seats it occupied.
double _agentPoints(
  List<SimulationReport> rotations,
  int hand,
  int players,
) {
  double sum = 0;
  for (int underTest = 0; underTest < players; underTest++) {
    sum += rotations[underTest].hands[hand].points[underTest];
  }
  return sum / players;
}

/// The baseline seats' mean points on the same deal.
double _baselinePoints(
  List<SimulationReport> rotations,
  int hand,
  int players,
) {
  double sum = 0;
  for (int underTest = 0; underTest < players; underTest++) {
    final HandResult result = rotations[underTest].hands[hand];
    for (int seat = 0; seat < players; seat++) {
      if (seat != underTest) {
        sum += result.points[seat];
      }
    }
  }
  return sum / (players * (players - 1));
}

double _meanOver(
  List<SimulationReport> rotations,
  int hands,
  int players,
  double Function(List<SimulationReport>, int, int) of,
) {
  double sum = 0;
  for (int hand = 0; hand < hands; hand++) {
    sum += of(rotations, hand, players);
  }
  return hands == 0 ? 0 : sum / hands;
}

/// Declaration quality, which is where most of the points live.
///
/// Missing the word and drowning in extras are different mistakes and a
/// policy can trade one for the other, so they are counted apart rather than
/// rolled into one success rate. The drift histogram is the shape a
/// declaration evaluator has to model, and it is printed because tuning one
/// without looking at it is guesswork.
void _writeDeclarationStats(
  List<SimulationReport> rotations,
  int players,
  String agent,
  String opponent,
) {
  double made = 0;
  double under = 0;
  double over = 0;
  double error = 0;
  double baseMade = 0;
  final Map<int, int> drift = <int, int>{};
  int driftTotal = 0;

  for (int underTest = 0; underTest < players; underTest++) {
    final SimulationReport report = rotations[underTest];
    made += report.declarationSuccessOf(underTest);
    under += report.undershootRateOf(underTest);
    over += report.overshootRateOf(underTest);
    error += report.declarationErrorOf(underTest);
    for (int seat = 0; seat < players; seat++) {
      if (seat != underTest) {
        baseMade += report.declarationSuccessOf(seat) / (players - 1);
      }
    }
    for (final HandResult result in report.hands) {
      final int? word = result.declarations[underTest];
      if (word == null) {
        continue;
      }
      final int delta = result.tricksWon[underTest] - word;
      drift[delta] = (drift[delta] ?? 0) + 1;
      driftTotal++;
    }
  }

  String pct(double total) => '${(total / players * 100).toStringAsFixed(1)}%';
  stdout.writeln('$agent soz tuttu  : ${pct(made)}');
  stdout.writeln('  kaldi (az aldi) : ${pct(under)}');
  stdout.writeln('  yandan batti    : ${pct(over)}');
  stdout.writeln(
    '  ortalama sapma  : ${(error / players).toStringAsFixed(2)} el',
  );
  stdout.writeln('$opponent soz tuttu: ${pct(baseMade)}');
  if (driftTotal > 0) {
    final List<int> deltas = drift.keys.toList()..sort();
    stdout.writeln(
      '  sapma dagilimi  : ${deltas.map((int d) => '$d:'
          '${(drift[d]! / driftTotal * 100).toStringAsFixed(1)}').join('  ')}',
    );
  }
}

/// A policy paired with the two callbacks the simulator wants.
final class _Agent {
  const _Agent({required this.play, required this.declare});

  final SeatDecider play;
  final SeatDeclarer declare;
}

_Agent _build(String name, {required int seed, required int worlds}) {
  switch (name) {
    case 'random':
      final RandomLegalPolicy policy = RandomLegalPolicy(seed: seed);
      return _Agent(
        play: policy.chooseCardSync,
        declare: policy.chooseDeclarationSync,
      );
    case 'beginner':
      return _heuristic(HeuristicPolicy.beginner(seed: seed));
    case 'greedy':
      return _heuristic(HeuristicPolicy.trickGreedy(seed: seed));
    case 'mc':
    case 'montecarlo':
      return _search(seed: seed, worlds: worlds, solverDepth: 0);
    case 'mc-solver':
      // The same sampler, finishing the last tricks exactly instead of
      // rolling them out. Its own agent name so the two can be run head to
      // head: a deeper level has to be measured against the shallower one,
      // not assumed to be better because it costs more.
      return _search(seed: seed, worlds: worlds, solverDepth: 4);
    case 'heuristic':
    default:
      return _heuristic(HeuristicPolicy(seed: seed));
  }
}

_Agent _search({
  required int seed,
  required int worlds,
  required int solverDepth,
}) {
  final MonteCarloPolicy search = MonteCarloPolicy(seed: seed);
  final HeuristicPolicy words = HeuristicPolicy(seed: seed);
  final AiComputeBudget budget = AiComputeBudget(
    // Generous on purpose: this measures the algorithm, and the shipped
    // levels cap it with budgets of their own.
    timeLimit: const Duration(milliseconds: 2000),
    maxWorlds: worlds,
    maxRollouts: 0,
    maxSolverDepth: solverDepth,
  );
  return _Agent(
    play: (SeatObservation observation) =>
        search.chooseCardSync(observation, budget),
    declare: words.chooseDeclarationSync,
  );
}

_Agent _heuristic(HeuristicPolicy policy) => _Agent(
      play: policy.chooseCardSync,
      declare: policy.chooseDeclarationSync,
    );

String _formatInterval(ConfidenceInterval interval) {
  final double half = interval.z * interval.standardError;
  return '${interval.mean >= 0 ? '+' : ''}${interval.mean.toStringAsFixed(2)} '
      '+/- ${half.toStringAsFixed(2)} points/hand (95%)';
}

/// Minimal `--key value` parser. No argument-parsing dependency for a
/// developer-only script.
Map<String, String> _parse(List<String> args) {
  final Map<String, String> parsed = <String, String>{};
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) {
      parsed[args[i].substring(2)] = args[i + 1];
    }
  }
  return parsed;
}
