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
/// ### Hands that are open on purpose
///
/// [openHands] is the one way another seat's cards reach a policy, and it is
/// not a leak: in acik esli Batak the declarer's partner lays its thirteen
/// cards face up and every seat at the table reads them, defenders included.
/// Which hands are open is decided by the match state -- the only place that
/// knows the dummy rules -- and handed in as `visibleHands`, so there is
/// still exactly one place to review. A hand that is not in that set is not
/// in this object, whatever the policy would like.
///
/// The declarer also sees its own cards while choosing for the open hand,
/// which is why the set is per *decider* rather than per seat: the
/// observation is built for the seat that is moving, and the set says which
/// other hands whoever is deciding may read.
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
    List<List<PlayingCard>> openHands = const <List<PlayingCard>>[],
    Set<int> publicOpenSeats = const <int>{},
  })  : match = match ?? MatchContext.none,
        publicOpenSeats = Set<int>.unmodifiable(publicOpenSeats),
        openHands = List<List<PlayingCard>>.unmodifiable(
          openHands.map(List<PlayingCard>.unmodifiable),
        ),
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
    Set<int> visibleHands = const <int>{},
    Set<int> publicHands = const <int>{},
  }) =>
      SeatObservation(
        seat: seat,
        match: match,
        publicOpenSeats: publicHands,
        hand: state.handOf(seat),
        openHands: <List<PlayingCard>>[
          for (int other = 0; other < state.seating.playerCount; other++)
            if (other != seat && visibleHands.contains(other))
              state.handOf(other)
            else
              const <PlayingCard>[],
        ],
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

  /// Other seats' hands that whoever is deciding may legally read, indexed by
  /// seat and empty where nothing is open. The observer's own entry is always
  /// empty; its cards are [hand].
  ///
  /// Empty throughout in every closed mode, which is every mode but acik
  /// esli Batak.
  final List<List<PlayingCard>> openHands;

  /// Seats whose cards are face up to **everybody**, not only to whoever is
  /// deciding.
  ///
  /// In acik esli Batak that is the open hand and nothing else: the declarer
  /// reads its own cards while playing for its partner, but no other seat
  /// does. The distinction matters to a search, which plays its sampled
  /// worlds out with the other seats' policies -- those seats may read the
  /// open hand, because everyone can, and must not read the declarer's.
  final Set<int> publicOpenSeats;

  /// Whether [other]'s cards are open to whoever is deciding.
  bool seesHandOf(int other) =>
      other == seat ||
      (other < openHands.length && openHands[other].isNotEmpty);

  /// [other]'s open cards, or empty when they are not open.
  List<PlayingCard> openHandOf(int other) => other == seat
      ? hand
      : (other < openHands.length ? openHands[other] : const <PlayingCard>[]);

  /// Every card this decision may read, the observer's own hand included.
  ///
  /// What a declarer plans with in acik esli: twenty-six known cards against
  /// twenty-six it must infer.
  List<PlayingCard> get allKnownCards => <PlayingCard>[
        ...hand,
        for (final List<PlayingCard> open in openHands) ...open,
      ];

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
  int? get pointsIfHandEndedNow => match.handPointsFor(
        seat: seat,
        tricksBySeat: tricksWon,
        tricksPerHand: tricksPerHand,
      );

  /// What [seat] would score on its current trick count, or null when it has
  /// not declared.
  int? projectedPointsFor(int other) => match.handPointsFor(
        seat: other,
        tricksBySeat: tricksWon,
        tricksPerHand: tricksPerHand,
      );

  /// The observer's partner, when the mode has partnerships.
  int? get partnerSeat => seating.partnerOf(seat);

  /// The observer's team id.
  int get myTeam => seating.teamOf(seat);

  /// Tricks taken by [team] so far this hand.
  int teamTricksOf(int team) {
    int total = 0;
    for (int other = 0; other < tricksWon.length; other++) {
      if (seating.teamOf(other) == team) {
        total += tricksWon[other];
      }
    }
    return total;
  }

  /// Tricks the observer's side has taken so far this hand.
  int get myTeamTricks => teamTricksOf(myTeam);

  /// Whether the observer's side holds the contract, in a team mode.
  bool get isOnDeclaringTeam =>
      match.hasTeamContract && match.declarerTeam == myTeam;

  /// Tricks the *declaring side* still owes on its contract, or null when the
  /// hand has no team contract. Zero once the contract is safe.
  int? get contractTricksOutstanding {
    if (!match.hasTeamContract) {
      return null;
    }
    final int short = match.contractBid! - teamTricksOf(match.declarerTeam!);
    return short > 0 ? short : 0;
  }

  /// Tricks still to be played in this hand.
  ///
  /// Equal to the cards left in any one hand, which is the quantity a
  /// contract calculation is actually against.
  /// Tricks in the whole deal: finished, in progress, and still to come.
  ///
  /// Derived the same way [TrickPlayState.tricksPerHand] derives it, from
  /// public hand counts alone.
  int get tricksPerHand {
    int longest = 0;
    for (final int size in handSizes) {
      if (size > longest) {
        longest = size;
      }
    }
    return trickHistory.length + longest + (currentTrick.plays.isEmpty ? 0 : 1);
  }

  /// Tricks still to be decided, the one in progress included.
  int get tricksRemaining => tricksPerHand - trickHistory.length;

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
