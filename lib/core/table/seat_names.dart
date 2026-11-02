import '../util/seeded_random.dart';

/// The names the opponents sit under.
///
/// "Oyuncu 2" is a seat number, not a person; a table reads as a table when
/// the other three chairs have names. They are drawn from the match seed
/// rather than the clock, so a saved match resumes with the same three people
/// at it and a replayed benchmark deal reproduces exactly. Nothing about a
/// name reaches a decision policy: this is display data, and the seat index
/// stays the identity everywhere else.
abstract final class SeatNames {
  /// Common Turkish first names, short enough for a seat badge.
  ///
  /// Kept deliberately plain and mixed, so the table does not read as one
  /// family or one generation. Length is what bounds the list: a name wider
  /// than roughly seven characters is ellipsised in a side seat.
  static const List<String> pool = <String>[
    'Ahmet',
    'Ayşe',
    'Burak',
    'Cem',
    'Defne',
    'Ebru',
    'Emre',
    'Esra',
    'Fatma',
    'Gökhan',
    'Hakan',
    'Hülya',
    'Kerem',
    'Levent',
    'Melis',
    'Merve',
    'Murat',
    'Nazlı',
    'Okan',
    'Pınar',
    'Selin',
    'Serkan',
    'Şebnem',
    'Tolga',
    'Tuna',
    'Yasemin',
    'Yusuf',
    'Zeynep',
  ];

  /// A name per seat, with [humanName] at [humanSeat].
  ///
  /// Distinct by construction: the pool is sampled without replacement, so no
  /// two chairs carry the same name. [seed] is the match seed, which is why
  /// the same match always shows the same table.
  static List<String> forMatch({
    required int seed,
    required int seatCount,
    required int humanSeat,
    required String humanName,
  }) {
    // Mixed into its own stream so that naming the table cannot shift the
    // deal or an opponent's choices, which draw on the same match seed.
    final SeededRandom random = SeededRandom(seed ^ 0x5EA71A3E);
    final List<String> remaining = List<String>.of(pool);
    return <String>[
      for (int seat = 0; seat < seatCount; seat++)
        if (seat == humanSeat)
          humanName
        else
          remaining.removeAt(random.nextInt(remaining.length)),
    ];
  }
}
