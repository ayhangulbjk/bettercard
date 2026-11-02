import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/cards/card_sorting.dart';
import '../../core/cards/playing_card.dart';
import '../../core/game_engine/trick/trick_play_engine.dart';
import '../../core/game_engine/trick/trick_play_state.dart';
import '../../core/rules/game_mode.dart';
import '../../core/rules/rule_presets.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/table/seat_names.dart';
import 'preview_state.dart';
import 'widgets/felt_background.dart';
import 'widgets/hand_fan.dart';
import 'widgets/placeholder_banner.dart';
import 'widgets/seat_panel.dart';
import 'widgets/table_layout.dart';
import 'widgets/trick_area.dart';
import 'widgets/trick_status_pill.dart';

/// A static preview of the gameplay table.
///
/// This is NOT a playable game. Nothing advances: tapping a card does not play
/// it, no opponent acts, nothing is scored. What it is, deliberately, is the
/// real portrait layout fed by real engine state, so card sizing, seat
/// arrangement and legal-move highlighting are validated against the actual
/// domain model rather than against invented data.
///
/// Connecting it to a live match is the next milestone; see docs/ROADMAP.md.
final class TablePreviewScreen extends ConsumerWidget {
  const TablePreviewScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final RuleProfile profile = RulePresets.defaultFor(mode);
    final TrickPlayState state = GameplayPreview.build(profile);
    const TrickPlayEngine engine = TrickPlayEngine();

    final List<PlayingCard> hand = CardSorting.bySuitStrongestFirst(
      state.handOf(0),
    );
    final bool humanToPlay = state.turnSeat == 0;
    final Set<PlayingCard> legal = humanToPlay
        ? engine.legalCards(state, 0).toSet()
        : const <PlayingCard>{};

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '${mode.turkishShortName} - ${strings.previewTableTitle}',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: PlaceholderBanner(
                  title: strings.previewTableTitle,
                  message: strings.modeNotPlayableExplanation,
                ),
              ),
              Expanded(
                child: _TableBody(
                  state: state,
                  strings: strings,
                  profile: profile,
                ),
              ),
              HandFan(cards: hand, legalCards: legal),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody({
    required this.state,
    required this.strings,
    required this.profile,
  });

  final TrickPlayState state;
  final AppStrings strings;
  final RuleProfile profile;

  @override
  Widget build(BuildContext context) {
    final List<int> tricks = state.tricksWon;
    final int players = state.seating.playerCount;
    final List<String> seatNames = SeatNames.forMatch(
      seed: GameplayPreview.defaultSeed,
      seatCount: players,
      humanSeat: 0,
      humanName: strings.seatSelf,
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: <Widget>[
          TrickStatusPill(
            trumpTitle: strings.gameplayTrumpLabel,
            trumpLabel: state.trump?.turkishName ?? strings.gameplayNoTrump,
            progressLabel: strings.trickProgress(
              state.trickNumber + 1,
              profile.tricksPerHand,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TableLayout(
              seatCount: players,
              center: TrickArea(trick: state.currentTrick),
              seatBuilder: (int seat) => SeatPanel(
                vertical: seat != 0,
                name: seatNames[seat],
                tricksWon: tricks[seat],
                cardsRemaining: state.handSizes[seat],
                isActive: state.turnSeat == seat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
