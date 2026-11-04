import 'package:meta/meta.dart';

/// A hand in which one side took every trick.
enum TeamSweep {
  /// Nothing special happened; the hand is scored the ordinary way.
  none,

  /// KING: the declaring team bid the whole hand and took the whole hand.
  king,

  /// 13 asagi / 13 yukari: a side took every trick without having bid them
  /// all. Either side can do it -- the defenders shutting out a contract of
  /// nine is the same result from the other direction.
  sweep,
}

/// What one completed partnership hand pays each team.
///
/// Produced by [PartnershipScoringRules.score] rather than assembled by the
/// caller, so the special results and the ordinary ones cannot be applied
/// twice -- which is the one real trap in this payoff and the reason the
/// decision order lives in a single method.
@immutable
final class TeamHandOutcome {
  TeamHandOutcome({
    required List<int> teamPoints,
    required this.sweep,
    required this.declarerMade,
    this.instantWinnerTeam,
  }) : teamPoints = List<int>.unmodifiable(teamPoints);

  /// Points scored, indexed by team id.
  final List<int> teamPoints;

  /// Whether this hand was a KING or a sweep.
  final TeamSweep sweep;

  /// Whether the declaring team reached its contract.
  ///
  /// False for a sweep by the defenders, true for a KING. Read from the
  /// trick count rather than from the sign of the points, because a sweep
  /// pays the same figure whatever the contract was.
  final bool declarerMade;

  /// A team that wins the match outright on this hand, whatever the
  /// scoreboard said before it.
  final int? instantWinnerTeam;

  @override
  String toString() => 'TeamHandOutcome($teamPoints, ${sweep.name}, '
      'made: $declarerMade, instant: $instantWinnerTeam)';
}

/// Esli Ihaleli Batak's payoff: two teams, one contract.
///
/// Deliberately **not** [AuctionScoringRules]. That pays one declarer against
/// three independent defenders and charges a defender that takes no tricks;
/// this pays two sides, and the floor a defending side has to clear is a
/// *team* floor -- two tricks between the partners, not two each. Sharing a
/// scorer between the two is exactly how a rule from one would leak into the
/// other.
///
/// ### The default payoff, as the table plays it
///
/// A declaring team that reaches its contract scores every trick it took, so
/// a bid of eight taking nine writes nine and extras are never punished. A
/// declaring team that falls short loses the contract's value whole, however
/// near the miss was. The defending side is paid its tricks once it has at
/// least [defenderMinimumTricks] of them, and is charged the contract's value
/// if it does not -- which is what stops a side quietly conceding a large
/// contract.
///
/// Both sides can go down in the same hand, but only in one position: a
/// contract of thirteen that takes twelve leaves the defence exactly one
/// trick, short of its own floor. It is a real result rather than an
/// inconsistency, so it is scored rather than rejected.
@immutable
class PartnershipScoringRules {
  const PartnershipScoringRules({
    this.enabled = false,
    this.pointsPerTrick = 1,
    this.defenderMinimumTricks = 2,
    this.kingEnabled = true,
    this.kingEndsMatch = true,
    this.sweepEnabled = true,
    this.sweepEndsMatch = false,
  });

  /// The mode pays some other way.
  static const PartnershipScoringRules none = PartnershipScoringRules();

  /// Klasik tam sayi, the default: a trick is a point.
  static const PartnershipScoringRules classic =
      PartnershipScoringRules(enabled: true);

  /// The same shape with everything times ten, for tables that keep score in
  /// points rather than in tricks.
  static const PartnershipScoringRules tenBased = PartnershipScoringRules(
    enabled: true,
    pointsPerTrick: 10,
  );

  /// Whether a hand is scored as one contract between two teams.
  final bool enabled;

  /// What one trick is worth. The whole payoff scales with it, KING included,
  /// because a ten-based table is the same game with a bigger pencil.
  final int pointsPerTrick;

