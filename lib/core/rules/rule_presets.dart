import '../cards/suit.dart';
import 'auction_scoring_rules.dart';
import 'bidding_rules.dart';
import 'bury_rules.dart';
import 'declaration_rules.dart';
import 'game_mode.dart';
import 'king_rules.dart';
import 'partnership_rules.dart';
import 'partnership_scoring_rules.dart';
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

  /// Açık Eşli İhaleli Batak, the default esli profile.
  ///
  /// Two fixed partnerships sitting opposite, one contract taken for a team,
  /// bids from 8 to 13 and a forced 7 if nobody wants the hand. Once the
  /// trump is named the declarer's partner lays its thirteen cards face up
  /// and the declarer plays both hands.
  ///
  /// Three things here are deliberately *not* Herkes Tek İhaleli's rules, and
  /// each one would be wrong if carried across:
  ///
  /// * trump may be led from the first trick, because drawing trumps opposite
  ///   an open hand is the plan rather than an exception;
  /// * the defending side's floor is two tricks **between the partners**, not
  ///   two each;
  /// * extras never sink a made contract, and there is no "yan batma" for an
  ///   individual seat.
  ///
  /// The match runs to 31 team points. `roundCount` is not the length but the
  /// backstop: a match that stays exactly level at the target plays another
  /// hand, and this is where that stops.
  static RuleProfile partnershipBatakOpen() => const RuleProfile(
        id: 'partnership_batak_open',
        turkishName: 'Eşli İhaleli Batak - Açık Eş',
        mode: GameMode.partnershipBatak,
        trickRules: TrickRules.partnershipBatak,
        biddingRules: BiddingRules.fourPlayerPartnership,
        scoringRules: BatakScoringRules(
          endCondition: MatchEndCondition.targetScore,
          targetScore: 31,
          roundCount: 30,
        ),
        partnershipRules: PartnershipRules.openDummy,
        partnershipScoringRules: PartnershipScoringRules.classic,
        buryRules: BuryRules.disabled,
      );

  /// Kapalı Eşli İhaleli Batak: the same game with four closed hands.
  ///
  /// Nobody's cards are shown, every seat plays its own, and the partners
  /// cooperate on the auction, the cards already played and the voids those
  /// prove. Same auction, same card rules, same payoff.
  static RuleProfile partnershipBatakClosed() => const RuleProfile(
        id: 'partnership_batak_closed',
        turkishName: 'Eşli İhaleli Batak - Kapalı Eş',
        mode: GameMode.partnershipBatak,
        trickRules: TrickRules.partnershipBatak,
        biddingRules: BiddingRules.fourPlayerPartnership,
        scoringRules: BatakScoringRules(
          endCondition: MatchEndCondition.targetScore,
          targetScore: 31,
          roundCount: 30,
        ),
        partnershipRules: PartnershipRules.closedPartnership,
        partnershipScoringRules: PartnershipScoringRules.classic,
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
        partnershipBatakOpen(),
        partnershipBatakClosed(),
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
