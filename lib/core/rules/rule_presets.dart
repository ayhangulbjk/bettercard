import '../cards/suit.dart';
import 'auction_scoring_rules.dart';
import 'bidding_rules.dart';
import 'bury_rules.dart';
import 'declaration_rules.dart';
import 'game_mode.dart';
import 'king_rules.dart';
import 'rule_profile.dart';
import 'scoring_rules.dart';
import 'trick_rules.dart';

/// The rule profiles shipped with the app.
///
/// Each preset documents the custom it reproduces. Where Turkish tables
/// disagree, the disagreement is recorded in docs/RULE_PROFILES.md with an
/// open-question id rather than being resolved by invention: the preset picks
/// the most commonly reported reading and the setting stays adjustable.
abstract final class RulePresets {
  /// Herkes Tek İhaleli Batak, four players, 13 tricks, bids from 5.
  ///
  /// One contract against three defenders, scored on the classic ten-based
  /// table: `soz x 10` won or lost whole, one more for each overtrick, ten a
  /// trick for a defender, and the contract's value charged to a defender
  /// that takes none ("yan batma"). A passed-out hand sticks the seat that
  /// opened the auction with four.
  ///
  /// Koz Maca's "yan 3 batar" does not apply here and must never be carried
  /// across: a declarer three tricks over its contract is simply three
  /// points better off.
  static RuleProfile auctionBatakStandard() => const RuleProfile(
        id: 'auction_batak_standard',
        turkishName: 'Tek İhaleli Batak - Standart',
        mode: GameMode.auctionBatak,
        trickRules: TrickRules.batakStandard,
        biddingRules: BiddingRules.fourPlayerStandard,
        scoringRules: BatakScoringRules(roundCount: 9),
        auctionScoringRules: AuctionScoringRules.classicTenBased,
        buryRules: BuryRules.disabled,
      );

  /// The same game scored the Gamyun way: a made contract pays a premium and
  /// a shut-out defender pays a flat fifty.
  static RuleProfile auctionBatakGamyun() => const RuleProfile(
        id: 'auction_batak_gamyun',
        turkishName: 'Tek İhaleli Batak - Gamyun',
        mode: GameMode.auctionBatak,
        trickRules: TrickRules.batakStandard,
        biddingRules: BiddingRules.fourPlayerStandard,
        scoringRules: BatakScoringRules(roundCount: 9),
        auctionScoringRules: AuctionScoringRules.gamyun,
        buryRules: BuryRules.disabled,
      );

  /// El basina puan: the same game kept in tricks rather than points, with
  /// no penalty for a defender that takes none.
  static RuleProfile auctionBatakPerTrick() => const RuleProfile(
        id: 'auction_batak_per_trick',
        turkishName: 'Tek İhaleli Batak - El Başına',
        mode: GameMode.auctionBatak,
        trickRules: TrickRules.batakStandard,
        biddingRules: BiddingRules.fourPlayerStandard,
        scoringRules: BatakScoringRules(roundCount: 9),
        auctionScoringRules: AuctionScoringRules.perTrick,
        buryRules: BuryRules.disabled,
      );

  /// Eşli İhaleli Batak: same card play, partnership scoring.
  static RuleProfile partnershipBatakStandard() => const RuleProfile(
        id: 'partnership_batak_standard',
        turkishName: 'Eşli İhaleli Batak - Standart',
        mode: GameMode.partnershipBatak,
        trickRules: TrickRules.batakStandard,
        biddingRules: BiddingRules.fourPlayerStandard,
        scoringRules: BatakScoringRules(
          declarerSuccess: DeclarerSuccessScore.tricksTaken,
          pointsPerTrickForOthers: 1,
        ),
        buryRules: BuryRules.disabled,
      );

  /// Koz Maça: spades permanently trump, no auction, trump may not be led
  /// until broken, and every seat declares its own trick count before the
  /// first card.
  static RuleProfile kozMacaStandard() => const RuleProfile(
        id: 'spades_batak_standard',
        turkishName: 'Koz Maça - Standart',
        mode: GameMode.spadesBatak,
        trickRules: TrickRules.kozMaca,
        biddingRules: BiddingRules.none,
        scoringRules: BatakScoringRules(
          declarerSuccess: DeclarerSuccessScore.tricksTaken,
          pointsPerTrickForOthers: 1,
        ),
        buryRules: BuryRules.disabled,
        declarationRules: DeclarationRules.kozMacaStandard,
        fixedTrump: Suit.spades,
      );

  /// Üçlü Gömmeli Batak on the full 52-card deck: 17 cards each leaves one
  /// card over, the declarer takes it and buries one, so every seat plays 17
  /// tricks. The deck is deliberately not divisible by three; the surplus is
  /// what the bury resolves. See open question B-4 for the variants that
  /// instead strip a card or bury three.
  static RuleProfile buriedBatakStandard() => const RuleProfile(
        id: 'buried_batak_standard',
        turkishName: 'Üçlü Gömmeli Batak - Standart',
        mode: GameMode.buriedBatak,
        trickRules: TrickRules.batakStandard,
        biddingRules: BiddingRules.threePlayerBuried,
        scoringRules: BatakScoringRules(
          declarerSuccess: DeclarerSuccessScore.tricksTaken,
          pointsPerTrickForOthers: 1,
          roundCount: 6,
        ),
        buryRules: BuryRules.threePlayerSingle,
      );

  /// King, 20 hands, the commonly played contract quota.
  static RuleProfile kingClassic() => RuleProfile(
        id: 'king_classic_20',
        turkishName: 'King - Klasik 20 El',
        mode: GameMode.king,
        trickRules: TrickRules.noTrump,
        biddingRules: BiddingRules.none,
        scoringRules: const BatakScoringRules(
          pointsPerTrickForOthers: 0,
          roundCount: 20,
        ),
        buryRules: BuryRules.disabled,
        kingRules: KingRules.classic20(),
      );

  /// King, short 8-hand session.
  static RuleProfile kingShort() => RuleProfile(
        id: 'king_short_8',
        turkishName: 'King - Kisa 8 El',
        mode: GameMode.king,
        trickRules: TrickRules.noTrump,
        biddingRules: BiddingRules.none,
        scoringRules: const BatakScoringRules(
          pointsPerTrickForOthers: 0,
          roundCount: 8,
        ),
        buryRules: BuryRules.disabled,
        kingRules: KingRules.short8(),
      );

  /// Every preset, in menu order.
  static List<RuleProfile> all() => <RuleProfile>[
        auctionBatakStandard(),
        auctionBatakGamyun(),
        auctionBatakPerTrick(),
        partnershipBatakStandard(),
        kozMacaStandard(),
        buriedBatakStandard(),
        kingClassic(),
        kingShort(),
      ];

  /// Presets available for [mode].
  static List<RuleProfile> forMode(GameMode mode) => all()
      .where((RuleProfile profile) => profile.mode == mode)
      .toList(growable: false);

  /// The default preset for [mode].
  static RuleProfile defaultFor(GameMode mode) => forMode(mode).first;
}
