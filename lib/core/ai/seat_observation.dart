import 'package:meta/meta.dart';

import '../cards/playing_card.dart';
import '../cards/suit.dart';
import '../game_engine/seating.dart';
import '../game_engine/trick/trick.dart';
import '../game_engine/trick/trick_legal_moves.dart';
import '../game_engine/trick/trick_play_state.dart';
import '../rules/declaration_rules.dart';
import '../rules/trick_rules.dart';
import 'match_context.dart';

/// Everything one seat is legally allowed to know.
///
/// This is the anti-cheating boundary of the whole AI system. A decision policy
/// receives only this object. It therefore cannot see:
///
/// * any other seat's cards,
/// * buried or undealt cards,
/// * the seeded generator's state,
/// * anything about the future.
///
/// What it does see is public: its own hand, the trick in progress, the full
/// trick history, the trump suit, the rule profile in force, public hand
/// counts, every declaration spoken so far, the scoreboard, and whatever can
/// be inferred from those (see `CardTracker`).
///
/// Monte Carlo policies may invent hidden hands consistent with this
/// information (see `HiddenHandSampler`); they may never read the real ones.
/// The test harness may inspect true hidden state to score outcomes, but must
/// never feed it back into a policy.
@immutable
class SeatObservation {
  SeatObservation({
    required this.seat,
    required List<PlayingCard> hand,
    required this.seating,
    required this.rules,
    required this.trump,
    required this.trumpBroken,
    required this.currentTrick,
    required List<CompletedTrick> trickHistory,
    required List<int> handSizes,
    required List<int> tricksWon,
    required List<PlayingCard> legalMoves,
    MatchContext? match,
  })  : match = match ?? MatchContext.none,
        hand = List<PlayingCard>.unmodifiable(hand),
        trickHistory = List<CompletedTrick>.unmodifiable(trickHistory),
        handSizes = List<int>.unmodifiable(handSizes),
        tricksWon = List<int>.unmodifiable(tricksWon),
        legalMoves = List<PlayingCard>.unmodifiable(legalMoves);

  /// Builds the observation for [seat] by stripping [state] down to public
  /// information plus that seat's own hand.
  ///
  /// This factory is the only sanctioned way to produce an observation from
  /// authoritative state. Keeping it the sole funnel is what makes the
  /// no-cheating property auditable: there is exactly one place to review.
  /// [match] carries what the trick state cannot know: the declarations
  /// spoken, the scoreboard, and the payoff in force. It defaults to
  /// [MatchContext.none] for the modes and tests that have none, so a caller
  /// never has to fabricate one.
  factory SeatObservation.fromState(
    TrickPlayState state,
    int seat, {
    MatchContext? match,
  }) =>
      SeatObservation(
        seat: seat,
        match: match,
        hand: state.handOf(seat),
        seating: state.seating,
        rules: state.rules,
        trump: state.trump,
        trumpBroken: state.trumpBroken,
        currentTrick: state.currentTrick,
        trickHistory: state.completedTricks,
        handSizes: state.handSizes,
        tricksWon: state.tricksWon,
        legalMoves: TrickLegalMoves.forHand(
          hand: state.handOf(seat),
          trick: state.currentTrick,
          trump: state.trump,
          rules: state.rules,
          trumpBroken: state.trumpBroken,
        ),
      );

  /// The observing seat.
  final int seat;

  /// Declarations, scores and the payoff in force; public information.
  final MatchContext match;

  /// The observer's own cards. The only private information present.
  final List<PlayingCard> hand;

  final SeatingPlan seating;
  final TrickRules rules;
  final Suit? trump;
  final bool trumpBroken;

  /// The trick in progress; public.
  final Trick currentTrick;

  /// Every finished trick with its winner; public.
  final List<CompletedTrick> trickHistory;

  /// How many cards each seat holds; public, since everyone can count.
  final List<int> handSizes;

  /// Tricks won per seat; public.
  final List<int> tricksWon;

  /// Pre-computed legal plays, so a policy cannot consider an illegal move and
  /// so every policy agrees with the engine.
  final List<PlayingCard> legalMoves;

  /// What this seat promised, or null when it has not spoken or the mode has
  /// no declaration round.
  int? get myDeclaration => match.declarationOf(seat);

  /// Tricks this seat has already taken.
  int get myTricks => tricksWon[seat];

  /// How many more tricks this seat needs to keep its word. Zero once the
  /// word is kept; null when there is no word.
  int? get tricksStillNeeded {
    final int? declared = myDeclaration;
    if (declared == null) {
      return null;
    }
    final int short = declared - myTricks;
    return short > 0 ? short : 0;
  }

  /// Tricks taken above a kept word ("yan"), or null when the word is not yet
  /// kept or there is no word.
  int? get extrasTaken {
    final int? declared = myDeclaration;
    if (declared == null || myTricks < declared) {
      return null;
    }
    return myTricks - declared;
  }

  /// How many more tricks this seat can take before a kept word is sunk by
  /// its own extras.
  ///
  /// Null when nothing can sink it: no declaration, no bust threshold, or a
  /// word not yet kept (missing the word is the other way to lose, and the
  /// policy that reads this is asking about the overshoot). Zero means the
  /// next trick busts the hand.
  int? get tricksBeforeBust {
    final int? extras = extrasTaken;
    final int? threshold = match.declarationRules.overtrickBustThreshold;
    if (extras == null || threshold == null) {
      return null;
    }
    final int room = threshold - 1 - extras;
    return room > 0 ? room : 0;
  }

  /// What this seat would score if the hand ended with the tricks it now has.
  ///
  /// Null when the mode has no declaration round. This is the quantity a
  /// score-aware policy is actually maximising, so it is derived once here
  /// rather than reimplemented per policy, and it is computed by
  /// [DeclarationRules.scoreFor] -- the same authority that pays the real
  /// hand -- so a policy cannot disagree with the scorer.
  int? get pointsIfHandEndedNow {
    final int? declared = myDeclaration;
    if (declared == null) {
      return null;
    }
    return match.declarationRules
        .scoreFor(declaration: declared, tricksTaken: myTricks);
  }

  /// What [seat] would score on its current trick count, or null when it has
  /// not declared.
  int? projectedPointsFor(int other) {
    final int? declared = match.declarationOf(other);
    if (declared == null) {
      return null;
    }
    return match.declarationRules
        .scoreFor(declaration: declared, tricksTaken: tricksWon[other]);
  }

  /// The observer's partner, when the mode has partnerships.
  int? get partnerSeat => seating.partnerOf(seat);

  /// Whether [other] is on the observer's team.
  bool isTeammate(int other) => seating.sameTeam(seat, other);

  /// Cards visible to everyone: played to finished tricks or lying in the
  /// current trick.
  List<PlayingCard> get publiclyPlayedCards => List<PlayingCard>.unmodifiable(
        <PlayingCard>[
          for (final CompletedTrick trick in trickHistory) ...trick.cards,
          ...currentTrick.plays.map((PlayedCard play) => play.card),
        ],
      );

  @override
  String toString() => 'SeatObservation(seat: $seat, hand: ${hand.length}, '
      'legal: ${legalMoves.length}, tricks: ${trickHistory.length})';
}
