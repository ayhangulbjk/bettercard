import '../../cards/playing_card.dart';
import '../../cards/rank.dart';
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

  @override
  Future<int> chooseDeclaration(
    SeatObservation observation,
    List<int> options,
    AiComputeBudget budget,
  ) async =>
      chooseDeclarationSync(observation, options);

  /// Counts the tricks the hand looks likely to win, then promises that many.
  ///
  /// A deliberately plain count, because a promise made from a static hand is
  /// a static-hand problem: top trumps, trump length beyond what the others
  /// can draw, and side-suit winners that are likely to survive. It does not
  /// model the other three seats' promises, and it never promises nil -- with
  /// cutting compulsory a nil hand can be forced to take a trick by a suit it
  /// is void in, so an "el almaz" worth -50 is a bet this policy has no way to
  /// evaluate. Declaring 1 instead is the honest floor.
  ///
  /// No strength claim attaches to this; see docs/AI_BENCHMARKS.md.
  int chooseDeclarationSync(SeatObservation observation, List<int> options) {
    if (options.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    if (blunderRate > 0 && _random.nextBool(blunderRate)) {
      return options[_random.nextInt(options.length)];
    }

    final double estimate = _expectedTricks(observation);
    int promise = estimate.round();

    // Never nil, and never more than the hand can hold.
    final int floor = options.firstWhere(
      (int value) => value >= 1,
      orElse: () => options.last,
    );
    if (promise < floor) {
      promise = floor;
    }
    if (promise > options.last) {
      promise = options.last;
    }
    return promise;
  }

  /// Expected trick count for a hand that has not been played yet.
  double _expectedTricks(SeatObservation observation) {
    final Suit? trump = observation.trump;
    final Map<Suit, List<PlayingCard>> bySuit = <Suit, List<PlayingCard>>{};
    for (final PlayingCard card in observation.hand) {
      bySuit.putIfAbsent(card.suit, () => <PlayingCard>[]).add(card);
    }

    double tricks = 0;
    for (final MapEntry<Suit, List<PlayingCard>> entry in bySuit.entries) {
      final List<PlayingCard> cards = entry.value
        ..sort(
            (PlayingCard a, PlayingCard b) => b.strength.compareTo(a.strength));
      final bool isTrump = entry.key == trump;
      final int length = cards.length;

      for (int index = 0; index < cards.length; index++) {
        final Rank rank = cards[index].rank;
        if (rank == Rank.ace) {
          tricks += 1;
        } else if (rank == Rank.king) {
          // A king needs one card to duck under it before it can win.
          tricks += length >= 2 ? 0.85 : 0.45;
        } else if (rank == Rank.queen) {
          tricks += length >= 3 ? 0.55 : 0.2;
        } else if (isTrump && rank == Rank.jack && length >= 4) {
          tricks += 0.3;
        }
      }

      if (isTrump) {
        // Trumps past the fourth tend to win once the others are drawn.
        tricks += length > 4 ? (length - 4) * 0.8 : 0;
      } else if (trump != null && length <= 1) {
        // A short side suit is a chance to cut -- worth something, but less
        // than tables assume, because every other seat must cut as well.
        tricks += length == 0 ? 0.5 : 0.25;
      }
    }
    return tricks;
  }

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
