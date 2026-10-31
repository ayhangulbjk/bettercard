import 'package:batak_king/core/rules/bidding_rules.dart';
import 'package:batak_king/core/rules/bury_rules.dart';
import 'package:batak_king/core/rules/king_rules.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/core/rules/rule_validation.dart';
import 'package:batak_king/core/rules/scoring_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> codesOf(RuleProfile profile) => RuleProfileValidator.validate(
      profile,
    ).map((RuleIssue issue) => issue.code).toSet();

void main() {
  group('the validator rejects inconsistent profiles', () {
    test('a bid above the trick count is an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        biddingRules: const BiddingRules(minimumBid: 5, maximumBid: 20),
      );
      expect(codesOf(broken), contains('bidding.max_above_tricks'));
      expect(RuleProfileValidator.isPlayable(broken), isFalse);
    });

    test('an inverted bid range is an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        biddingRules: const BiddingRules(minimumBid: 11, maximumBid: 7),
      );
      expect(codesOf(broken), contains('bidding.inverted_range'));
    });

    test('an auction mode without an auction is an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard()
          .copyWith(biddingRules: BiddingRules.none);
      expect(codesOf(broken), contains('bidding.mode_mismatch'));
    });

    test('a minimum bid below one is an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        biddingRules: const BiddingRules(minimumBid: 0, maximumBid: 13),
      );
      expect(codesOf(broken), contains('bidding.min_below_one'));
      expect(RuleProfileValidator.isPlayable(broken), isFalse);
    });

    test('the standard 5-of-13 opening bid raises nothing', () {
      // Regression guard: an earlier draft warned whenever the bid floor was
      // below half the tricks, which flagged the genuine standard custom.
      expect(codesOf(RulePresets.auctionBatakStandard()), isEmpty);
    });

    test('buried Batak without bury rules is an error', () {
      final RuleProfile broken = RulePresets.buriedBatakStandard()
          .copyWith(buryRules: BuryRules.disabled);
      expect(codesOf(broken), contains('bury.required_for_mode'));
    });

    test('a bury count that does not match the surplus is an error', () {
      final RuleProfile broken = RulePresets.buriedBatakStandard().copyWith(
        buryRules: const BuryRules(
          enabled: true,
          cardsDealtToDeclarer: 1,
          cardsToBury: 2,
        ),
      );
      final Set<String> codes = codesOf(broken);
      expect(codes, contains('bury.count_mismatch'));
    });

    test('a King contract with the wrong point sign is an error', () {
      final RuleProfile broken = RulePresets.kingClassic().copyWith(
        kingRules: KingRules(
          contracts: const <KingContractRule>[
            // El Almaz is a penalty contract, so a positive value is wrong.
            KingContractRule(
              contract: KingContract.noTricks,
              pointsPerUnit: 50,
              quotaPerPlayer: 1,
            ),
          ],
        ),
      );
      expect(codesOf(broken), contains('king.points_sign'));
    });

    test('a King profile with every quota at zero is an error', () {
      final RuleProfile broken = RulePresets.kingClassic().copyWith(
        kingRules: KingRules(
          contracts: const <KingContractRule>[
            KingContractRule(
              contract: KingContract.noTricks,
              pointsPerUnit: -50,
              quotaPerPlayer: 0,
            ),
          ],
        ),
      );
      final Set<String> codes = codesOf(broken);
      expect(codes, contains('king.no_active_contracts'));
      expect(codes, contains('king.zero_hands'));
    });

    test('a non-positive round count is an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        scoringRules: const BatakScoringRules(roundCount: 0),
      );
      expect(codesOf(broken), contains('scoring.non_positive_rounds'));
    });

    test('negative trick points are an error', () {
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        scoringRules: const BatakScoringRules(pointsPerTrickForOthers: -1),
      );
      expect(codesOf(broken), contains('scoring.negative_trick_points'));
    });

    test('King rules on a non-King mode are a warning', () {
      final RuleProfile odd = RulePresets.auctionBatakStandard()
          .copyWith(kingRules: KingRules.short8());
      expect(codesOf(odd), contains('king.rules_ignored'));
      expect(RuleProfileValidator.isPlayable(odd), isTrue);
    });

    test('errors are listed before warnings', () {
      // An error (bid above the trick count) plus a warning (King rules on a
      // non-King mode).
      final RuleProfile broken = RulePresets.auctionBatakStandard().copyWith(
        biddingRules: const BiddingRules(minimumBid: 5, maximumBid: 20),
        kingRules: KingRules.short8(),
      );
      final List<RuleIssue> issues = RuleProfileValidator.validate(broken);
      final int firstWarning =
          issues.indexWhere((RuleIssue issue) => !issue.isError);
      final int lastError =
          issues.lastIndexWhere((RuleIssue issue) => issue.isError);
      expect(firstWarning, greaterThanOrEqualTo(0), reason: 'no warning');
      expect(lastError, greaterThanOrEqualTo(0), reason: 'no error');
      expect(firstWarning, greaterThan(lastError));
    });

    // These two branches were unreachable through copyWith until it gained
    // explicit clear flags: `field ?? this.field` silently kept the old value,
    // so a test could not construct a profile with no trump source or a King
    // profile with no contract rules. Both are real states the validator is
    // supposed to catch.
    test('a mode with neither a declarer nor a fixed trump is rejected', () {
      final RuleProfile broken = RulePresets.kozMacaStandard().copyWith(
        clearFixedTrump: true,
        biddingRules: const BiddingRules(
          minimumBid: 5,
          maximumBid: 13,
          declarerNamesTrump: false,
        ),
      );
      expect(codesOf(broken), contains('bidding.no_trump_source'));
    });

    test('a King profile without contract rules is rejected', () {
      final RuleProfile broken =
          RulePresets.kingClassic().copyWith(clearKingRules: true);
      expect(codesOf(broken), contains('king.missing_rules'));
    });

    test('clearing a field is distinguishable from leaving it alone', () {
      final RuleProfile base = RulePresets.kozMacaStandard();
      expect(base.fixedTrump, isNotNull);

      // Passing null must NOT clear: that is the trap this guards.
      expect(base.copyWith(fixedTrump: null).fixedTrump, base.fixedTrump);
      // The explicit flag must clear.
      expect(base.copyWith(clearFixedTrump: true).fixedTrump, isNull);

      final RuleProfile king = RulePresets.kingClassic();
      expect(king.kingRules, isNotNull);
      expect(king.copyWith(kingRules: null).kingRules, king.kingRules);
      expect(king.copyWith(clearKingRules: true).kingRules, isNull);
    });
  });
}
