import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../game_engine/trick/trick.dart';
import '../../game_engine/trick/trick_resolver.dart';
import '../../util/seeded_random.dart';
import '../ai_difficulty.dart';
import '../ai_policy.dart';
import '../card_tracker.dart';
import '../partnership_plan.dart';
import '../seat_observation.dart';
import 'card_choice.dart';

/// Why a card was chosen.
///
/// Carried out of the decision rather than reconstructed afterwards, so an
/// explanation shown to the player is the actual reason the card was picked
/// and not a plausible story written later. That distinction is the whole
/// value of it: a made-up explanation teaches the player something false.
enum PartnershipReason {
  /// Only one card was legal.
  forced,

  /// Deliberately random, at the weakest level.
  blunder,

  /// Drawing the opponents' trumps while the side holds the best one.
  drawTrumps,

  /// Cashing a card no opponent can beat or ruff.
  cashWinner,

  /// Leading a suit the partner is out of, so the partner can ruff.
  ruffFromPartner,

  /// Leading so the next trick is opened from the other hand of the side.
  manageEntry,

  /// Leading low, keeping the winners for later.
  leadLow,

  /// Taking a trick the side needs, as cheaply as it can be taken.
  winCheaply,

  /// Overtaking nobody: the partner already holds the trick.
  partnerIsWinning,

  /// Cutting with trump because the lead suit is gone and trump is
  /// compulsory.
  forcedRuff,

  /// Letting the trick go and throwing the least useful card.
  discard,

  /// Letting the trick go on purpose, because taking it would cost the side.
  duck,
}

/// One decision, with the reason behind it.
final class PartnershipDecision {
  const PartnershipDecision(this.card, this.reason);

  final PlayingCard card;
  final PartnershipReason reason;

  @override
  String toString() => 'PartnershipDecision($card, ${reason.name})';
}

/// Esli Ihaleli Batak's card player.
///
/// The objective it maximises is the **side's** result, which is not the same
/// as its own trick count and is sometimes its opposite: a trick taken off
/// one's own partner changes nothing for the side and costs a card. So every
/// branch below asks a team question. [TeamPlan] holds the arithmetic -- what
/// the side still needs and whether it can still get there -- and this file
/// holds the tactics.
///
/// ### What it does that a solo policy cannot
///
/// * **Two hands, one plan.** When the open hand is face up and this seat is
///   the declarer, the two hands are planned together: trumps are counted
///   across both, a winner is cashed from whichever hand holds it, and the
///   lead is steered to the hand that should be on lead next. That last one
///   -- entry management -- is what separates a declarer from somebody
///   playing two hands in turn.
/// * **It does not overtake its partner.** When the side already holds the
///   trick the card goes to the discard logic, not the winning logic, unless
///   the rules force a raise. The rules are never bent for a partner: a
///   compulsory raise is compulsory, and this policy chooses from
///   `legalMoves` like every other.
/// * **It counts the contract, not the tricks.** A defending side that has
///   cleared its floor plays for the break; one that has not plays for the
///   floor first, because missing it is charged at the contract's value.
/// * **It knows when a trick is worthless.** A declaring side whose contract
///   is already broken is paid the same whatever else happens, so it stops
///   spending winners -- except to stop a sweep, which still costs real
///   points.
///
/// Everything it knows arrives through [SeatObservation] and the inferences
/// [CardTracker] draws from the public record. The open hand reaches it the
/// same way, because it is public. No hidden hand is ever read.
final class PartnershipPolicy implements AiPolicy, SyncCardPolicy {
  PartnershipPolicy({
    required int seed,
    this.blunderRate = 0,
  }) : _random = SeededRandom(seed) {
    if (blunderRate < 0 || blunderRate > 1) {
      throw ArgumentError.value(
        blunderRate,
        'blunderRate',
        'must be a probability',
      );
    }
  }

