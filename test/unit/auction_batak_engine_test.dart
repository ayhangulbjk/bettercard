// The contract mode end to end: deal, auction, name trump, thirteen tricks,
// score, deal again.
//
// The engine is the authority, so these drive it with commands exactly as the
// UI and the bots do. Nothing here reaches into the state to set up a
// position by hand, because a position the engine cannot produce is not worth
// asserting about.

import 'package:batak_king/core/ai/ai_difficulty.dart';
import 'package:batak_king/core/ai/auction_policy.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/persistence/saved_match.dart';
import 'package:batak_king/core/rules/bidding_rules.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/core/rules/rule_violation.dart';
import 'package:batak_king/features/gameplay/match_restore.dart';
import 'package:batak_king/features/gameplay/match_runtime.dart';
import 'package:batak_king/games/auction_batak/auction_batak_engine.dart';
import 'package:batak_king/games/auction_batak/auction_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart'
    show HandScore;
import 'package:flutter_test/flutter_test.dart';

const AuctionBatakEngine engine = AuctionBatakEngine();

RuleProfile profile({int rounds = 2}) =>
    RulePresets.auctionBatakStandard().copyWith(
      scoringRules: RulePresets.auctionBatakStandard().scoringRules.copyWith(
            roundCount: rounds,
          ),
    );

AuctionBatakMatchState start({int seed = 7, int rounds = 2}) =>
    AuctionBatakEngine.start(profile: profile(rounds: rounds), seed: seed);

AuctionBatakMatchState accept(
  AuctionBatakMatchState state,
  GameCommand command,
) {
  final CommandOutcome<AuctionBatakMatchState> outcome =
      engine.apply(state, command);
  expect(
    outcome,
    isA<CommandAccepted<AuctionBatakMatchState>>(),
    reason: 'engine rejected $command',
  );
  return (outcome as CommandAccepted<AuctionBatakMatchState>).state;
}

RuleViolation? refusal(
  AuctionBatakMatchState state,
  GameCommand command,
) {
  final CommandOutcome<AuctionBatakMatchState> outcome =
      engine.apply(state, command);
  return outcome is CommandRejected<AuctionBatakMatchState>
      ? outcome.violation
      : null;
}

/// Runs the auction with a single bid of [bid] from the opening seat, the
/// rest passing, then names [trump].
AuctionBatakMatchState settleContract(
  AuctionBatakMatchState state, {
  required int bid,
  Suit trump = Suit.spades,
}) {
  AuctionBatakMatchState current = state;
  current = accept(
    current,
    PlaceBidCommand(seat: current.seatToAct!, tricks: bid),
  );
  while (current.isAuctioning) {
    current = accept(current, PassBidCommand(seat: current.seatToAct!));
  }
  return accept(
    current,
    DeclareTrumpCommand(seat: current.declarerSeat!, trump: trump),
  );
}

