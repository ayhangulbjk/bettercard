// Paired strength benchmark: one agent against the legal-random baseline.
//
// Run with:
//   dart run tool/benchmarks/run_matchup.dart --hands 2000
//   dart run tool/benchmarks/run_matchup.dart --hands 2000 --agent beginner
//
// Protocol, per docs/AI_BENCHMARKS.md: the same deals are replayed with the
// measured agent in every seat in turn, so seat order and deal luck cancel out
// instead of being averaged over. The reported number is the agent's tricks
// per hand minus the share a seat gets by chance (tricks / players), with a
// 95% interval. A margin whose interval excludes zero is the only thing this
// project accepts as evidence that one agent is stronger than another.
//
// This measures trick taking in the shared trick core, which is the whole of
// the Koz Maca objective. It says nothing about the auction modes, where
// making or breaking a contract -- not trick count -- is what scores.

import 'dart:io';

import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/policies/random_legal_policy.dart';
import 'package:batak_king/core/cards/suit.dart';
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

  final SimulationConfig config = SimulationConfig(
    handCount: hands,
    playerCount: players,
    baseSeed: seed,
    trump: Suit.spades,
    rules: TrickRules.kozMaca,
    // Off here: this run measures strength over many deals, and the
    // correctness harness (run_baseline.dart) is the one that checks every
    // ply. Illegal moves still fail the run.
    checkInvariants: false,
  );

  stdout.writeln('Batak & King - matchup benchmark');
  stdout.writeln(
    'agent=$agent vs random-legal  hands=$hands players=$players seed=$seed',
  );
  stdout.writeln('');

  const HeadlessSimulator simulator = HeadlessSimulator();
  final List<SimulationReport> rotations = <SimulationReport>[
    for (int underTest = 0; underTest < players; underTest++)
      simulator.run(
        config: config,
        deciders: <SeatDecider>[
          for (int seat = 0; seat < players; seat++)
            seat == underTest
                ? _agentDecider(agent, seed: seed * 7919 + underTest)
                : RandomLegalPolicy(seed: seed * 1000 + underTest * 10 + seat)
                    .chooseCardSync,
        ],
      ),
  ];

  final int tricksPerHand = config.effectiveHandSize;
  final double chanceShare = tricksPerHand / players;

  // One paired sample per deal: the agent's tricks averaged over the seats it
  // occupied, minus the chance share. Pairing is what makes a few thousand
  // deals enough; unpaired, deal luck would swamp the margin.
  final List<double> margins = <double>[
    for (int hand = 0; hand < hands; hand++)
      _meanAgentTricks(rotations, hand, players) - chanceShare,
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

  stdout.writeln('deals            : $hands (x$players seat rotations)');
  stdout.writeln('decisions        : $decisions');
  stdout.writeln('chance share     : ${chanceShare.toStringAsFixed(3)} '
      'tricks/hand');
  stdout.writeln('agent tricks     : '
      '${(margin.mean + chanceShare).toStringAsFixed(3)} tricks/hand');
  stdout.writeln('margin           : ${_formatInterval(margin)}');
  stdout.writeln('latency (p50/p95): '
      '${rotations.first.latency.p50Micros}us / '
      '${rotations.first.latency.p95Micros}us');
  stdout.writeln('');

  if (illegal > 0) {
    stderr.writeln('FAIL: $illegal illegal command(s) recorded.');
    exitCode = 1;
    return;
  }

  final double low = margin.mean - margin.z * margin.standardError;
  final double high = margin.mean + margin.z * margin.standardError;
  if (low > 0) {
    stdout.writeln(
      'STRONGER than random-legal: the interval excludes zero.',
    );
  } else if (high < 0) {
    stdout.writeln(
      'WEAKER than random-legal: the interval excludes zero.',
    );
  } else {
    stdout.writeln(
      'INCONCLUSIVE: the interval contains zero. No strength claim.',
    );
  }
}

/// The agent's mean tricks on one deal, across the seats it occupied.
double _meanAgentTricks(
  List<SimulationReport> rotations,
  int hand,
  int players,
) {
  double sum = 0;
  for (int underTest = 0; underTest < players; underTest++) {
    sum += rotations[underTest].hands[hand].tricksWon[underTest];
  }
  return sum / players;
}

SeatDecider _agentDecider(String agent, {required int seed}) => switch (agent) {
      'beginner' => HeuristicPolicy.beginner(seed: seed).chooseCardSync,
      'random' => RandomLegalPolicy(seed: seed).chooseCardSync,
      _ => HeuristicPolicy(seed: seed).chooseCardSync,
    };

String _formatInterval(ConfidenceInterval interval) {
  final double half = interval.z * interval.standardError;
  return '${interval.mean >= 0 ? '+' : ''}${interval.mean.toStringAsFixed(3)} '
      '+/- ${half.toStringAsFixed(3)} tricks/hand (95%)';
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
