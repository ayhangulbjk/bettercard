import 'package:meta/meta.dart';

/// When a seat is allowed to lead a trump card.
enum TrumpLeadRule {
  /// Trump may be led at any time (standard auction Batak: the declarer
  /// usually wants to draw trump immediately).
  unrestricted,

  /// Trump may not be led until trump has been played to some earlier trick,
  /// unless the seat holds nothing but trump. This is the Spades-family rule
  /// that Koz Maca tables commonly use.
  onlyAfterBroken,
}

/// The rules that govern card play within a trick.
///
/// These flags are where regional Batak variation actually lives. Every one of
/// them changes the legal move set, so the authoritative engine reads them
/// directly rather than hard-coding any single table's custom.
@immutable
class TrickRules {
  const TrickRules({
    this.mustFollowSuit = true,
    this.mustPlayTrumpWhenVoid = false,
    this.mustOvertrumpWhenPossible = false,
    this.mustBeatLeadSuitWhenPossible = false,
    this.trumpLeadRule = TrumpLeadRule.unrestricted,
  });

  /// Standard Batak play: all five modes in this app use mandatory following.
  static const TrickRules batakStandard = TrickRules(
    mustPlayTrumpWhenVoid: true,
    mustOvertrumpWhenPossible: true,
  );

  /// Koz Maca: spades are permanent trump and may not be led until broken.
  static const TrickRules kozMaca = TrickRules(
    mustPlayTrumpWhenVoid: false,
    mustOvertrumpWhenPossible: false,
    trumpLeadRule: TrumpLeadRule.onlyAfterBroken,
  );

  /// King's penalty contracts: no trump exists, so only following applies.
  static const TrickRules noTrump = TrickRules();

  /// A seat holding the lead suit must play it.
  final bool mustFollowSuit;

  /// A seat void in the lead suit must play a trump if it holds one
  /// ("koz kesme zorunlulugu"). When false, a void seat may discard freely.
  final bool mustPlayTrumpWhenVoid;

  /// A seat playing trump into a trick that already contains trump must beat
  /// the highest trump in it, if able.
  final bool mustOvertrumpWhenPossible;

  /// A seat following suit must play higher than the best lead-suit card so
  /// far, if able. Rare, and tables disagree; see docs/RULE_PROFILES.md.
  final bool mustBeatLeadSuitWhenPossible;

  /// Whether trump may be led freely.
  final TrumpLeadRule trumpLeadRule;

  TrickRules copyWith({
    bool? mustFollowSuit,
    bool? mustPlayTrumpWhenVoid,
    bool? mustOvertrumpWhenPossible,
    bool? mustBeatLeadSuitWhenPossible,
    TrumpLeadRule? trumpLeadRule,
  }) =>
      TrickRules(
        mustFollowSuit: mustFollowSuit ?? this.mustFollowSuit,
        mustPlayTrumpWhenVoid:
            mustPlayTrumpWhenVoid ?? this.mustPlayTrumpWhenVoid,
        mustOvertrumpWhenPossible:
            mustOvertrumpWhenPossible ?? this.mustOvertrumpWhenPossible,
        mustBeatLeadSuitWhenPossible:
            mustBeatLeadSuitWhenPossible ?? this.mustBeatLeadSuitWhenPossible,
        trumpLeadRule: trumpLeadRule ?? this.trumpLeadRule,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'mustFollowSuit': mustFollowSuit,
        'mustPlayTrumpWhenVoid': mustPlayTrumpWhenVoid,
        'mustOvertrumpWhenPossible': mustOvertrumpWhenPossible,
        'mustBeatLeadSuitWhenPossible': mustBeatLeadSuitWhenPossible,
        'trumpLeadRule': trumpLeadRule.name,
      };

  static TrickRules fromJson(Map<String, Object?> json) => TrickRules(
        mustFollowSuit: json['mustFollowSuit'] as bool? ?? true,
        mustPlayTrumpWhenVoid: json['mustPlayTrumpWhenVoid'] as bool? ?? false,
        mustOvertrumpWhenPossible:
            json['mustOvertrumpWhenPossible'] as bool? ?? false,
        mustBeatLeadSuitWhenPossible:
            json['mustBeatLeadSuitWhenPossible'] as bool? ?? false,
        trumpLeadRule: TrumpLeadRule.values.firstWhere(
          (TrumpLeadRule rule) => rule.name == json['trumpLeadRule'],
          orElse: () => TrumpLeadRule.unrestricted,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is TrickRules &&
      other.mustFollowSuit == mustFollowSuit &&
      other.mustPlayTrumpWhenVoid == mustPlayTrumpWhenVoid &&
      other.mustOvertrumpWhenPossible == mustOvertrumpWhenPossible &&
      other.mustBeatLeadSuitWhenPossible == mustBeatLeadSuitWhenPossible &&
      other.trumpLeadRule == trumpLeadRule;

  @override
  int get hashCode => Object.hash(
        mustFollowSuit,
        mustPlayTrumpWhenVoid,
        mustOvertrumpWhenPossible,
        mustBeatLeadSuitWhenPossible,
        trumpLeadRule,
      );
}
