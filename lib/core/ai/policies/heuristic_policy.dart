import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../game_engine/trick/trick.dart';
import '../../game_engine/trick/trick_resolver.dart';
import '../../util/seeded_random.dart';
import '../ai_difficulty.dart';
import '../ai_policy.dart';
import '../card_tracker.dart';
import '../seat_observation.dart';

/// Plays by rule of thumb rather than by search.
///
/// The objective it maximises is "tricks for my side", which is exactly the
/// Koz Maca objective: every trick pays the same and there is no contract to
/// make or break. The auction modes need a declarer-aware evaluation on top of
/// this -- a defender there wants the declarer to fall short, which is not the
/// same as taking tricks -- so this policy is scoped to the trick-maximising
/// modes and says so rather than pretending to generalise.
///
/// Everything it knows arrives through [SeatObservation] and the inferences
/// `CardTracker` draws from the public record. It never sees a hidden hand,
/// and card legality is never re-decided here: it chooses from
/// `observation.legalMoves`, and asks [TrickResolver] who is winning rather
/// than reimplementing the comparison.
///
/// No strength claim is attached to it yet. Measuring it against
/// `RandomLegalPolicy` on paired deals is a separate step; see
/// docs/AI_BENCHMARKS.md.
final class HeuristicPolicy implements AiPolicy {
  HeuristicPolicy({required int seed, this.blunderRate = 0})
      : _random = SeededRandom(seed) {
    if (blunderRate < 0 || blunderRate > 1) {
      throw ArgumentError.value(
        blunderRate,
        'blunderRate',
        'must be a probability',
      );
    }
  }

  /// The Beginner level: the same reasoning, with a documented share of
  /// decisions replaced by a uniformly random legal card.
  ///
  /// Difficulty is an algorithmic difference, never a delay and never a
  /// handicap applied to the player's own cards. A weak human reasons
  /// correctly most of the time and throws a card away the rest of the time,
  /// so that is what the weak level does.
  factory HeuristicPolicy.beginner({required int seed}) =>
      HeuristicPolicy(seed: seed, blunderRate: beginnerBlunderRate);

  /// Share of Beginner decisions that are random instead of reasoned.
  static const double beginnerBlunderRate = 0.4;

  final SeededRandom _random;

  /// Probability that a decision is replaced by a random legal card.
  final double blunderRate;

  @override
  String get id => blunderRate == 0 ? 'heuristic' : 'heuristic-blunder';

  @override
  String get displayName =>
      blunderRate == 0 ? 'Sezgisel' : 'Sezgisel (hata yapan)';

  @override
  Future<PlayingCard> chooseCard(
    SeatObservation observation,
    AiComputeBudget budget,
  ) async =>
      chooseCardSync(observation);

  /// Synchronous variant for the headless simulator and the benchmark CLI,
  /// which run millions of decisions and should not pay for a future per card.
  PlayingCard chooseCardSync(SeatObservation observation) {
    final List<PlayingCard> legal = observation.legalMoves;
    if (legal.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    if (legal.length == 1) {
      return legal.first;
    }
    if (blunderRate > 0 && _random.nextBool(blunderRate)) {
      return legal[_random.nextInt(legal.length)];
    }
    final CardTracker tracker = CardTracker.fromObservation(observation);
    return observation.currentTrick.isEmpty
        ? _lead(observation, tracker, legal)
        : _follow(observation, tracker, legal);
  }

  /// Opens a trick.
  PlayingCard _lead(
    SeatObservation observation,
    CardTracker tracker,
    List<PlayingCard> legal,
  ) {
    final Suit? trump = observation.trump;

    // Cash a side-suit master that nobody is known to be void in. It takes the
    // trick outright, and a seat still obliged to follow cannot trump it.
    final List<PlayingCard> sideMasters = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump && tracker.isMaster(card)) card,
    ];
    final PlayingCard? safeMaster =
        _bestUnrufflable(sideMasters, observation, tracker);
    if (safeMaster != null) {
      return safeMaster;
    }

    final List<PlayingCard> trumps = trump == null
        ? const <PlayingCard>[]
        : <PlayingCard>[
            for (final PlayingCard card in legal)
              if (card.suit == trump) card,
          ];
    if (trump != null && trumps.isNotEmpty) {
      final int outstanding = tracker.unseenCountOf(trump);
      if (outstanding == 0) {
        // Every trump left is ours, so each one is a winner whenever we choose
        // to spend it. Spend the smallest first and keep the big ones.
        return _lowest(trumps);
      }
      // Draw trumps while holding the top one: a round of trump costs us one
      // card and strips up to two from the opponents, which is what clears the
      // way for side-suit length later in the hand.
      final PlayingCard highestTrump = _highest(trumps);
      if (tracker.isMaster(highestTrump)) {
        return highestTrump;
      }
    }