void main() {
  group('deal', () {
    test('every seat holds thirteen distinct cards and the deck is whole', () {
      final AuctionBatakMatchState state = start();
      final Set<PlayingCard> seen = <PlayingCard>{};
      for (int seat = 0; seat < 4; seat++) {
        final List<PlayingCard> hand = state.hand!.handOf(seat);
        expect(hand, hasLength(13));
        expect(hand.toSet(), hasLength(13), reason: 'seat $seat has a double');
        seen.addAll(hand);
      }
      expect(seen, hasLength(52));
    });

    test('the same seed deals the same cards', () {
      expect(start(seed: 11).hand!.handOf(0), start(seed: 11).hand!.handOf(0));
    });

    test('the deal rotates so no seat keeps the opening', () {
      final AuctionBatakMatchState first = start();
      expect(first.dealerSeat, 0);
      expect(first.openingSeat, 1);
      expect(first.seatToAct, 1);
    });

    test('trump starts unnamed and unbroken', () {
      final AuctionBatakMatchState state = start();
      expect(state.trump, isNull);
      expect(state.hand!.trumpBroken, isFalse);
      expect(state.isAuctioning, isTrue);
      expect(state.isPlaying, isFalse);
    });
  });

  group('phase order', () {
    test('no card may be played while the auction runs', () {
      final AuctionBatakMatchState state = start();
      final PlayingCard card = state.hand!.handOf(1).first;
      expect(
        refusal(state, PlayCardCommand(seat: 1, card: card))?.code,
        RuleViolationCode.wrongPhase,
      );
    });

    test('no card may be played before a trump is named', () {
      AuctionBatakMatchState state = start();
      state = accept(state, const PlaceBidCommand(seat: 1, tricks: 5));
      while (state.isAuctioning) {
        state = accept(state, PassBidCommand(seat: state.seatToAct!));
      }
      expect(state.isChoosingTrump, isTrue);
      final PlayingCard card = state.hand!.handOf(1).first;
      expect(
        refusal(state, PlayCardCommand(seat: 1, card: card))?.code,
        RuleViolationCode.wrongPhase,
      );
    });

    test('only the contract winner may name the trump', () {
      AuctionBatakMatchState state = start();
      state = accept(state, const PlaceBidCommand(seat: 1, tricks: 5));
      while (state.isAuctioning) {
        state = accept(state, PassBidCommand(seat: state.seatToAct!));
      }
      expect(
        refusal(state, const DeclareTrumpCommand(seat: 2, trump: Suit.hearts))
            ?.code,
        RuleViolationCode.notYourTurn,
      );
    });

    test('a bid out of turn is refused', () {
      final AuctionBatakMatchState state = start();
      expect(
        refusal(state, const PlaceBidCommand(seat: 3, tricks: 6))?.code,
        RuleViolationCode.notYourTurn,
      );
    });

    test('a bid that does not raise is refused', () {
      AuctionBatakMatchState state = start();
      state = accept(state, const PlaceBidCommand(seat: 1, tricks: 7));
      expect(
        refusal(state, const PlaceBidCommand(seat: 2, tricks: 6))?.code,
        RuleViolationCode.invalidBid,
      );
    });

    test('a passed seat cannot bid again', () {
      AuctionBatakMatchState state = start();
      state = accept(state, const PassBidCommand(seat: 1));
      state = accept(state, const PlaceBidCommand(seat: 2, tricks: 5));
      state = accept(state, const PassBidCommand(seat: 3));
      state = accept(state, const PassBidCommand(seat: 0));
      // Seat 1 passed first; the auction is over and it never got another say.
      expect(state.isAuctioning, isFalse);
      expect(
        refusal(state, const PlaceBidCommand(seat: 1, tricks: 6))?.code,
        RuleViolationCode.wrongPhase,
      );
    });

    test('no-trump is refused rather than silently allowed', () {
      AuctionBatakMatchState state = start();
      state = accept(state, const PlaceBidCommand(seat: 1, tricks: 5));
      while (state.isAuctioning) {
        state = accept(state, PassBidCommand(seat: state.seatToAct!));
      }
      expect(
        refusal(state, const DeclareTrumpCommand(seat: 1, trump: null))?.code,
        RuleViolationCode.invalidBid,
      );
    });
  });

  group('contract', () {
    test('the contract winner leads the first trick, not the opener', () {
      AuctionBatakMatchState state = start();
      // Seat 1 opens and passes; seat 2 takes the contract.
      state = accept(state, const PassBidCommand(seat: 1));
      state = accept(state, const PlaceBidCommand(seat: 2, tricks: 6));
      state = accept(state, const PassBidCommand(seat: 3));
      state = accept(state, const PassBidCommand(seat: 0));
      state = accept(
        state,
        const DeclareTrumpCommand(seat: 2, trump: Suit.clubs),
      );
      expect(state.declarerSeat, 2);
      expect(state.hand!.turnSeat, 2);
      expect(state.openingSeat, 1);
    });

    test('the named trump holds for the whole hand', () {
      final AuctionBatakMatchState state =
          settleContract(start(), bid: 5, trump: Suit.diamonds);
      expect(state.trump, Suit.diamonds);
      expect(state.hand!.trump, Suit.diamonds);
    });

    test('a passed-out hand forces a contract on the opener', () {
      AuctionBatakMatchState state = start();
      for (int i = 0; i < 4; i++) {
        state = accept(state, PassBidCommand(seat: state.seatToAct!));
      }
      expect(state.declarerSeat, 1);
      expect(state.contractBid, 4);
      expect(state.contractWasForced, isTrue);
      expect(state.isChoosingTrump, isTrue);
    });

    test('a redeal table deals again and scores nothing', () {
      final RuleProfile redealing = profile().copyWith(
        biddingRules: BiddingRules.fourPlayerStandard.copyWith(
          passOutRule: PassOutRule.redeal,
        ),
      );
      AuctionBatakMatchState state =
          AuctionBatakEngine.start(profile: redealing, seed: 7);
      final List<PlayingCard> before = state.hand!.handOf(0);
      for (int i = 0; i < 4; i++) {
        state = accept(state, PassBidCommand(seat: state.seatToAct!));
      }
      expect(state.history, isEmpty);
      expect(state.handIndex, 0);
      expect(state.isAuctioning, isTrue);
      expect(state.hand!.handOf(0), isNot(before));
    });
  });

  group('a hand played out', () {
    test('thirteen tricks are played and they add up to thirteen', () {
      final AuctionBatakMatchState end = _playHand(start(rounds: 1));
      expect(end.history, hasLength(1));
      final HandScore score = end.history.single;
      expect(score.totalTricks, 13);
    });

    test('the declarer and only the declarer has a contract on the sheet', () {
      final AuctionBatakMatchState end = _playHand(start(rounds: 1));
      final HandScore score = end.history.single;
      final List<int> withContract = <int>[
        for (int seat = 0; seat < 4; seat++)
          if (score.declarationOf(seat) != null) seat,
      ];
      expect(withContract, hasLength(1));
    });

    test('the sheet agrees with the payoff table', () {
      final AuctionBatakMatchState end = _playHand(start(rounds: 1));
      final HandScore score = end.history.single;
      final int declarer = withContractSeat(score);
      final int bid = score.declarationOf(declarer)!;
      for (int seat = 0; seat < 4; seat++) {
        expect(
          score.pointsOf(seat),
          profile().auctionScoringRules.scoreFor(
                seat: seat,
                declarerSeat: declarer,
                bid: bid,
                tricksTaken: score.tricksOf(seat),
              ),
          reason: 'seat $seat was paid something the rules do not say',
        );
      }
    });

    test('totals are the running sum of the hands', () {
      final AuctionBatakMatchState end = _playHand(_playHand(start()));
      expect(end.history, hasLength(2));
      for (int seat = 0; seat < 4; seat++) {
        expect(
          end.totals[seat],
          end.history.fold<int>(
            0,
            (int sum, HandScore h) => sum + h.pointsOf(seat),
          ),
        );
      }
    });

    test('a finished match is terminal and has a winner', () {
      final AuctionBatakMatchState end = _playHand(_playHand(start()));
      expect(engine.isTerminal(end), isTrue);
      expect(end.isOver, isTrue);
      expect(end.winners, isNotEmpty);
    });
  });

  _saveTests();
}

