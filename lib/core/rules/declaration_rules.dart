import 'package:meta/meta.dart';

/// What happens to tricks taken beyond a made declaration.
enum OvertrickRule {
  /// They are worth nothing. The declaration alone pays.
  ignored,

  /// Each one pays [DeclarationRules.pointsPerOvertrick] on top.
  scored,
}

/// Per-seat trick declarations, the "soz" every seat gives before the first
/// card of a hand.
///
/// This is NOT an auction. Nobody outbids anybody and there is no declarer:
/// each seat independently says how many of the hand's tricks it expects to
/// take, and is paid or penalised against its own number. That is why it is a
/// separate rule record from [BiddingRules], whose `minimumBid`,
/// `declarerNamesTrump` and pass-out resolution all describe a contest that
/// does not happen here.
///
/// Turkish tables differ on what the extras are worth and on whether a seat
/// may declare nothing at all, so both are settings; see open questions K-4
/// to K-6 in docs/RULE_PROFILES.md.
@immutable
class DeclarationRules {
  const DeclarationRules({
    this.enabled = false,
    this.allowNil = true,
    this.nilBonus = 50,
    this.overtrickRule = OvertrickRule.ignored,
    this.pointsPerOvertrick = 1,
  });

  /// No declaration step. The hand goes straight to the first trick.
  static const DeclarationRules none = DeclarationRules();

  /// Koz Maca as commonly played: everyone declares, making it pays the
  /// declaration, missing it costs the same, extras are worth nothing, and
  /// "el almaz" pays or costs 50.
  static const DeclarationRules kozMacaStandard = DeclarationRules(
    enabled: true,
  );

  /// Whether a hand opens with a declaration round.
  final bool enabled;

  /// Whether a seat may declare zero ("el almaz").
  final bool allowNil;

  /// Paid for a kept nil, and charged for a broken one.
  final int nilBonus;

  /// What tricks above the declaration are worth.
  final OvertrickRule overtrickRule;

  /// Value of one overtrick when [overtrickRule] scores them.
  final int pointsPerOvertrick;

  /// Lowest number a seat may declare.
  int get minimumDeclaration => allowNil ? 0 : 1;

  /// Whether [declaration] is a legal number when [tricksPerHand] are in play.
  bool isInRange(int declaration, {required int tricksPerHand}) =>
      declaration >= minimumDeclaration && declaration <= tricksPerHand;

  /// What [seat] scores for taking [tricksTaken] against [declaration].
  ///
  /// The whole payoff table in one place, so the scorer, the rules screen and
  /// any future AI evaluation cannot disagree about what a hand is worth.
  int scoreFor({required int declaration, required int tricksTaken}) {
    if (declaration == 0) {
      // Nil is all or nothing: one trick breaks it, and taking several is no
      // worse than taking one. Tables that charge per trick are open question
      // K-5.
      return tricksTaken == 0 ? nilBonus : -nilBonus;
    }
    if (tricksTaken < declaration) {
      return -declaration;
    }
    final int extras = tricksTaken - declaration;
    return switch (overtrickRule) {
      OvertrickRule.ignored => declaration,
      OvertrickRule.scored => declaration + extras * pointsPerOvertrick,
    };
  }

  DeclarationRules copyWith({
    bool? enabled,
    bool? allowNil,
    int? nilBonus,
    OvertrickRule? overtrickRule,
    int? pointsPerOvertrick,
  }) =>
      DeclarationRules(
        enabled: enabled ?? this.enabled,
        allowNil: allowNil ?? this.allowNil,
        nilBonus: nilBonus ?? this.nilBonus,
        overtrickRule: overtrickRule ?? this.overtrickRule,
        pointsPerOvertrick: pointsPerOvertrick ?? this.pointsPerOvertrick,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'allowNil': allowNil,
        'nilBonus': nilBonus,
        'overtrickRule': overtrickRule.name,
        'pointsPerOvertrick': pointsPerOvertrick,
      };

  static DeclarationRules fromJson(Map<String, Object?> json) =>
      DeclarationRules(
        enabled: json['enabled'] as bool? ?? false,
        allowNil: json['allowNil'] as bool? ?? true,
        nilBonus: json['nilBonus'] as int? ?? 50,
        overtrickRule: OvertrickRule.values.firstWhere(
          (OvertrickRule rule) => rule.name == json['overtrickRule'],
          orElse: () => OvertrickRule.ignored,
        ),
        pointsPerOvertrick: json['pointsPerOvertrick'] as int? ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is DeclarationRules &&
      other.enabled == enabled &&
      other.allowNil == allowNil &&
      other.nilBonus == nilBonus &&
      other.overtrickRule == overtrickRule &&
      other.pointsPerOvertrick == pointsPerOvertrick;

  @override
  int get hashCode => Object.hash(
        enabled,
        allowNil,
        nilBonus,
        overtrickRule,
        pointsPerOvertrick,
      );
}
