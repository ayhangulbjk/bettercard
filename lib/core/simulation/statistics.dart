import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A mean with an uncertainty interval.
///
/// Benchmarks report these rather than bare averages because a strength claim
/// from a handful of deals is noise. The project rule is that no agent is
/// described as stronger than another unless the difference interval excludes
/// zero; see docs/AI_BENCHMARKS.md.
@immutable
class ConfidenceInterval {
  const ConfidenceInterval({
    required this.mean,
    required this.standardError,
    required this.sampleCount,
    required this.z,
  });

  /// Two-sided 95% normal-approximation interval over [samples].
  ///
  /// The normal approximation is adequate for the sample sizes benchmarks use
  /// (thousands of deals) and is noted as an approximation rather than an
  /// exact bound.
  factory ConfidenceInterval.ofSamples(
    List<double> samples, {
    double z = 1.959964,
  }) {
    if (samples.isEmpty) {
      return ConfidenceInterval(
        mean: double.nan,
        standardError: double.nan,
        sampleCount: 0,
        z: z,
      );
    }
    final int n = samples.length;
    final double mean = samples.reduce((double a, double b) => a + b) / n;
    if (n == 1) {
      return ConfidenceInterval(
        mean: mean,
        standardError: double.nan,
        sampleCount: 1,
        z: z,
      );
    }
    double sumSquares = 0;
    for (final double value in samples) {
      final double delta = value - mean;
      sumSquares += delta * delta;
    }
    final double variance = sumSquares / (n - 1);
    return ConfidenceInterval(
      mean: mean,
      standardError: math.sqrt(variance / n),
      sampleCount: n,
      z: z,
    );
  }

  final double mean;
  final double standardError;
  final int sampleCount;

  /// Normal quantile used for the interval (1.96 for 95%).
  final double z;

  double get halfWidth => standardError * z;

  double get lowerBound => mean - halfWidth;

  double get upperBound => mean + halfWidth;

  /// Whether the interval excludes zero, i.e. the effect is distinguishable
  /// from no effect at this confidence level.
  bool get excludesZero =>
      !lowerBound.isNaN && (lowerBound > 0 || upperBound < 0);

  @override
  String toString() => sampleCount < 2
      ? 'mean ${mean.toStringAsFixed(4)} (n=$sampleCount, no interval)'
      : '${mean.toStringAsFixed(4)} +/- ${halfWidth.toStringAsFixed(4)} '
          '(n=$sampleCount)';
}

/// Latency summary for AI decisions.
@immutable
class LatencySummary {
  const LatencySummary({
    required this.p50Micros,
    required this.p95Micros,
    required this.maxMicros,
    required this.sampleCount,
  });

  /// Summarises [micros]. The input is copied before sorting, so the caller's
  /// list is left alone.
  factory LatencySummary.ofMicros(List<int> micros) {
    if (micros.isEmpty) {
      return const LatencySummary(
        p50Micros: 0,
        p95Micros: 0,
        maxMicros: 0,
        sampleCount: 0,
      );
    }
    final List<int> sorted = List<int>.of(micros)..sort();
    return LatencySummary(
      p50Micros: _percentile(sorted, 0.50),
      p95Micros: _percentile(sorted, 0.95),
      maxMicros: sorted.last,
      sampleCount: sorted.length,
    );
  }

  final int p50Micros;
  final int p95Micros;
  final int maxMicros;
  final int sampleCount;

  /// Nearest-rank percentile of an already sorted list.
  static int _percentile(List<int> sorted, double fraction) {
    final int index = (fraction * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  String toString() => 'p50 ${p50Micros}us, p95 ${p95Micros}us, '
      'max ${maxMicros}us (n=$sampleCount)';
}