  /// Tricks the defending team must take between them to avoid going down.
  final int defenderMinimumTricks;

  /// Whether bidding the whole hand and taking it is a KING.
  final bool kingEnabled;

  /// Whether a KING ends the match there and then, whatever the totals were.
  final bool kingEndsMatch;

  /// Whether taking every trick without having bid them all pays the same
  /// figure (13 asagi / 13 yukari).
  final bool sweepEnabled;

  /// Whether a sweep also ends the match. Off by default: tables award the
  /// points but keep playing.
  final bool sweepEndsMatch;

  /// What a made contract of [bid] taking [tricks] pays, before any special
  /// result. Exposed so the bidding AI values a contract with the same
  /// arithmetic that pays it.
  int declarerScore({required int bid, required int tricks}) =>
      tricks >= bid ? tricks * pointsPerTrick : -bid * pointsPerTrick;

  /// What a defending team taking [tricks] against [bid] is paid.
  int defenderScore({required int bid, required int tricks}) =>
      tricks >= defenderMinimumTricks
          ? tricks * pointsPerTrick
          : -bid * pointsPerTrick;

  /// Scores one finished hand.
  ///
  /// [teamTricks] is indexed by team id and must account for every trick in
  /// the hand; [tricksPerHand] is what "every trick" means, so a reduced-deck
  /// variant needs no special case here. A partial hand is refused, because a
  /// score that could still change is not a score -- use [project] for that.
  TeamHandOutcome score({
    required int contractBid,
    required int declarerTeam,
    required List<int> teamTricks,
    required int tricksPerHand,
  }) {
    final int total = teamTricks.fold(0, (int a, int b) => a + b);
    if (total != tricksPerHand) {
      throw StateError(
        'Team tricks $teamTricks sum to $total, not $tricksPerHand',
      );
    }
    return project(
      contractBid: contractBid,
      declarerTeam: declarerTeam,
      teamTricks: teamTricks,
      tricksPerHand: tricksPerHand,
    );
  }

  /// What the hand pays on the tricks taken **so far**.
  ///
  /// The same arithmetic as [score] without the finished-hand requirement, so
  /// a policy can ask what it is currently being paid. The special results
  /// only fire when a side genuinely holds every trick of the hand, which is
  /// why a partial count cannot read as a sweep.
  ///
  /// The decision order is the point of this method, and it is the order the
  /// table uses:
  ///
  /// 1. KING -- the whole hand bid and the whole hand taken;
  /// 2. a sweep by either side;
  /// 3. the ordinary contract test;
  /// 4. the defending team's floor.
  ///
  /// A hand that resolved at step 1 or 2 is never scored again at step 3,
  /// which is the mistake this shape exists to make impossible.
  TeamHandOutcome project({
    required int contractBid,
    required int declarerTeam,
    required List<int> teamTricks,
    required int tricksPerHand,
  }) {
    if (!enabled) {
      throw StateError('Partnership scoring is off but a hand asked for it');
    }
    if (teamTricks.length != 2) {
      throw ArgumentError.value(
        teamTricks,
        'teamTricks',
        'a partnership hand has exactly two teams',
      );
    }
    if (declarerTeam != 0 && declarerTeam != 1) {
      throw ArgumentError.value(declarerTeam, 'declarerTeam');
    }

    final int defendingTeam = 1 - declarerTeam;
    final int declarerTricks = teamTricks[declarerTeam];
    final int defenderTricks = teamTricks[defendingTeam];
    final int whole = tricksPerHand * pointsPerTrick;

    if (kingEnabled &&
        contractBid == tricksPerHand &&
        declarerTricks == tricksPerHand) {
      return _sweepOutcome(
        winner: declarerTeam,
        whole: whole,
        sweep: TeamSweep.king,
        declarerMade: true,
        endsMatch: kingEndsMatch,
      );
    }
    if (sweepEnabled && declarerTricks == tricksPerHand) {
      return _sweepOutcome(
        winner: declarerTeam,
        whole: whole,
        sweep: TeamSweep.sweep,
        declarerMade: true,
        endsMatch: sweepEndsMatch,
      );
    }
    if (sweepEnabled && defenderTricks == tricksPerHand) {
      return _sweepOutcome(
        winner: defendingTeam,
        whole: whole,
        sweep: TeamSweep.sweep,
        declarerMade: false,
        endsMatch: sweepEndsMatch,
      );
    }

    final List<int> points = List<int>.filled(2, 0);
    points[declarerTeam] =
        declarerScore(bid: contractBid, tricks: declarerTricks);
    points[defendingTeam] =
        defenderScore(bid: contractBid, tricks: defenderTricks);
    return TeamHandOutcome(
      teamPoints: points,
      sweep: TeamSweep.none,
      declarerMade: declarerTricks >= contractBid,
    );
  }

