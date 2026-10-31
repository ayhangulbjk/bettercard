import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:batak_king/core/simulation/headless_simulator.dart';
import 'package:batak_king/core/simulation/simulation_config.dart';
import 'package:batak_king/core/simulation/simulation_report.dart';
import 'package:flutter_test/flutter_test.dart';

const HeadlessSimulator simulator = HeadlessSimulator();

void main() {
  group('baseline batch', () {
    test('plays every hand to completion with no illegal move', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 40, playerCount: 4),
      );
      expect(report.handCount, 40);
      expect(report.totalIllegalAttempts, 0);
      // 4 seats x 13 tricks of decisions per hand.
      expect(report.totalDecisions, 40 * 52);
      for (final HandResult hand in report.hands) {
        expect(
          hand.tricksWon.reduce((int a, int b) => a + b),
          13,
          reason: 'hand ${hand.seed} did not distribute 13 tricks',
        );
      }
    });

    test('is reproducible: the same config yields the same results', () {
      const SimulationConfig config =
          SimulationConfig(handCount: 25, playerCount: 4, baseSeed: 99);
      final SimulationReport first = simulator.runRandomBaseline(config);
      final SimulationReport second = simulator.runRandomBaseline(config);
      for (int i = 0; i < first.handCount; i++) {
        expect(
          second.hands[i].tricksWon,
          equals(first.hands[i].tricksWon),
          reason: 'hand $i diverged between identical runs',
        );
      }
    });

    test('a different base seed produces different hands', () {
      final SimulationReport a = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 20, playerCount: 4, baseSeed: 1),
      );
      final SimulationReport b = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 20, playerCount: 4, baseSeed: 500),
      );
      final List<List<int>> aTricks =
          a.hands.map((HandResult h) => h.tricksWon).toList();
      final List<List<int>> bTricks =
          b.hands.map((HandResult h) => h.tricksWon).toList();
      expect(aTricks, isNot(equals(bTricks)));
    });

    test('extending a run does not change the earlier hands', () {
      // Hand i depends only on baseSeed + i, so a longer benchmark remains
      // comparable with a shorter one.
      final SimulationReport short = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 10, playerCount: 4, baseSeed: 7),
      );
      final SimulationReport long = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 30, playerCount: 4, baseSeed: 7),
      );
      for (int i = 0; i < short.handCount; i++) {
        expect(long.hands[i].tricksWon, equals(short.hands[i].tricksWon));
      }
    });
  });

  group('rule variations run clean', () {
    test('three seats with a reduced hand size', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(
          handCount: 15,
          playerCount: 3,
          handSize: 17,
        ),
      );
      expect(report.totalIllegalAttempts, 0);
      for (final HandResult hand in report.hands) {
        expect(hand.tricksWon.reduce((int a, int b) => a + b), 17);
      }
    });

    test('no-trump hands run clean', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(
          handCount: 15,
          playerCount: 4,
          trump: null,
          rules: TrickRules.noTrump,
        ),
      );
      expect(report.totalIllegalAttempts, 0);
    });

    test('the Koz Maca trump-lead restriction runs clean', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(
          handCount: 15,
          playerCount: 4,
          trump: Suit.spades,
          rules: TrickRules.kozMaca,
        ),
      );
      expect(report.totalIllegalAttempts, 0);
    });
  });

  group('reporting', () {
    test('per-seat intervals are produced for every seat', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 60, playerCount: 4),
      );
      expect(report.tricksPerSeat, hasLength(4));
      for (final interval in report.tricksPerSeat) {
        expect(interval.sampleCount, 60);
        expect(interval.mean, greaterThan(0));
      }
    });

    test('mean tricks across seats sum to the trick count', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 60, playerCount: 4),
      );
      final double total = report.tricksPerSeat
          .map((interval) => interval.mean)
          .reduce((double a, double b) => a + b);
      expect(total, closeTo(13.0, 0.0001));
    });

    test('describe produces a non-empty summary', () {
      final SimulationReport report = simulator.runRandomBaseline(
        const SimulationConfig(handCount: 5, playerCount: 4),
      );
      expect(report.describe(), contains('Hands:'));
      expect(report.describe(), contains('Illegal:'));
    });

    test('mismatched decider count is rejected', () {
      expect(
        () => simulator.run(
          config: const SimulationConfig(handCount: 1, playerCount: 4),
          deciders: const <SeatDecider>[],
        ),
        throwsArgumentError,
      );
    });
  });
}
