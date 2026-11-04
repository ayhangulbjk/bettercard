// Developer probe: what the esli bidder and the esli card policy actually do.
//
//   dart run tool/checks/partnership_probe.dart --hands 400
//   dart run tool/checks/partnership_probe.dart --hands 400 --mode closed
//   dart run tool/checks/partnership_probe.dart --hands 400 --risk 0.5
//
// Plays whole hands of Esli Ihaleli Batak with the shipped policies and
// prints what came out: the contracts bid, how often an auction passes out,
// how often the declaring side makes it, how many tricks each side takes,
// and how often the defending side misses its floor. A bidder that never bids
// and one that always bids thirteen both look fine from a unit test; this is
// what shows which one you have.
//
// It is also what the constants in PartnershipBidEvaluator were set from, and
// the honest way to re-set them: change one, run this, read the line.
//
// Every hand runs through the real engine, so an invariant breach surfaces
// here as a thrown error rather than as a quietly wrong number.

import 'dart:io';

import 'package:batak_king/core/ai/policies/partnership_auction_policy.dart';
import 'package:batak_king/core/ai/policies/partnership_bid_evaluator.dart';
import 'package:batak_king/core/ai/policies/partnership_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/games/partnership_batak/partnership_batak_engine.dart';
import 'package:batak_king/games/partnership_batak/partnership_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart'
    show HandScore;

const PartnershipBatakEngine _engine = PartnershipBatakEngine();

void main(List<String> args) {
  final int hands = _intArg(args, 'hands') ?? 400;
  final double risk = _doubleArg(args, 'risk') ?? 0;
  final bool closed = _stringArg(args, 'mode') == 'closed';

  final RuleProfile base = closed
      ? RulePresets.partnershipBatakClosed()
      : RulePresets.partnershipBatakOpen();
  // One hand per match, so every deal is an independent sample of the auction
  // rather than a continuation of a scoreboard.
  final RuleProfile profile = base.copyWith(
    scoringRules: base.scoringRules.copyWith(roundCount: 1),
  );

  final Map<int, int> bids = <int, int>{};
  final Map<int, int> teamCapacity = <int, int>{};
  int forced = 0;
  int made = 0;
  int declarerTricks = 0;
  int defenceShortOfFloor = 0;
  int sweeps = 0;
  int partnerRaises = 0;
  int totalPoints = 0;

  for (int hand = 0; hand < hands; hand++) {
    PartnershipBatakMatchState state = PartnershipBatakEngine.start(
      profile: profile,
      seed: 7000 + hand,
    );
    for (int seat = 0; seat < 4; seat++) {
      final double capacity = PartnershipBidEvaluator.bestTrump(
        state.hand!.handOf(seat),
      ).teamCapacity;
      teamCapacity[capacity.round()] =
          (teamCapacity[capacity.round()] ?? 0) + 1;
    }

    final _HandOutcome outcome = _playHand(
      state: state,
      profile: profile,
      risk: risk,
      onPartnerRaise: () => partnerRaises++,
    );
    state = outcome.state;

    final int bid = outcome.bid;
    bids[bid] = (bids[bid] ?? 0) + 1;
    if (outcome.wasForced) {
      forced++;
    }

    final HandScore score = state.history.single;
    final int declarerTeam = outcome.declarerTeam;
    int ours = 0;
    int theirs = 0;
    for (int seat = 0; seat < 4; seat++) {
      if (seat % 2 == declarerTeam) {
        ours += score.tricksOf(seat);
      } else {
        theirs += score.tricksOf(seat);
      }
    }
    declarerTricks += ours;
    if (ours >= bid) {
      made++;
    }
    if (theirs < profile.partnershipScoringRules.defenderMinimumTricks) {
      defenceShortOfFloor++;
    }
    if (ours == profile.tricksPerHand || theirs == profile.tricksPerHand) {
      sweeps++;
    }
    // Both partners carry the side's points, so one seat per side is enough.
    totalPoints += score.pointsOf(declarerTeam);
  }

  stdout.writeln('profile          : ${profile.id}'
      '${risk == 0 ? '' : '  risk=${risk.toStringAsFixed(1)}'}');
  stdout.writeln('hands            : $hands');
  stdout.writeln('passed out       : $forced '
      '(${_pct(forced, hands)})');
  stdout.writeln('contract made    : $made (${_pct(made, hands)})');
  stdout.writeln('declaring tricks : '
      '${(declarerTricks / hands).toStringAsFixed(2)} of '
      '${profile.tricksPerHand}');
  stdout.writeln('declaring points : '
      '${(totalPoints / hands).toStringAsFixed(2)} per hand');
  stdout.writeln('defence < floor  : $defenceShortOfFloor '
      '(${_pct(defenceShortOfFloor, hands)})');
  stdout.writeln('all-13 hands     : $sweeps (${_pct(sweeps, hands)})');
  stdout.writeln('raised own side  : $partnerRaises');
  stdout.writeln('bids             : ${_histogram(bids)}');
  stdout.writeln('team capacity    : ${_histogram(teamCapacity)}');
}

