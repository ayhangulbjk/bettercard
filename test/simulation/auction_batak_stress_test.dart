// Thousands of contract hands driven by the shipped bots, checking the things
// that must never stop being true.
//
// This is the property test for the mode: not "does this position work" but
// "is there any position this engine can reach where the cards do not add up".
// It plays real auctions with real policies, because a stress test fed random
// commands would never reach the positions a bidding bot actually produces.

import 'package:batak_king/core/ai/auction_policy.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/cards/suit.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/rules/auction_scoring_rules.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/core/rules/rule_profile.dart';
import 'package:batak_king/games/auction_batak/auction_batak_engine.dart';
import 'package:batak_king/games/auction_batak/auction_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_scorer.dart'
    show HandScore;
import 'package:flutter_test/flutter_test.dart';

const AuctionBatakEngine _engine = AuctionBatakEngine();
const int _players = 4;

/// Hands per profile. Three profiles, so the suite plays this many times
/// three; raise it for a longer soak run.
const int _handsPerProfile = 400;

void main() {
  group('contract hands hold their invariants', () {
    for (final RuleProfile profile in <RuleProfile>[
      RulePresets.auctionBatakStandard(),
      // The Gamyun and per-trick payoffs are no longer offered as presets --
      // the product ships one Herkes Tek Ihaleli rule set -- but the payoff
      // shapes still exist as settings, so the soak keeps covering them.
      RulePresets.auctionBatakStandard().copyWith(
        id: 'auction_batak_gamyun',
        auctionScoringRules: AuctionScoringRules.gamyun,
      ),
      RulePresets.auctionBatakStandard().copyWith(
        id: 'auction_batak_per_trick',
        auctionScoringRules: AuctionScoringRules.perTrick,
      ),
    ]) {
      test('${profile.id}: $_handsPerProfile hands', () {
        int contracts = 0;
        int forced = 0;
        int made = 0;

        for (int hand = 0; hand < _handsPerProfile; hand++) {
          final _HandRecord record = _playOneHand(profile, seed: 5000 + hand);
          contracts++;
          if (record.wasForced) {
            forced++;
          }
          if (record.score.pointsOf(record.declarer) > 0) {
            made++;
          }

          // Exactly one declarer, and a contract inside the legal range.
          expect(record.declarer, inInclusiveRange(0, _players - 1));
          expect(
            record.bid,
            inInclusiveRange(
              record.wasForced
                  ? profile.biddingRules.effectiveForcedBid
                  : profile.biddingRules.minimumBid,
              profile.biddingRules.maximumBid,
            ),
          );

          // Thirteen tricks, all accounted for, nobody with a negative count.
          expect(record.score.totalTricks, profile.tricksPerHand);
          for (int seat = 0; seat < _players; seat++) {
            expect(record.score.tricksOf(seat), greaterThanOrEqualTo(0));
          }

          // Every card dealt was played exactly once.
          expect(record.playedCards, hasLength(52));
          expect(record.playedCards.toSet(), hasLength(52));

          // The sheet matches the payoff table, seat by seat.
          for (int seat = 0; seat < _players; seat++) {
            expect(
              record.score.pointsOf(seat),
              profile.auctionScoringRules.scoreFor(
                seat: seat,
                declarerSeat: record.declarer,
                bid: record.bid,
                tricksTaken: record.score.tricksOf(seat),
              ),
            );
          }

          // A trump was named and it was a real suit.
          expect(Suit.values, contains(record.trump));
        }

        expect(contracts, _handsPerProfile);
        // Sanity on the bots rather than on the engine: a bidder that never
        // makes a contract, or always does, is not playing the game.
        expect(made, greaterThan(_handsPerProfile ~/ 10));
        expect(made, lessThan(_handsPerProfile));
        // Forced contracts should be rare but not impossible.
        expect(forced, lessThan(_handsPerProfile ~/ 2));
      });
    }
  });

  test('a bot never sees a card it is not holding', () {
    // The fairness boundary again, from inside this mode: the auction and the
    // trump choice are new decision points, and both read an observation.
    final RuleProfile profile = RulePresets.auctionBatakStandard();
    for (int hand = 0; hand < 40; hand++) {
      _playOneHand(
        profile,
        seed: 9000 + hand,
        inspect: (AuctionBatakMatchState state, SeatObservation observation) {
          final Set<PlayingCard> mine = observation.hand.toSet();
          for (int seat = 0; seat < _players; seat++) {
            if (seat == observation.seat) {
              continue;
            }
            for (final PlayingCard card in state.hand!.handOf(seat)) {
              expect(
                mine.contains(card),
                isFalse,
                reason: 'seat ${observation.seat} can see $card from $seat',
              );
            }
          }
          for (final PlayingCard card in observation.legalMoves) {
            expect(mine.contains(card), isTrue);
          }
        },
      );
    }
  });
}

