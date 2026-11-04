// Checks that an Esli Ihaleli Batak match survives a save and a reload.
//
//   dart run tool/checks/partnership_roundtrip.dart 60
//
// The esli save has more to lose than the other modes': the log has to carry
// the auction, the named trump and the cards, and the replayed position has to
// agree about who holds the contract, which seat is the open hand, whether its
// cards are face up, and which seat chooses for it. A save that replayed the
// cards correctly and lost the contract would restore a hand nobody is
// playing for anything.
//
// It replays through `MatchRestore`, which is the same code path "Devam Et"
// uses, so a pass here is a pass for the product rather than for a copy of it.

import 'dart:io';

import 'package:batak_king/core/ai/ai_difficulty.dart';
import 'package:batak_king/core/ai/policies/partnership_auction_policy.dart';
import 'package:batak_king/core/ai/policies/partnership_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/persistence/saved_match.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/features/gameplay/match_restore.dart';
import 'package:batak_king/features/gameplay/match_runtime.dart';

void main(List<String> args) {
  final int plies = int.tryParse(args.isEmpty ? '' : args.first) ?? 60;
  int checked = 0;

  for (final RuleProfile profile in <RuleProfile>[
    RulePresets.partnershipBatakOpen(),
    RulePresets.partnershipBatakClosed(),
  ]) {
    for (int seed = 9000; seed < 9012; seed++) {
      _checkOne(profile: profile, seed: seed, plies: plies);
      checked++;
    }
  }

  stdout.writeln('Batak & King - esli save round trip');
  stdout.writeln('$checked matches replayed, positions identical');
}

void _checkOne({
  required RuleProfile profile,
  required int seed,
  required int plies,
}) {
  const PartnershipAuctionPolicy auction = PartnershipAuctionPolicy();
  final List<PartnershipPolicy> cards = <PartnershipPolicy>[
    for (int seat = 0; seat < 4; seat++) PartnershipPolicy(seed: seed + seat),
  ];

  MatchRuntime runtime = MatchRuntime.start(profile: profile, seed: seed);
  final List<int> moves = <int>[];

  for (int ply = 0; ply < plies; ply++) {
    final int? owner = runtime.seatToAct;
    if (owner == null) {
      break;
    }
    final int decider = runtime.controllerOf(owner);
    final SeatObservation observation = SeatObservation.fromState(
      runtime.hand!,
      owner,
      match: runtime.aiContext,
      visibleHands: runtime.visibleHandsFor(decider),
      publicHands: runtime.publicOpenHands,
    );

    final GameCommand command;
    switch (runtime.step) {
      case MatchStep.bidding:
        final int? offer =
            auction.chooseBid(observation, runtime.legalBids(owner));
        if (offer == null) {
          moves.add(SavedMatch.passMove);
          command = PassBidCommand(seat: owner);
        } else {
          moves.add(SavedMatch.encodeBid(offer));
          command = PlaceBidCommand(seat: owner, tricks: offer);
        }
      case MatchStep.choosingTrump:
        final Suit trump =
            auction.chooseTrump(observation, runtime.legalTrumps);
        moves.add(SavedMatch.encodeTrump(trump.index));
        command = DeclareTrumpCommand(seat: owner, trump: trump);
      case MatchStep.playing:
        final PlayingCard card = cards[decider].chooseCardSync(observation);
        moves.add(card.id);
        command = PlayCardCommand(seat: owner, card: card);
      case MatchStep.declaring:
        throw StateError('Esli Ihaleli has no declaration round');
      case MatchStep.finished:
        return;
    }

    final MatchRuntimeOutcome outcome = runtime.apply(command);
    final MatchRuntime? next = outcome.runtime;
    if (next == null) {
      throw StateError('refused $command: ${outcome.rejection?.name}');
    }
    runtime = next;
  }

  final SavedMatch save = SavedMatch(
    matchId: 'roundtrip-$seed',
    ruleProfile: profile,
    dealSeed: seed,
    savedAtEpochMillis: 0,
    humanSeat: 0,
    difficulty: AiDifficulty.hard,
    moves: moves,
    handsPlayed: runtime.handsPlayed,
    scores: runtime.totals,
  );

  final MatchRuntime? restored =
      MatchRestore.replay(SavedMatch.decode(save.encode()));
  if (restored == null) {
    throw StateError('${profile.id} seed $seed did not replay');
  }

  _expect(restored.handIndex == runtime.handIndex, 'hand index');
  _expect(restored.seatToAct == runtime.seatToAct, 'seat to act');
  _expect('${restored.totals}' == '${runtime.totals}', 'totals');
  _expect('${restored.teamTotals}' == '${runtime.teamTotals}', 'team totals');
  _expect(restored.declarerSeat == runtime.declarerSeat, 'declarer');
  _expect(restored.contractBid == runtime.contractBid, 'contract');
  _expect(restored.trump == runtime.trump, 'trump');
  _expect(restored.dummySeat == runtime.dummySeat, 'open hand seat');
  _expect(
    restored.isDummyRevealed == runtime.isDummyRevealed,
    'open hand visibility',
  );
  _expect(
    '${restored.dummyHand}' == '${runtime.dummyHand}',
    'open hand cards',
  );
  final int? lastOwner = runtime.seatToAct;
  if (lastOwner != null) {
    _expect(
      restored.controllerOf(lastOwner) == runtime.controllerOf(lastOwner),
      'who chooses',
    );
  }
  for (int seat = 0; seat < runtime.seatCount; seat++) {
    _expect(
      '${restored.hand?.handOf(seat)}' == '${runtime.hand?.handOf(seat)}',
      'hand of seat $seat',
    );
  }
}

void _expect(bool condition, String what) {
  if (!condition) {
    throw StateError('round trip lost: $what');
  }
}