  TeamHandOutcome _sweepOutcome({
    required int winner,
    required int whole,
    required TeamSweep sweep,
    required bool declarerMade,
    required bool endsMatch,
  }) {
    final List<int> points = List<int>.filled(2, 0);
    points[winner] = whole;
    points[1 - winner] = -whole;
    return TeamHandOutcome(
      teamPoints: points,
      sweep: sweep,
      declarerMade: declarerMade,
      instantWinnerTeam: endsMatch ? winner : null,
    );
  }

  PartnershipScoringRules copyWith({
    bool? enabled,
    int? pointsPerTrick,
    int? defenderMinimumTricks,
    bool? kingEnabled,
    bool? kingEndsMatch,
    bool? sweepEnabled,
    bool? sweepEndsMatch,
  }) =>
      PartnershipScoringRules(
        enabled: enabled ?? this.enabled,
        pointsPerTrick: pointsPerTrick ?? this.pointsPerTrick,
        defenderMinimumTricks:
            defenderMinimumTricks ?? this.defenderMinimumTricks,
        kingEnabled: kingEnabled ?? this.kingEnabled,
        kingEndsMatch: kingEndsMatch ?? this.kingEndsMatch,
        sweepEnabled: sweepEnabled ?? this.sweepEnabled,
        sweepEndsMatch: sweepEndsMatch ?? this.sweepEndsMatch,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'pointsPerTrick': pointsPerTrick,
        'defenderMinimumTricks': defenderMinimumTricks,
        'kingEnabled': kingEnabled,
        'kingEndsMatch': kingEndsMatch,
        'sweepEnabled': sweepEnabled,
        'sweepEndsMatch': sweepEndsMatch,
      };

  static PartnershipScoringRules fromJson(Map<String, Object?> json) =>
      PartnershipScoringRules(
        enabled: json['enabled'] as bool? ?? false,
        pointsPerTrick: json['pointsPerTrick'] as int? ?? 1,
        defenderMinimumTricks: json['defenderMinimumTricks'] as int? ?? 2,
        kingEnabled: json['kingEnabled'] as bool? ?? true,
        kingEndsMatch: json['kingEndsMatch'] as bool? ?? true,
        sweepEnabled: json['sweepEnabled'] as bool? ?? true,
        sweepEndsMatch: json['sweepEndsMatch'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is PartnershipScoringRules &&
      other.enabled == enabled &&
      other.pointsPerTrick == pointsPerTrick &&
      other.defenderMinimumTricks == defenderMinimumTricks &&
      other.kingEnabled == kingEnabled &&
      other.kingEndsMatch == kingEndsMatch &&
      other.sweepEnabled == sweepEnabled &&
      other.sweepEndsMatch == sweepEndsMatch;

  @override
  int get hashCode => Object.hash(
        enabled,
        pointsPerTrick,
        defenderMinimumTricks,
        kingEnabled,
        kingEndsMatch,
        sweepEnabled,
        sweepEndsMatch,
      );
}