  /// The Baslangic level: the same reasoning with a documented share of
  /// decisions replaced by a uniformly random legal card.
  ///
  /// Difficulty is an algorithmic difference, never a delay and never a
  /// handicap applied to the player's own cards. A weak partner reasons
  /// correctly most of the time and throws a card away the rest of the time,
  /// so that is what the weak level does.
  factory PartnershipPolicy.beginner({required int seed}) =>
      PartnershipPolicy(seed: seed, blunderRate: beginnerBlunderRate);

  /// Share of Baslangic decisions that are random instead of reasoned.
  static const double beginnerBlunderRate = 0.4;

  final SeededRandom _random;

  /// Probability that a decision is replaced by a random legal card.
  final double blunderRate;

  @override
  String get id => blunderRate == 0 ? 'partnership' : 'partnership-blunder';

  @override
  String get displayName =>
      blunderRate == 0 ? 'Eşli sezgisel' : 'Eşli sezgisel (hata yapan)';

  @override
  Future<PlayingCard> chooseCard(
    SeatObservation observation,
    AiComputeBudget budget,
  ) async =>
      chooseCardSync(observation);

  /// Declaring is not part of this mode: the auction says the number.
  ///
  /// Reached only if a profile were wired wrongly, so it fails loudly rather
  /// than answering a question the mode never asks.
  @override
  Future<int> chooseDeclaration(
    SeatObservation observation,
    List<int> options,
    AiComputeBudget budget,
  ) async =>
      throw StateError('Esli Ihaleli Batak has no declaration round');

  @override
  PlayingCard chooseCardSync(SeatObservation observation) =>
      decide(observation).card;

  /// Chooses a card and says why.
  PartnershipDecision decide(SeatObservation observation) {
    final List<PlayingCard> legal = observation.legalMoves;
    if (legal.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    if (legal.length == 1) {
      return PartnershipDecision(legal.first, PartnershipReason.forced);
    }
    if (blunderRate > 0 && _random.nextBool(blunderRate)) {
      return PartnershipDecision(
        legal[_random.nextInt(legal.length)],
        PartnershipReason.blunder,
      );
    }

    final CardTracker tracker = CardTracker.fromObservation(observation);
    final TeamPlan plan = TeamPlan.from(observation);
    return observation.currentTrick.isEmpty
        ? _lead(observation, tracker, plan, legal)
        : _follow(observation, tracker, plan, legal);
  }

  // ---------------------------------------------------------------- leading

  /// Opens a trick.
  PartnershipDecision _lead(
    SeatObservation observation,
    CardTracker tracker,
    TeamPlan plan,
    List<PlayingCard> legal,
  ) {
    final Suit? trump = observation.trump;

    // A hand that is paid nothing more has nothing to spend. Lead the card
    // least likely to matter and keep the rest.
    if (!plan.tricksStillPay) {
      return PartnershipDecision(
        _cheapest(legal, observation, tracker, trump),
        PartnershipReason.duck,
      );
    }

    final List<PlayingCard> trumps = trump == null
        ? const <PlayingCard>[]
        : <PlayingCard>[
            for (final PlayingCard card in legal)
              if (card.suit == trump) card,
          ];

    // 1. Draw trumps. Worth doing while the side holds the best trump left
    //    and the opponents still hold any, because every round of trump costs
    //    the side one card and strips up to two from the opponents -- which
    //    is what lets side-suit length run later. Not worth doing when the
    //    side's trumps are wanted for ruffing instead: a short suit opposite
    //    a long one is a source of tricks that drawing would spend.
    if (trump != null && trumps.isNotEmpty) {
      final int outstanding = _opponentTrumpsLeft(observation, tracker, trump);
      if (outstanding == 0 && !plan.objectiveMet) {
        // Every trump left is ours. Each is a winner whenever we choose to
        // spend it, so spend the smallest and keep the big ones.
        return PartnershipDecision(
          lowestOf(trumps),
          PartnershipReason.drawTrumps,
        );
      }
      final PlayingCard top = highestOf(trumps);
      if (outstanding > 0 &&
          tracker.isMaster(top) &&
          !_wantsToRuff(observation, tracker, trump)) {
        return PartnershipDecision(top, PartnershipReason.drawTrumps);
      }
    }

    // 2. Cash a side-suit card nobody can beat and nobody can ruff. It takes
    //    the trick outright, and a seat still obliged to follow cannot trump
    //    it.
    final List<PlayingCard> sideMasters = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump && tracker.isMaster(card)) card,
    ];
    final PlayingCard? safeMaster =
        bestUnrufflable(sideMasters, observation, tracker);
    if (safeMaster != null) {
      return PartnershipDecision(safeMaster, PartnershipReason.cashWinner);
    }

