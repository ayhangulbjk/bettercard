import 'package:meta/meta.dart';

/// What happens when every seat passes the auction.
enum PassOutRule {
  /// Redeal the hand with the same dealer.
  redeal,

  /// The dealer is forced to take the minimum contract (dagitan tutar).
  dealerMustBid,
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
  });

  /// No auction at all (Koz Maca, King). Both bounds are zero and the UI must
  /// not show an auction step.
  static const BiddingRules none = BiddingRules(
    minimumBid: 0,
    maximumBid: 0,
    declarerNamesTrump: false,
  );

  /// Four-player Batak: bids run from 5 to 13 of the 13 tricks.
  static const BiddingRules fourPlayerStandard = BiddingRules(
    minimumBid: 5,
    maximumBid: 13,
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
      );

  @override
  bool operator ==(Object other) =>
      other is BiddingRules &&
      other.minimumBid == minimumBid &&
      other.maximumBid == maximumBid &&
      other.passOutRule == passOutRule &&
      other.declarerNamesTrump == declarerNamesTrump &&
      other.allowPassAfterBidding == allowPassAfterBidding &&
      other.maximumBidIsShootTheMoon == maximumBidIsShootTheMoon;

  @override
  int get hashCode => Object.hash(
        minimumBid,
        maximumBid,
        passOutRule,
        declarerNamesTrump,
        allowPassAfterBidding,
        maximumBidIsShootTheMoon,
      );
}
