import '../../core/cards/deck.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/game_engine/game_command.dart';
import '../../core/game_engine/game_engine.dart';
import '../../core/game_engine/seating.dart';
import '../../core/game_engine/trick/trick_play_engine.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/rule_profile.dart';

/// Builds a deterministic mid-trick position for the table preview.
///
/// It deals a seeded hand and plays a few plies through the authoritative
/// engine, so the preview can never render a position the rules would not
/// allow. It lives in the presentation layer, not the domain, because its only
/// purpose is to give the layout something realistic to draw.
abstract final class GameplayPreview {
  /// Fixed seed, so the preview always shows the same hand. A preview that
  /// changed on every open would make layout regressions hard to spot.
  static const int defaultSeed = 20260131;

  /// Plies played before the snapshot is returned, so the trick area is not
  /// empty.
  static const int pliesToAdvance = 2;

  /// A snapshot for [profile].
  static TrickPlayState build(
    RuleProfile profile, {
    int seed = defaultSeed,
    int plies = pliesToAdvance,
  }) {
    final SeatingPlan seating = profile.mode.hasPartnerships
        ? SeatingPlan.partnership4()
        : SeatingPlan.individual(profile.playerCount);

    // A trump is needed to exercise the trump badge and the legal-move
    // highlighting. Profiles with a fixed trump use theirs; the rest get
    // hearts, which is a presentation choice and not a rule claim.
    final Suit trump = profile.fixedTrump ?? Suit.hearts;

    final Deal deal = Deck.shuffleAndDeal(
      seed: seed,
      handCount: profile.playerCount,
      handSize: profile.handSize,
      excluded: <PlayingCard>{
        for (final int id in profile.deckExclusions) PlayingCard.fromId(id),
      },
    );

    TrickPlayState state = TrickPlayState.opening(
      hands: deal.hands,
      seating: seating,
      rules: profile.trickRules,
      trump: trump,
      leadSeat: 1,
    );

    const TrickPlayEngine engine = TrickPlayEngine();
    for (int ply = 0; ply < plies; ply++) {
      final List<PlayingCard> legal = engine.legalCards(state, state.turnSeat);
      if (legal.isEmpty) {
        break;
      }
      final CommandOutcome<TrickPlayState> outcome = engine.apply(
        state,
        PlayCardCommand(seat: state.turnSeat, card: legal.first),
      );
      if (outcome
          case CommandAccepted<TrickPlayState>(
            state: final TrickPlayState next,
          )) {
        state = next;
      } else {
        break;
      }
    }
    return state;
  }
}
