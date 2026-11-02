import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/game_engine/trick/trick_legal_moves.dart';
import 'package:batak_king/core/rules/trick_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard card(Suit suit, Rank rank) => PlayingCard(suit, rank);

Trick leadWith(Suit suit, Rank rank, {int seat = 0}) => Trick(
      leadSeat: seat,
      expectedPlays: 4,
      plays: <PlayedCard>[
        PlayedCard(seat: seat, card: PlayingCard(suit, rank)),
      ],
    );

void main() {
  group('leading', () {
    test('unrestricted rules allow the whole hand', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.two),
        card(Suit.spades, Rank.ace),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: null,
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: false,
        ),
        unorderedEquals(hand),
      );
    });

    test('onlyAfterBroken forbids leading trump before it is broken', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.hearts, Rank.two),
            card(Suit.spades, Rank.ace),
          ],
          trick: null,
          trump: Suit.spades,
          rules: TrickRules.kozMaca,
          trumpBroken: false,
        ),
        <PlayingCard>[card(Suit.hearts, Rank.two)],
      );
    });

    test('onlyAfterBroken permits trump once broken', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.two),
        card(Suit.spades, Rank.ace),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: null,
          trump: Suit.spades,
          rules: TrickRules.kozMaca,
          trumpBroken: true,
        ),
        unorderedEquals(hand),
      );
    });

    test('a trump-only hand may lead trump even when unbroken', () {
      // Otherwise the seat would have no legal move at all.
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.spades, Rank.ace),
        card(Suit.spades, Rank.two),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: null,
          trump: Suit.spades,
          rules: TrickRules.kozMaca,
          trumpBroken: false,
        ),
        unorderedEquals(hand),
      );
    });
  });

  group('following suit', () {
    test('holding the lead suit restricts the hand to it', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.hearts, Rank.two),
            card(Suit.hearts, Rank.king),
            card(Suit.clubs, Rank.ace),
          ],
          trick: leadWith(Suit.hearts, Rank.five),
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: true,
        ),
        unorderedEquals(<PlayingCard>[
          card(Suit.hearts, Rank.two),
          card(Suit.hearts, Rank.king),
        ]),
      );
    });

    test('mustBeatLeadSuit narrows to the cards that beat it', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.hearts, Rank.two),
            card(Suit.hearts, Rank.king),
          ],
          trick: leadWith(Suit.hearts, Rank.ten),
          trump: Suit.spades,
          rules: const TrickRules(mustBeatLeadSuitWhenPossible: true),
          trumpBroken: true,
        ),
        <PlayingCard>[card(Suit.hearts, Rank.king)],
      );
    });

    test('mustBeatLeadSuit falls back when no card beats the trick', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.hearts, Rank.two),
        card(Suit.hearts, Rank.three),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: leadWith(Suit.hearts, Rank.ace),
          trump: Suit.spades,
          rules: const TrickRules(mustBeatLeadSuitWhenPossible: true),
          trumpBroken: true,
        ),
        unorderedEquals(hand),
      );
    });
  });

  group('void in the lead suit', () {
    test('compulsory trump restricts a void seat to its trumps', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.spades, Rank.four),
            card(Suit.clubs, Rank.ace),
          ],
          trick: leadWith(Suit.hearts, Rank.five),
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: true,
        ),
        <PlayingCard>[card(Suit.spades, Rank.four)],
      );
    });

    test('without compulsory trump a void seat may discard freely', () {
      // The flag off, not a shipped preset: every preset now has trumping
      // compulsory, Koz Maca included. The flag still has to work, because
      // the tables that play it the other way are a setting away.
      const TrickRules optional = TrickRules(mustPlayTrumpWhenVoid: false);
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.spades, Rank.four),
        card(Suit.clubs, Rank.ace),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: leadWith(Suit.hearts, Rank.five),
          trump: Suit.spades,
          rules: optional,
          trumpBroken: true,
        ),
        unorderedEquals(hand),
      );
    });

    test('Koz Maca makes cutting compulsory', () {
      // The bug this covers: a seat void in the lead suit was offered a
      // discard while holding a spade.
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.spades, Rank.four),
            card(Suit.clubs, Rank.ace),
          ],
          trick: leadWith(Suit.hearts, Rank.five),
          trump: Suit.spades,
          rules: TrickRules.kozMaca,
          trumpBroken: true,
        ),
        <PlayingCard>[card(Suit.spades, Rank.four)],
      );
    });

    test('a void seat holding no trump may discard anything', () {
      final List<PlayingCard> hand = <PlayingCard>[
        card(Suit.clubs, Rank.ace),
        card(Suit.diamonds, Rank.two),
      ];
      expect(
        TrickLegalMoves.forHand(
          hand: hand,
          trick: leadWith(Suit.hearts, Rank.five),
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: true,
        ),
        unorderedEquals(hand),
      );
    });
  });

  group('overtrumping', () {
    Trick trumpedTrick() => Trick(
          leadSeat: 0,
          expectedPlays: 4,
          plays: <PlayedCard>[
            PlayedCard(seat: 0, card: card(Suit.hearts, Rank.five)),
            PlayedCard(seat: 1, card: card(Suit.spades, Rank.nine)),
          ],
        );

    test('compulsory overtrump restricts to higher trumps', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.spades, Rank.four),
            card(Suit.spades, Rank.king),
            card(Suit.clubs, Rank.ace),
          ],
          trick: trumpedTrick(),
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: true,
        ),
        <PlayingCard>[card(Suit.spades, Rank.king)],
      );
    });

    test('a seat that cannot overtrump may still play a low trump', () {
      expect(
        TrickLegalMoves.forHand(
          hand: <PlayingCard>[
            card(Suit.spades, Rank.four),
            card(Suit.clubs, Rank.ace),
          ],
          trick: trumpedTrick(),
          trump: Suit.spades,
          rules: TrickRules.batakStandard,
          trumpBroken: true,
        ),
        <PlayingCard>[card(Suit.spades, Rank.four)],
      );
    });
  });

  test('an empty hand yields no legal moves', () {
    expect(
      TrickLegalMoves.forHand(
        hand: const <PlayingCard>[],
        trick: null,
        trump: Suit.spades,
        rules: TrickRules.batakStandard,
        trumpBroken: false,
      ),
      isEmpty,
    );
  });
}
