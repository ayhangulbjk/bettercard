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
    List<int?>? declarations,
    List<int>? points,
  })  : tricksWon = List<int>.unmodifiable(tricksWon),
        declarations = List<int?>.unmodifiable(
          declarations ?? List<int?>.filled(tricksWon.length, null),
        ),
        points = List<int>.unmodifiable(
          points ?? List<int>.filled(tricksWon.length, 0),
        );

  /// The seed this hand was dealt from; replay it to reproduce the hand.
  final int seed;

  /// Tricks taken per seat.
  final List<int> tricksWon;

  /// What each seat declared, or null in a run with no declaration round.
  final List<int?> declarations;

  /// Points scored per seat, by [DeclarationRules.scoreFor]. All zero in a
  /// run with no declaration round, where tricks are the only outcome.
  final List<int> points;

  /// Whether [seat] came out of the hand ahead. Null when it did not declare.
  ///
  /// Read from the points, for the same reason `HandScore.madeDeclaration`
  /// is: clearing the declared number is not the same as being paid for it.
  bool? madeDeclaration(int seat) =>
      declarations[seat] == null ? null : points[seat] > 0;

  /// Tricks taken above a kept declaration, or null when the declaration was
  /// missed outright or there was none.
  int? extrasOf(int seat) {
    final int? declared = declarations[seat];
    if (declared == null || tricksWon[seat] < declared) {
      return null;
    }
    return tricksWon[seat] - declared;
  }

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
    List<ConfidenceInterval>? pointsPerSeat,
  })  : hands = List<HandResult>.unmodifiable(hands),
        tricksPerSeat = List<ConfidenceInterval>.unmodifiable(tricksPerSeat),
        pointsPerSeat = List<ConfidenceInterval>.unmodifiable(
          pointsPerSeat ?? const <ConfidenceInterval>[],
        );

  final List<HandResult> hands;

  /// Per-decision latency distribution.
  final LatencySummary latency;

  /// Wall-clock time for the whole batch. Reported for throughput only; no
  /// engine logic reads a clock.
  final Duration elapsed;

  /// Mean tricks won per seat, with 95% intervals.
  final List<ConfidenceInterval> tricksPerSeat;

  /// Mean points scored per seat, with 95% intervals. Empty in a run with no
  /// declaration round.
  final List<ConfidenceInterval> pointsPerSeat;

  /// Whether this batch scored declarations at all.
  bool get hasDeclarations => pointsPerSeat.isNotEmpty;

  /// Share of declarations [seat] was paid for, over the hands it declared.
  ///
  /// Returns 0 when the seat never declared, which only happens in a run
  /// with no declaration round.
  double declarationSuccessOf(int seat) {
    int declared = 0;
    int made = 0;
    for (final HandResult hand in hands) {
      final bool? result = hand.madeDeclaration(seat);
      if (result == null) {
        continue;
      }
      declared++;
      if (result) {
        made++;
      }
    }
    return declared == 0 ? 0 : made / declared;
  }

  /// Share of hands [seat] lost by missing its number outright, as opposed to
  /// by collecting too many extras. The two are different mistakes and a
  /// policy can trade one for the other, so they are counted apart.
  double undershootRateOf(int seat) => _rateOf(
        seat,
        (HandResult hand, int declared) => hand.tricksWon[seat] < declared,
      );

  /// Share of hands [seat] lost by overshooting a kept declaration.
  double overshootRateOf(int seat) => _rateOf(
        seat,
        (HandResult hand, int declared) =>
            hand.tricksWon[seat] >= declared && hand.points[seat] <= 0,
      );

  /// Mean absolute distance between what [seat] declared and what it took.
  double declarationErrorOf(int seat) {
    int declared = 0;
    int total = 0;
    for (final HandResult hand in hands) {
      final int? value = hand.declarations[seat];
      if (value == null) {
        continue;
      }
      declared++;
      total += (hand.tricksWon[seat] - value).abs();
    }
    return declared == 0 ? 0 : total / declared;
  }

  double _rateOf(int seat, bool Function(HandResult, int) predicate) {
    int declared = 0;
    int hits = 0;
    for (final HandResult hand in hands) {
      final int? value = hand.declarations[seat];
      if (value == null) {
        continue;
      }
      declared++;
      if (predicate(hand, value)) {
        hits++;
      }
    }
    return declared == 0 ? 0 : hits / declared;
  }

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
