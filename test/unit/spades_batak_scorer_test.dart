import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/core/rules/scoring_rules.dart';
import 'package:batak_king/games/spades_batak/spades_batak_engine.dart';
import 'package:batak_king/games/spades_batak/spades_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_positions.dart';

void main() {
  final RuleProfile kozMaca = RulePresets.kozMacaStandard();

  group('SpadesBatakScorer', () {
    test('refuses to score an unfinished hand', () {
      final state = TestPositions.dealt(seed: 7, plies: 4);
      expect(
        () => SpadesBatakScorer.scoreHand(state, kozMaca.scoringRules),
        throwsStateError,
      );
    });

    test('awards one point per trick and nothing else', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score =
          SpadesBatakScorer.scoreHand(state, kozMaca.scoringRules);

      expect(score.seatCount, 4);
      // pointsPerTrickForOthers is 1, so points and tricks must agree exactly.
      for (int seat = 0; seat < 4; seat++) {
        expect(score.pointsOf(seat), score.tricksOf(seat));
      }
      expect(score.totalTricks, 13);
      expect(score.totalPoints, 13);
    });

    test('scales with pointsPerTrickForOthers', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score = SpadesBatakScorer.scoreHand(
        state,
        const BatakScoringRules(pointsPerTrickForOthers: 3),
      );
      expect(score.totalPoints, 39);
      for (int seat = 0; seat < 4; seat++) {
        expect(score.pointsOf(seat), score.tricksOf(seat) * 3);
      }
    });

    test('pays nobody when tricks are worth zero', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score = SpadesBatakScorer.scoreHand(
        state,
        const BatakScoringRules(pointsPerTrickForOthers: 0),
      );
      expect(score.totalPoints, 0);
      expect(score.totalTricks, 13);
    });

    test('score lists are unmodifiable', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score =
          SpadesBatakScorer.scoreHand(state, kozMaca.scoringRules);
      expect(() => score.points.add(1), throwsUnsupportedError);
      expect(() => score.tricks.add(1), throwsUnsupportedError);
    });
  });

  group('SpadesBatakEngine.start', () {
    test('deals a playable opening hand', () {
      final SpadesBatakMatchState state =
          SpadesBatakEngine.start(profile: kozMaca, seed: 2026);

      expect(state.isOver, isFalse);
      expect(state.handIndex, 0);
      expect(state.handsPlayed, 0);
      expect(state.totals, <int>[0, 0, 0, 0]);
      expect(state.hand!.handSizes, <int>[13, 13, 13, 13]);
      expect(state.hand!.trump, kozMaca.fixedTrump);
    });

    test('rejects a profile with an auction', () {
      expect(
        () => SpadesBatakEngine.start(
          profile: RulePresets.auctionBatakStandard(),
          seed: 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a profile with no fixed trump', () {
      expect(
        () => SpadesBatakEngine.start(
          profile: kozMaca.copyWith(clearFixedTrump: true),
          seed: 1,
        ),
        throwsArgumentError,
      );
    });

    test('the same seed deals the same match', () {
      final a = SpadesBatakEngine.start(profile: kozMaca, seed: 55);
      final b = SpadesBatakEngine.start(profile: kozMaca, seed: 55);
      expect(a.hand!.handOf(0), b.hand!.handOf(0));
      expect(a.hand!.handOf(3), b.hand!.handOf(3));
    });

    test('different seeds deal different matches', () {
      final a = SpadesBatakEngine.start(profile: kozMaca, seed: 55);
      final b = SpadesBatakEngine.start(profile: kozMaca, seed: 56);
      expect(a.hand!.handOf(0), isNot(b.hand!.handOf(0)));
    });
  });
}
