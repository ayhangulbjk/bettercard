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
/// ### The payoff, as the table plays it
///
/// A declaration of `d` stakes `d * pointsPerDeclaredTrick` points -- ten per
/// trick at a Turkish table, which is why a hand reads as 50 rather than 5.
/// Keep the word and the stake is won; miss it and the same stake is lost.
/// Tricks above the word ("yan") pay [pointsPerOvertrick] each, so promising
/// five and taking seven writes 52.
///
/// Collecting too many of them is its own way to go down:
/// [overtrickBustThreshold] is the number of extras that turns a made word
/// into a lost one, so the same hand played at a table that busts on two
/// extras writes -50 instead of 52. Tables disagree about where that line
/// sits, and some do not draw it at all, so it is a setting rather than a
/// constant.
///
/// Whether a seat may declare nothing, and what that pays, is also a setting;
/// see open question K-5 in docs/RULE_PROFILES.md.
@immutable
class DeclarationRules {
  const DeclarationRules({
    this.enabled = false,
    this.allowNil = true,
    this.nilBonus = 50,
    this.pointsPerDeclaredTrick = 1,
    this.overtrickRule = OvertrickRule.ignored,
    this.pointsPerOvertrick = 1,
    this.overtrickBustThreshold,
  });

  /// No declaration step. The hand goes straight to the first trick.
  static const DeclarationRules none = DeclarationRules();

  /// Koz Maca as commonly played: everyone declares, the word is worth ten a
  /// trick either way, each extra trick pays one on top, three extras sink
  /// the hand, and "el almaz" pays or costs 50.
  ///
  /// Every value is spelled out rather than left to the constructor defaults.
  /// The defaults are deliberately the older, flat reading, so a profile
  /// stored before these settings existed keeps scoring the way it was saved.
  static const DeclarationRules kozMacaStandard = DeclarationRules(
    enabled: true,
    pointsPerDeclaredTrick: 10,
    overtrickRule: OvertrickRule.scored,
    pointsPerOvertrick: 1,
    overtrickBustThreshold: 3,
  );

  /// Whether a hand opens with a declaration round.
  final bool enabled;

  /// Whether a seat may declare zero ("el almaz").
  final bool allowNil;

  /// Paid for a kept nil, and charged for a broken one.
  final int nilBonus;

  /// What one declared trick is worth, won or lost.
  final int pointsPerDeclaredTrick;

  /// What tricks above the declaration are worth.
  final OvertrickRule overtrickRule;

  /// Value of one overtrick when [overtrickRule] scores them.
  final int pointsPerOvertrick;

  /// How many extras turn a kept word into a lost one, or null when extras
  /// can never sink a hand.
  final int? overtrickBustThreshold;

  /// Lowest number a seat may declare.
  int get minimumDeclaration => allowNil ? 0 : 1;

  /// Whether [declaration] is a legal number when [tricksPerHand] are in play.
  bool isInRange(int declaration, {required int tricksPerHand}) =>
      declaration >= minimumDeclaration && declaration <= tricksPerHand;

  /// What a seat scores for taking [tricksTaken] against [declaration].
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
    final int stake = declaration * pointsPerDeclaredTrick;
    if (tricksTaken < declaration) {
      return -stake;
    }
    final int extras = tricksTaken - declaration;
    final int? bust = overtrickBustThreshold;
    if (bust != null && extras >= bust) {
      // Too many extras costs the same as never making the word at all: the
      // hand is down, not merely unrewarded.
      return -stake;
    }
    return switch (overtrickRule) {
      OvertrickRule.ignored => stake,
      OvertrickRule.scored => stake + extras * pointsPerOvertrick,
    };
  }

  DeclarationRules copyWith({
    bool? enabled,
    bool? allowNil,
    int? nilBonus,
    int? pointsPerDeclaredTrick,
    OvertrickRule? overtrickRule,
    int? pointsPerOvertrick,
    int? overtrickBustThreshold,
    bool clearOvertrickBustThreshold = false,
  }) =>
      DeclarationRules(
        enabled: enabled ?? this.enabled,
        allowNil: allowNil ?? this.allowNil,
        nilBonus: nilBonus ?? this.nilBonus,
        pointsPerDeclaredTrick:
            pointsPerDeclaredTrick ?? this.pointsPerDeclaredTrick,
        overtrickRule: overtrickRule ?? this.overtrickRule,
        pointsPerOvertrick: pointsPerOvertrick ?? this.pointsPerOvertrick,
        overtrickBustThreshold: clearOvertrickBustThreshold
            ? null
            : (overtrickBustThreshold ?? this.overtrickBustThreshold),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'allowNil': allowNil,
        'nilBonus': nilBonus,
        'pointsPerDeclaredTrick': pointsPerDeclaredTrick,
        'overtrickRule': overtrickRule.name,
        'pointsPerOvertrick': pointsPerOvertrick,
        'overtrickBustThreshold': overtrickBustThreshold,
      };

  /// Reads a stored record.
  ///
  /// Missing keys fall back to the flat, bust-free reading rather than to the
  /// Koz Maca preset. A save written before these settings existed carries a
  /// profile without them, and a match in progress must keep the scoring it
  /// was dealt under; see the frozen-profile rule in CLAUDE.md.
  static DeclarationRules fromJson(Map<String, Object?> json) =>
      DeclarationRules(
        enabled: json['enabled'] as bool? ?? false,
        allowNil: json['allowNil'] as bool? ?? true,
        nilBonus: json['nilBonus'] as int? ?? 50,
        pointsPerDeclaredTrick: json['pointsPerDeclaredTrick'] as int? ?? 1,
        overtrickRule: OvertrickRule.values.firstWhere(
          (OvertrickRule rule) => rule.name == json['overtrickRule'],
          orElse: () => OvertrickRule.ignored,
        ),
        pointsPerOvertrick: json['pointsPerOvertrick'] as int? ?? 1,
        overtrickBustThreshold: json['overtrickBustThreshold'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is DeclarationRules &&
      other.enabled == enabled &&
      other.allowNil == allowNil &&
      other.nilBonus == nilBonus &&
      other.pointsPerDeclaredTrick == pointsPerDeclaredTrick &&
      other.overtrickRule == overtrickRule &&
      other.pointsPerOvertrick == pointsPerOvertrick &&
      other.overtrickBustThreshold == overtrickBustThreshold;

  @override
  int get hashCode => Object.hash(
        enabled,
        allowNil,
        nilBonus,
        pointsPerDeclaredTrick,
        overtrickRule,
        pointsPerOvertrick,
        overtrickBustThreshold,
      );
}
