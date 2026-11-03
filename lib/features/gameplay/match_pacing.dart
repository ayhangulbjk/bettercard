import '../../core/ai/ai_difficulty.dart';
import '../../core/ai/ai_policy.dart';
import '../../core/ai/policies/heuristic_policy.dart';
import '../../core/persistence/app_settings.dart';

/// How long the table waits, and for what.
///
/// A pause is presentation, not a rule, and it is the one part of the table
/// the player tunes: animation speed scales every wait, and "hizli oyun"
/// shortens the one between tricks. Difficulty deliberately does NOT appear
/// here -- a harder opponent must think better, not longer.
final class MatchPacing {
  const MatchPacing(this.settings);

  factory MatchPacing.of(AppSettings settings) => MatchPacing(settings);

  final AppSettings settings;

  /// How long an opponent appears to think, before scaling.
  static const Duration baseThinkDelay = Duration(milliseconds: 420);

  /// How long a finished trick lies still before it is collected, before
  /// scaling.
  ///
  /// Generous on purpose. This is the only moment in a hand when all four
  /// cards are visible at once, and it is when the player works out who took
  /// the trick and with what; the earlier value let the cards start leaving
  /// almost as soon as the last one landed.
  static const Duration baseTrickPause = Duration(milliseconds: 1250);

  /// The same hold with quick play on: short enough to keep the pace, long
  /// enough that the cards do not vanish unseen.
  static const Duration quickTrickPause = Duration(milliseconds: 600);

  /// How long the pile takes to travel to the seat that won it, before
  /// scaling.
  static const Duration baseTrickGather = Duration(milliseconds: 620);

  Duration get thinkDelay => _scaled(baseThinkDelay);

  Duration get trickPause =>
      _scaled(settings.quickPlay ? quickTrickPause : baseTrickPause);

  /// The collecting animation. Quick play does not shorten it: it is the part
  /// that answers "who took that?", and a sped-up answer is no answer.
  Duration get trickGather => _scaled(baseTrickGather);

  Duration _scaled(Duration base) => Duration(
        microseconds:
            (base.inMicroseconds * settings.animationSpeed.multiplier).round(),
      );

  /// Waits [duration], skipping the timer entirely when it rounds to nothing.
  ///
  /// The animation-free setting should be immediate, not a zero-length timer
  /// per ply.
  static Future<void> wait(Duration duration) => duration <= Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(duration);
}

/// The opponents at one table: a policy per seat, fixed for the match.
///
/// Frozen at the start like the rule profile. Swapping opponents mid-hand
/// would change the game underneath the player, and a policy carries its own
/// generator, so rebuilding one mid-match would also break replay.
final class OpponentRoster {
  const OpponentRoster(this._bySeat);

  /// Builds opponents for every seat except [humanSeat].
  ///
  /// Each seat gets its own generator stream derived from the match seed, so
  /// two opponents never make correlated choices, and the whole table replays
  /// from that one seed.
  factory OpponentRoster.forMatch({
    required AiDifficulty difficulty,
    required int matchSeed,
    required int seatCount,
    required int humanSeat,
  }) =>
      OpponentRoster(<int, AiPolicy>{
        for (int seat = 0; seat < seatCount; seat++)
          if (seat != humanSeat)
            seat: _policyFor(difficulty, matchSeed ^ (0x9E3779B1 * (seat + 1))),
      });

  static const OpponentRoster empty = OpponentRoster(<int, AiPolicy>{});

  final Map<int, AiPolicy> _bySeat;

  /// The policy for [seat], or null when that seat is the player's.
  AiPolicy? policyFor(int seat) => _bySeat[seat];

  /// The policy for one difficulty level.
  ///
  /// Zor, Uzman and Efsane have no policy of their own yet and are not
  /// selectable (see [AiDifficulty.isImplemented]). Mapping them onto the
  /// heuristic would make the selector a lie, so this only has to handle a
  /// stale stored setting, and it does so with the strongest policy that
  /// actually exists rather than by crashing.
  static AiPolicy _policyFor(AiDifficulty difficulty, int seed) =>
      switch (difficulty) {
        AiDifficulty.beginner => HeuristicPolicy.beginner(seed: seed),
        AiDifficulty.normal ||
        AiDifficulty.hard ||
        AiDifficulty.expert ||
        AiDifficulty.legendary =>
          HeuristicPolicy(seed: seed),
      };
}
