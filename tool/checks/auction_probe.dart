// Developer probe: what the bidding evaluator actually says, hand by hand.
//
//   dart run tool/checks/auction_probe.dart --hands 200
//
// Prints the distribution of contracts the shipped bidder produces, how often
// an auction passes out, and how often the contract is made. A bidder that
// never bids and one that always bids the maximum both look fine from a unit
// test; this is what shows which one you have.

import 'dart:io';

import 'package:batak_king/core/ai/auction_policy.dart';
import 'package:batak_king/core/ai/policies/bid_evaluator.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/games/auction_batak/auction_batak_engine.dart';
import 'package:batak_king/games/auction_batak/auction_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart'
    show HandScore;

const AuctionBatakEngine _engine = AuctionBatakEngine();
const HeuristicAuctionPolicy _auction = HeuristicAuctionPolicy();

void main(List<String> args) {
  final int hands = _intArg(args, 'hands') ?? 200;
  final double? risk = _doubleArg(args, 'risk');
  if (risk != null) {
    _matchup(hands: hands, risk: risk);
    return;
  }
  final RuleProfile base = RulePresets.auctionBatakStandard();
  final RuleProfile profile = base.copyWith(
    scoringRules: base.scoringRules.copyWith(roundCount: 1),
  );

  final Map<int, int> bids = <int, int>{};
  final Map<int, int> capacityBuckets = <int, int>{};
  int forced = 0;
  int made = 0;
  int declarerTricks = 0;

  for (int hand = 0; hand < hands; hand++) {
    AuctionBatakMatchState state =
        AuctionBatakEngine.start(profile: profile, seed: 5000 + hand);
    for (int seat = 0; seat < 4; seat++) {
      final double capacity =
          BidEvaluator.bestTrump(state.hand!.handOf(seat)).capacity;
      capacityBuckets[capacity.round()] =
          (capacityBuckets[capacity.round()] ?? 0) + 1;
    }

    final List<HeuristicPolicy> cards = <HeuristicPolicy>[
      for (int seat = 0; seat < 4; seat++) HeuristicPolicy(seed: 31 + seat),
    ];
    while (!state.isOver && state.history.isEmpty) {
      final int seat = state.seatToAct!;
      final SeatObservation observation = SeatObservation.fromState(
        state.hand!,
        seat,
        match: state.aiContext,
      );
      final GameCommand command;
      if (state.isAuctioning) {
        final int? offer =
            _auction.chooseBid(observation, _engine.legalBids(state, seat));
        command = offer == null
            ? PassBidCommand(seat: seat)
            : PlaceBidCommand(seat: seat, tricks: offer);
      } else if (state.isChoosingTrump) {
        bids[state.contractBid!] = (bids[state.contractBid!] ?? 0) + 1;
        if (state.contractWasForced) {
          forced++;
        }
        command = DeclareTrumpCommand(
          seat: seat,
          trump: _auction.chooseTrump(observation, _engine.legalTrumps(state)),
        );
      } else {
        final PlayingCard card = cards[seat].chooseCardSync(observation);
        command = PlayCardCommand(seat: seat, card: card);
      }
      state = switch (_engine.apply(state, command)) {
        CommandAccepted<AuctionBatakMatchState>(
          state: final AuctionBatakMatchState next
        ) =>
          next,
        CommandRejected<AuctionBatakMatchState>(:final Object violation) =>
          throw StateError('refused $command: $violation'),
      };
    }
    final HandScore score = state.history.single;
    for (int seat = 0; seat < 4; seat++) {
      if (score.declarationOf(seat) != null) {
        declarerTricks += score.tricksOf(seat);
        if (score.pointsOf(seat) > 0) {
          made++;
        }
      }
    }
  }

  stdout.writeln('hands            : $hands');
  stdout.writeln('passed out       : $forced '
      '(${(forced / hands * 100).toStringAsFixed(1)}%)');
  stdout.writeln('contract made    : $made '
      '(${(made / hands * 100).toStringAsFixed(1)}%)');
  stdout.writeln(
    'declarer tricks  : ${(declarerTricks / hands).toStringAsFixed(2)}',
  );
  stdout.writeln('bids             : ${_histogram(bids)}');
  stdout.writeln('best capacity    : ${_histogram(capacityBuckets)}');
}

/// One seat bids with [risk] extra optimism, the other three without.
///
/// Reported as ground gained: the agent's points minus the table average, on
/// the same deals with the agent rotated through every seat. That is the
/// quantity a match is actually decided on, and the only one worth tuning a
/// bidder against.
void _matchup({required int hands, required double risk}) {
  final RuleProfile base = RulePresets.auctionBatakStandard();
  final RuleProfile profile = base.copyWith(
    scoringRules: base.scoringRules.copyWith(roundCount: 1),
  );
  double total = 0;
  int samples = 0;

  for (int hand = 0; hand < hands; hand++) {
    for (int underTest = 0; underTest < 4; underTest++) {
      final List<HeuristicAuctionPolicy> bidders = <HeuristicAuctionPolicy>[
        for (int seat = 0; seat < 4; seat++)
          HeuristicAuctionPolicy(
            riskAppetite: seat == underTest ? risk : 0,
          ),
      ];
      final HandScore score = _runHand(
        profile: profile,
        seed: 5000 + hand,
        bidders: bidders,
      );
      final int mine = score.pointsOf(underTest);
      final int table = score.totalPoints;
      total += mine - table / 4;
      samples++;
    }
  }

  stdout.writeln('risk=${risk.toStringAsFixed(1)} over $hands deals '
      'x4 seats');
  stdout.writeln(
    'ground gained    : ${(total / samples).toStringAsFixed(2)} points/hand',
  );
}

HandScore _runHand({
  required RuleProfile profile,
  required int seed,
  required List<HeuristicAuctionPolicy> bidders,
}) {
  AuctionBatakMatchState state =
      AuctionBatakEngine.start(profile: profile, seed: seed);
  final List<HeuristicPolicy> cards = <HeuristicPolicy>[
    for (int seat = 0; seat < 4; seat++) HeuristicPolicy(seed: 31 + seat),
  ];
  while (!state.isOver && state.history.isEmpty) {
    final int seat = state.seatToAct!;
    final SeatObservation observation = SeatObservation.fromState(
      state.hand!,
      seat,
      match: state.aiContext,
    );
    final GameCommand command;
    if (state.isAuctioning) {
      final int? offer =
          bidders[seat].chooseBid(observation, _engine.legalBids(state, seat));
      command = offer == null
          ? PassBidCommand(seat: seat)
          : PlaceBidCommand(seat: seat, tricks: offer);
    } else if (state.isChoosingTrump) {
      command = DeclareTrumpCommand(
        seat: seat,
        trump:
            bidders[seat].chooseTrump(observation, _engine.legalTrumps(state)),
      );
    } else {
      command = PlayCardCommand(
        seat: seat,
        card: cards[seat].chooseCardSync(observation),
      );
    }
    state = switch (_engine.apply(state, command)) {
      CommandAccepted<AuctionBatakMatchState>(
        state: final AuctionBatakMatchState next
      ) =>
        next,
      CommandRejected<AuctionBatakMatchState>(:final Object violation) =>
        throw StateError('refused $command: $violation'),
    };
  }
  return state.history.single;
}

double? _doubleArg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--$name') {
      return double.tryParse(args[i + 1]);
    }
  }
  return null;
}

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