    // 3. Lead a suit the partner is out of, so the partner's trump takes the
    //    trick. Only with a partner whose hand is known -- in the closed mode
    //    this is an inference from the public record, which [CardTracker]
    //    makes, and in the open mode it is simply read off the table.
    final PlayingCard? ruffer =
        _ruffLead(observation, tracker, plan, legal, trump);
    if (ruffer != null) {
      return PartnershipDecision(ruffer, PartnershipReason.ruffFromPartner);
    }

    // 4. Steer the next lead to the hand that wants it. Only possible when
    //    both hands of the side are known, which is the open mode's whole
    //    advantage.
    final PlayingCard? entry = _entryLead(observation, tracker, legal, trump);
    if (entry != null) {
      return PartnershipDecision(entry, PartnershipReason.manageEntry);
    }

    // 5. A master an opponent could ruff is still the best card of its suit.
    if (sideMasters.isNotEmpty) {
      return PartnershipDecision(
        highestOf(sideMasters),
        PartnershipReason.cashWinner,
      );
    }

    // 6. Nothing here wins. Lead low from the shortest side suit: it keeps
    //    trumps and length for later, forces an opponent to spend a winner
    //    now, and shortens the hand towards a void it can ruff from.
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump) card,
    ];
    return PartnershipDecision(
      side.isEmpty
          ? lowestOf(legal)
          : lowestOfShortestSuit(side, observation.hand),
      PartnershipReason.leadLow,
    );
  }

  /// A lead that lets the partner ruff, or null when there is none worth it.
  ///
  /// Three things have to hold: the partner is out of the suit, the partner
  /// still holds a trump, and this side still wants tricks. The third matters
  /// -- a side that has made its contract and is sitting on the lead has
  /// better uses for its partner's trump.
  PlayingCard? _ruffLead(
    SeatObservation observation,
    CardTracker tracker,
    TeamPlan plan,
    List<PlayingCard> legal,
    Suit? trump,
  ) {
    final int? partner = observation.partnerSeat;
    if (trump == null || partner == null || plan.objectiveMet) {
      return null;
    }
    if (observation.handSizes[partner] == 0) {
      return null;
    }
    final bool partnerHasTrump = observation.seesHandOf(partner)
        ? observation
            .openHandOf(partner)
            .any((PlayingCard c) => c.suit == trump)
        : !tracker.isKnownVoid(partner, trump);
    if (!partnerHasTrump) {
      return null;
    }
    PlayingCard? best;
    for (final PlayingCard card in legal) {
      if (card.suit == trump) {
        continue;
      }
      final bool partnerVoid = observation.seesHandOf(partner)
          ? !observation
              .openHandOf(partner)
              .any((PlayingCard c) => c.suit == card.suit)
          : tracker.isKnownVoid(partner, card.suit);
      if (!partnerVoid) {
        continue;
      }
      // Spend the cheapest card of the suit: the trick is meant to be won by
      // the partner's trump, not by this card.
      if (best == null || card.strength < best.strength) {
        best = card;
      }
    }
    return best;
  }

  /// A lead chosen so the *other* hand of the side opens the next trick.
  ///
  /// Only available with both hands known. The question it answers is the one
  /// that makes two hands into one plan: a long suit that will run is useless
  /// if the wrong hand is on lead when the trumps are gone, so a trick is
  /// deliberately given to the hand that holds it. Returns null when the hand
  /// already on lead is the one that wants to be.
  PlayingCard? _entryLead(
    SeatObservation observation,
    CardTracker tracker,
    List<PlayingCard> legal,
    Suit? trump,
  ) {
    final int? partner = observation.partnerSeat;
    if (partner == null || !observation.seesHandOf(partner)) {
      return null;
    }
    final List<PlayingCard> partnerHand = observation.openHandOf(partner);
    if (partnerHand.isEmpty) {
      return null;
    }
    // The suit the side is relying on, and which hand holds it.
    final Suit? mineLong = _longestSideSuit(observation.hand, trump);
    final Suit? theirsLong = _longestSideSuit(partnerHand, trump);
    if (theirsLong == null || theirsLong == mineLong) {
      return null;
    }
    final int theirLength = suitLength(partnerHand, theirsLong);
    if (theirLength < 4) {
      // Not a suit worth crossing the table for.
      return null;
    }
    // Lead a card of that suit the partner can take: the trick lands opposite
    // and the next one is opened from there.
    PlayingCard? best;
    for (final PlayingCard card in legal) {
      if (card.suit != theirsLong) {
        continue;
      }
      final bool partnerCanWin = partnerHand.any(
        (PlayingCard c) => c.suit == theirsLong && c.strength > card.strength,
      );
      if (!partnerCanWin) {
        continue;
      }
      if (best == null || card.strength < best.strength) {
        best = card;
      }
    }
    return best;
  }

  // -------------------------------------------------------------- following

  /// Plays into a trick already under way.
  PartnershipDecision _follow(
    SeatObservation observation,
    CardTracker tracker,
    TeamPlan plan,
    List<PlayingCard> legal,
  ) {
    final PlayedCard leader = TrickResolver.winningPlay(
      observation.currentTrick,
      trump: observation.trump,
    );
    final Suit? trump = observation.trump;

    final List<PlayingCard> winners = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (wouldLead(card, observation)) card,
    ];

    // Our own side already holds the trick. Overtaking buys something the
    // side has, and costs a card. So throw the least useful card instead --
    // unless every legal card wins it, which the compulsory raise can force,
    // in which case the cheapest of them loses the least.
    if (observation.isTeammate(leader.seat)) {
      if (winners.length == legal.length) {
        return PartnershipDecision(
          lowestOf(legal),
          PartnershipReason.partnerIsWinning,
        );
      }
      final List<PlayingCard> losers = <PlayingCard>[
        for (final PlayingCard card in legal)
          if (!wouldLead(card, observation)) card,
      ];
      return PartnershipDecision(
        _cheapest(losers, observation, tracker, trump),
        PartnershipReason.partnerIsWinning,
      );
    }

    // An opponent holds it and nothing of ours beats it. The only question
    // left is what to throw.
    if (winners.isEmpty) {
      final bool ruffing = trump != null &&
          legal.every((PlayingCard c) => c.suit == trump) &&
          observation.currentTrick.leadSuit != trump;
      return PartnershipDecision(
        _cheapest(legal, observation, tracker, trump),
        ruffing ? PartnershipReason.forcedRuff : PartnershipReason.discard,
      );
    }

    // A trick that pays the side nothing is not worth a card. The one
    // exception is a sweep forming against us, which costs real points and is
    // worth breaking.
    if (!plan.tricksStillPay) {
      final List<PlayingCard> losers = <PlayingCard>[
        for (final PlayingCard card in legal)
          if (!wouldLead(card, observation)) card,
      ];
      if (losers.isNotEmpty) {
        return PartnershipDecision(
          _cheapest(losers, observation, tracker, trump),
          PartnershipReason.duck,
        );
      }
      return PartnershipDecision(
        lowestOf(winners),
        PartnershipReason.forced,
      );
    }

    // Take it with the cheapest card that does the job. A later seat may take
    // it back; declining would have handed it over for certain.
    return PartnershipDecision(
      lowestOf(winners),
      PartnershipReason.winCheaply,
    );
  }

  // ------------------------------------------------------------------ parts

  /// The card the side will miss least.
  ///
  /// Keeps trumps while anything else is legal and keeps masters while
  /// anything else is spare: both of those are tricks later in the hand.
  /// Ties break towards the shortest suit, because shedding a short suit is
  /// what creates a void to ruff from.
  PlayingCard _cheapest(
    List<PlayingCard> candidates,
    SeatObservation observation,
    CardTracker tracker,
    Suit? trump,
  ) {
    if (candidates.length == 1) {
      return candidates.first;
    }
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in candidates)
        if (card.suit != trump) card,
    ];
    final List<PlayingCard> pool = side.isEmpty ? candidates : side;
    final List<PlayingCard> spare = <PlayingCard>[
      for (final PlayingCard card in pool)
        if (!tracker.isMaster(card)) card,
    ];
    return lowestOfShortestSuit(
      spare.isEmpty ? pool : spare,
      observation.hand,
    );
  }

  /// Trumps the two opponents can still hold between them.
  ///
  /// Counted from the unseen set, which already excludes the open hand: a
  /// trump lying face up on the table is not an opponent's trump, and
  /// treating it as one is what makes a declarer draw a round it did not need
  /// to.
  int _opponentTrumpsLeft(
    SeatObservation observation,
    CardTracker tracker,
    Suit trump,
  ) {
    final int unseen = tracker.unseenCountOf(trump);
    final int? partner = observation.partnerSeat;
    if (partner == null || observation.seesHandOf(partner)) {
      return unseen;
    }
    // In the closed mode the partner's trumps are part of the unseen set, so
    // the share expected to sit opposite is subtracted rather than counted as
    // enemy trumps -- otherwise a declarer draws a round it did not need to.
    int hidden = 0;
    for (int seat = 0; seat < observation.handSizes.length; seat++) {
      if (seat == observation.seat || observation.seesHandOf(seat)) {
        continue;
      }
      hidden += observation.handSizes[seat];
    }
    if (hidden <= 0) {
      return unseen;
    }
    final int opposite =
        (unseen * observation.handSizes[partner] / hidden).round();
    final int left = unseen - opposite;
    return left < 0 ? 0 : left;
  }

  /// Whether the side's trumps are better spent ruffing than drawing.
  ///
  /// True when one hand of the side is short in a suit the other is long in
  /// and still holds trumps for it: that is a source of tricks which drawing
  /// trumps would spend. Only answerable with both hands known; in the closed
  /// mode it returns false, which is the cautious reading -- draw, and find
  /// out.
  bool _wantsToRuff(
    SeatObservation observation,
    CardTracker tracker,
    Suit trump,
  ) {
    final int? partner = observation.partnerSeat;
    if (partner == null || !observation.seesHandOf(partner)) {
      return false;
    }
    final List<PlayingCard> partnerHand = observation.openHandOf(partner);
    final int partnerTrumps =
        partnerHand.where((PlayingCard c) => c.suit == trump).length;
    if (partnerTrumps == 0) {
      return false;
    }
    for (final Suit suit in Suit.values) {
      if (suit == trump) {
        continue;
      }
      final int mine = suitLength(observation.hand, suit);
      final int theirs = suitLength(partnerHand, suit);
      // A doubleton or shorter opposite a four-card holding is the shape that
      // produces ruffs; anything flatter is not worth keeping trumps for.
      if (theirs <= 1 && mine >= 4) {
        return true;
      }
      if (mine <= 1 && theirs >= 4) {
        return true;
      }
    }
    return false;
  }

  /// The longest suit that is not trump, or null when there is none.
  static Suit? _longestSideSuit(List<PlayingCard> hand, Suit? trump) {
    Suit? best;
    int bestLength = 0;
    for (final Suit suit in Suit.values) {
      if (suit == trump) {
        continue;
      }
      final int length = suitLength(hand, suit);
      if (length > bestLength) {
        bestLength = length;
        best = suit;
      }
    }
    return best;
  }
}
