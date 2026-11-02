import 'package:meta/meta.dart';

import '../ai/ai_difficulty.dart';

/// One finished match, as it is kept for the statistics screen.
///
/// Only finished matches are recorded. An abandoned match is not a loss and
/// counting it as one would make the win rate a number about the player's
/// patience rather than their play.
///
/// The final scores are stored rather than a precomputed result, so the same
/// record answers questions nobody has asked yet -- margin, average points,
/// how often a seat was runner-up -- without a migration.
@immutable
final class MatchRecord {
  MatchRecord({
    required this.matchId,
    required this.modeId,
    required this.profileId,
    required this.difficulty,
    required this.finishedAtEpochMillis,
    required this.humanSeat,
    required List<int> scores,
    required this.handsPlayed,
    required this.humanTricks,
  }) : scores = List<int>.unmodifiable(scores);

  static const int currentSchemaVersion = 1;

  final String matchId;

  /// `GameMode.id`, kept as a string so a record outlives an enum reordering.
  final String modeId;

  /// `RuleProfile.id` the match was played under.
  final String profileId;

  final AiDifficulty difficulty;

  /// Supplied by the caller; the domain reads no clock.
  final int finishedAtEpochMillis;

  final int humanSeat;

  /// Final totals, indexed by seat.
  final List<int> scores;

  final int handsPlayed;

  /// Tricks the player took across the whole match.
  final int humanTricks;

  int get humanScore => humanSeat < scores.length ? scores[humanSeat] : 0;

  int get bestScore =>
      scores.isEmpty ? 0 : scores.reduce((int a, int b) => a > b ? a : b);

  /// Seats that finished level with the best score.
  int get winnerCount => scores.where((int score) => score == bestScore).length;

  bool get isWin => humanScore == bestScore && winnerCount == 1;

  bool get isDraw => humanScore == bestScore && winnerCount > 1;

  bool get isLoss => humanScore < bestScore;

  /// Points between the player and the best other seat. Negative when behind.
  int get margin {
    int bestOther = 0;
    bool any = false;
    for (int seat = 0; seat < scores.length; seat++) {
      if (seat == humanSeat) {
        continue;
      }
      if (!any || scores[seat] > bestOther) {
        bestOther = scores[seat];
        any = true;
      }
    }
    return any ? humanScore - bestOther : 0;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'matchId': matchId,
        'modeId': modeId,
        'profileId': profileId,
        'difficulty': difficulty.name,
        'finishedAtEpochMillis': finishedAtEpochMillis,
        'humanSeat': humanSeat,
        'scores': scores,
        'handsPlayed': handsPlayed,
        'humanTricks': humanTricks,
      };

  static MatchRecord fromJson(Map<String, Object?> json) => MatchRecord(
        matchId: json['matchId']! as String,
        modeId: json['modeId']! as String,
        profileId: json['profileId'] as String? ?? '',
        difficulty: _difficultyByName(json['difficulty']),
        finishedAtEpochMillis: json['finishedAtEpochMillis']! as int,
        humanSeat: json['humanSeat'] as int? ?? 0,
        scores: (json['scores']! as List<Object?>).cast<int>(),
        handsPlayed: json['handsPlayed'] as int? ?? 0,
        humanTricks: json['humanTricks'] as int? ?? 0,
      );

  static AiDifficulty _difficultyByName(Object? name) {
    for (final AiDifficulty value in AiDifficulty.values) {
      if (value.name == name) {
        return value;
      }
    }
    return AiDifficulty.normal;
  }

  @override
  String toString() => 'MatchRecord($modeId, scores $scores, '
      'human $humanSeat)';
}

/// Where finished matches are kept.
abstract interface class MatchHistoryRepository {
  /// Every stored record, oldest first. A damaged store reads as empty: losing
  /// statistics is a far better outcome than failing to open the screen.
  Future<List<MatchRecord>> load();

  Future<void> append(MatchRecord record);

  Future<void> clear();
}

/// Process-lifetime history.
final class InMemoryMatchHistoryRepository implements MatchHistoryRepository {
  InMemoryMatchHistoryRepository([List<MatchRecord>? initial])
      : _records = <MatchRecord>[...?initial];

  final List<MatchRecord> _records;

  @override
  Future<List<MatchRecord>> load() async =>
      List<MatchRecord>.unmodifiable(_records);

  @override
  Future<void> append(MatchRecord record) async => _records.add(record);

  @override
  Future<void> clear() async => _records.clear();
}
