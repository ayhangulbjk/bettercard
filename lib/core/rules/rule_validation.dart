import 'package:meta/meta.dart';

import 'game_mode.dart';
import 'king_rules.dart';
import 'rule_profile.dart';

/// Severity of a rule-profile finding.
enum RuleIssueSeverity {
  /// The profile cannot be played; the UI must refuse to start a match.
  error,

  /// The profile is playable but unusual, or combines options that tables
  /// rarely combine. Worth surfacing, not worth blocking.
  warning,
}

/// One problem found in a rule profile.
@immutable
class RuleIssue {
  const RuleIssue({
    required this.severity,
    required this.code,
    required this.turkishMessage,
  });

  final RuleIssueSeverity severity;

  /// Stable machine code, for tests and for linking to documentation.
  final String code;

  /// Player-facing Turkish explanation.
  final String turkishMessage;

  bool get isError => severity == RuleIssueSeverity.error;

  @override
  String toString() => '[${severity.name}] $code: $turkishMessage';
}

/// Checks that a rule profile is internally consistent.
///
/// The product requirement is that only logically valid customisation
/// combinations are exposed. This validator is how that is enforced: the
/// settings UI runs it on every change and keeps the start button disabled
/// while any [RuleIssueSeverity.error] remains, and match setup refuses an
/// invalid profile. Keeping the checks here rather than in widget code means
/// the same verdict applies to a profile loaded from an old save file.
abstract final class RuleProfileValidator {
  /// Every issue found in [profile], errors first.
  static List<RuleIssue> validate(RuleProfile profile) {
    final List<RuleIssue> issues = <RuleIssue>[
      ..._validateDeck(profile),
      ..._validateBidding(profile),
      ..._validateBury(profile),
      ..._validateKing(profile),
      ..._validateScoring(profile),
    ];
    issues.sort((RuleIssue a, RuleIssue b) =>
        (a.isError ? 0 : 1).compareTo(b.isError ? 0 : 1));
    return List<RuleIssue>.unmodifiable(issues);
  }

  /// Whether [profile] may be used to start a match.
  static bool isPlayable(RuleProfile profile) =>
      !validate(profile).any((RuleIssue issue) => issue.isError);

