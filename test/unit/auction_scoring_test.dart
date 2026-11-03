// The single-contract payoff, including the rule most often got wrong:
// "yan 3 batar" belongs to Koz Maca and does not exist here. A declarer three
// tricks over its contract is simply three points better off.

import 'package:batak_king/core/rules/auction_scoring_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classic ten-based', () {
    const AuctionScoringRules rules = AuctionScoringRules.classicTenBased;

    test('a made contract pays its stake plus the extras', () {
      expect(rules.declarerScore(bid: 5, tricksTaken: 5), 50);
      expect(rules.declarerScore(bid: 5, tricksTaken: 6), 51);
      expect(rules.declarerScore(bid: 6, tricksTaken: 8), 62);
      expect(rules.declarerScore(bid: 7, tricksTaken: 9), 72);
    });

    test('a broken contract loses the stake whole', () {
      expect(rules.declarerScore(bid: 5, tricksTaken: 4), -50);
      expect(rules.declarerScore(bid: 7, tricksTaken: 6), -70);
      expect(rules.declarerScore(bid: 8, tricksTaken: 2), -80);
    });

    test('how near the miss was makes no difference', () {
      expect(
        rules.declarerScore(bid: 7, tricksTaken: 6),
        rules.declarerScore(bid: 7, tricksTaken: 0),
      );
    });

    test('too many extras never sink a contract', () {
      // Koz Maca's "yan 3 batar" would make this -50. It must not be here.
      expect(rules.declarerScore(bid: 5, tricksTaken: 8), 53);
      expect(rules.declarerScore(bid: 5, tricksTaken: 13), 58);
    });

    test('a defender is paid ten a trick', () {
      expect(rules.defenderScore(bid: 7, tricksTaken: 3), 30);
      expect(rules.defenderScore(bid: 7, tricksTaken: 1), 10);
    });

    test('a defender with no tricks pays the contract value', () {
      expect(rules.defenderScore(bid: 7, tricksTaken: 0), -70);
      expect(rules.defenderScore(bid: 5, tricksTaken: 0), -50);
    });

    test('scoreFor picks the right side of the contract', () {
      expect(
        rules.scoreFor(seat: 2, declarerSeat: 2, bid: 6, tricksTaken: 7),
        61,
      );
      expect(
        rules.scoreFor(seat: 1, declarerSeat: 2, bid: 6, tricksTaken: 7),
        70,
      );
    });
  });

  group('alternative profiles', () {
    test('per-trick keeps the shape and drops the scale', () {
      const AuctionScoringRules rules = AuctionScoringRules.perTrick;
      expect(rules.declarerScore(bid: 5, tricksTaken: 6), 5);
      expect(rules.declarerScore(bid: 5, tricksTaken: 4), -5);
      expect(rules.defenderScore(bid: 5, tricksTaken: 3), 3);
      expect(rules.defenderScore(bid: 5, tricksTaken: 0), 0);
    });

    test('gamyun pays a premium and a flat shut-out charge', () {
      const AuctionScoringRules rules = AuctionScoringRules.gamyun;
      expect(rules.declarerScore(bid: 6, tricksTaken: 6), 90);
      expect(rules.declarerScore(bid: 6, tricksTaken: 8), 110);
      expect(rules.declarerScore(bid: 6, tricksTaken: 5), -90);
      expect(rules.defenderScore(bid: 6, tricksTaken: 2), 20);
      expect(rules.defenderScore(bid: 6, tricksTaken: 0), -50);
    });

    test('yan batma can be switched off', () {
      const AuctionScoringRules rules = AuctionScoringRules(
        enabled: true,
        defenderNilPenalty: DefenderNilPenalty.none,
      );
      expect(rules.defenderScore(bid: 7, tricksTaken: 0), 0);
    });

    test('a doubling table charges twice for a broken contract', () {
      const AuctionScoringRules rules =
          AuctionScoringRules(enabled: true, failureMultiplier: 2);
      expect(rules.declarerScore(bid: 7, tricksTaken: 6), -140);
      expect(
        rules.declarerScore(bid: 7, tricksTaken: 7),
        70,
        reason: 'doubling applies to the penalty only',
      );
    });

    test('the profiles stay apart through a save round trip', () {
      for (final AuctionScoringRules rules in <AuctionScoringRules>[
        AuctionScoringRules.classicTenBased,
        AuctionScoringRules.perTrick,
        AuctionScoringRules.gamyun,
      ]) {
        expect(AuctionScoringRules.fromJson(rules.toJson()), rules);
      }
    });
  });
}
