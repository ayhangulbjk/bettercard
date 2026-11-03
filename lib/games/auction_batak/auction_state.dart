import 'package:meta/meta.dart';

import '../../core/rules/bidding_rules.dart';

/// One thing a seat said during the auction.
@immutable
final class AuctionCall {
  const AuctionCall.bid({required this.seat, required int this.tricks});

  const AuctionCall.pass({required this.seat}) : tricks = null;

  final int seat;

  /// The contract offered, or null for a pass.
  final int? tricks;

  bool get isPass => tricks == null;

  Map<String, Object?> toJson() => <String, Object?>{
        'seat': seat,
        'tricks': tricks,
      };

  static AuctionCall fromJson(Map<String, Object?> json) {
    final int seat = json['seat']! as int;
    final int? tricks = json['tricks'] as int?;
    return tricks == null
        ? AuctionCall.pass(seat: seat)
        : AuctionCall.bid(seat: seat, tricks: tricks);
  }

  @override
  bool operator ==(Object other) =>
      other is AuctionCall && other.seat == seat && other.tricks == tricks;

  @override
  int get hashCode => Object.hash(seat, tricks);

  @override
  String toString() => isPass ? 'Pass(seat: $seat)' : 'Bid($seat: $tricks)';
}

/// The open auction: one contract, raised until three seats have given up.
///
/// This is where Herkes Tek Ihaleli Batak parts company with Koz Maca most
/// sharply, and the reason it is a state machine of its own rather than a
/// variation on the declaration round. There, four seats each make an
/// independent promise and all four are paid against it. Here, four seats
/// compete for **one** contract, only the winner is held to a number, and a
/// pass is final.
///
/// The auction is derived from its call history rather than stored as a
/// handful of flags, so a flag and the record can never disagree and the
/// whole thing replays from a save by replaying the calls.
@immutable
final class AuctionState {
  AuctionState({
    required this.rules,
    required this.seatCount,
    required this.openingSeat,
    required this.dealerSeat,
    required List<AuctionCall> calls,
  }) : calls = List<AuctionCall>.unmodifiable(calls);

  /// A fresh auction, nobody having spoken.
  factory AuctionState.opening({
    required BiddingRules rules,
    required int seatCount,
    required int openingSeat,
    required int dealerSeat,
  }) =>
      AuctionState(
        rules: rules,
        seatCount: seatCount,
        openingSeat: openingSeat,
        dealerSeat: dealerSeat,
        calls: const <AuctionCall>[],
      );

  final BiddingRules rules;
  final int seatCount;

  /// The seat that speaks first; the dealer's right-hand neighbour.
  final int openingSeat;

  final int dealerSeat;

  /// Every call made, in order.
  final List<AuctionCall> calls;

  /// The seats that have passed, which is permanent for this hand.
  Set<int> get passedSeats => <int>{
        for (final AuctionCall call in calls)
          if (call.isPass) call.seat,
      };

  /// The highest contract offered so far, or null when nobody has bid.
  int? get standingBid {
    int? best;
    for (final AuctionCall call in calls) {
      final int? tricks = call.tricks;
      if (tricks != null && (best == null || tricks > best)) {
        best = tricks;
      }
    }
    return best;
  }

  /// The seat holding the standing bid, or null when nobody has bid.
  int? get standingBidder {
    int? seat;
    int? best;
    for (final AuctionCall call in calls) {
      final int? tricks = call.tricks;
      if (tricks != null && (best == null || tricks > best)) {
        best = tricks;
        seat = call.seat;
      }
    }
    return seat;
  }

  /// Seats that may still bid: everyone who has not passed.
  ///
  /// The standing bidder counts as active even though it will not be asked
  /// to raise itself; [isComplete] is what resolves that.
  Set<int> get activeSeats => <int>{
        for (int seat = 0; seat < seatCount; seat++)
          if (!passedSeats.contains(seat)) seat,
      };

