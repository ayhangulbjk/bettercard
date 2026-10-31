import 'package:meta/meta.dart';

import '../cards/suit.dart';
import 'bidding_rules.dart';
import 'bury_rules.dart';
import 'game_mode.dart';
import 'king_rules.dart';
import 'scoring_rules.dart';
import 'trick_rules.dart';

/// The complete, immutable rule set a match is played under.
///
/// A profile is captured when a match starts and stored verbatim in the save
/// file. Changing the app's defaults, or the player's settings, therefore
/// cannot retroactively alter a game in progress -- which matters because the
/// scoring of a half-finished hand would otherwise become ambiguous.
///
/// [schemaVersion] exists so a future rule field can be added without
/// invalidating saves: the loader can migrate an older profile explicitly
/// instead of guessing.
@immutable
class RuleProfile {
  const RuleProfile({
    required this.id,
    required this.turkishName,
    required this.mode,
    required this.trickRules,
    required this.biddingRules,
    required this.scoringRules,
    required this.buryRules,
    this.kingRules,
    this.fixedTrump,
    this.deckExclusions = const <int>{},
    this.schemaVersion = currentSchemaVersion,
  });

  /// Bumped whenever a field is added, removed or reinterpreted.
  static const int currentSchemaVersion = 1;

  /// Stable identifier, e.g. `auction_batak_standard`.
  final String id;

  /// Turkish name shown in the rule picker.
  final String turkishName;

  final GameMode mode;
  final TrickRules trickRules;
  final BiddingRules biddingRules;
  final BatakScoringRules scoringRules;
  final BuryRules buryRules;

  /// Present only for [GameMode.king].
  final KingRules? kingRules;

  /// A trump suit fixed by the rules rather than chosen (Koz Maca: spades).
  final Suit? fixedTrump;

  /// Dense card ids removed from the deck for this profile, for reduced-deck
  /// variants. Stored as ids so the profile stays a plain data record.
  final Set<int> deckExclusions;

  final int schemaVersion;

  /// Seats at the table.
  int get playerCount => mode.playerCount;

  /// Cards in play after deck exclusions.
  int get deckSize => 52 - deckExclusions.length;

  /// Cards that leave play before the first trick, i.e. the buried pile.
  ///
  /// Three-player Batak depends on this: 52 cards do not divide by three, and
  /// the surplus is resolved by the declarer burying it rather than by
  /// stripping the deck. So a bury profile is *expected* to have a deck that
  /// is not evenly divisible, and the real invariant is the one below.
  int get cardsSetAside => buryRules.enabled ? buryRules.cardsToBury : 0;

  /// Cards that actually get played to tricks.
  int get playableCardCount => deckSize - cardsSetAside;

  /// Tricks per hand.
  int get tricksPerHand => playableCardCount ~/ playerCount;

  /// Cards dealt to each seat in the initial deal.
  int get handSize => tricksPerHand;

  RuleProfile copyWith({
    String? id,
    String? turkishName,
    TrickRules? trickRules,
    BiddingRules? biddingRules,
    BatakScoringRules? scoringRules,
    BuryRules? buryRules,
    KingRules? kingRules,
    Suit? fixedTrump,
    Set<int>? deckExclusions,
  }) =>
      RuleProfile(
        id: id ?? this.id,
        turkishName: turkishName ?? this.turkishName,
        mode: mode,
        trickRules: trickRules ?? this.trickRules,
        biddingRules: biddingRules ?? this.biddingRules,
        scoringRules: scoringRules ?? this.scoringRules,
        buryRules: buryRules ?? this.buryRules,
        kingRules: kingRules ?? this.kingRules,
        fixedTrump: fixedTrump ?? this.fixedTrump,
        deckExclusions: deckExclusions ?? this.deckExclusions,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'turkishName': turkishName,
        'mode': mode.id,
        'trickRules': trickRules.toJson(),
        'biddingRules': biddingRules.toJson(),
        'scoringRules': scoringRules.toJson(),
        'buryRules': buryRules.toJson(),
        'kingRules': kingRules?.toJson(),
        'fixedTrump': fixedTrump?.name,
        'deckExclusions': deckExclusions.toList(growable: false)..sort(),
      };

  static RuleProfile fromJson(Map<String, Object?> json) {
    final int version = json['schemaVersion'] as int? ?? 1;
    if (version > currentSchemaVersion) {
      throw UnsupportedError(
        'Rule profile schema $version is newer than this build supports '
        '($currentSchemaVersion)',
      );
    }
    final Object? king = json['kingRules'];
    final Object? trump = json['fixedTrump'];
    return RuleProfile(
      schemaVersion: version,
      id: json['id']! as String,
      turkishName: json['turkishName']! as String,
      mode: GameMode.fromId(json['mode']! as String),
      trickRules:
          TrickRules.fromJson(json['trickRules']! as Map<String, Object?>),
      biddingRules:
          BiddingRules.fromJson(json['biddingRules']! as Map<String, Object?>),
      scoringRules: BatakScoringRules.fromJson(
        json['scoringRules']! as Map<String, Object?>,
      ),
      buryRules: BuryRules.fromJson(json['buryRules']! as Map<String, Object?>),
      kingRules: king == null
          ? null
          : KingRules.fromJson(king as Map<String, Object?>),
      fixedTrump: trump == null
          ? null
          : Suit.values.firstWhere((Suit s) => s.name == trump),
      deckExclusions:
          (json['deckExclusions'] as List<Object?>? ?? const <Object?>[])
              .cast<int>()
              .toSet(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RuleProfile &&
      other.id == id &&
      other.turkishName == turkishName &&
      other.mode == mode &&
      other.trickRules == trickRules &&
      other.biddingRules == biddingRules &&
      other.scoringRules == scoringRules &&
      other.buryRules == buryRules &&
      other.kingRules == kingRules &&
      other.fixedTrump == fixedTrump &&
      other.schemaVersion == schemaVersion &&
      other.deckExclusions.length == deckExclusions.length &&
      other.deckExclusions.containsAll(deckExclusions);

  @override
  int get hashCode => Object.hash(
        id,
        turkishName,
        mode,
        trickRules,
        biddingRules,
        scoringRules,
        buryRules,
        kingRules,
        fixedTrump,
        schemaVersion,
        Object.hashAll(deckExclusions.toList(growable: false)..sort()),
      );

  @override
  String toString() => 'RuleProfile($id, ${mode.id})';
}
