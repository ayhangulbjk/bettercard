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
  /// resumed. Nothing ever wrote one -- no mode was playable -- so it is
  /// rejected rather than migrated.
  ///
  /// Version 3 lets the log carry declarations as well as cards. A version 2
  /// file still reads: its log is all cards, and the profile it carries has no
  /// declaration round, so replaying it reproduces the match it recorded.
  ///
  /// Version 4 adds the three calls an auction needs -- a bid, a pass and a
  /// named trump. Older files still read: their logs use only the card and
  /// declaration ranges, which are unchanged.
  static const int currentSchemaVersion = 4;

  /// Oldest log format this build can replay.
  static const int oldestReadableSchemaVersion = 2;

  /// How each kind of move is written into [moves].
  ///
  /// Card ids are dense and non-negative, so the negatives are free, and each
  /// kind gets a band of its own. Keeping every encoder next to its decoder
  /// is what stops a writer and a reader drifting apart over a format with no
  /// field names.
  ///
  /// | Band | Meaning |
  /// |---|---|
  /// | `0 .. 51` | a card id |
  /// | `-1 .. -14` | a Koz Maca declaration |
  /// | `-100` | a pass |
  /// | `-201 .. -213` | an auction bid |
  /// | `-301 .. -304` | a named trump |
  static int encodeDeclaration(int tricks) => -(tricks + 1);

  /// The declaration [move] encodes, or null when it is something else.
  static int? decodeDeclaration(int move) =>
      move < 0 && move > -100 ? -move - 1 : null;

  /// The pass marker.
  static const int passMove = -100;

  /// How an auction bid of [tricks] is written.
  static int encodeBid(int tricks) => -(200 + tricks);

  /// The bid [move] encodes, or null when it is something else.
  static int? decodeBid(int move) =>
      move <= -201 && move >= -299 ? -move - 200 : null;

  /// How a trump of suit index [suitIndex] is written.
  static int encodeTrump(int suitIndex) => -(301 + suitIndex);

  /// The trump suit index [move] encodes, or null when it is something else.
  static int? decodeTrump(int move) =>
      move <= -301 && move >= -399 ? -move - 301 : null;

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
    if (version < oldestReadableSchemaVersion) {
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
