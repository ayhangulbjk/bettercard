import '../../cards/playing_card.dart';
import '../../game_engine/game_command.dart';
import '../../game_engine/game_engine.dart';
import '../../game_engine/trick/trick.dart';
import '../../game_engine/trick/trick_play_engine.dart';
import '../../game_engine/trick/trick_play_state.dart';
import '../../util/seeded_random.dart';
import '../ai_difficulty.dart';
import '../ai_policy.dart';
import '../card_tracker.dart';
import '../endgame_solver.dart';
import '../hidden_hand_sampler.dart';
import '../seat_observation.dart';
import 'heuristic_policy.dart';

/// Chooses by playing the hand out, many times, in many worlds it cannot rule
/// out.
///
/// The hidden-information problem is handled by determinization: the cards it
/// cannot see are *invented*, over and over, in ways consistent with
/// everything the public record proves (see [HiddenHandSampler]). A card is
/// judged by the points it averages across those worlds, not by the tricks it
/// wins, so the bust line, the word and "el almaz" are all accounted for
/// without a rule for any of them -- the scorer that pays the real hand is the
/// same one that scores a rollout.
///
/// Determinization has a known blind spot and it is worth stating plainly:
/// because every rollout is played as if the cards were face up from that
/// point, the search never values a play for the information it hides or
/// reveals. It will not find a deceptive card. What it does find is the
/// arithmetic a heuristic gets wrong -- which trick is worth taking when the
/// word is nearly made, which trump is worth spending now, how a hand plays
/// out from here -- and that is most of the gap.
///
/// It never sees a real hidden hand. Its worlds come from the observation and
/// the tracker, exactly like every other policy's.
final class MonteCarloPolicy implements AiPolicy {
  MonteCarloPolicy({required int seed, this.rolloutSeed = 17})
      : _random = SeededRandom(seed);

  /// Worlds drawn per decision when the budget does not say otherwise.
  static const int defaultWorlds = 24;

  /// Seed for the policies that play a rollout out.
  ///
  /// Fixed rather than drawn, so two candidate cards are compared on the same
  /// rollout behaviour and a difference between them is the card.
  final int rolloutSeed;

  final SeededRandom _random;

  static const TrickPlayEngine _engine = TrickPlayEngine();
  static const HiddenHandSampler _sampler = HiddenHandSampler();

  @override
  String get id => 'monte-carlo';

  @override
  String get displayName => 'Monte Carlo';

  @override
  Future<PlayingCard> chooseCard(
    SeatObservation observation,
    AiComputeBudget budget,
  ) async =>
      chooseCardSync(observation, budget);

  /// Declarations are left to the heuristic evaluator.
  ///
  /// Rolling a hand out before the first card would mean sampling 39 unknown
  /// cards with nothing proved about any of them, which is a lot of work for
  /// an estimate the hand valuation already makes about as well. The search
  /// earns its keep once there is a public record to constrain it.
  @override
  Future<int> chooseDeclaration(
    SeatObservation observation,
    List<int> options,
    AiComputeBudget budget,
  ) async =>
      HeuristicPolicy(seed: rolloutSeed)
          .chooseDeclarationSync(observation, options);

  /// Synchronous variant for the simulator and the benchmark CLI.
  PlayingCard chooseCardSync(
    SeatObservation observation, [
    AiComputeBudget budget = const AiComputeBudget(
      timeLimit: Duration(milliseconds: 100),
      maxWorlds: defaultWorlds,
      maxRollouts: 0,
    ),
  ]) {
    final List<PlayingCard> legal = observation.legalMoves;
    if (legal.isEmpty) {
      throw NoLegalMoveError(observation.seat);
    }
    if (legal.length == 1) {
      return legal.first;
    }

    final CardTracker tracker = CardTracker.fromObservation(observation);
    final int worldCount =
        budget.maxWorlds > 0 ? budget.maxWorlds : defaultWorlds;
    final List<SampledDeal> worlds = _sampler.sampleMany(
      observation: observation,
      tracker: tracker,
      random: _random,
      count: worldCount,
    );
    if (worlds.isEmpty) {
      // No consistent world could be drawn, which a tight void pattern can
      // cause. Falling back beats guessing, and it is the same policy the
      // rollouts would have used anyway.
      return HeuristicPolicy(seed: rolloutSeed).chooseCardSync(observation);
    }

    final Stopwatch clock = Stopwatch()..start();
    final List<double> totals = List<double>.filled(legal.length, 0);
    final List<int> counts = List<int>.filled(legal.length, 0);

    // World-major, so an exhausted budget leaves every candidate judged on
    // the same set of worlds. Candidate-major would let the first card be
    // measured on worlds the last one never saw, and the comparison would be
    // between samples rather than between cards.
    // Once the hand is short enough, each world is finished exactly instead
    // of being guessed at: the uncertainty that remains is which world, not
    // what happens in it.
    final bool exact = budget.maxSolverDepth > 0 &&
        observation.hand.length <= budget.maxSolverDepth;

    for (final SampledDeal world in worlds) {
      if (clock.elapsed >= budget.timeLimit) {
        break;
      }
      for (int index = 0; index < legal.length; index++) {
        final double? value =
            exact ? _solve(observation, world, legal[index]) : null;
        totals[index] += value ?? _rollout(observation, world, legal[index]);
        counts[index]++;
      }
    }

    int best = 0;
    double bestValue = double.negativeInfinity;
    for (int index = 0; index < legal.length; index++) {
      if (counts[index] == 0) {
        continue;
      }
      final double value = totals[index] / counts[index];
      if (value > bestValue) {
        bestValue = value;
        best = index;
      }
    }
    return legal[best];
  }

