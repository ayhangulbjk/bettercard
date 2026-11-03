import 'package:meta/meta.dart';

/// What a seat is paid in a single-contract auction hand.
///
/// This is a different payoff from both [BatakScoringRules] and
/// [DeclarationRules], and keeping it apart is deliberate. Koz Maca pays four
/// independent promises; this mode pays **one** contract and three defenders,
/// and the two must never be read through the same record. A hand here has
/// exactly one declarer, and "yan 3 batar" -- the Koz Maca rule that too many
/// extras sink a made hand -- does not exist in it at all.
///
/// ### The default payoff, as the table plays it
///
/// A contract of `b` stakes `b * pointsPerBidTrick`. Make it and the stake is
/// won, plus [pointsPerOvertrick] for each trick above it, so a bid of 6
/// taking 8 writes 62. Miss it and the same stake is lost whole, however near
/// the miss was: 7 bid and 6 taken is -70, exactly like 7 bid and 2 taken.
///
/// A defender is paid [pointsPerDefenderTrick] a trick. A defender that takes
/// **none** is charged the declarer's stake ("yan batma"), which is what stops
/// three seats quietly conceding a large contract -- each of them has its own
/// skin in the hand. That rule is a setting, because tables differ.
@immutable
class AuctionScoringRules {
  const AuctionScoringRules({
    this.enabled = false,
    this.pointsPerBidTrick = 10,
    this.pointsPerOvertrick = 1,
    this.pointsPerDefenderTrick = 10,
    this.defenderNilPenalty = DefenderNilPenalty.contractValue,
    this.flatNilPenalty = 50,
    this.failureMultiplier = 1,
  });

  /// No single-contract scoring. The mode pays some other way.
  static const AuctionScoringRules none = AuctionScoringRules();

  /// Klasik 10 tabanli, the default: `bid x 10 + extras`, `-bid x 10` for a
  /// miss, ten a trick for defenders, and a defender with no tricks pays the
  /// contract's value.
  static const AuctionScoringRules classicTenBased = AuctionScoringRules(
    enabled: true,
  );

  /// El basina puan: the same shape with everything divided by ten, for
  /// tables that keep score in tricks rather than points.
  static const AuctionScoringRules perTrick = AuctionScoringRules(
    enabled: true,
    pointsPerBidTrick: 1,
    pointsPerOvertrick: 0,
    pointsPerDefenderTrick: 1,
    defenderNilPenalty: DefenderNilPenalty.none,
  );

  /// Gamyun tipi: a made contract pays a premium, extras pay ten each, and a
  /// defender with no tricks pays a flat fifty.
  static const AuctionScoringRules gamyun = AuctionScoringRules(
    enabled: true,
    pointsPerBidTrick: 15,
    pointsPerOvertrick: 10,
    pointsPerDefenderTrick: 10,
    defenderNilPenalty: DefenderNilPenalty.flat,
    flatNilPenalty: 50,
    failureMultiplier: 1,
  );

  /// Whether a hand is scored as one contract against three defenders.
  final bool enabled;

  /// What one bid trick stakes, won or lost.
  final int pointsPerBidTrick;

  /// What one trick above a made contract pays. Zero means extras are free.
  final int pointsPerOvertrick;

  /// What one trick pays a defender.
  final int pointsPerDefenderTrick;

  /// What a defender that took no tricks pays.
  final DefenderNilPenalty defenderNilPenalty;

  /// The charge when [defenderNilPenalty] is [DefenderNilPenalty.flat].
  final int flatNilPenalty;

  /// Multiplier on a broken contract. One is the common reading; two is the
  /// table that doubles a failed declarer.
  final int failureMultiplier;

  /// The stake a contract of [bid] puts up.
  int stakeFor(int bid) => bid * pointsPerBidTrick;

  /// What the declarer scores for taking [tricksTaken] against [bid].
  ///
  /// The whole declarer payoff in one place, so the scorer, the rules screen
  /// and the bidding AI cannot disagree about what a contract is worth.
  int declarerScore({required int bid, required int tricksTaken}) {
    final int stake = stakeFor(bid);
    if (tricksTaken < bid) {
      return -stake * failureMultiplier;
    }
    return stake + (tricksTaken - bid) * pointsPerOvertrick;
  }