final class _HandRecord {
  const _HandRecord({
    required this.declarer,
    required this.bid,
    required this.trump,
    required this.wasForced,
    required this.score,
    required this.playedCards,
  });

  final int declarer;
  final int bid;
  final Suit? trump;
  final bool wasForced;
  final HandScore score;
  final List<PlayingCard> playedCards;
}

/// Plays one hand to its score with the shipped bots.
_HandRecord _playOneHand(
  RuleProfile profile, {
  required int seed,
  void Function(AuctionBatakMatchState, SeatObservation)? inspect,
}) {
  const HeuristicAuctionPolicy auction = HeuristicAuctionPolicy();
  final List<HeuristicPolicy> cards = <HeuristicPolicy>[
    for (int seat = 0; seat < _players; seat++)
      HeuristicPolicy(seed: seed * 31 + seat),
  ];

  AuctionBatakMatchState state = AuctionBatakEngine.start(
    profile: profile.copyWith(
      scoringRules: profile.scoringRules.copyWith(roundCount: 1),
    ),
    seed: seed,
  );

  int? declarer;
  int? bid;
  Suit? trump;
  bool forced = false;
  final List<PlayingCard> played = <PlayingCard>[];

  while (!state.isOver && state.history.isEmpty) {
    final int seat = state.seatToAct!;
    final SeatObservation observation = SeatObservation.fromState(
      state.hand!,
      seat,
      match: state.aiContext,
    );
    inspect?.call(state, observation);

    final GameCommand command;
    if (state.isAuctioning) {
      final int? offer =
          auction.chooseBid(observation, _engine.legalBids(state, seat));
      command = offer == null
          ? PassBidCommand(seat: seat)
          : PlaceBidCommand(seat: seat, tricks: offer);
    } else if (state.isChoosingTrump) {
      declarer = state.declarerSeat;
      bid = state.contractBid;
      forced = state.contractWasForced;
      command = DeclareTrumpCommand(
        seat: seat,
        trump: auction.chooseTrump(observation, _engine.legalTrumps(state)),
      );
    } else {
      trump ??= state.trump;
      final PlayingCard card = cards[seat].chooseCardSync(observation);
      expect(
        observation.legalMoves,
        contains(card),
        reason: 'a policy offered a card outside the legal set',
      );
      played.add(card);
      command = PlayCardCommand(seat: seat, card: card);
    }

    final CommandOutcome<AuctionBatakMatchState> outcome =
        _engine.apply(state, command);
    expect(
      outcome,
      isA<CommandAccepted<AuctionBatakMatchState>>(),
      reason: 'engine refused $command in hand $seed',
    );
    final AuctionBatakMatchState next =
        (outcome as CommandAccepted<AuctionBatakMatchState>).state;
    // A redeal resets the hand, so everything about it goes with it.
    if (next.history.isEmpty && next.isAuctioning && !state.isAuctioning) {
      declarer = null;
      bid = null;
      trump = null;
      played.clear();
    }
    state = next;
  }

  return _HandRecord(
    declarer: declarer!,
    bid: bid!,
    trump: trump,
    wasForced: forced,
    score: state.history.single,
    playedCards: played,
  );
}