  /// Finishes [world] exactly after playing [card], or null when the search
  /// gave up and the caller should roll out instead.
  double? _solve(
    SeatObservation observation,
    SampledDeal world,
    PlayingCard card,
  ) {
    final TrickPlayState? next = _apply(
      _positionIn(observation, world),
      observation.seat,
      card,
    );
    if (next == null) {
      throw StateError('Endgame search rejected a legal card $card');
    }
    final List<double>? values = EndgameSolver.values(
      state: next,
      match: observation.match,
    );
    return values?[observation.seat];
  }

  /// The real position with [world]'s cards behind the other seats' backs.
  static TrickPlayState _positionIn(
    SeatObservation observation,
    SampledDeal world,
  ) =>
      TrickPlayState(
        hands: world.hands,
        seating: observation.seating,
        rules: observation.rules,
        trump: observation.trump,
        turnSeat: observation.seat,
        currentTrick: observation.currentTrick,
        completedTricks: List<CompletedTrick>.of(observation.trickHistory),
        trumpBroken: observation.trumpBroken,
      );

  /// Plays [card] in [world] and finishes the hand, returning what this seat
  /// scores for it.
  double _rollout(
    SeatObservation observation,
    SampledDeal world,
    PlayingCard card,
  ) {
    TrickPlayState state = _positionIn(observation, world);

    final List<HeuristicPolicy> rollouts = <HeuristicPolicy>[
      for (int seat = 0; seat < observation.seating.playerCount; seat++)
        HeuristicPolicy(seed: rolloutSeed + seat),
    ];

    TrickPlayState? next = _apply(state, observation.seat, card);
    if (next == null) {
      // The candidate was legal in the real position, so it is legal here:
      // the sampled world leaves this seat's own hand untouched. A rejection
      // would be an engine bug, and silently scoring it would hide one.
      throw StateError('Rollout rejected a legal card $card');
    }
    state = next;

    while (!_engine.isTerminal(state)) {
      final int seat = state.turnSeat;
      final PlayingCard played = rollouts[seat].chooseCardSync(
        SeatObservation.fromState(state, seat, match: observation.match),
      );
      next = _apply(state, seat, played);
      if (next == null) {
        throw StateError('Rollout rejected its own legal card $played');
      }
      state = next;
    }

    return _valueOf(observation, state.tricksWon[observation.seat]);
  }

  /// What [tricks] is worth to this seat at the end of the hand.
  ///
  /// Through [MatchContext.pointsFor], which picks the payoff this hand is
  /// actually being paid under -- four independent promises, or one contract
  /// against three defenders -- so the search optimises the scoreboard rather
  /// than a proxy for it, in either mode. With neither payoff in force the
  /// tricks themselves are the score, which is what those modes pay.
  static double _valueOf(SeatObservation observation, int tricks) =>
      (observation.match
                  .pointsFor(seat: observation.seat, tricksTaken: tricks) ??
              tricks)
          .toDouble();

  static TrickPlayState? _apply(
    TrickPlayState state,
    int seat,
    PlayingCard card,
  ) =>
      switch (_engine.apply(state, PlayCardCommand(seat: seat, card: card))) {
        CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
          next,
        CommandRejected<TrickPlayState>() => null,
      };
}
