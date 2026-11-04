import 'package:meta/meta.dart';

/// How the two partnerships see each other's cards.
///
/// Turkish tables play Esli Ihaleli Batak both ways and they are genuinely
/// different games, not a presentation preference, so the choice is a rule.
enum PartnershipMode {
  /// Acik esli: once the trump is named, the declarer's partner lays its
  /// thirteen cards face up and the declarer plays them.
  ///
  /// This is the common reading and the default. The open hand is public --
  /// every seat at the table sees it, defenders included -- which is why it
  /// is not an information leak but a rule.
  openDummy,

  /// Kapali esli: nobody's cards are shown. Each seat plays its own hand and
  /// the partners cooperate on inference alone.
  closedPartnership,
}

/// The mechanics of a partnership hand: who sees what, and who decides.
///
/// Kept apart from [PartnershipScoringRules] for the same reason
/// [BiddingRules] is kept apart from [AuctionScoringRules]: this decides how
/// the cards are played, that decides what the hand pays, and a table can
/// change one without changing the other.
@immutable
class PartnershipRules {
  const PartnershipRules({
    this.enabled = false,
    this.mode = PartnershipMode.openDummy,
    this.humanDummyControlOverride = false,
  });

  /// Not a partnership mode. Every seat plays for itself.
  static const PartnershipRules none = PartnershipRules();

  /// Acik esli, the default: the declarer's partner is the open hand.
  static const PartnershipRules openDummy = PartnershipRules(enabled: true);

  /// Kapali esli: four closed hands, two teams.
  static const PartnershipRules closedPartnership = PartnershipRules(
    enabled: true,
    mode: PartnershipMode.closedPartnership,
  );

  /// Whether seats are grouped into two fixed partnerships.
  final bool enabled;

  final PartnershipMode mode;

  /// Whether the person at the device plays their own cards when the deal
  /// makes them the open hand.
  ///
  /// Off by default, because it is a departure from the classic rule: in acik
  /// esli Batak the declarer plays both hands, and when a bot wins the
  /// contract that means the bot plays the player's cards. Tables do not
  /// offer this; the product does, for players who would rather keep the
  /// cards than watch. It changes nothing about the engine -- the card is
  /// still played from the open hand's own seat and still has to be legal in
  /// it -- only who chooses it, so the session applies it rather than the
  /// rules layer, which does not know which seat the person is sitting in.
  final bool humanDummyControlOverride;

  /// Whether the declarer's partner lays its hand face up.
  bool get revealsDummy => enabled && mode == PartnershipMode.openDummy;

  PartnershipRules copyWith({
    bool? enabled,
    PartnershipMode? mode,
    bool? humanDummyControlOverride,
  }) =>
      PartnershipRules(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        humanDummyControlOverride:
            humanDummyControlOverride ?? this.humanDummyControlOverride,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'mode': mode.name,
        'humanDummyControlOverride': humanDummyControlOverride,
      };

  static PartnershipRules fromJson(Map<String, Object?> json) =>
      PartnershipRules(
        enabled: json['enabled'] as bool? ?? false,
        mode: PartnershipMode.values.firstWhere(
          (PartnershipMode value) => value.name == json['mode'],
          orElse: () => PartnershipMode.openDummy,
        ),
        humanDummyControlOverride:
            json['humanDummyControlOverride'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is PartnershipRules &&
      other.enabled == enabled &&
      other.mode == mode &&
      other.humanDummyControlOverride == humanDummyControlOverride;

  @override
  int get hashCode => Object.hash(enabled, mode, humanDummyControlOverride);

  @override
  String toString() => 'PartnershipRules(${enabled ? mode.name : 'off'})';
}
