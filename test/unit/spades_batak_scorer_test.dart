import 'package:batak_king/core/game_engine/trick/trick_play_state.dart';
import 'package:batak_king/core/rules/declaration_rules.dart';
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

  /// Koz Maca without the declaration round, i.e. flat trick scoring. Kept as
  /// its own profile rather than as the shipped one, because the shipped
  /// preset now declares and a saved match may still be running under either.
  final RuleProfile flat =
      kozMaca.copyWith(declarationRules: DeclarationRules.none);

  group('SpadesBatakScorer without declarations', () {
    test('refuses to score an unfinished hand', () {
      final state = TestPositions.dealt(seed: 7, plies: 4);
      expect(
        () => SpadesBatakScorer.scoreHand(state: state, profile: flat),
        throwsStateError,
      );
    });

    test('awards one point per trick and nothing else', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score =
          SpadesBatakScorer.scoreHand(state: state, profile: flat);

      expect(score.seatCount, 4);
      // pointsPerTrickForOthers is 1, so points and tricks must agree exactly.
      for (int seat = 0; seat < 4; seat++) {
        expect(score.pointsOf(seat), score.tricksOf(seat));
        expect(score.declarationOf(seat), isNull);
      }
      expect(score.totalTricks, 13);
      expect(score.totalPoints, 13);
    });

    test('scales with pointsPerTrickForOthers', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score = SpadesBatakScorer.scoreHand(
        state: state,
        profile: flat.copyWith(
          scoringRules: const BatakScoringRules(pointsPerTrickForOthers: 3),
        ),
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
        state: state,
        profile: flat.copyWith(
          scoringRules: const BatakScoringRules(pointsPerTrickForOthers: 0),
        ),
      );
      expect(score.totalPoints, 0);
      expect(score.totalTricks, 13);
    });

    test('score lists are unmodifiable', () {
      final state =
          TestPositions.playToCompletion(TestPositions.dealt(seed: 11));
      final HandScore score =
          SpadesBatakScorer.scoreHand(state: state, profile: flat);
      expect(() => score.points.add(1), throwsUnsupportedError);
      expect(() => score.tricks.add(1), throwsUnsupportedError);
      expect(() => score.declarations.add(1), throwsUnsupportedError);
    });
  });

  group('SpadesBatakScorer with declarations', () {
    final TrickPlayState played =
        TestPositions.playToCompletion(TestPositions.dealt(seed: 11));

    test('pays ten a trick for a kept word and charges it for a broken one',
        () {
      final List<int> tricks = played.tricksWon;
      // One seat promises exactly what it took and the rest promise one more,
      // so the same hand exercises both halves of the payoff. Promising one
      // more is never nil, so no seat falls into the nil branch by accident.
      final int kept = tricks.indexWhere((int won) => won > 0);
      expect(kept, isNot(-1), reason: 'the fixture needs a seat with tricks');
      final HandScore score = SpadesBatakScorer.scoreHand(
        state: played,
        profile: kozMaca,
        declarations: <int?>[
          for (int s = 0; s < 4; s++) s == kept ? tricks[s] : tricks[s] + 1,
        ],
      );

      expect(score.pointsOf(kept), tricks[kept] * 10);
      expect(score.madeDeclaration(kept), isTrue);
      for (int seat = 0; seat < 4; seat++) {
        if (seat == kept) {
          continue;
        }
        expect(score.pointsOf(seat), -((tricks[seat] + 1) * 10));
        expect(score.madeDeclaration(seat), isFalse);
        expect(score.declarationOf(seat), tricks[seat] + 1);
      }
    });

    test('extras pay one each under the shipped preset', () {
      final List<int> tricks = played.tricksWon;
      final int seat = tricks.indexWhere((int won) => won >= 2);
      expect(seat, isNot(-1), reason: 'the fixture needs a seat with tricks');
      // One short of what it took, so there is exactly one extra and the
      // bust threshold is nowhere near.
      final int declared = tricks[seat] - 1;
      final HandScore score = SpadesBatakScorer.scoreHand(
        state: played,
        profile: kozMaca,
        declarations: <int?>[
          for (int s = 0; s < 4; s++) s == seat ? declared : tricks[s],
        ],
      );
      expect(score.pointsOf(seat), declared * 10 + 1);
    });

    test('extras are worth nothing where the profile ignores them', () {
      final List<int> tricks = played.tricksWon;
      final int seat = tricks.indexWhere((int won) => won >= 2);
      final HandScore score = SpadesBatakScorer.scoreHand(
        state: played,
        profile: kozMaca.copyWith(
          declarationRules: DeclarationRules.kozMacaStandard.copyWith(
            overtrickRule: OvertrickRule.ignored,
            clearOvertrickBustThreshold: true,
          ),
        ),
        declarations: <int?>[
          for (int s = 0; s < 4; s++) s == seat ? 1 : tricks[s],
        ],
      );
      expect(score.pointsOf(seat), 10);
    });

    test('too many extras sink a word that was otherwise kept', () {
      final List<int> tricks = played.tricksWon;
      final int seat = tricks.indexWhere((int won) => won >= 2);
      final HandScore score = SpadesBatakScorer.scoreHand(
        state: played,
        profile: kozMaca.copyWith(
          // One extra is enough at this table, which makes the case reachable
          // from any fixture.
          declarationRules: DeclarationRules.kozMacaStandard.copyWith(
            overtrickBustThreshold: 1,
          ),
        ),
        declarations: <int?>[
          for (int s = 0; s < 4; s++) s == seat ? 1 : tricks[s],
        ],
      );
      expect(score.pointsOf(seat), -10);
      // Clearing the number by trick count is not the same as keeping the
      // word: the hand is down, and the score sheet has to say so.
      expect(score.madeDeclaration(seat), isFalse);
    });

    test('the payoff table matches the custom this build ships', () {
      const DeclarationRules rules = DeclarationRules.kozMacaStandard;
      // Said five, took five: fifty.
      expect(rules.scoreFor(declaration: 5, tricksTaken: 5), 50);
      // Said five, took seven: fifty-two, the two extras paying one each.
      expect(rules.scoreFor(declaration: 5, tricksTaken: 7), 52);
      // Said five, took eight: three extras sink it, so minus fifty.
      expect(rules.scoreFor(declaration: 5, tricksTaken: 8), -50);
      // Said five, took three: minus fifty.
      expect(rules.scoreFor(declaration: 5, tricksTaken: 3), -50);
      // The same hand at a table that busts on two extras.
      expect(
        rules
            .copyWith(overtrickBustThreshold: 2)
            .scoreFor(declaration: 5, tricksTaken: 7),
        -50,
      );
    });

    test('el almaz pays the bonus only when no trick is taken', () {
      final List<int> tricks = played.tricksWon;
      final int empty = tricks.indexWhere((int won) => won == 0);
      final int busy = tricks.indexWhere((int won) => won > 0);
      expect(busy, isNot(-1));

      final HandScore score = SpadesBatakScorer.scoreHand(
        state: played,
        profile: kozMaca,
        declarations: <int?>[
          for (int s = 0; s < 4; s++) s == busy ? 0 : tricks[s],
        ],
      );
      expect(score.pointsOf(busy), -50);
      if (empty != -1) {
        final HandScore kept = SpadesBatakScorer.scoreHand(
          state: played,
          profile: kozMaca,
          declarations: <int?>[
            for (int s = 0; s < 4; s++) s == empty ? 0 : tricks[s],
          ],
        );
        expect(kept.pointsOf(empty), 50);
      }
    });

    test('a declaring profile refuses to score a hand nobody declared in', () {
      expect(
        () => SpadesBatakScorer.scoreHand(state: played, profile: kozMaca),
        throwsStateError,
      );
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