/// The move log and the position it replays into must agree.
///
/// The auction adds three kinds of move the log never carried before -- a
/// bid, a pass and a named trump -- and a save that dropped any of them would
/// replay into a hand with no contract, which the engine would then refuse at
/// the first card. So the round trip is asserted here rather than trusted.
void _saveTests() {
  group('save and resume', () {
    test('a mid-auction position replays exactly', () {
      final _Replayed replayed = _replay(plies: 3);
      expect(replayed.after.isAuctioning, isTrue);
      expect(
        replayed.after.auction!.calls,
        replayed.before.auction!.calls,
      );
      expect(replayed.after.seatToAct, replayed.before.seatToAct);
    });

    test('a settled contract and its trump survive', () {
      final _Replayed replayed = _replay(plies: 6);
      expect(replayed.after.declarerSeat, replayed.before.declarerSeat);
      expect(replayed.after.contractBid, replayed.before.contractBid);
      expect(replayed.after.trump, replayed.before.trump);
      expect(replayed.after.trump, isNotNull);
    });

    test('a hand in progress replays card for card', () {
      final _Replayed replayed = _replay(plies: 20);
      expect(replayed.after.hand!.handOf(0), replayed.before.hand!.handOf(0));
      expect(replayed.after.hand!.tricksWon, replayed.before.hand!.tricksWon);
      expect(replayed.after.totals, replayed.before.totals);
    });

    test('a truncated log is refused rather than half-replayed', () {
      final _Replayed replayed = _replay(plies: 20);
      final List<int> damaged = List<int>.of(replayed.moves)
        ..removeAt(replayed.moves.length ~/ 2);
      expect(
        MatchRestore.replay(_saveOf(damaged, replayed.before)),
        isNull,
      );
    });
  });
}

