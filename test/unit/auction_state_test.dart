// The auction, which is where Herkes Tek Ihaleli Batak differs most from
// every other mode in this app. One contract, raised until three seats have
// given up, and a pass that is final.

import 'package:batak_king/core/game_engine/auction/auction_state.dart';
import 'package:batak_king/core/rules/bidding_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const BiddingRules _rules = BiddingRules.fourPlayerStandard;

AuctionState open({BiddingRules rules = _rules, int dealer = 0}) =>
    AuctionState.opening(
      rules: rules,
      seatCount: 4,
      openingSeat: (dealer + 1) % 4,
      dealerSeat: dealer,
    );

AuctionState play(AuctionState auction, List<int?> calls) {
  AuctionState state = auction;
  for (final int? call in calls) {
    final int seat = state.seatToAct!;
    state = state.withCall(
      call == null
          ? AuctionCall.pass(seat: seat)
          : AuctionCall.bid(seat: seat, tricks: call),
    );
  }
  return state;
}

void main() {
  group('opening', () {
    test('the dealer\'s right-hand neighbour speaks first', () {
      expect(open(dealer: 2).seatToAct, 3);
      expect(open(dealer: 3).seatToAct, 0);
    });

    test('the first bid may be anything from the minimum up', () {
      expect(open().legalBids(1), <int>[5, 6, 7, 8, 9, 10, 11, 12, 13]);
    });

    test('a seat that is not on turn may offer nothing', () {
      expect(open().legalBids(2), isEmpty);
      expect(open().canPass(2), isFalse);
    });
  });

  group('raising', () {
    test('a later bid must beat the standing one', () {
      final AuctionState state = play(open(), <int?>[5]);
      expect(state.standingBid, 5);
      expect(state.legalBids(state.seatToAct!).first, 6);
    });

    test('the same contract cannot be said twice', () {
      final AuctionState state = play(open(), <int?>[6]);
      expect(state.legalBids(state.seatToAct!), isNot(contains(6)));
    });

    test('turn order skips the seats that have passed', () {
      // Seat 1 opens, 2 passes, 3 bids. The turn is seat 0's, and after it
      // the auction comes back to 1 -- never to 2.
      AuctionState state = play(open(), <int?>[5, null, 6]);
      expect(state.seatToAct, 0);
      state = play(state, <int?>[null]);
      expect(state.seatToAct, 1);
    });
  });

  group('ending', () {
    test('one bid and three passes gives the contract to the bidder', () {
      final AuctionState state = play(open(), <int?>[5, null, null, null]);
      expect(state.isComplete, isTrue);
      expect(state.winner, 1);
      expect(state.winningBid, 5);
      expect(state.wasForced, isFalse);
    });

    test('the standing bidder is never asked to outbid itself', () {
      // Seat 1 bids 5, seat 2 bids 6, seats 3 and 0 pass, seat 1 passes.
      // Seat 2 is now the only active seat, so the auction is over without
      // it being asked anything.
      final AuctionState state = play(open(), <int?>[5, 6, null, null, null]);
      expect(state.isComplete, isTrue);
      expect(state.seatToAct, isNull);
      expect(state.winner, 2);
      expect(state.winningBid, 6);
    });

    test('the maximum contract closes the auction at once', () {
      final AuctionState state = play(open(), <int?>[13]);
      expect(state.isComplete, isTrue);
      expect(state.winner, 1);
      expect(state.winningBid, 13);
      expect(state.calls, hasLength(1));
    });

    test('a passed seat is out for good', () {
      final AuctionState state = play(open(), <int?>[null, 5]);
      expect(state.passedSeats, <int>{1});
      expect(state.activeSeats, <int>{0, 2, 3});
      expect(state.legalBids(1), isEmpty);
      expect(state.canPass(1), isFalse);
    });

    test('an unfinished auction yields no contract', () {
      final AuctionState state = play(open(), <int?>[5, null]);
      expect(state.isComplete, isFalse);
      expect(state.winner, isNull);
      expect(state.winningBid, isNull);
    });
  });

  group('passing out', () {
    test('the opener is stuck with the forced contract', () {
      final AuctionState state = play(open(), <int?>[null, null, null, null]);
      expect(state.passedOut, isTrue);
      expect(state.isComplete, isTrue);
      expect(state.winner, 1, reason: 'seat 1 opened the auction');
      expect(state.winningBid, 4);
      expect(state.wasForced, isTrue);
    });

    test('the forced contract is below the voluntary minimum', () {
      // Deliberate: four is not a contract anybody may choose, and that is
      // the point -- nobody chose this one.
      expect(_rules.effectiveForcedBid, lessThan(_rules.minimumBid));
    });

    test('a dealer-must-bid table sticks the dealer instead', () {
      final AuctionState state = play(
        open(
          rules: _rules.copyWith(passOutRule: PassOutRule.dealerMustBid),
          dealer: 2,
        ),
        <int?>[null, null, null, null],
      );
      expect(state.winner, 2);
    });

    test('a redeal table produces no contract at all', () {
      final AuctionState state = play(
        open(rules: _rules.copyWith(passOutRule: PassOutRule.redeal)),
        <int?>[null, null, null, null],
      );
      expect(state.needsRedeal, isTrue);
      expect(state.winner, isNull);
      expect(state.winningBid, isNull);
    });

    test('one bid is enough to stop a pass-out', () {
      final AuctionState state = play(open(), <int?>[5, null, null, null]);
      expect(state.passedOut, isFalse);
      expect(state.wasForced, isFalse);
    });
  });

  test('an auction survives a save round trip', () {
    final AuctionState state = play(open(dealer: 2), <int?>[6, null, 8]);
    final AuctionState restored = AuctionState.fromJson(
      state.toJson(),
      rules: _rules,
      seatCount: 4,
    );
    expect(restored.calls, state.calls);
    expect(restored.standingBid, state.standingBid);
    expect(restored.seatToAct, state.seatToAct);
    expect(restored.openingSeat, state.openingSeat);
  });
}
