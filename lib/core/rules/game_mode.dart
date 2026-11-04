/// The five supported games.
///
/// The enum id is persisted in save files and benchmark reports, so the
/// identifiers are stable even if the Turkish labels are reworded.
enum GameMode {
  /// Herkes Tek Ihaleli Batak: four players, each for themselves, auction for
  /// the contract, declarer names trump.
  auctionBatak(
    id: 'auction_batak',
    turkishName: 'Herkes Tek İhaleli Batak',
    turkishShortName: 'Tek İhaleli',
    turkishTagline: 'Dört oyuncu, herkes kendi için, ihaleli',
    playerCount: 4,
    hasPartnerships: false,
    hasAuction: true,
  ),

  /// Esli Ihaleli Batak: four players in two fixed partnerships.
  partnershipBatak(
    id: 'partnership_batak',
    turkishName: 'Eşli İhaleli Batak',
    turkishShortName: 'Eşli Batak',
    turkishTagline: 'Karşı karşıya eşler, ortak ihale',
    playerCount: 4,
    hasPartnerships: true,
    hasAuction: true,
  ),

  /// Koz Maca: spades are permanently trump, no auction for trump.
  spadesBatak(
    id: 'spades_batak',
    turkishName: 'Koz Maça',
    turkishShortName: 'Koz Maça',
    turkishTagline: 'Koz her zaman maça',
    playerCount: 4,
    hasPartnerships: false,
    hasAuction: false,
  ),

  /// Uclu Gommeli Batak: three players, the declarer buries cards face down.
  buriedBatak(
    id: 'buried_batak',
    turkishName: 'Üçlü Gömmeli Batak',
    turkishShortName: 'Gömmeli',
    turkishTagline: 'Üç oyuncu, ihaleyi alan gömer',
    playerCount: 3,
    hasPartnerships: false,
    hasAuction: true,
  ),

  /// King: a multi-contract game mixing penalty hands and trump hands.
  king(
    id: 'king',
    turkishName: 'King',
    turkishShortName: 'King',
    turkishTagline: 'Ceza ve koz elleri, uzun parti',
    playerCount: 4,
    hasPartnerships: false,
    hasAuction: false,
  );

  const GameMode({
    required this.id,
    required this.turkishName,
    required this.turkishShortName,
    required this.turkishTagline,
    required this.playerCount,
    required this.hasPartnerships,
    required this.hasAuction,
  });

  /// Stable persistence identifier.
  final String id;

  /// Full Turkish name, used in headings.
  final String turkishName;

  /// Short Turkish name, used where space is tight.
  final String turkishShortName;

  /// One-line Turkish description for the mode cards on the home screen.
  final String turkishTagline;

  /// Seats at the table.
  final int playerCount;

  /// Whether seats are grouped into fixed partnerships.
  final bool hasPartnerships;

  /// Whether the mode runs a trick auction before play.
  final bool hasAuction;

  /// Whether a mode can be played from the product today.
  ///
  /// Koz Maca, Herkes Tek Ihaleli Batak and Esli Ihaleli Batak have tables;
  /// the rest do not yet, and the menu shows them dimmed rather than letting
  /// a tap reach an engine that would refuse their profile.
  /// `MatchRuntime.start` is the other half of the same guarantee: it throws
  /// for a profile no table exists for, rather than falling back to another
  /// game's engine.
  bool get isPlayable =>
      this == GameMode.spadesBatak ||
      this == GameMode.auctionBatak ||
      this == GameMode.partnershipBatak;

  /// Looks up a mode by its persisted [id].
  static GameMode fromId(String id) => values.firstWhere(
        (GameMode mode) => mode.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown game mode'),
      );
}
