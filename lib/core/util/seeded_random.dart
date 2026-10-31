/// Deterministic pseudo random number generator.
///
/// Why not `dart:math` `Random(seed)`: its algorithm is an implementation
/// detail of the SDK and is explicitly allowed to change between Dart
/// releases. Saved matches, replays and AI benchmarks must reproduce
/// bit-for-bit across SDK upgrades, so the project owns its generator.
///
/// Algorithm: xorshift64* (Vigna). Fast, allocation-free, 64-bit state,
/// period 2^64-1. Statistically ample for card shuffling and Monte Carlo
/// sampling; it is NOT cryptographically secure and must never be used for
/// anything security relevant.
///
/// Requires 64-bit integers, i.e. the Dart VM / AOT (Android, iOS, tests).
/// Dart web compiles `int` to double and would silently lose precision; the
/// app does not target web.
class SeededRandom {
  /// Creates a generator for [seed]. Every seed yields a distinct stream;
  /// seed `0` is remapped because xorshift cannot leave zero state.
  SeededRandom(int seed) : _state = _scramble(seed == 0 ? _goldenGamma : seed);

  /// Restores a generator previously snapshotted via [state].
  SeededRandom.fromState(int state)
      : _state = state == 0 ? _goldenGamma : state;

  static const int _goldenGamma = 0x9E3779B97F4A7C15;
  static const int _multiplier = 0x2545F4914F6CDD1D;
  static const int _pow32 = 0x100000000;

  int _state;

  /// Current internal state. Exposed only so a game state can be snapshotted
  /// and replayed; AI decision policies must never read it.
  int get state => _state;

  /// SplitMix64-style finalizer, so that nearby seeds (0, 1, 2 ...) produce
  /// well-separated streams instead of correlated ones.
  static int _scramble(int seed) {
    var z = seed + _goldenGamma;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  /// Advances the state and returns the raw 64-bit output.
  int nextRaw() {
    var x = _state;
    x ^= x >>> 12;
    x ^= x << 25;
    x ^= x >>> 27;
    _state = x;
    return x * _multiplier;
  }

  /// Uniform integer in `[0, max)`.
  ///
  /// Uses rejection sampling, so the result carries no modulo bias. An unbiased
  /// shuffle matters for a game that advertises fair, non-cheating opponents.
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    final int bound = _pow32 - (_pow32 % max);
    while (true) {
      final int candidate = (nextRaw() >>> 32) & 0xFFFFFFFF;
      if (candidate < bound) {
        return candidate % max;
      }
    }
  }

  /// Uniform double in `[0, 1)` with 53 bits of entropy.
  double nextDouble() => (nextRaw() >>> 11) / 9007199254740992.0;

  /// Returns true with probability [probability].
  bool nextBool([double probability = 0.5]) => nextDouble() < probability;

  /// Derives an independent child stream.
  ///
  /// Keeps concerns from interfering: the deal, each AI seat's sampling and the
  /// benchmark harness each take their own fork, so changing the number of
  /// Monte Carlo samples cannot alter which cards were dealt.
  SeededRandom fork(int salt) =>
      SeededRandom(_scramble(_state ^ _scramble(salt)));

  /// Shuffles [items] in place with an unbiased Fisher-Yates pass.
  void shuffleInPlace<T>(List<T> items) {
    for (int i = items.length - 1; i > 0; i--) {
      final int j = nextInt(i + 1);
      final T tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}
