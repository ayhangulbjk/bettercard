import 'package:meta/meta.dart';

import 'statistics.dart';

/// Outcome of one simulated hand.
@immutable
class HandResult {
  HandResult({
    required this.seed,
    required List<int> tricksWon,
    required this.decisionCount,
    required this.illegalAttempts,
  }) : tricksWon = List<int>.unmodifiable(tricksWon);

  /// The seed this hand was dealt from; replay it to reproduce the hand.
  final int seed;

  /// Tricks taken per seat.
  final List<int> tricksWon;

  /// How many card decisions were made.
  final int decisionCount;

  /// How many commands the engine rejected.
  ///
  /// Any value above zero is a defect in an agent or in the engine, never bad
  /// luck, so benchmarks treat it as a hard failure rather than a statistic.
  final int illegalAttempts;

  @override
  String toString() =>
      'HandResult(seed: $seed, tricks: $tricksWon, illegal: $illegalAttempts)';
}

/// Aggregated results of a simulation batch.
@immutable
class SimulationReport {
  SimulationReport({
    required List<HandResult> hands,
    required this.latency,
    required this.elapsed,
    required List<ConfidenceInterval> tricksPerSeat,
  })  : hands = List<HandResult>.unmodifiable(hands),
        tricksPerSeat = List<ConfidenceInterval>.unmodifiable(tricksPerSeat);

  final List<HandResult> hands;

  /// Per-decision latency distribution.
  final LatencySummary latency;

  /// Wall-clock time for the whole batch. Reported for throughput only; no
  /// engine logic reads a clock.
  final Duration elapsed;

  /// Mean tricks won per seat, with 95% intervals.
  final List<ConfidenceInterval> tricksPerSeat;

  int get handCount => hands.length;

  /// Total rejected commands across the batch. Must be zero.
  int get totalIllegalAttempts => hands.fold<int>(
        0,
        (int sum, HandResult h) => sum + h.illegalAttempts,
      );

  int get totalDecisions => hands.fold<int>(
        0,
        (int sum, HandResult h) => sum + h.decisionCount,
      );

  /// Decisions per second over the batch.
  double get decisionsPerSecond {
    final int micros = elapsed.inMicroseconds;
    return micros == 0 ? 0 : totalDecisions * 1000000 / micros;
  }

  /// A short human-readable summary for the AI lab screen and the CLI.
  String describe() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Hands:      $handCount')
      ..writeln('Decisions:  $totalDecisions')
      ..writeln('Illegal:    $totalIllegalAttempts')
      ..writeln('Latency:    $latency')
      ..writeln(
        'Throughput: ${decisionsPerSecond.toStringAsFixed(0)} decisions/s',
      );
    for (int seat = 0; seat < tricksPerSeat.length; seat++) {
      buffer.writeln('Seat $seat:     ${tricksPerSeat[seat]}');
    }
    return buffer.toString();
  }
}
