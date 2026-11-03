import 'package:meta/meta.dart';

import 'declaration_rules.dart';
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
      ..._validateDeclarations(profile),
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
            '${profile.playerCount} oyuncuya eşit dağıtılamıyor.',
      ));
    }
    final int surplus =
        profile.deckSize - profile.playerCount * profile.tricksPerHand;
    if (surplus != profile.cardsSetAside) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'deck.surplus_mismatch',
        turkishMessage: 'Dağıtımdan artan $surplus kart, gömülecek '
            '${profile.cardsSetAside} kart ile uyuşmuyor.',
      ));
    }
    for (final int id in profile.deckExclusions) {
      if (id < 0 || id >= 52) {
        issues.add(RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'deck.bad_exclusion',
          turkishMessage: 'Geçersiz kart kimliği desteden çıkarılmış: $id.',
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
            ? '${profile.mode.turkishName} ihale gerektirir ama ihale kapalı.'
            : '${profile.mode.turkishName} ihalesizdir ama ihale açık.',
      ));
    }
    if (!profileHasAuction) {
      return issues;
    }
    if (profile.biddingRules.minimumBid > profile.biddingRules.maximumBid) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.inverted_range',
        turkishMessage: 'En küçük ihale en büyük ihaleden büyük olamaz.',
      ));
    }
    if (profile.biddingRules.maximumBid > profile.tricksPerHand) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.max_above_tricks',
        turkishMessage:
            'En büyük ihale (${profile.biddingRules.maximumBid}) eldeki el '
            'sayısından (${profile.tricksPerHand}) fazla olamaz.',
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
        turkishMessage: 'En küçük ihale en az 1 el olmalıdır.',
      ));
    }
    if (!profile.biddingRules.declarerNamesTrump &&
        profile.fixedTrump == null) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bidding.no_trump_source',
        turkishMessage:
            'Koz ne ihaleyi alan tarafından seçilir ne de kurallarda sabittir.',
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
          turkishMessage: 'Gömmeli Batak gömme kuralları olmadan oynanamaz.',
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
            'İhaleyi alana verilen fazla kart sayısı gömülecek kart sayısına '
            'eşit olmalıdır, yoksa eller farklı büyüklükte kalır.',
      ));
    }
    if (profile.buryRules.cardsToBury <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'bury.zero_cards',
        turkishMessage: 'Gömme açık ama gömülecek kart sayısı sıfır.',
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
                    'King sözleşme ayarları bu oyun modunda yok sayılacak.',
              ),
            ];
    }
    if (configured == null) {
      return const <RuleIssue>[
        RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'king.missing_rules',
          turkishMessage: 'King profili sözleşme ayarları içermiyor.',
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
            'En az bir sözleşmenin kotası sıfırdan büyük olmalıdır.',
      ));
    }
    if (king.playerCount != profile.playerCount) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'king.player_count_mismatch',
        turkishMessage:
            'King oyuncu sayısı (${king.playerCount}) mod oyuncu sayısıyla '
            '(${profile.playerCount}) uyuşmuyor.',
      ));
    }
    for (final KingContractRule rule in king.contracts) {
      if (rule.quotaPerPlayer < 0) {
        issues.add(RuleIssue(
          severity: RuleIssueSeverity.error,
          code: 'king.negative_quota',
          turkishMessage:
              '${rule.contract.turkishName} için kota negatif olamaz.',
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
              ? '${rule.contract.turkishName} bir ceza sözleşmesidir; puanı '
                  'negatif olmalıdır.'
              : '${rule.contract.turkishName} puan kazandırır; puanı pozitif '
                  'olmalıdır.',
        ));
      }
    }
    if (king.totalHands <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'king.zero_hands',
        turkishMessage: 'Kotalardan hesaplanan el sayısı sıfır.',
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
        turkishMessage: 'El başına puan negatif olamaz.',
      ));
    }
    if (profile.scoringRules.roundCount <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'scoring.non_positive_rounds',
        turkishMessage: 'Parti el sayısı pozitif olmalıdır.',
      ));
    }
    if (profile.scoringRules.targetScore <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'scoring.non_positive_target',
        turkishMessage: 'Hedef puan pozitif olmalıdır.',
      ));
    }
    return issues;
  }

  static List<RuleIssue> _validateDeclarations(RuleProfile profile) {
    final DeclarationRules rules = profile.declarationRules;
    if (!rules.enabled) {
      return const <RuleIssue>[];
    }
    final List<RuleIssue> issues = <RuleIssue>[];
    if (rules.pointsPerDeclaredTrick <= 0) {
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'declaration.non_positive_stake',
        turkishMessage: 'Söz başına puan pozitif olmalıdır.',
      ));
    }
    final int? bust = rules.overtrickBustThreshold;
    if (bust != null && bust < 1) {
      // Zero would mean a hand that exactly makes its word is already down,
      // which is not a custom any table plays; it is a mis-set value.
      issues.add(const RuleIssue(
        severity: RuleIssueSeverity.error,
        code: 'declaration.bust_below_one',
        turkishMessage: 'Batıran yan sayısı en az 1 olmalıdır.',
      ));
    }
    if (bust != null && bust > profile.tricksPerHand) {
      issues.add(RuleIssue(
        severity: RuleIssueSeverity.warning,
        code: 'declaration.bust_unreachable',
        turkishMessage: 'Batıran yan sayısı ($bust) bir dağıtımdaki el '
            'sayısından (${profile.tricksPerHand}) büyük; hiç batılmaz.',
      ));
    }
    return issues;
  }
}