  static List<RuleIssue> _validateDeck(RuleProfile profile) {
    final List<RuleIssue> issues = <RuleIssue>[];
    // The invariant is about *playable* cards, not the raw deck: a bury
    // profile deliberately starts from a deck that does not divide evenly and
    // resolves the surplus by burying it.
    if (profile.playableCardCount % profile.playerCount != 0) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'deck.not_divisible',
        turkishMessage: 'Oynanacak ${profile.playableCardCount} kart '
            '${profile.playerCount} oyuncuya esit dagitilamiyor.',
      ));
    }
    final int surplus =
        profile.deckSize - profile.playerCount * profile.tricksPerHand;
    if (surplus != profile.cardsSetAside) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'deck.surplus_mismatch',
        turkishMessage: 'Dagitimdan artan $surplus kart, gomulecek '
            '${profile.cardsSetAside} kart ile uyusmuyor.',
      ));
    }
    for (final int id in profile.deckExclusions) {
      if (id < 0 || id >= 52) {
        issues.add(RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'deck.bad_exclusion',
          turkishMessage: 'Gecersiz kart kimligi desteden cikarilmis: $id.',
        ));
      }
    }
    return issues;
  }

  static List<RuleIssue> _validateBidding(RuleProfile profile) {
    final List<RuleIssue> issues = <RuleIssue>[];
    final bool modeWantsAuction = profile.mode.hasAuction;
    final bool profileHasAuction = profile.biddingRules.hasAuction;

    if (modeWantsAuction != profileHasAuction) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.mode_mismatch',
        turkishMessage: modeWantsAuction
            ? '${profile.mode.turkishName} ihale gerektirir ama ihale kapali.'
            : '${profile.mode.turkishName} ihalesizdir ama ihale acik.',
      ));
    }
    if (!profileHasAuction) {
      return issues;
    }
    if (profile.biddingRules.minimumBid > profile.biddingRules.maximumBid) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.inverted_range',
        turkishMessage: 'En kucuk ihale en buyuk ihaleden buyuk olamaz.',
      ));
    }
    if (profile.biddingRules.maximumBid > profile.tricksPerHand) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.max_above_tricks',
        turkishMessage:
            'En buyuk ihale (${profile.biddingRules.maximumBid}) eldeki el '
            'sayisindan (${profile.tricksPerHand}) fazla olamaz.',
      ));
    }
    // Note: a minimum bid below half the tricks is NOT flagged. Standard
    // four-player Batak opens at 5 of 13, which is below half, and only one
    // seat wins an auction anyway -- so "the floor is not a majority" is not
    // an inconsistency. Only a floor that cannot be bid at all is.
    if (profile.biddingRules.minimumBid < 1) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.min_below_one',
        turkishMessage: 'En kucuk ihale en az 1 el olmalidir.',
      ));
    }
    if (!profile.biddingRules.declarerNamesTrump &&
        profile.fixedTrump == null) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.no_trump_source',
        turkishMessage:
            'Koz ne ihaleyi alan tarafindan secilir ne de kurallarda sabittir.',
      ));
    }
    return issues;
  }

  static List<RuleIssue> _validateBury(RuleProfile profile) {
    final List<RuleIssue> issues = <RuleIssue>[];
    if (!profile.buryRules.enabled) {
      if (profile.mode == GameMode.buriedBatak) {
        issues.add(const RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'bury.required_for_mode',
          turkishMessage: 'Gommeli Batak gomme kurallari olmadan oynanamaz.',
        ));
      }
      return issues;
    }
    if (profile.buryRules.cardsToBury !=
        profile.buryRules.cardsDealtToDeclarer) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bury.count_mismatch',
        turkishMessage:
            'Ihaleyi alana verilen fazla kart sayisi gomulecek kart sayisina '
            'esit olmalidir, yoksa eller farkli buyuklukte kalir.',
      ));
    }
    if (profile.buryRules.cardsToBury <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bury.zero_cards',
        turkishMessage: 'Gomme acik ama gomulecek kart sayisi sifir.',
      ));
    }
    return issues;
  }

  static List<RuleIssue> _validateKing(RuleProfile profile) {
    final KingRules? configured = profile.kingRules;
    if (profile.mode != GameMode.king) {
      return configured == null
          ? const <RuleIssue>[]
          : const <RuleIssue>[
              RuleIssue(
                severity: RuleIssueSeverity.warning,
                code: 'king.rules_ignored',
                turkishMessage:
                    'King sozlesme ayarlari bu oyun modunda yok sayilacak.',
              ),
            ];
    }
    if (configured == null) {
      return const <RuleIssue>[
        RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'king.missing_rules',
          turkishMessage: 'King profili sozlesme ayarlari icermiyor.',
        ),
      ];
    }

    final KingRules king = configured;
    final List<RuleIssue> issues = <RuleIssue>[];
    if (king.activeContracts.isEmpty) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'king.no_active_contracts',
        turkishMessage:
            'En az bir sozlesmenin kotasi sifirdan buyuk olmalidir.',
      ));
    }
    if (king.playerCount != profile.playerCount) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'king.player_count_mismatch',
        turkishMessage:
            'King oyuncu sayisi (${king.playerCount}) mod oyuncu sayisiyla '
            '(${profile.playerCount}) uyusmuyor.',
      ));
    }
    for (final KingContractRule rule in king.contracts) {
      if (rule.quotaPerPlayer < 0) {
        issues.add(RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'king.negative_quota',
          turkishMessage:
              '${rule.contract.turkishName} icin kota negatif olamaz.',
        ));
      }
      if (rule.quotaPerPlayer <= 0) {
        continue;
      }
      final bool signWrong = rule.contract.isPenalty
          ? rule.pointsPerUnit >= 0
          : rule.pointsPerUnit <= 0;
      if (signWrong) {
        issues.add(RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'king.points_sign',
          turkishMessage: rule.contract.isPenalty
              ? '${rule.contract.turkishName} bir ceza sozlesmesidir; puani '
                  'negatif olmalidir.'
              : '${rule.contract.turkishName} puan kazandirir; puani pozitif '
                  'olmalidir.',
        ));
      }
    }
    if (king.totalHands <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'king.zero_hands',
        turkishMessage: 'Kotalardan hesaplanan el sayisi sifir.',
      ));
    }
    return issues;
  }

  static List<RuleIssue> _validateScoring(RuleProfile profile) {
    final List<RuleIssue> issues = <RuleIssue>[];
    if (profile.scoringRules.pointsPerTrickForOthers < 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'scoring.negative_trick_points',
        turkishMessage: 'El basina puan negatif olamaz.',
      ));
    }
    if (profile.scoringRules.roundCount <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'scoring.non_positive_rounds',
        turkishMessage: 'Parti el sayisi pozitif olmalidir.',
      ));
    }
    if (profile.scoringRules.targetScore <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'scoring.non_positive_target',
        turkishMessage: 'Hedef puan pozitif olmalidir.',
      ));
    }
    return issues;
  }
}
