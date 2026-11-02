import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/ai_difficulty.dart';
import '../rules/rule_profile.dart';

/// An autosaved match in progress.
///
/// What is stored is a **move log**, not a position: the rule profile, the
/// seed the match was dealt from, and every card played so far in order.
/// Replaying those through the engine reproduces the exact position, because
/// the domain is deterministic and deals hand `i` from `baseSeed + i`. See
/// `SpadesBatakRestore`.
///
/// A log rather than a snapshot for three reasons. It cannot describe a
/// position the rules would not allow, since every move goes back through the
/// engine's validation on the way in. It stays small and stable as the state
/// types grow. And a corrupt save fails loudly at a specific move instead of
/// loading a plausible-looking but wrong position.
///
/// The rule profile is stored in full rather than by id. That is the point of
/// the type: a match must keep playing, and scoring, under exactly the rules
/// it started with, even if the player later changes their settings or the app
/// ships new defaults.
@immutable
class SavedMatch {
  SavedMatch({
    required this.matchId,
    required this.ruleProfile,
    required this.dealSeed,
    required this.savedAtEpochMillis,
    required this.humanSeat,
    required this.difficulty,
    required List<int> moves,
    required this.handsPlayed,
    required List<int> scores,
  })  : moves = List<int>.unmodifiable(moves),
        scores = List<int>.unmodifiable(scores);

  /// Version 1 stored a position summary with no move log, so it could not be
  /// resumed. Nothing ever wrote one -- no mode was playable -- so version 2
  /// rejects it rather than carrying a migration for a file that cannot exist.
  static const int currentSchemaVersion = 2;

  /// Unique id for this match.
  final String matchId;

  /// The immutable rules this match is played under.
  final RuleProfile ruleProfile;

  /// Seed the match was dealt from, so hands can be reproduced exactly.
  final int dealSeed;

  /// When the save was written. Supplied by the caller rather than read from
  /// a clock here, so the domain stays time-free and tests stay deterministic.
  final int savedAtEpochMillis;

  /// The seat the player occupies.
  final int humanSeat;

  /// The difficulty the opponents were built with. Frozen for the match.
  final AiDifficulty difficulty;

  /// Every card played so far, as `PlayingCard.id`, in play order across all
  /// hands. The authoritative content of the save.
  final List<int> moves;

  /// Completed hands. Denormalised for the resume card on the home screen, so
  /// it can be drawn without replaying the log; the replay is what decides the
  /// real value, and a mismatch means the file is corrupt.
  final int handsPlayed;

  /// Cumulative score per seat. Denormalised for the same reason.
  final List<int> scores;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'matchId': matchId,
        'ruleProfile': ruleProfile.toJson(),
        'dealSeed': dealSeed,
        'savedAtEpochMillis': savedAtEpochMillis,
        'humanSeat': humanSeat,
        'difficulty': difficulty.name,
        'moves': moves,
        'handsPlayed': handsPlayed,
        'scores': scores,
      };

  static SavedMatch fromJson(Map<String, Object?> json) {
    final int version = json['schemaVersion'] as int? ?? 1;
    if (version > currentSchemaVersion) {
      throw UnsupportedError(
        'Saved match schema $version is newer than this build supports '
        '($currentSchemaVersion)',
      );
    }
    if (version < currentSchemaVersion) {
      throw const FormatException(
        'Saved match schema 1 holds no move log and cannot be resumed',
      );
    }
    return SavedMatch(
      matchId: json['matchId']! as String,
      ruleProfile:
          RuleProfile.fromJson(json['ruleProfile']! as Map<String, Object?>),
      dealSeed: json['dealSeed']! as int,
      savedAtEpochMillis: json['savedAtEpochMillis']! as int,
      humanSeat: json['humanSeat'] as int? ?? 0,
      difficulty: _difficultyByName(json['difficulty']),
      moves: (json['moves']! as List<Object?>).cast<int>(),
      handsPlayed: json['handsPlayed']! as int,
      scores: (json['scores']! as List<Object?>).cast<int>(),
    );
  }

  static AiDifficulty _difficultyByName(Object? name) {
    for (final AiDifficulty value in AiDifficulty.values) {
      if (value.name == name) {
        return value;
      }
    }
    return AiDifficulty.normal;
  }

  String encode() => jsonEncode(toJson());

  static SavedMatch decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, Object?>);

  @override
  String toString() => 'SavedMatch(${ruleProfile.mode.id}, '
      'hands $handsPlayed, ${moves.length} moves)';
}

/// Where a match in progress is kept.
///
/// One match at a time: the product offers "Devam Et", not a list of saved
/// games, so a second save would be state nobody can reach.
abstract interface class MatchArchive {
  /// The stored match, or null when there is none or the stored one cannot be
  /// read. A damaged save is not an error the player can act on, so it reads
  /// as "no match" rather than failing startup.
  Future<SavedMatch?> load();

  Future<void> save(SavedMatch match);

  Future<void> clear();
}

/// Process-lifetime archive. Survives navigation, not a restart.
final class InMemoryMatchArchive implements MatchArchive {
  InMemoryMatchArchive([SavedMatch? initial]) : _stored = initial;

  SavedMatch? _stored;

  @override
  Future<SavedMatch?> load() async => _stored;

  @override
  Future<void> save(SavedMatch match) async => _stored = match;

  @override
  Future<void> clear() async => _stored = null;
}
