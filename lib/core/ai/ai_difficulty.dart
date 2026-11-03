import 'package:meta/meta.dart';

/// AI strength levels offered to the player.
///
/// Difficulty is an algorithmic difference, never a delay. See
/// docs/AI_STRATEGY.md for the algorithm per level and docs/AI_BENCHMARKS.md
/// for the measurement protocol and the recorded margins.
///
/// A level is only offered once a measurement says it is stronger than the
/// level below it, on paired deals with rotated seats and an interval that
/// excludes zero. Uzman and Efsane are not offered for exactly that reason:
/// the search that would back them has been built, but no measured step up
/// over Zor has been recorded for it yet.
enum AiDifficulty {
  beginner('Başlangıç'),
  normal('Normal'),
  hard('Zor'),
  expert('Uzman'),
  legendary('Efsane');

  const AiDifficulty(this.turkishName);

  /// Turkish display name.
  final String turkishName;

  /// Whether a policy actually implements this level today.
  ///
  /// Beginner and Normal are the heuristic policy, with and without a
  /// documented blunder rate. Zor is the sampling search, which is measured
  /// at +4.5 points per hand over Normal. Uzman and Efsane stay unselectable
  /// rather than quietly reusing Zor and implying a strength nobody measured.
  bool get isImplemented => this == beginner || this == normal || this == hard;

  /// What this level is allowed to spend on one decision.
  ///
  /// The wall-clock bound is what keeps the table responsive; the world count
  /// is what actually decides the strength, and it is picked off the measured
  /// curve in docs/AI_BENCHMARKS.md rather than guessed. Zor's is small on
  /// purpose: past about six worlds the curve flattens, so the extra cost
  /// would buy latency rather than play.
  AiComputeBudget get budget => switch (this) {
        AiDifficulty.beginner || AiDifficulty.normal => AiComputeBudget.none,
        AiDifficulty.hard => const AiComputeBudget(
            timeLimit: Duration(milliseconds: 60),
            maxWorlds: 6,
            maxRollouts: 0,
          ),
        AiDifficulty.expert || AiDifficulty.legendary => const AiComputeBudget(
            timeLimit: Duration(milliseconds: 250),
            maxWorlds: 16,
            maxRollouts: 0,
            maxSolverDepth: 4,
          ),
      };
}

/// A hard ceiling on what a decision may spend.
///
/// The UI thread must never wait on AI work, so every policy is handed a
/// budget and is required to return its best answer so far when the budget
/// runs out. Budgets are expressed in both time and work units because a
/// time-only bound is not reproducible: benchmarks pin the work units so that
/// results compare across machines, while the shipping app pins the wall-clock
/// bound so that a slow device still feels responsive.
@immutable
class AiComputeBudget {
  const AiComputeBudget({
    required this.timeLimit,
    required this.maxWorlds,
    required this.maxRollouts,
    this.maxSolverDepth = 0,
  });

  /// Budget for the legal-random baseline: it needs no search at all.
  static const AiComputeBudget none = AiComputeBudget(
    timeLimit: Duration(milliseconds: 1),
    maxWorlds: 0,
    maxRollouts: 0,
  );

  /// Wall-clock ceiling. A policy that exceeds it must be cancellable.
  final Duration timeLimit;

  /// How many sampled hidden-hand worlds a sampling policy may draw.
  final int maxWorlds;

  /// How many playouts in total a Monte Carlo policy may run.
  final int maxRollouts;

  /// Remaining-trick count at which an exact endgame solver may take over.
  /// Zero disables the solver.
  final int maxSolverDepth;

  AiComputeBudget copyWith({
    Duration? timeLimit,
    int? maxWorlds,
    int? maxRollouts,
    int? maxSolverDepth,
  }) =>
      AiComputeBudget(
        timeLimit: timeLimit ?? this.timeLimit,
        maxWorlds: maxWorlds ?? this.maxWorlds,
        maxRollouts: maxRollouts ?? this.maxRollouts,
        maxSolverDepth: maxSolverDepth ?? this.maxSolverDepth,
      );

  @override
  String toString() => 'AiComputeBudget(${timeLimit.inMilliseconds}ms, '
      'worlds: $maxWorlds, rollouts: $maxRollouts, solver: $maxSolverDepth)';
}
