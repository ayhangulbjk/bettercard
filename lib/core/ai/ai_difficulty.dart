import 'package:meta/meta.dart';

/// AI strength levels offered to the player.
///
/// Difficulty is an algorithmic difference, never a delay. See
/// docs/AI_STRATEGY.md for the intended algorithm per level and
/// docs/AI_BENCHMARKS.md for the measurement protocol. As of milestone 1 only
/// the legal-random baseline is implemented, and no level above it has any
/// measured strength claim attached to it.
enum AiDifficulty {
  beginner('Baslangic'),
  normal('Normal'),
  hard('Zor'),
  expert('Uzman'),
  legendary('Efsane');

  const AiDifficulty(this.turkishName);

  /// Turkish display name.
  final String turkishName;
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
