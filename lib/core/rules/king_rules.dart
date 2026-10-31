import 'package:meta/meta.dart';

/// The contracts a King hand can be played under.
///
/// Scoring values are NOT baked into this enum: they live in
/// [KingContractRule] because tables disagree about them and because some
/// variants omit contracts entirely. The enum only says what each contract
/// measures.
enum KingContract {
  /// Koz: trump hand, taking tricks scores positively.
  trumpTricks(
    id: 'koz',
    turkishName: 'Koz',
    isPenalty: false,
    unitDescription: 'alınan her el',
  ),

  /// El Almaz: avoid taking tricks.
  noTricks(
    id: 'el_almaz',
    turkishName: 'El Almaz',
    isPenalty: true,
    unitDescription: 'alınan her el',
  ),

  /// Kiz Almaz: avoid the four queens.
  queens(
    id: 'kiz_almaz',
    turkishName: 'Kız Almaz',
    isPenalty: true,
    unitDescription: 'alınan her kız',
  ),

  /// Erkek Almaz: avoid the jacks and kings.
  jacksAndKings(
    id: 'erkek_almaz',
    turkishName: 'Erkek Almaz',
    isPenalty: true,
    unitDescription: 'alınan her vale ve papaz',
  ),

  /// Rifki: avoid the king of hearts.
  heartsKing(
    id: 'rifki',
    turkishName: 'Rıfkı',
    isPenalty: true,
    unitDescription: 'kupa papazı',
  ),

  /// Son Iki: avoid the last two tricks.
  lastTwoTricks(
    id: 'son_iki',
    turkishName: 'Son İki',
    isPenalty: true,
    unitDescription: 'son iki elden her biri',
  );

  const KingContract({
    required this.id,
    required this.turkishName,
    required this.isPenalty,
    required this.unitDescription,
  });

  /// Stable persistence identifier.
  final String id;

  /// Turkish display name.
  final String turkishName;

  /// Whether the contract is scored negatively (avoid) rather than positively.
  final bool isPenalty;

  /// Turkish description of what one scoring unit is.
  final String unitDescription;

  /// Whether the hand is played without a trump suit.
  ///
  /// Every penalty contract is a no-trump hand; only Koz has a trump.
  bool get isNoTrump => isPenalty;

  static KingContract fromId(String id) => values.firstWhere(
        (KingContract c) => c.id == id,
        orElse: () =>
            throw ArgumentError.value(id, 'id', 'unknown King contract'),
      );
}

/// One contract as configured for a specific King profile.
@immutable
class KingContractRule {
  const KingContractRule({
    required this.contract,
    required this.pointsPerUnit,
    required this.quotaPerPlayer,
  });

  final KingContract contract;

  /// Points scored per unit. Negative for penalty contracts.
  final int pointsPerUnit;

  /// How many times each player must declare this contract during the match.
  /// Zero removes the contract from the profile entirely.
  final int quotaPerPlayer;

  Map<String, Object?> toJson() => <String, Object?>{
        'contract': contract.id,
        'pointsPerUnit': pointsPerUnit,
        'quotaPerPlayer': quotaPerPlayer,
      };

  static KingContractRule fromJson(Map<String, Object?> json) =>
      KingContractRule(
        contract: KingContract.fromId(json['contract']! as String),
        pointsPerUnit: json['pointsPerUnit']! as int,
        quotaPerPlayer: json['quotaPerPlayer']! as int,
      );

  @override
  bool operator ==(Object other) =>
      other is KingContractRule &&
      other.contract == contract &&
      other.pointsPerUnit == pointsPerUnit &&
      other.quotaPerPlayer == quotaPerPlayer;

  @override
  int get hashCode => Object.hash(contract, pointsPerUnit, quotaPerPlayer);

  @override
  String toString() =>
      'KingContractRule(${contract.id}, $pointsPerUnit x$quotaPerPlayer)';
}

/// A complete King configuration.
///
/// The match length is derived, not declared: it is the sum of every player's
/// quota. That is the only way to keep a profile internally consistent when
/// the contract set itself is configurable, and it is why this app does not
/// assume the familiar 20-hand table.
@immutable
class KingRules {
  KingRules({
    required List<KingContractRule> contracts,
    this.playerCount = 4,
  }) : contracts = List<KingContractRule>.unmodifiable(contracts);

  /// A widely played 20-hand Turkish table: each of the four players declares
  /// two Koz hands plus one each of El Almaz, Kiz Almaz and Erkek Almaz.
  ///
  /// The point values and the quota split are the most commonly reported ones
  /// but are not universal. Rifki and Son Iki are listed at zero quota so the
  /// settings UI can offer them without silently changing the match length.
  /// See docs/RULE_PROFILES.md, open question K-1.
  factory KingRules.classic20() => KingRules(
        contracts: const <KingContractRule>[
          KingContractRule(
            contract: KingContract.trumpTricks,
            pointsPerUnit: 50,
            quotaPerPlayer: 2,
          ),
          KingContractRule(
            contract: KingContract.noTricks,
            pointsPerUnit: -50,
            quotaPerPlayer: 1,
          ),
          KingContractRule(
            contract: KingContract.queens,
            pointsPerUnit: -100,
            quotaPerPlayer: 1,
          ),
          KingContractRule(
            contract: KingContract.jacksAndKings,
            pointsPerUnit: -60,
            quotaPerPlayer: 1,
          ),
          KingContractRule(
            contract: KingContract.heartsKing,
            pointsPerUnit: -320,
            quotaPerPlayer: 0,
          ),
          KingContractRule(
            contract: KingContract.lastTwoTricks,
            pointsPerUnit: -180,
            quotaPerPlayer: 0,
          ),
        ],
      );

  /// A short 8-hand profile: one Koz and one El Almaz each. Useful for tests
  /// and for players who do not want a long session.
  factory KingRules.short8() => KingRules(
        contracts: const <KingContractRule>[
          KingContractRule(
            contract: KingContract.trumpTricks,
            pointsPerUnit: 50,
            quotaPerPlayer: 1,
          ),
          KingContractRule(
            contract: KingContract.noTricks,
            pointsPerUnit: -50,
            quotaPerPlayer: 1,
          ),
        ],
      );

  final List<KingContractRule> contracts;
  final int playerCount;

  /// Contracts that are actually part of this profile.
  List<KingContractRule> get activeContracts =>
      List<KingContractRule>.unmodifiable(
        contracts.where((KingContractRule r) => r.quotaPerPlayer > 0),
      );

  /// Total hands in the match, derived from the quotas.
  int get totalHands =>
      playerCount *
      contracts.fold<int>(
        0,
        (int sum, KingContractRule r) => sum + r.quotaPerPlayer,
      );

  /// The configured rule for [contract], or null when it is not in the profile.
  KingContractRule? ruleFor(KingContract contract) {
    for (final KingContractRule rule in contracts) {
      if (rule.contract == contract) {
        return rule;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'playerCount': playerCount,
        'contracts': contracts
            .map((KingContractRule r) => r.toJson())
            .toList(growable: false),
      };

  static KingRules fromJson(Map<String, Object?> json) => KingRules(
        playerCount: json['playerCount'] as int? ?? 4,
        contracts: (json['contracts']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(KingContractRule.fromJson)
            .toList(growable: false),
      );

  @override
  bool operator ==(Object other) {
    if (other is! KingRules || other.playerCount != playerCount) {
      return false;
    }
    if (other.contracts.length != contracts.length) {
      return false;
    }
    for (int i = 0; i < contracts.length; i++) {
      if (other.contracts[i] != contracts[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(playerCount, Object.hashAll(contracts));
}