  /// What a defender scores for taking [tricksTaken] against a contract of
  /// [bid].
  int defenderScore({required int bid, required int tricksTaken}) {
    if (tricksTaken > 0) {
      return tricksTaken * pointsPerDefenderTrick;
    }
    return switch (defenderNilPenalty) {
      DefenderNilPenalty.none => 0,
      DefenderNilPenalty.flat => -flatNilPenalty,
      DefenderNilPenalty.contractValue => -stakeFor(bid),
    };
  }

  /// What [seat] scores, given who declared.
  ///
  /// The one entry point worth calling: it is impossible to use it and forget
  /// which side of the contract a seat was on.
  int scoreFor({
    required int seat,
    required int declarerSeat,
    required int bid,
    required int tricksTaken,
  }) =>
      seat == declarerSeat
          ? declarerScore(bid: bid, tricksTaken: tricksTaken)
          : defenderScore(bid: bid, tricksTaken: tricksTaken);

  AuctionScoringRules copyWith({
    bool? enabled,
    int? pointsPerBidTrick,
    int? pointsPerOvertrick,
    int? pointsPerDefenderTrick,
    DefenderNilPenalty? defenderNilPenalty,
    int? flatNilPenalty,
    int? failureMultiplier,
  }) =>
      AuctionScoringRules(
        enabled: enabled ?? this.enabled,
        pointsPerBidTrick: pointsPerBidTrick ?? this.pointsPerBidTrick,
        pointsPerOvertrick: pointsPerOvertrick ?? this.pointsPerOvertrick,
        pointsPerDefenderTrick:
            pointsPerDefenderTrick ?? this.pointsPerDefenderTrick,
        defenderNilPenalty: defenderNilPenalty ?? this.defenderNilPenalty,
        flatNilPenalty: flatNilPenalty ?? this.flatNilPenalty,
        failureMultiplier: failureMultiplier ?? this.failureMultiplier,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'pointsPerBidTrick': pointsPerBidTrick,
        'pointsPerOvertrick': pointsPerOvertrick,
        'pointsPerDefenderTrick': pointsPerDefenderTrick,
        'defenderNilPenalty': defenderNilPenalty.name,
        'flatNilPenalty': flatNilPenalty,
        'failureMultiplier': failureMultiplier,
      };

  static AuctionScoringRules fromJson(Map<String, Object?> json) =>
      AuctionScoringRules(
        enabled: json['enabled'] as bool? ?? false,
        pointsPerBidTrick: json['pointsPerBidTrick'] as int? ?? 10,
        pointsPerOvertrick: json['pointsPerOvertrick'] as int? ?? 1,
        pointsPerDefenderTrick: json['pointsPerDefenderTrick'] as int? ?? 10,
        defenderNilPenalty: DefenderNilPenalty.values.firstWhere(
          (DefenderNilPenalty v) => v.name == json['defenderNilPenalty'],
          orElse: () => DefenderNilPenalty.contractValue,
        ),
        flatNilPenalty: json['flatNilPenalty'] as int? ?? 50,
        failureMultiplier: json['failureMultiplier'] as int? ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is AuctionScoringRules &&
      other.enabled == enabled &&
      other.pointsPerBidTrick == pointsPerBidTrick &&
      other.pointsPerOvertrick == pointsPerOvertrick &&
      other.pointsPerDefenderTrick == pointsPerDefenderTrick &&
      other.defenderNilPenalty == defenderNilPenalty &&
      other.flatNilPenalty == flatNilPenalty &&
      other.failureMultiplier == failureMultiplier;

  @override
  int get hashCode => Object.hash(
        enabled,
        pointsPerBidTrick,
        pointsPerOvertrick,
        pointsPerDefenderTrick,
        defenderNilPenalty,
        flatNilPenalty,
        failureMultiplier,
      );
}

/// What a defender that took no tricks pays ("yan batma").
enum DefenderNilPenalty {
  /// Nothing. A tricksless defender simply scores zero.
  none,

  /// A fixed charge, whatever the contract was.
  flat,

  /// The contract's own stake, so a big contract punishes a shut-out defender
  /// harder than a small one does.
  contractValue,
}