  /// Whether the auction has finished.
  ///
  /// Three ways to end, and the first is the one that is easy to get wrong:
  ///
  /// * somebody bid and everyone else has passed -- the standing bidder is
  ///   not asked to outbid itself, so the auction is over the moment it is
  ///   the only seat left;
  /// * somebody bid the maximum, which nobody can raise;
  /// * everybody passed, which hands the hand to [forcedSeat].
  bool get isComplete {
    if (standingBid == rules.maximumBid) {
      return true;
    }
    if (passedSeats.length == seatCount) {
      return true;
    }
    return standingBid != null && activeSeats.length <= 1;
  }

  /// Whether every seat passed without a single bid.
  bool get passedOut => standingBid == null && passedSeats.length == seatCount;

  /// The seat a passed-out hand is forced on, or null when the rule is to
  /// redeal.
  int? get forcedSeat {
    if (!passedOut) {
      return null;
    }
    return switch (rules.passOutRule) {
      PassOutRule.redeal => null,
      PassOutRule.dealerMustBid => dealerSeat,
      PassOutRule.openerMustBid => openingSeat,
    };
  }

  /// Whether this hand must be redealt: everyone passed at a table that does
  /// not force a contract.
  bool get needsRedeal => passedOut && rules.passOutRule == PassOutRule.redeal;

  /// Who won the contract, or null while the auction is unfinished or the
  /// hand must be redealt.
  int? get winner {
    if (!isComplete) {
      return null;
    }
    return passedOut ? forcedSeat : standingBidder;
  }

  /// The contract value, or null while unresolved.
  int? get winningBid {
    if (!isComplete) {
      return null;
    }
    if (!passedOut) {
      return standingBid;
    }
    return forcedSeat == null ? null : rules.effectiveForcedBid;
  }

  /// Whether the contract was given rather than taken.
  bool get wasForced => passedOut && forcedSeat != null;

  /// The seat to speak, or null when the auction is over.
  ///
  /// Turn order walks on from the last call, skipping seats that have
  /// already passed, so a pass really does remove a seat from the auction
  /// rather than merely making it decline each time round.
  int? get seatToAct {
    if (isComplete) {
      return null;
    }
    int seat = calls.isEmpty ? openingSeat : (calls.last.seat + 1) % seatCount;
    for (int step = 0; step < seatCount; step++) {
      if (!passedSeats.contains(seat)) {
        return seat;
      }
      seat = (seat + 1) % seatCount;
    }
    return null;
  }

  /// The contracts [seat] may offer right now.
  ///
  /// Empty when it is not that seat's turn, which is what makes an
  /// out-of-turn bid impossible rather than merely discouraged.
  List<int> legalBids(int seat) {
    if (seatToAct != seat) {
      return const <int>[];
    }
    final int floor = standingBid == null ? rules.minimumBid : standingBid! + 1;
    return <int>[
      for (int bid = floor; bid <= rules.maximumBid; bid++) bid,
    ];
  }

  /// Whether [seat] may pass right now.
  bool canPass(int seat) => seatToAct == seat;

  /// The auction with [call] appended. Validation belongs to the engine.
  AuctionState withCall(AuctionCall call) => AuctionState(
        rules: rules,
        seatCount: seatCount,
        openingSeat: openingSeat,
        dealerSeat: dealerSeat,
        calls: <AuctionCall>[...calls, call],
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'openingSeat': openingSeat,
        'dealerSeat': dealerSeat,
        'calls': <Map<String, Object?>>[
          for (final AuctionCall call in calls) call.toJson(),
        ],
      };

  /// Rebuilds an auction from a save. [rules] and [seatCount] come from the
  /// profile, which is stored separately and in full.
  static AuctionState fromJson(
    Map<String, Object?> json, {
    required BiddingRules rules,
    required int seatCount,
  }) =>
      AuctionState(
        rules: rules,
        seatCount: seatCount,
        openingSeat: json['openingSeat']! as int,
        dealerSeat: json['dealerSeat']! as int,
        calls: <AuctionCall>[
          for (final Object? entry in json['calls']! as List<Object?>)
            AuctionCall.fromJson(entry! as Map<String, Object?>),
        ],
      );

  @override
  String toString() => 'AuctionState(calls: $calls, standing: $standingBid '
      'by $standingBidder, complete: $isComplete)';
}
