import 'package:batak_king/core/cards/deck.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('standard52', () {
    test('contains 52 cards', () {
      expect(Deck.standard52(), hasLength(52));
    });

    test('every card is unique', () {
      final List<PlayingCard> deck = Deck.standard52();
      expect(deck.toSet(), hasLength(52));
    });

    test('covers every suit and rank exactly once', () {
      final List<PlayingCard> deck = Deck.standard52();
      for (final Suit suit in Suit.values) {
        for (final Rank rank in Rank.values) {
          expect(
            deck.where((PlayingCard c) => c.suit == suit && c.rank == rank),
            hasLength(1),
            reason: 'missing or duplicated $rank of $suit',
          );
        }
      }
    });

    test('ids are dense and cover 0..51', () {
      final Set<int> ids =
          Deck.standard52().map((PlayingCard c) => c.id).toSet();
      expect(ids, hasLength(52));
      expect(ids.reduce((int a, int b) => a < b ? a : b), 0);
      expect(ids.reduce((int a, int b) => a > b ? a : b), 51);
    });

    test('fromId round-trips every card', () {
      for (final PlayingCard card in Deck.standard52()) {
        expect(PlayingCard.fromId(card.id), card);
      }
    });

    test('fromId rejects out-of-range ids', () {
      expect(() => PlayingCard.fromId(-1), throwsArgumentError);
      expect(() => PlayingCard.fromId(52), throwsArgumentError);
    });
  });

  group('shuffled', () {
    test('is a permutation of the full deck', () {
      final List<PlayingCard> shuffled = Deck.shuffled(seed: 7);
      expect(shuffled, hasLength(52));
      expect(shuffled.toSet(), equals(Deck.standard52().toSet()));
    });

    test('honours exclusions', () {
      const PlayingCard removed = PlayingCard(Suit.clubs, Rank.two);
      final List<PlayingCard> shuffled =
          Deck.shuffled(seed: 7, excluded: <PlayingCard>{removed});
      expect(shuffled, hasLength(51));
      expect(shuffled, isNot(contains(removed)));
    });

    test('is not left in canonical order', () {
      // Guards against a shuffle that silently does nothing.
      expect(Deck.shuffled(seed: 1), isNot(equals(Deck.standard52())));
    });
  });

  group('deal', () {
    test('splits into equal hands with the remainder left over', () {
      final Deal deal = Deck.shuffleAndDeal(
        seed: 3,
        handCount: 3,
        handSize: 17,
      );
      expect(deal.hands, hasLength(3));
      for (final List<PlayingCard> hand in deal.hands) {
        expect(hand, hasLength(17));
      }
      expect(deal.remaining, hasLength(1));
    });

    test('deals every card exactly once across hands and remainder', () {
      final Deal deal = Deck.shuffleAndDeal(
        seed: 3,
        handCount: 4,
        handSize: 13,
      );
      final List<PlayingCard> all = <PlayingCard>[
        for (final List<PlayingCard> hand in deal.hands) ...hand,
        ...deal.remaining,
      ];
      expect(all, hasLength(52));
      expect(all.toSet(), hasLength(52));
    });

    test('hands are unmodifiable', () {
      final Deal deal =
          Deck.shuffleAndDeal(seed: 1, handCount: 4, handSize: 13);
      expect(
        () => deal.hands.first.add(const PlayingCard(Suit.spades, Rank.ace)),
        throwsUnsupportedError,
      );
    });

    test('throws when the deck cannot satisfy the request', () {
      expect(
        () => Deck.deal(
          cards: Deck.standard52(),
          handCount: 4,
          handSize: 14,
        ),
        throwsArgumentError,
      );
    });
  });
}
