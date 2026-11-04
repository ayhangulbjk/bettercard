import '../../cards/playing_card.dart';
import '../../cards/suit.dart';
import '../../game_engine/trick/trick.dart';
import '../../game_engine/trick/trick_resolver.dart';
import '../../util/seeded_random.dart';
import '../ai_difficulty.dart';
import '../ai_policy.dart';
import '../card_tracker.dart';
import '../seat_observation.dart';
import 'card_choice.dart';
import 'declaration_evaluator.dart';

/// Plays by rule of thumb rather than by search.
///
/// The objective it maximises is **points**, which under Koz Maca's
/// declaration scoring is not the same as tricks and is sometimes its
/// opposite. A seat that has already made its word gains one point from the
/// next trick and loses its whole stake a couple of tricks later, so past
/// that line the correct play is to lose on purpose. That is the single
/// decision this policy makes before anything else; see [_Intent].
///
/// With no declaration round the two objectives coincide and it maximises
/// tricks, which is what the mode asks for. The auction modes need a
/// declarer-aware evaluation on top of this -- a defender there wants the
/// declarer to fall short, which is a third objective again -- so this policy
/// is scoped to the modes it fits and says so rather than pretending to
/// generalise.
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
final class HeuristicPolicy implements AiPolicy, SyncCardPolicy {
  HeuristicPolicy({
    required int seed,
    this.blunderRate = 0,
    this.scoreAware = true,
  }) : _random = SeededRandom(seed) {
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

  /// The trick-maximising control, kept so the score-aware version has
  /// something to be measured against.
  ///
  /// This is what the policy did before it knew what a declaration was:
  /// promise the rounded estimate, never promise nil, and take every trick it
  /// can for the rest of the hand. Claiming the newer reasoning is better is
  /// only allowed with a paired margin over this, which is why it is a flag
  /// on the real policy rather than a deleted commit. See
  /// docs/AI_BENCHMARKS.md.
  factory HeuristicPolicy.trickGreedy({required int seed}) =>
      HeuristicPolicy(seed: seed, scoreAware: false);

  /// Share of Beginner decisions that are random instead of reasoned.
  static const double beginnerBlunderRate = 0.4;

  final SeededRandom _random;

  /// Probability that a decision is replaced by a random legal card.
  final double blunderRate;

  /// Whether the policy plays for points rather than for tricks.
  ///
  /// False restores the trick-maximising control; see [trickGreedy].
  final bool scoreAware;

  @override
  String get id => !scoreAware
      ? 'heuristic-greedy'
      : (blunderRate == 0 ? 'heuristic' : 'heuristic-blunder');

  @override
  String get displayName => !scoreAware
      ? 'Sezgisel (löve avcısı)'
      : (blunderRate == 0 ? 'Sezgisel' : 'Sezgisel (hata yapan)');

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

  /// Promises a number of tricks. See `declaration_evaluator.dart`, which
  /// owns the reasoning and the measured constants behind it.
  int chooseDeclarationSync(SeatObservation observation, List<int> options) {
    if (options.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    if (blunderRate > 0 && _random.nextBool(blunderRate)) {
      return options[_random.nextInt(options.length)];
    }
    return scoreAware
        ? chooseDeclarationFor(observation, options)
        : _roundedDeclaration(observation, options);
  }

  /// The control's declaration: round the estimate, never promise nil.
  ///
  /// Kept verbatim so the comparison is against what actually shipped, not
  /// against a remembered version of it.
  int _roundedDeclaration(SeatObservation observation, List<int> options) {
    int promise = expectedTricks(observation).round();
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

  @override
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
    final _Intent intent = _intentFor(observation);
    if (intent == _Intent.duck) {
      return observation.currentTrick.isEmpty
          ? _leadSafely(observation, tracker, legal)
          : _duck(observation, legal);
    }
    return observation.currentTrick.isEmpty
        ? _lead(observation, tracker, legal)
        : _follow(observation, tracker, legal);
  }

  /// Whether this seat still wants the trick.
  ///
  /// Every branch is a payoff question, not a card question, which is why it
  /// is decided once here from the declaration rather than scattered through
  /// the card logic.
  _Intent _intentFor(SeatObservation observation) {
    if (!scoreAware) {
      return _Intent.win;
    }
    final int? declared = observation.myDeclaration;
    if (declared == null) {
      // No word to keep: every trick pays and none can cost.
      return _Intent.win;
    }
    if (declared == 0) {
      // "El almaz" is all or nothing. One trick breaks it, and once it is
      // broken no further trick can make it worse.
      return observation.myTricks == 0 ? _Intent.duck : _Intent.win;
    }
    if (observation.tricksStillNeeded! > 0) {
      return _Intent.win;
    }
    final int? room = observation.tricksBeforeBust;
    if (room == null) {
      // A table where extras never sink a hand. They only add.
      return _Intent.win;
    }
    // Cards left in hand is tricks left to play. If every one of them could
    // be taken without crossing the line, there is nothing to avoid.
    if (room >= observation.hand.length) {
      return _Intent.win;
    }
    // The word is kept and the line is reachable. An extra pays
    // pointsPerOvertrick; crossing the line costs the whole stake, which is
    // an order of magnitude more. That trade is not close.
    return _Intent.duck;
  }

  /// Plays the card least likely to win the trick.
  ///
  /// The highest loser, not the lowest. Every high card still in hand is a
  /// trick waiting to happen, and the rest of this hand is spent avoiding
  /// tricks, so a card that loses safely today is a card that cannot force a
  /// win tomorrow. Keeping the big ones back is what fills a hand with cards
  /// it cannot get rid of.
  ///
  /// The same reasoning decides the forced case, where every legal card
  /// wins: take the trick with the highest of them. It costs nothing extra --
  /// the trick is lost either way -- and it sheds the card most likely to
  /// cost the next one. Measured at +1.3 points per hand over paying with the
  /// cheapest card; see docs/AI_BENCHMARKS.md.
  PlayingCard _duck(SeatObservation observation, List<PlayingCard> legal) {
    final List<PlayingCard> losers = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (!wouldLead(card, observation)) card,
    ];
    return highestOf(losers.isEmpty ? legal : losers);
  }

  /// Opens a trick without trying to win it.
  ///
  /// Leading is the worst position for a seat that must not take tricks, so
  /// the aim is a card somebody else is likely to beat: low, off trump, and
  /// not the best card of its suit.
  PlayingCard _leadSafely(
    SeatObservation observation,
    CardTracker tracker,
    List<PlayingCard> legal,
  ) {
    final Suit? trump = observation.trump;
    final List<PlayingCard> safe = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump && !tracker.isMaster(card)) card,
    ];
    if (safe.isNotEmpty) {
      return lowestOf(safe);
    }
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump) card,
    ];
    return lowestOf(side.isEmpty ? legal : side);
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
        bestUnrufflable(sideMasters, observation, tracker);
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
        return lowestOf(trumps);
      }
      // Draw trumps while holding the top one: a round of trump costs us one
      // card and strips up to two from the opponents, which is what clears the
      // way for side-suit length later in the hand.
      final PlayingCard highestTrump = highestOf(trumps);
      if (tracker.isMaster(highestTrump)) {
        return highestTrump;
      }
    }

    // A master that an opponent could ruff is still the best card of its suit.
    if (sideMasters.isNotEmpty) {
      return highestOf(sideMasters);
    }

    // Nothing here wins. Lead low from the shortest side suit: it keeps trumps
    // and length for later tricks, forces an opponent to spend a winner now,
    // and shortens us towards a void we can ruff from.
    final List<PlayingCard> side = <PlayingCard>[
      for (final PlayingCard card in legal)
        if (card.suit != trump) card,
    ];
    if (side.isNotEmpty) {
      return lowestOfShortestSuit(side, observation.hand);
    }
    return lowestOf(legal);
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
        if (wouldLead(card, observation)) card,
    ];
    if (winners.isEmpty) {
      return _discard(legal, observation, tracker);
    }

    // Contest it with the cheapest card that does the job. Every trick is
    // worth the same here, so a trick we decline is a trick an opponent banks;
    // the only question is how little we can pay for it. A later seat may take
    // it back, but declining would have handed it over for certain.
    return lowestOf(winners);
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
    return lowestOfShortestSuit(
      spare.isEmpty ? pool : spare,
      observation.hand,
    );
  }
}

/// What this seat is trying to do with the trick in front of it.
///
/// Two states rather than a scale, because the payoff really is a step: an
/// extra trick is worth one point until the one that is worth minus the whole
/// stake.
enum _Intent {
  /// The trick is wanted: the word is not yet kept, or extras cannot hurt.
  win,

  /// The trick is to be avoided within the rules.
  duck,
}
