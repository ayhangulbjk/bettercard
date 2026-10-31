import 'dart:convert';

import 'package:meta/meta.dart';

import '../rules/rule_profile.dart';

/// An autosaved match.
///
/// The rule profile is stored in full rather than by id. That is the point of
/// this type: a match must keep playing, and scoring, under exactly the rules
/// it started with, even if the player later changes their settings or the app
/// ships new defaults. Storing an id would make an old save silently adopt new
/// rules, which can change the result of a hand already in progress.
///
/// Milestone 1 stores no move log yet because no game-mode lifecycle exists to
/// produce one. The field is reserved by [schemaVersion] so adding it later is
/// a declared migration rather than a guess.
@immutable
class SavedMatch {
  const SavedMatch({
    required this.matchId,
    required this.ruleProfile,
    required this.dealSeed,
    required this.savedAtEpochMillis,
    required this.handsPlayed,
    required this.scores,
  });

  static const int currentSchemaVersion = 1;

  /// Unique id for this match.
  final String matchId;

  /// The immutable rules this match is played under.
  final RuleProfile ruleProfile;

  /// Seed the match was dealt from, so hands can be reproduced exactly.
  final int dealSeed;

  /// When the save was written. Supplied by the caller rather than read from
  /// a clock here, so the domain stays time-free and tests stay deterministic.
  final int savedAtEpochMillis;

  final int handsPlayed;

  /// Cumulative score per seat.
  final List<int> scores;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'matchId': matchId,
        'ruleProfile': ruleProfile.toJson(),
        'dealSeed': dealSeed,
        'savedAtEpochMillis': savedAtEpochMillis,
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
    return SavedMatch(
      matchId: json['matchId']! as String,
      ruleProfile:
          RuleProfile.fromJson(json['ruleProfile']! as Map<String, Object?>),
      dealSeed: json['dealSeed']! as int,
      savedAtEpochMillis: json['savedAtEpochMillis']! as int,
      handsPlayed: json['handsPlayed']! as int,
      scores: (json['scores']! as List<Object?>).cast<int>(),
    );
  }

  String encode() => jsonEncode(toJson());

  static SavedMatch decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, Object?>);
}
