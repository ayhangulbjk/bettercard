import 'package:batak_king/core/rules/game_mode.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/core/rules/rule_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shipped presets', () {
    test('every preset validates without errors', () {
      for (final RuleProfile profile in RulePresets.all()) {
        final List<RuleIssue> issues = RuleProfileValidator.validate(profile);
        final Iterable<RuleIssue> errors =
            issues.where((RuleIssue issue) => issue.isError);
        expect(
          errors,
          isEmpty,
          reason: '${profile.id} has errors: ${errors.join('; ')}',
        );
      }
    });

    test('every game mode has at least one preset', () {
      for (final GameMode mode in GameMode.values) {
        expect(
          RulePresets.forMode(mode),
          isNotEmpty,
          reason: 'no preset for ${mode.id}',
        );
      }
    });

    test('preset ids are unique', () {
      final List<RuleProfile> all = RulePresets.all();
      expect(all.map((RuleProfile p) => p.id).toSet(), hasLength(all.length));
    });

    test('deck arithmetic is consistent for every preset', () {
      for (final RuleProfile profile in RulePresets.all()) {
        expect(
          profile.playableCardCount % profile.playerCount,
          0,
          reason: '${profile.id} cannot deal evenly',
        );
        expect(
          profile.deckSize - profile.playerCount * profile.tricksPerHand,
          profile.cardsSetAside,
          reason: '${profile.id} surplus does not match the bury count',
        );
      }
    });

    test('the four-player presets play 13 tricks', () {
      for (final RuleProfile profile in RulePresets.all()) {
        if (profile.playerCount == 4) {
          expect(profile.tricksPerHand, 13, reason: profile.id);
        }
      }
    });

    test('the three-player buried preset plays 17 tricks', () {
      final RuleProfile profile = RulePresets.buriedBatakStandard();
      expect(profile.playerCount, 3);
      expect(profile.tricksPerHand, 17);
      expect(profile.cardsSetAside, 1);
    });

    test('the classic King preset derives 20 hands from its quotas', () {
      expect(RulePresets.kingClassic().kingRules!.totalHands, 20);
    });

    test('the short King preset derives 8 hands from its quotas', () {
      expect(RulePresets.kingShort().kingRules!.totalHands, 8);
    });
  });

  group('JSON round-trip', () {
    test('every preset survives encode and decode unchanged', () {
      for (final RuleProfile profile in RulePresets.all()) {
        final RuleProfile restored = RuleProfile.fromJson(profile.toJson());
        expect(restored, equals(profile), reason: profile.id);
        expect(restored.hashCode, profile.hashCode, reason: profile.id);
      }
    });

    test('a King profile keeps its contract quotas and point values', () {
      final RuleProfile original = RulePresets.kingClassic();
      final RuleProfile restored = RuleProfile.fromJson(original.toJson());
      expect(restored.kingRules, equals(original.kingRules));
      expect(restored.kingRules!.totalHands, original.kingRules!.totalHands);
    });

    test('a profile from a newer schema is refused, not guessed at', () {
      final Map<String, Object?> json =
          RulePresets.auctionBatakStandard().toJson();
      json['schemaVersion'] = RuleProfile.currentSchemaVersion + 1;
      expect(() => RuleProfile.fromJson(json), throwsUnsupportedError);
    });
  });
}
