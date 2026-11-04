import '../cards/playing_card.dart';
import '../game_engine/game_command.dart';
import '../game_engine/game_engine.dart';
import '../game_engine/trick/trick_play_engine.dart';
import '../game_engine/trick/trick_play_state.dart';
import 'match_context.dart';

/// Plays out the last few tricks exactly, given a world.
///
/// Once a hand is short enough the position stops being a guessing game and
/// becomes arithmetic: with the cards known, every continuation can be walked
/// and the best one chosen. This is what the stronger difficulty levels have
/// that the weaker ones do not -- not a better guess, a finished calculation.
///
/// The cards it is given are **sampled**, not real: a Monte Carlo policy hands
/// it one invented world at a time. Solving a world exactly is not cheating,
/// because the world is a guess; averaging the answers over many worlds is
/// how the guessing is handled.
///
/// ### Why max-n rather than minimax
///
/// Koz Maca is four independent players, not two sides. Each seat is paid
/// against its own word, so "the opponent's loss is my gain" is simply false:
/// a seat past its bust line wants to lose tricks, and will. Minimax would
/// model all three opponents as trying to hurt this seat, predict defences
/// that nobody has a reason to play, and get the endgame wrong in exactly the
/// positions it is supposed to settle. So every seat maximises its own final
/// points, which is what each of them is actually paid to do.
abstract final class EndgameSolver {
  static const TrickPlayEngine _engine = TrickPlayEngine();

  /// A hard cap on nodes, so a pathological position cannot run away with the
  /// decision budget. Hit it and the search returns what it has.
  static const int maxNodes = 120000;

  /// The best card for the seat to act in [state], assuming every seat plays
  /// for its own score under [rules] and [declarations].
  ///
  /// Returns null when the position is terminal or the node cap was reached
  /// before any line was finished, which leaves the caller free to fall back
  /// rather than act on half an answer.
  static PlayingCard? bestCard({
    required TrickPlayState state,
    required MatchContext match,
  }) {
    if (_engine.isTerminal(state)) {
      return null;
    }
    final _Search search = _Search(match);
    final _Line line = search.solve(state);
    return search.exhausted ? null : line.card;
  }

  /// The final points every seat reaches from [state] under best own-score
  /// play, or null when the node cap was reached.
  ///
  /// This is what a Monte Carlo policy wants back: the value of the position
  /// in the currency the scoreboard uses.
  static List<double>? values({
    required TrickPlayState state,
    required MatchContext match,
  }) {
    final _Search search = _Search(match);
    final _Line line = search.solve(state);
    return search.exhausted ? null : line.values;
  }
}

/// One line of play: the card that starts it and what every seat ends up with.
final class _Line {
  const _Line({required this.card, required this.values});

  final PlayingCard? card;
  final List<double> values;
}

final class _Search {
  _Search(this.match);

  final MatchContext match;

  int _nodes = 0;
  bool exhausted = false;

  _Line solve(TrickPlayState state) {
    _nodes++;
    if (_nodes > EndgameSolver.maxNodes) {
      exhausted = true;
      return _Line(card: null, values: _payoff(state));
    }
    if (EndgameSolver._engine.isTerminal(state)) {
      return _Line(card: null, values: _payoff(state));
    }

    final int seat = state.turnSeat;
    final List<PlayingCard> legal =
        EndgameSolver._engine.legalCards(state, seat);
    PlayingCard? bestCard;
    List<double>? best;

    for (final PlayingCard card in legal) {
      final TrickPlayState? next = _apply(state, seat, card);
      if (next == null) {
        // The engine refused a card its own generator produced, which is a
        // defect rather than a line to evaluate.
        throw StateError('Endgame search was handed an illegal legal move');
      }
      final List<double> value = solve(next).values;
      // Each seat picks the line best for itself. Ties keep the first card,
      // which keeps the search deterministic.
      if (best == null || value[seat] > best[seat]) {
        best = value;
        bestCard = card;
      }
      if (exhausted) {
        break;
      }
    }
    return _Line(card: bestCard, values: best ?? _payoff(state));
  }

  /// What every seat scores for the hand as it now stands.
  ///
  /// Through [MatchContext.handPointsFor], so the search optimises what the
  /// scoreboard pays under whichever of the three payoffs this hand is using
  /// -- a team payoff included, which is a function of the side's tricks
  /// rather than of one seat's. A seat with no payoff of its own falls back
  /// to its trick count, which keeps the comparison meaningful in a mode that
  /// scores nothing else.
  List<double> _payoff(TrickPlayState state) {
    final List<int> tricks = state.tricksWon;
    final int tricksPerHand = state.tricksPerHand;
    return <double>[
      for (int seat = 0; seat < tricks.length; seat++)
        (match.handPointsFor(
                  seat: seat,
                  tricksBySeat: tricks,
                  tricksPerHand: tricksPerHand,
                ) ??
                tricks[seat])
            .toDouble(),
    ];
  }

  static TrickPlayState? _apply(
    TrickPlayState state,
    int seat,
    PlayingCard card,
  ) =>
      switch (EndgameSolver._engine
          .apply(state, PlayCardCommand(seat: seat, card: card))) {
        CommandAccepted<TrickPlayState>(state: final TrickPlayState next) =>
          next,
        CommandRejected<TrickPlayState>() => null,
      };
}