    // A master that an opponent could ruff is still the best card of its suit.
    if (sideMasters.isNotEmpty) {
      return _highest(sideMasters);
    }

    // Nothing here wins. Lead low from the shortest side suit: it keeps trumps
    // and length for later tricks, forces an opponent to spend a winner now,
    // and shortens us towards a void we can ruff from.
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump) card,
    ];
    if (side.isNotEmpty) {
      return _lowestOfShortestSuit(side, observation.hand);
    }
    return _lowest(legal);
  }

  /// Plays into a trick already under way.
  PlayingCard _follow(
    SeatObservation observation,
    CardTracker tracker,
    List<PlayingCard> legal,
  ) {
    final PlayedCard leader = TrickResolver.winningPlay(
      observation.currentTrick,
      trump: observation.trump,
    );

    // Our side already holds the trick. Overtaking spends a card to buy
    // something we have, so keep the card and throw the least useful one.
    if (observation.isTeammate(leader.seat)) {
      return _discard(legal, observation, tracker);
    }

    final List<PlayingCard> winners = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (_wouldLead(card, observation)) card,
    ];
    if (winners.isEmpty) {
      return _discard(legal, observation, tracker);
    }

    // Contest it with the cheapest card that does the job. Every trick is
    // worth the same here, so a trick we decline is a trick an opponent banks;
    // the only question is how little we can pay for it. A later seat may take
    // it back, but declining would have handed it over for certain.
    return _lowest(winners);
  }

  /// Throws the card we will miss least.
  PlayingCard _discard(
    List<PlayingCard> legal,
    SeatObservation observation,
    CardTracker tracker,
  ) {
    final Suit? trump = observation.trump;
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump) card,
    ];
    // Keep trumps if anything else is legal, and keep masters if anything else
    // is spare: both of those are tricks later in the hand.
    final List<PlayingCard> pool = side.isEmpty ? legal : side;
    final List<PlayingCard> spare = <PlayingCard>[
      for (final PlayingCard card in pool)
        if (!tracker.isMaster(card)) card,
    ];
    return _lowestOfShortestSuit(
      spare.isEmpty ? pool : spare,
      observation.hand,
    );
  }

  /// The strongest card in [candidates] whose suit every opponent might still
  /// have to follow, or null when each candidate can be ruffed.
  PlayingCard? _bestUnrufflable(
    List<PlayingCard> candidates,
    SeatObservation observation,
    CardTracker tracker,
  ) {
    PlayingCard? best;
    for (final PlayingCard card in candidates) {
      if (_anyOpponentKnownVoid(card.suit, observation, tracker)) {
        continue;
      }
      if (best == null || card.strength > best.strength) {
        best = card;
      }
    }
    return best;
  }

  bool _anyOpponentKnownVoid(
    Suit suit,
    SeatObservation observation,
    CardTracker tracker,
  ) {
    for (int seat = 0; seat < observation.seating.playerCount; seat++) {
      if (seat == observation.seat || observation.isTeammate(seat)) {
        continue;
      }
      if (tracker.isKnownVoid(seat, suit)) {
        return true;
      }
    }
    return false;
  }

  /// Whether playing [card] would put us in front of the trick right now.
  ///
  /// Asked by building the trick and consulting [TrickResolver], so the policy
  /// cannot disagree with the engine about who is winning.
  bool _wouldLead(PlayingCard card, SeatObservation observation) {
    final Trick candidate = observation.currentTrick.withPlay(
      PlayedCard(seat: observation.seat, card: card),
    );
    return TrickResolver.winnerSeat(candidate, trump: observation.trump) ==
        observation.seat;
  }

  static PlayingCard _highest(List<PlayingCard> cards) {
    PlayingCard best = cards.first;
    for (final PlayingCard card in cards) {
      if (card.strength > best.strength) {
        best = card;
      }
    }
    return best;
  }

  static PlayingCard _lowest(List<PlayingCard> cards) {
    PlayingCard best = cards.first;
    for (final PlayingCard card in cards) {
      if (card.strength < best.strength) {
        best = card;
      }
    }
    return best;
  }

  /// The lowest card in [candidates], breaking ties towards the suit we hold
  /// fewest of, because shedding a short suit is what creates a ruffing void.
  static PlayingCard _lowestOfShortestSuit(
    List<PlayingCard> candidates,
    List<PlayingCard> hand,
  ) {
    PlayingCard best = candidates.first;
    int bestLength = _suitLength(hand, best.suit);
    for (final PlayingCard card in candidates) {
      final int length = _suitLength(hand, card.suit);
      if (card.strength < best.strength ||
          (card.strength == best.strength && length < bestLength)) {
        best = card;
        bestLength = length;
      }
    }
    return best;
  }

  static int _suitLength(List<PlayingCard> hand, Suit suit) {
    int count = 0;
    for (final PlayingCard card in hand) {
      if (card.suit == suit) {
        count++;
      }
    }
    return count;
  }
}
