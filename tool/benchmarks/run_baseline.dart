// Headless baseline benchmark.
//
// Run with:
//   dart run tool/benchmarks/run_baseline.dart --hands 2000 --players 4
//
// What it measures today: that the shared trick core never produces a position
// with no legal move, that no agent can submit an illegal command, and how
// fast decisions flow through the engine. It is NOT a strength benchmark --
// the only agent that exists is the legal-random baseline, so there is nothing
// to compare it against yet. See docs/AI_BENCHMARKS.md for the protocol the
// strength comparisons will follow once a second agent exists.

import 'dart:io';

import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:batak_king/core/simulation/headless_simulator.dart';
import 'package:batak_king/core/simulation/simulation_config.dart';
import 'package:batak_king/core/simulation/simulation_report.dart';

void main(List<String> args) {
  final Map<String, String> options = _parse(args);
  final int hands = int.tryParse(options['hands'] ?? '') ?? 1000;
  final int players = int.tryParse(options['players'] ?? '') ?? 4;
  final int seed = int.tryParse(options['seed'] ?? '') ?? 1;
  final String ruleName = options['rules'] ?? 'batak';

  final TrickRules rules = switch (ruleName) {
    'kozmaca' => TrickRules.kozMaca,
    'notrump' => TrickRules.noTrump,
    _ => TrickRules.batakStandard,
  };
  final Suit? trump = ruleName == 'notrump' ? null : Suit.spades;

  stdout.writeln('Batak & King - baseline benchmark');
  stdout.writeln('hands=$hands players=$players seed=$seed rules=$ruleName');
  stdout.writeln('');

  final SimulationReport report = const HeadlessSimulator().runRandomBaseline(
    SimulationConfig(
      handCount: hands,
      playerCount: players,
      baseSeed: seed,
      trump: trump,
      rules: rules,
      // Invariants are checked on every ply here: this harness exists to find
      // correctness bugs, and throughput is the secondary number.
      checkInvariants: true,
    ),
  );

  stdout.write(report.describe());

  if (report.totalIllegalAttempts > 0) {
    stderr.writeln(
      'FAIL: ${report.totalIllegalAttempts} illegal command(s) recorded.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('');
  stdout.writeln('OK: no illegal commands, all invariants held.');
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