final class _Replayed {
  const _Replayed({
    required this.before,
    required this.after,
    required this.moves,
  });

  final AuctionBatakMatchState before;
  final AuctionBatakMatchState after;
  final List<int> moves;
}

SavedMatch _saveOf(List<int> moves, AuctionBatakMatchState state) => SavedMatch(
      matchId: 'auction-roundtrip',
      ruleProfile: state.profile,
      dealSeed: 7,
      savedAtEpochMillis: 0,
      humanSeat: 0,
      difficulty: AiDifficulty.normal,
      moves: moves,
      handsPlayed: state.history.length,
      scores: state.totals,
    );

/// Plays [plies] decisions with the bots, recording the log, then replays it.
_Replayed _replay({required int plies}) {
  const HeuristicAuctionPolicy auction = HeuristicAuctionPolicy();
  final List<HeuristicPolicy> cards = <HeuristicPolicy>[
    for (int seat = 0; seat < 4; seat++) HeuristicPolicy(seed: 500 + seat),
  ];
  AuctionBatakMatchState state = start(rounds: 4);
  final List<int> moves = <int>[];

  for (int ply = 0; ply < plies; ply++) {
    final int? seat = state.seatToAct;
    if (seat == null) {
      break;
    }
    final SeatObservation observation = SeatObservation.fromState(
      state.hand!,
      seat,
      match: state.aiContext,
    );
    if (state.isAuctioning) {
      final int? offer =
          auction.chooseBid(observation, engine.legalBids(state, seat));
      if (offer == null) {
        moves.add(SavedMatch.passMove);
        state = accept(state, PassBidCommand(seat: seat));
      } else {
        moves.add(SavedMatch.encodeBid(offer));
        state = accept(state, PlaceBidCommand(seat: seat, tricks: offer));
      }
    } else if (state.isChoosingTrump) {
      final Suit named =
          auction.chooseTrump(observation, engine.legalTrumps(state));
      moves.add(SavedMatch.encodeTrump(named.index));
      state = accept(state, DeclareTrumpCommand(seat: seat, trump: named));
    } else {
      final PlayingCard card = cards[seat].chooseCardSync(observation);
      moves.add(card.id);
      state = accept(state, PlayCardCommand(seat: seat, card: card));
    }
  }

  final MatchRuntime? restored = MatchRestore.replay(_saveOf(moves, state));
  expect(restored, isA<AuctionBatakRuntime>());
  return _Replayed(
    before: state,
    after: (restored! as AuctionBatakRuntime).state,
    moves: moves,
  );
}

int withContractSeat(HandScore score) {
  for (int seat = 0; seat < score.seatCount; seat++) {
    if (score.declarationOf(seat) != null) {
      return seat;
    }
  }
  throw StateError('No seat held the contract');
}

/// Plays one whole hand with the shipped bots, from wherever [state] is.
AuctionBatakMatchState _playHand(AuctionBatakMatchState state) {
  const HeuristicAuctionPolicy auction = HeuristicAuctionPolicy();
  final List<HeuristicPolicy> cards = <HeuristicPolicy>[
    for (int seat = 0; seat < 4; seat++) HeuristicPolicy(seed: 100 + seat),
  ];
  AuctionBatakMatchState current = state;
  final int startedAt = current.history.length;

  while (!current.isOver && current.history.length == startedAt) {
    final int seat = current.seatToAct!;
    final SeatObservation observation = SeatObservation.fromState(
      current.hand!,
      seat,
      match: current.aiContext,
    );
    if (current.isAuctioning) {
      final int? bid = auction.chooseBid(
        observation,
        engine.legalBids(current, seat),
      );
      current = accept(
        current,
        bid == null
            ? PassBidCommand(seat: seat)
            : PlaceBidCommand(seat: seat, tricks: bid),
      );
    } else if (current.isChoosingTrump) {
      current = accept(
        current,
        DeclareTrumpCommand(
          seat: seat,
          trump: auction.chooseTrump(observation, engine.legalTrumps(current)),
        ),
      );
    } else {
      current = accept(
        current,
        PlayCardCommand(
            seat: seat, card: cards[seat].chooseCardSync(observation)),
      );
    }
  }
  return current;
}
