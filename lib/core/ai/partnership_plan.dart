import 'seat_observation.dart';

/// Where a partnership hand stands, from one side's point of view.
///
/// The arithmetic every team decision rests on, derived once instead of
/// re-derived inside each branch of a policy. Nothing here is a tactic: it is
/// the answer to "what does my side still have to do", which is the question
/// that decides whether a trick is worth taking at all.
///
/// Built from public information plus the observer's own hand. A defending
/// side's plan is the mirror of the declaring side's, which is why both come
/// out of the same object: the declarer needs `bid` tricks, the defenders
/// need `tricksPerHand - bid + 1` to break it, and both of those are read off
/// the same scoreboard.
final class TeamPlan {
  const TeamPlan._({
    required this.hasContract,
    required this.weDeclare,
    required this.contractBid,
    required this.ourTricks,
    required this.theirTricks,
    required this.tricksRemaining,
    required this.tricksPerHand,
    required this.defenderFloor,
  });

  /// Reads the plan out of [observation].
  ///
  /// A mode with no team contract produces a plan with [hasContract] false,
  /// in which the only sensible objective is tricks; policies check that
  /// rather than assuming a contract exists.
  factory TeamPlan.from(SeatObservation observation) {
    final bool hasContract = observation.match.hasTeamContract;
    final int myTeam = observation.myTeam;
    final int? declarerTeam = observation.match.declarerTeam;
    return TeamPlan._(
      hasContract: hasContract,
      weDeclare: hasContract && declarerTeam == myTeam,
      contractBid: observation.match.contractBid ?? 0,
      ourTricks: observation.teamTricksOf(myTeam),
      theirTricks: observation.teamTricksOf(1 - myTeam),
      tricksRemaining: observation.tricksRemaining,
      tricksPerHand: observation.tricksPerHand,
      defenderFloor:
          observation.match.partnershipScoringRules.defenderMinimumTricks,
    );
  }

  /// Whether this hand is one contract between two sides.
  final bool hasContract;

  /// Whether the observer's side holds the contract.
  final bool weDeclare;

  /// The contract, in tricks. Zero when there is none.
  final int contractBid;

  /// Tricks the observer's side has taken so far.
  final int ourTricks;

  /// Tricks the other side has taken so far.
  final int theirTricks;

  /// Tricks still to be decided, the one in progress included.
  final int tricksRemaining;

  /// Tricks in the whole deal.
  final int tricksPerHand;

  /// Tricks a defending side must take between them to avoid going down.
  final int defenderFloor;

  /// Tricks the defending side needs to break the contract.
  ///
  /// One more than the contract leaves them: hold the declarer to `bid - 1`
  /// and the hand is down.
  int get tricksToBreak => tricksPerHand - contractBid + 1;

  /// Tricks our side still has to win to reach its own objective.
  ///
  /// The contract when we hold it; enough to break it when we do not. Zero
  /// once the objective is met.
  int get outstanding {
    if (!hasContract) {
      return tricksRemaining;
    }
    final int target = weDeclare ? contractBid : tricksToBreak;
    final int short = target - ourTricks;
    return short > 0 ? short : 0;
  }

  /// Tricks our side still has to win to clear its *floor*.
  ///
  /// For a defending side that is the two tricks it is charged the contract
  /// for missing, which it has to clear even in a hand it cannot break.
  /// Meaningless for the declaring side, which has no floor below its
  /// contract, so it reports zero there.
  int get floorOutstanding {
    if (!hasContract || weDeclare) {
      return 0;
    }
    final int short = defenderFloor - ourTricks;
    return short > 0 ? short : 0;
  }

  /// Whether our objective is already secured and cannot be taken back.
  bool get objectiveMet => hasContract && outstanding == 0;

  /// Whether our objective can no longer be reached at all.
  ///
  /// Once it cannot, the hand is not over: a defending side that cannot break
  /// the contract still wants tricks, because tricks are what it is paid, and
  /// a declaring side that is going down still wants to lose by less --
  /// except that it does not, since a broken contract costs the same whatever
  /// the margin. That asymmetry is why this is a separate question from
  /// [objectiveMet] rather than its negation.
  bool get objectiveLost => hasContract && outstanding > tricksRemaining;

  /// Whether every trick so far has gone to our side.
  bool get sweepAlive => hasContract && theirTricks == 0;

  /// Whether every trick so far has gone to the other side.
  bool get sweepAgainstUs => hasContract && ourTricks == 0;

  /// Whether a trick still changes what this hand pays.
  ///
  /// Only false in one position, and it is a real one: a declaring side whose
  /// contract is already broken is paid minus the contract whatever else
  /// happens, so from there the tricks it takes are worth nothing -- unless
  /// the other side is on course to take every one of them, which pays a
  /// sweep and is worth a trick to stop.
  bool get tricksStillPay {
    if (!hasContract) {
      return true;
    }
    if (weDeclare && objectiveLost) {
      return sweepAgainstUs;
    }
    return true;
  }

  @override
  String toString() => 'TeamPlan(${weDeclare ? 'declaring' : 'defending'} '
      '$contractBid, us $ourTricks, them $theirTricks, '
      'need $outstanding of $tricksRemaining)';
}
