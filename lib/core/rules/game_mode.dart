/// The five supported games.
///
/// The enum id is persisted in save files and benchmark reports, so the
/// identifiers are stable even if the Turkish labels are reworded.
enum GameMode {
  /// Herkes Tek Ihaleli Batak: four players, each for themselves, auction for
  /// the contract, declarer names trump.
  auctionBatak(
    id: 'auction_batak',
    turkishName: 'Herkes Tek Ihaleli Batak',
    turkishShortName: 'Tek Ihaleli',
    turkishTagline: 'Dort oyuncu, herkes kendi icin, ihaleli',
    playerCount: 4,
    hasPartnerships: false,
    hasAuction: true,
  ),

  /// Esli Ihaleli Batak: four players in two fixed partnerships.
  partnershipBatak(
    id: 'partnership_batak',
    turkishName: 'Esli Ihaleli Batak',
    turkishShortName: 'Esli Batak',
    turkishTagline: 'Karsi karsiya esler, ortak ihale',
    playerCount: 4,
    hasPartnerships: true,
    hasAuction: true,
  ),

  /// Koz Maca: spades are permanently trump, no auction for trump.
  spadesBatak(
    id: 'spades_batak',
    turkishName: 'Koz Maca',
    turkishShortName: 'Koz Maca',
    turkishTagline: 'Koz her zaman maca',
    playerCount: 4,
    hasPartnerships: false,
    hasAuction: false,
  ),

  /// Uclu Gommeli Batak: three players, the declarer buries cards face down.
  buriedBatak(
    id: 'buried_batak',
    turkishName: 'Uclu Gommeli Batak',
    turkishShortName: 'Gommeli',
    turkishTagline: 'Uc oyuncu, ihaleyi alan gomer',
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

  /// Whether this mode's full lifecycle is implemented and playable.
  ///
  /// Milestone 1 ships the shared trick core only; no mode has its auction,
  /// contract or scoring lifecycle yet, so this is false everywhere. The home
  /// screen reads this flag to label modes honestly rather than opening a
  /// table that cannot be played.
  bool get isPlayable => false;

  /// Looks up a mode by its persisted [id].
  static GameMode fromId(String id) => values.firstWhere(
        (GameMode mode) => mode.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown game mode'),
      );
}
