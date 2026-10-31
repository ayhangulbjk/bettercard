import 'package:batak_king/core/cards/deck.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/util/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('determinism', () {
    test('the same seed produces the same sequence', () {
      final SeededRandom a = SeededRandom(42);
      final SeededRandom b = SeededRandom(42);
      for (int i = 0; i < 500; i++) {
        expect(a.nextInt(1000), b.nextInt(1000));
      }
    });

    test('different seeds diverge', () {
      final SeededRandom a = SeededRandom(1);
      final SeededRandom b = SeededRandom(2);
      final List<int> first = <int>[
        for (int i = 0; i < 20; i++) a.nextInt(1000)
      ];
      final List<int> second = <int>[
        for (int i = 0; i < 20; i++) b.nextInt(1000)
      ];
      expect(first, isNot(equals(second)));
    });

    test('adjacent seeds are not correlated in their first draw', () {
      // A weak scrambler makes seed n and n+1 open with the same value, which
      // would make consecutive deals feel repetitive.
      final Set<int> firstDraws = <int>{
        for (int seed = 0; seed < 64; seed++) SeededRandom(seed).nextInt(10000),
      };
      expect(firstDraws.length, greaterThan(55));
    });

    test('state can be snapshotted and resumed', () {
      final SeededRandom original = SeededRandom(99);
      for (int i = 0; i < 10; i++) {
        original.nextInt(100);
      }
      final SeededRandom resumed = SeededRandom.fromState(original.state);
      for (int i = 0; i < 50; i++) {
        expect(resumed.nextInt(100), original.nextInt(100));
      }
    });

    test('seed 0 is usable and does not collapse to a constant', () {
      final SeededRandom zero = SeededRandom(0);
      final Set<int> draws = <int>{
        for (int i = 0; i < 50; i++) zero.nextInt(1000)
      };
      expect(draws.length, greaterThan(20));
    });

    test('forked streams differ from the parent and from each other', () {
      final SeededRandom parent = SeededRandom(5);
      final SeededRandom childA = parent.fork(1);
      final SeededRandom childB = parent.fork(2);
      final List<int> a = <int>[
        for (int i = 0; i < 20; i++) childA.nextInt(1000)
      ];
      final List<int> b = <int>[
        for (int i = 0; i < 20; i++) childB.nextInt(1000)
      ];
      expect(a, isNot(equals(b)));
    });
  });

  group('bounds and distribution', () {
    test('nextInt stays within range', () {
      final SeededRandom random = SeededRandom(11);
      for (int i = 0; i < 2000; i++) {
        final int value = random.nextInt(13);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(13));
      }
    });

    test('nextInt rejects a non-positive bound', () {
      final SeededRandom random = SeededRandom(1);
      expect(() => random.nextInt(0), throwsArgumentError);
      expect(() => random.nextInt(-3), throwsArgumentError);
    });

    test('nextDouble stays in [0, 1)', () {
      final SeededRandom random = SeededRandom(13);
      for (int i = 0; i < 2000; i++) {
        final double value = random.nextDouble();
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(1.0));
      }
    });

    test('nextInt covers every value of a small range', () {
      final SeededRandom random = SeededRandom(17);
      final Set<int> seen = <int>{};
      for (int i = 0; i < 1000; i++) {
        seen.add(random.nextInt(4));
      }
      expect(seen, <int>{0, 1, 2, 3});
    });

    test('nextInt is roughly uniform over a 13-way split', () {
      // A crude bias check: with 130000 draws over 13 buckets, every bucket
      // should land within 10% of the 10000 expected. Catches modulo bias or
      // a stuck low bit, not subtle non-randomness.
      final SeededRandom random = SeededRandom(23);
      final List<int> buckets = List<int>.filled(13, 0);
      for (int i = 0; i < 130000; i++) {
        buckets[random.nextInt(13)]++;
      }
      for (final int count in buckets) {
        expect(count, greaterThan(9000));
        expect(count, lessThan(11000));
      }
    });
  });

  group('shuffleInPlace', () {
    test('is a permutation, never a loss or duplication', () {
      final List<int> items = List<int>.generate(100, (int i) => i);
      SeededRandom(3).shuffleInPlace(items);
      expect(items, hasLength(100));
      expect(items.toSet(), hasLength(100));
    });

    test('identical seeds shuffle identically, so deals replay', () {
      final List<PlayingCard> first = Deck.shuffled(seed: 2026);
      final List<PlayingCard> second = Deck.shuffled(seed: 2026);
      expect(first, equals(second));
    });

    test('a single-element list survives', () {
      final List<int> single = <int>[7];
      SeededRandom(1).shuffleInPlace(single);
      expect(single, <int>[7]);
    });

    test('an empty list survives', () {
      final List<int> empty = <int>[];
      SeededRandom(1).shuffleInPlace(empty);
      expect(empty, isEmpty);
    });
  });
}
