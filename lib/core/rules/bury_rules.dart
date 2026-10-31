import 'package:meta/meta.dart';

/// Restrictions on which cards may be buried.
enum BuryRestriction {
  /// Anything may be buried.
  none,

  /// Trump cards may not be buried.
  noTrump,

  /// Neither trump nor aces may be buried.
  noTrumpOrAces,
}

/// Configuration for variants where the declarer sets cards aside face down.
///
/// Three-player Batak needs this because 52 does not divide by three. The
/// common approach is to deal every card, give the declarer a surplus, and
/// have it bury the surplus back down; the buried cards then count towards the
/// declarer's tricks at scoring time (or not, depending on the table).
@immutable
class BuryRules {
  const BuryRules({
    required this.enabled,
    this.cardsDealtToDeclarer = 0,
    this.cardsToBury = 0,
    this.restriction = BuryRestriction.none,
    this.buriedCardsCountForDeclarer = true,
  });

  /// No burying (all four-player modes).
  static const BuryRules disabled = BuryRules(enabled: false);

  /// Three-player buried Batak on the full 52-card deck: 17 cards each leaves
  /// one card over, the declarer takes it and buries one back. See
  /// docs/RULE_PROFILES.md, open question B-4: the surplus size and whether
  /// the buried cards score are the least consistently reported rules here.
  static const BuryRules threePlayerSingle = BuryRules(
    enabled: true,
    cardsDealtToDeclarer: 1,
    cardsToBury: 1,
    restriction: BuryRestriction.none,
  );

  /// Whether this profile buries at all.
  final bool enabled;

  /// Extra cards handed to the auction winner before burying.
  final int cardsDealtToDeclarer;

  /// How many cards the declarer must put face down.
  final int cardsToBury;

  /// Which cards may not be buried.
  final BuryRestriction restriction;

  /// Whether buried cards are credited to the declarer when scoring.
  final bool buriedCardsCountForDeclarer;

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'cardsDealtToDeclarer': cardsDealtToDeclarer,
        'cardsToBury': cardsToBury,
        'restriction': restriction.name,
        'buriedCardsCountForDeclarer': buriedCardsCountForDeclarer,
      };

  static BuryRules fromJson(Map<String, Object?> json) => BuryRules(
        enabled: json['enabled']! as bool,
        cardsDealtToDeclarer: json['cardsDealtToDeclarer'] as int? ?? 0,
        cardsToBury: json['cardsToBury'] as int? ?? 0,
        restriction: BuryRestriction.values.firstWhere(
          (BuryRestriction r) => r.name == json['restriction'],
          orElse: () => BuryRestriction.none,
        ),
        buriedCardsCountForDeclarer:
            json['buriedCardsCountForDeclarer'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is BuryRules &&
      other.enabled == enabled &&
      other.cardsDealtToDeclarer == cardsDealtToDeclarer &&
      other.cardsToBury == cardsToBury &&
      other.restriction == restriction &&
      other.buriedCardsCountForDeclarer == buriedCardsCountForDeclarer;

  @override
  int get hashCode => Object.hash(
        enabled,
        cardsDealtToDeclarer,
        cardsToBury,
        restriction,
        buriedCardsCountForDeclarer,
      );
}
