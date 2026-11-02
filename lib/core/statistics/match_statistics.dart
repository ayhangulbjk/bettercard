import 'package:meta/meta.dart';

import 'match_record.dart';

/// What a set of finished matches adds up to.
///
/// Derived on demand from the records rather than stored as running counters.
/// A counter can drift out of step with the history behind it, and there is no
/// way to notice; a derivation cannot. The volumes here are a few hundred
/// records, so the cost is irrelevant next to that guarantee.
@immutable
final class MatchStatistics {
  const MatchStatistics({
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.totalPoints,
    required this.totalHands,
    required this.totalTricks,
    required this.bestScore,
    required this.bestMargin,
    required this.currentWinStreak,
    required this.longestWinStreak,
    required this.lastPlayedEpochMillis,
  });

  /// Statistics over [records]. Order matters for the streaks, which read the
  /// list as the order the matches were played.
  factory MatchStatistics.fromRecords(List<MatchRecord> records) {
    int won = 0;
    int drawn = 0;
    int lost = 0;
    int totalPoints = 0;
    int totalHands = 0;
    int totalTricks = 0;
    int bestScore = 0;
    int bestMargin = 0;
    int streak = 0;
    int longest = 0;
    int lastPlayed = 0;
    bool anyMargin = false;

    for (final MatchRecord record in records) {
      if (record.isWin) {
        won++;
        streak++;
        if (streak > longest) {
          longest = streak;
        }
      } else {
        // A draw ends a winning streak without being a loss: the streak counts
        // consecutive wins, and a draw is not one.
        streak = 0;
        if (record.isDraw) {
          drawn++;
        } else {
          lost++;
        }
      }
      totalPoints += record.humanScore;
      totalHands += record.handsPlayed;
      totalTricks += record.humanTricks;
      if (record.humanScore > bestScore) {
        bestScore = record.humanScore;
      }
      // Tracked with a flag rather than seeded at zero: every match can be a
      // loss, and the best margin is then negative.
      if (!anyMargin || record.margin > bestMargin) {
        bestMargin = record.margin;
        anyMargin = true;
      }
      if (record.finishedAtEpochMillis > lastPlayed) {
        lastPlayed = record.finishedAtEpochMillis;
      }
    }

    return MatchStatistics(
      played: records.length,
      won: won,
      drawn: drawn,
      lost: lost,
      totalPoints: totalPoints,
      totalHands: totalHands,
      totalTricks: totalTricks,
      bestScore: bestScore,
      bestMargin: records.isEmpty ? 0 : bestMargin,
      currentWinStreak: streak,
      longestWinStreak: longest,
      lastPlayedEpochMillis: lastPlayed,
    );
  }

  static const MatchStatistics empty = MatchStatistics(
    played: 0,
    won: 0,
    drawn: 0,
    lost: 0,
    totalPoints: 0,
    totalHands: 0,
    totalTricks: 0,
    bestScore: 0,
    bestMargin: 0,
    currentWinStreak: 0,
    longestWinStreak: 0,
    lastPlayedEpochMillis: 0,
  );

  final int played;
  final int won;
  final int drawn;
  final int lost;

  /// Points the player scored across every match.
  final int totalPoints;

  final int totalHands;
  final int totalTricks;

  /// Highest match total the player has finished on.
  final int bestScore;

  /// Largest winning margin over the best opponent.
  final int bestMargin;

  final int currentWinStreak;
  final int longestWinStreak;

  /// Zero when nothing has been played.
  final int lastPlayedEpochMillis;

  bool get isEmpty => played == 0;

  /// Share of matches won, 0..1. Draws count as neither.
  double get winRate => played == 0 ? 0 : won / played;

  /// Mean match score. Zero when nothing has been played, rather than NaN:
  /// a screen should print "0", never "NaN".
  double get averagePoints => played == 0 ? 0 : totalPoints / played;

  /// Mean tricks per hand, the one number comparable across match lengths.
  double get averageTricksPerHand =>
      totalHands == 0 ? 0 : totalTricks / totalHands;

  /// The same statistics over the records of one mode.
  static Map<String, MatchStatistics> byMode(List<MatchRecord> records) {
    final Map<String, List<MatchRecord>> grouped =
        <String, List<MatchRecord>>{};
    for (final MatchRecord record in records) {
      grouped.putIfAbsent(record.modeId, () => <MatchRecord>[]).add(record);
    }
    return <String, MatchStatistics>{
      for (final MapEntry<String, List<MatchRecord>> entry in grouped.entries)
        entry.key: MatchStatistics.fromRecords(entry.value),
    };
  }

  @override
  String toString() => 'MatchStatistics($played played, $won won, '
      'streak $currentWinStreak)';
}
