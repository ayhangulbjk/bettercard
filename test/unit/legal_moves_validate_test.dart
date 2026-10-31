import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/game_engine/trick/trick_legal_moves.dart';
import 'package:batak_king/core/rules/rule_violation.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard card(Suit suit, Rank rank) => PlayingCard(suit, rank);

Trick leadWith(Suit suit, Rank rank) => Trick(
      leadSeat: 0,
      expectedPlays: 4,
      plays: <PlayedCard>[
        PlayedCard(seat: 0, card: PlayingCard(suit, rank)),
      ],
    );

void main() {
  test('a legal card produces no violation', () {
    expect(
      TrickLegalMoves.validate(
        card: card(Suit.hearts, Rank.two),
        hand: <PlayingCard>[card(Suit.hearts, Rank.two)],
        trick: leadWith(Suit.hearts, Rank.five),
        trump: Suit.spades,
        rules: TrickRules.batakStandard,
        trumpBroken: true,
      ),
      isNull,
    );
  });

  test('a card the seat does not hold is reported as such', () {
    final RuleViolation? violation = TrickLegalMoves.validate(
      card: card(Suit.spades, Rank.ace),
      hand: <PlayingCard>[card(Suit.hearts, Rank.two)],
      trick: null,
      trump: Suit.spades,
      rules: TrickRules.batakStandard,
      trumpBroken: true,
    );
    expect(violation?.code, RuleViolationCode.cardNotInHand);
  });

  test('failing to follow suit is reported specifically', () {
    final RuleViolation? violation = TrickLegalMoves.validate(
      card: card(Suit.clubs, Rank.ace),
      hand: <PlayingCard>[
        card(Suit.hearts, Rank.two),
        card(Suit.clubs, Rank.ace),
      ],
      trick: leadWith(Suit.hearts, Rank.five),
      trump: Suit.spades,
      rules: TrickRules.batakStandard,
      trumpBroken: true,
    );
    expect(violation?.code, RuleViolationCode.mustFollowSuit);
  });

  test('failing to play compulsory trump is reported specifically', () {
    final RuleViolation? violation = TrickLegalMoves.validate(
      card: card(Suit.clubs, Rank.ace),
      hand: <PlayingCard>[
        card(Suit.spades, Rank.four),
        card(Suit.clubs, Rank.ace),
      ],
      trick: leadWith(Suit.hearts, Rank.five),
      trump: Suit.spades,
      rules: TrickRules.batakStandard,
      trumpBroken: true,
    );
    expect(violation?.code, RuleViolationCode.mustPlayTrump);
  });

  test('an illegal trump lead is reported specifically', () {
    final RuleViolation? violation = TrickLegalMoves.validate(
      card: card(Suit.spades, Rank.ace),
      hand: <PlayingCard>[
        card(Suit.spades, Rank.ace),
        card(Suit.hearts, Rank.two),
      ],
      trick: null,
      trump: Suit.spades,
      rules: TrickRules.kozMaca,
      trumpBroken: false,
    );
    expect(violation?.code, RuleViolationCode.trumpNotBroken);
  });

  test('every legal move validates, for every rule profile', () {
    // Cross-check: forHand and validate must agree, or the UI could highlight
    // a card the engine would then reject.
    final List<PlayingCard> hand = <PlayingCard>[
      card(Suit.hearts, Rank.two),
      card(Suit.hearts, Rank.king),
      card(Suit.spades, Rank.four),
      card(Suit.clubs, Rank.ace),
    ];
    final List<TrickRules> profiles = <TrickRules>[
      TrickRules.batakStandard,
      TrickRules.kozMaca,
      TrickRules.noTrump,
      const TrickRules(mustBeatLeadSuitWhenPossible: true),
    ];
    final List<Trick?> tricks = <Trick?>[
      null,
      leadWith(Suit.hearts, Rank.five),
      leadWith(Suit.diamonds, Rank.five),
    ];

    for (final TrickRules rules in profiles) {
      for (final Trick? trick in tricks) {
        for (final bool broken in <bool>[true, false]) {
          final List<PlayingCard> legal = TrickLegalMoves.forHand(
            hand: hand,
            trick: trick,
            trump: Suit.spades,
            rules: rules,
            trumpBroken: broken,
          );
          expect(legal, isNotEmpty, reason: 'no legal move for $rules');
          for (final PlayingCard candidate in legal) {
            expect(
              TrickLegalMoves.validate(
                card: candidate,
                hand: hand,
                trick: trick,
                trump: Suit.spades,
                rules: rules,
                trumpBroken: broken,
              ),
              isNull,
              reason: '$candidate was generated but rejected under $rules',
            );
          }
        }
      }
    }
  });
}
