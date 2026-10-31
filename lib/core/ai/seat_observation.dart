import 'package:meta/meta.dart';

import '../cards/playing_card.dart';
import '../cards/suit.dart';
import '../game_engine/seating.dart';
import '../game_engine/trick/trick.dart';
import '../game_engine/trick/trick_legal_moves.dart';
import '../game_engine/trick/trick_play_state.dart';
import '../rules/trick_rules.dart';

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
/// counts, and whatever can be inferred from those (see `CardTracker`).
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
  })  : hand = List<PlayingCard>.unmodifiable(hand),
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
  factory SeatObservation.fromState(TrickPlayState state, int seat) =>
      SeatObservation(
        seat: seat,
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