/// Plays one hand out and reports what the auction produced.
_HandOutcome _playHand({
  required PartnershipBatakMatchState state,
  required RuleProfile profile,
  required double risk,
  required void Function() onPartnerRaise,
}) {
  final PartnershipAuctionPolicy auction =
      PartnershipAuctionPolicy(riskAppetite: risk);
  final List<PartnershipPolicy> cards = <PartnershipPolicy>[
    for (int seat = 0; seat < 4; seat++) PartnershipPolicy(seed: 41 + seat),
  ];
  PartnershipBatakMatchState current = state;
  int bid = 0;
  int declarerTeam = 0;
  bool wasForced = false;

  while (!current.isOver && current.history.isEmpty) {
    final int owner = current.seatToAct!;
    final int decider = current.controllerOf(owner);
    final SeatObservation observation = SeatObservation.fromState(
      current.hand!,
      owner,
      match: current.aiContext,
      visibleHands: current.visibleHandsFor(decider),
      publicHands: current.publicOpenHands,
    );
    final GameCommand command;
    if (current.isAuctioning) {
      final bool standingIsOurs = current.aiContext.standingBidIsOurs(owner);
      final int? offer =
          auction.chooseBid(observation, _engine.legalBids(current, owner));
      if (offer != null && standingIsOurs) {
        onPartnerRaise();
      }
      command = offer == null
          ? PassBidCommand(seat: owner)
          : PlaceBidCommand(seat: owner, tricks: offer);
    } else if (current.isChoosingTrump) {
      bid = current.contractBid!;
      declarerTeam = current.declarerTeam!;
      wasForced = current.contractWasForced;
      command = DeclareTrumpCommand(
        seat: owner,
        trump: auction.chooseTrump(observation, _engine.legalTrumps(current)),
      );
    } else {
      command = PlayCardCommand(
        seat: owner,
        // The declarer decides for the open hand, so the policy asked is the
        // decider's -- while the card still comes out of the owner's hand.
        card: cards[decider].chooseCardSync(observation),
      );
    }
    current = switch (_engine.apply(current, command)) {
      CommandAccepted<PartnershipBatakMatchState>(
        state: final PartnershipBatakMatchState next
      ) =>
        next,
      CommandRejected<PartnershipBatakMatchState>(:final Object violation) =>
        throw StateError('refused $command: $violation'),
    };
  }
  return _HandOutcome(
    state: current,
    bid: bid,
    declarerTeam: declarerTeam,
    wasForced: wasForced,
  );
}

final class _HandOutcome {
  const _HandOutcome({
    required this.state,
    required this.bid,
    required this.declarerTeam,
    required this.wasForced,
  });

  final PartnershipBatakMatchState state;
  final int bid;
  final int declarerTeam;
  final bool wasForced;
}

String _pct(int part, int whole) =>
    '${(part / whole * 100).toStringAsFixed(1)}%';

String _histogram(Map<int, int> counts) {
  final List<int> keys = counts.keys.toList()..sort();
  return keys.map((int k) => '$k:${counts[k]}').join('  ');
}

int? _intArg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--$name') {
      return int.tryParse(args[i + 1]);
    }
  }
  return null;
}

double? _doubleArg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--$name') {
      return double.tryParse(args[i + 1]);
    }
  }
  return null;
}

String? _stringArg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--$name') {
      return args[i + 1];
    }
  }
  return null;
}
