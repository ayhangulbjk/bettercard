import 'package:meta/meta.dart';

/// What happens when every seat passes the auction.
///
/// Turkish tables disagree here and the disagreement changes who is in
/// trouble, so it is a setting. The common reading at a four-handed table is
/// that the seat which opened the auction -- the dealer's right-hand
/// neighbour -- is stuck with a small forced contract.
enum PassOutRule {
  /// Redeal the hand with the same dealer. No score, no contract.
  redeal,

  /// The dealer is forced to take [BiddingRules.forcedBid] (dagitan tutar).
  dealerMustBid,

  /// The seat that opened the auction is forced to take
  /// [BiddingRules.forcedBid].
  openerMustBid,
}

/// Auction configuration.
///
/// Turkish Batak tables vary most around the auction, so every knob that
/// changes a legal bid lives here rather than in code. See
/// docs/RULE_PROFILES.md for which real-world customs each combination
/// reproduces, and which ones remain open questions.
@immutable
class BiddingRules {
  const BiddingRules({
    required this.minimumBid,
    required this.maximumBid,
    this.passOutRule = PassOutRule.dealerMustBid,
    this.declarerNamesTrump = true,
    this.allowPassAfterBidding = true,
    this.maximumBidIsShootTheMoon = false,
    this.forcedBid,
  });

  /// No auction at all (Koz Maca, King). Both bounds are zero and the UI must
  /// not show an auction step.
  static const BiddingRules none = BiddingRules(
    minimumBid: 0,
    maximumBid: 0,
    declarerNamesTrump: false,
  );

  /// Four-player Batak: bids run from 5 to 13 of the 13 tricks.
  ///
  /// A passed-out hand sticks the seat that opened the auction with four,
  /// which is deliberately *below* [minimumBid]: nobody chose it, so it is
  /// not held to the floor a voluntary contract is. See
  /// docs/RULE_PROFILES.md.
  static const BiddingRules fourPlayerStandard = BiddingRules(
    minimumBid: 5,
    maximumBid: 13,
    passOutRule: PassOutRule.openerMustBid,
    forcedBid: 4,
  );

  /// Three-player buried Batak: 17 tricks are in play, so the bid range and
  /// the more-than-half threshold both shift.
  static const BiddingRules threePlayerBuried = BiddingRules(
    minimumBid: 9,
    maximumBid: 17,
  );

  /// Lowest contract a seat may take.
  final int minimumBid;

  /// Highest contract a seat may take, normally the trick count of the hand.
  final int maximumBid;

  /// Resolution when the auction passes out.
  final PassOutRule passOutRule;

  /// Whether the auction winner chooses the trump suit.
  final bool declarerNamesTrump;

  /// Whether a seat that has already bid may pass later in the auction.
  final bool allowPassAfterBidding;

  /// Whether taking the maximum contract scores as an all-or-nothing hand with
  /// an enlarged payoff. Tables disagree; off by default.
  final bool maximumBidIsShootTheMoon;

  /// The contract a passed-out hand forces on a seat, or null to use
  /// [minimumBid].
  ///
  /// Separate from [minimumBid] because it is a different number for a
  /// different reason: the floor is what a seat may *choose*, and this is
  /// what a seat is *given* when nobody chose anything. The common Turkish
  /// reading makes the forced contract smaller than the floor, which is only
  /// expressible with two fields.
  final int? forcedBid;

  /// The contract value a passed-out hand forces.
  int get effectiveForcedBid => forcedBid ?? minimumBid;

  bool get hasAuction => maximumBid > 0;

  /// Whether [bid] is a legal contract value in isolation.
  bool isBidInRange(int bid) => bid >= minimumBid && bid <= maximumBid;

  /// Whether [bid] may be made over a [standingBid] (null when none yet).
  bool isLegalRaise(int bid, {int? standingBid}) {
    if (!isBidInRange(bid)) {
      return false;
    }
    return standingBid == null || bid > standingBid;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'minimumBid': minimumBid,
        'maximumBid': maximumBid,
        'passOutRule': passOutRule.name,
        'declarerNamesTrump': declarerNamesTrump,
        'allowPassAfterBidding': allowPassAfterBidding,
        'maximumBidIsShootTheMoon': maximumBidIsShootTheMoon,
        'forcedBid': forcedBid,
      };

  static BiddingRules fromJson(Map<String, Object?> json) => BiddingRules(
        minimumBid: json['minimumBid']! as int,
        maximumBid: json['maximumBid']! as int,
        passOutRule: PassOutRule.values.firstWhere(
          (PassOutRule rule) => rule.name == json['passOutRule'],
          orElse: () => PassOutRule.dealerMustBid,
        ),
        declarerNamesTrump: json['declarerNamesTrump'] as bool? ?? true,
        allowPassAfterBidding: json['allowPassAfterBidding'] as bool? ?? true,
        maximumBidIsShootTheMoon:
            json['maximumBidIsShootTheMoon'] as bool? ?? false,
        forcedBid: json['forcedBid'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is BiddingRules &&
      other.minimumBid == minimumBid &&
      other.maximumBid == maximumBid &&
      other.passOutRule == passOutRule &&
      other.declarerNamesTrump == declarerNamesTrump &&
      other.allowPassAfterBidding == allowPassAfterBidding &&
      other.maximumBidIsShootTheMoon == maximumBidIsShootTheMoon &&
      other.forcedBid == forcedBid;

  @override
  int get hashCode => Object.hash(
        minimumBid,
        maximumBid,
        passOutRule,
        declarerNamesTrump,
        allowPassAfterBidding,
        maximumBidIsShootTheMoon,
        forcedBid,
      );

  BiddingRules copyWith({
    int? minimumBid,
    int? maximumBid,
    PassOutRule? passOutRule,
    bool? declarerNamesTrump,
    bool? allowPassAfterBidding,
    bool? maximumBidIsShootTheMoon,
    int? forcedBid,
    bool clearForcedBid = false,
  }) =>
      BiddingRules(
        minimumBid: minimumBid ?? this.minimumBid,
        maximumBid: maximumBid ?? this.maximumBid,
        passOutRule: passOutRule ?? this.passOutRule,
        declarerNamesTrump: declarerNamesTrump ?? this.declarerNamesTrump,
        allowPassAfterBidding:
            allowPassAfterBidding ?? this.allowPassAfterBidding,
        maximumBidIsShootTheMoon:
            maximumBidIsShootTheMoon ?? this.maximumBidIsShootTheMoon,
        forcedBid: clearForcedBid ? null : (forcedBid ?? this.forcedBid),
      );
}
