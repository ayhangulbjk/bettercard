import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/rank.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/trick/trick.dart';
import 'package:batak_king/core/game_engine/trick/trick_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Trick trickOf(List<(int, Suit, Rank)> plays, {int leadSeat = 0}) => Trick(
      leadSeat: leadSeat,
      expectedPlays: 4,
      plays: <PlayedCard>[
        for (final (int seat, Suit suit, Rank rank) in plays)
          PlayedCard(seat: seat, card: PlayingCard(suit, rank)),
      ],
    );

void main() {
  group('no trump in the trick', () {
    test('highest card of the lead suit wins', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.five),
        (1, Suit.hearts, Rank.king),
        (2, Suit.hearts, Rank.seven),
        (3, Suit.hearts, Rank.nine),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 1);
    });

    test('off-suit discards cannot win, however high', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.three),
        (1, Suit.diamonds, Rank.ace),
        (2, Suit.clubs, Rank.ace),
        (3, Suit.hearts, Rank.four),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 3);
    });
  });

  group('with trump', () {
    test('any trump beats the lead suit', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.ace),
        (1, Suit.spades, Rank.two),
        (2, Suit.hearts, Rank.king),
        (3, Suit.hearts, Rank.queen),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 1);
    });

    test('the highest trump wins when several are played', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.ace),
        (1, Suit.spades, Rank.five),
        (2, Suit.spades, Rank.jack),
        (3, Suit.spades, Rank.three),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 2);
    });

    test('a led trump is resolved as trump, not merely as the lead suit', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.spades, Rank.ten),
        (1, Suit.spades, Rank.ace),
        (2, Suit.hearts, Rank.ace),
        (3, Suit.clubs, Rank.ace),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 1);
    });
  });

  group('no-trump contracts', () {
    test('a null trump means only the lead suit can win', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.clubs, Rank.four),
        (1, Suit.spades, Rank.ace),
        (2, Suit.clubs, Rank.six),
        (3, Suit.hearts, Rank.ace),
      ]);
      expect(TrickResolver.winnerSeat(trick, trump: null), 2);
    });
  });

  group('edge cases', () {
    test('a lone card wins its own trick', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (2, Suit.diamonds, Rank.two),
      ], leadSeat: 2);
      expect(TrickResolver.winnerSeat(trick, trump: Suit.spades), 2);
    });

    test('an empty trick has no winner', () {
      final Trick empty = Trick.empty(leadSeat: 0, expectedPlays: 4);
      expect(
        () => TrickResolver.winnerSeat(empty, trump: Suit.spades),
        throwsStateError,
      );
    });

    test('the winning play reports the card as well as the seat', () {
      final Trick trick = trickOf(<(int, Suit, Rank)>[
        (0, Suit.hearts, Rank.two),
        (1, Suit.hearts, Rank.ace),
        (2, Suit.hearts, Rank.three),
        (3, Suit.hearts, Rank.four),
      ]);
      final PlayedCard winner =
          TrickResolver.winningPlay(trick, trump: Suit.clubs);
      expect(winner.seat, 1);
      expect(winner.card, const PlayingCard(Suit.hearts, Rank.ace));
    });
  });
}
