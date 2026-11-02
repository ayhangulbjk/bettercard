import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/game_engine/trick/trick.dart';
import '../../../core/game_engine/trick/trick_play_state.dart';
import '../match_session.dart';
import 'seat_panel.dart';
import 'table_layout.dart';
import 'trick_area.dart';
import 'trick_status_pill.dart';

/// The table: a seat on each of the four edges, the trick in the middle.
final class MatchTable extends StatelessWidget {
  const MatchTable({
    required this.session,
    required this.strings,
    required this.seatNames,
    this.highlightDropZone = false,
    super.key,
  });

  final MatchSession session;
  final AppStrings strings;
  final List<String> seatNames;

  /// Whether a card is being dragged over the table right now.
  final bool highlightDropZone;

  @override
  Widget build(BuildContext context) {
    final TrickPlayState? hand = session.hand;
    final List<int> tricks = session.tricksThisHand;
    final List<int> handSizes = session.cardsRemaining;
    // Nobody is to move while a scored hand is on screen, so no seat is lit.
    final int? active = session.isShowingFinishedHand ? null : hand?.turnSeat;
    final int? winner = session.highlightedWinner;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          TrickStatusPill(
            trumpTitle: strings.gameplayTrumpLabel,
            trumpLabel:
                (hand?.trump ?? session.profile.fixedTrump)?.turkishName ??
                    strings.gameplayNoTrump,
            progressLabel: strings.trickProgress(
              session.displayTrickNumber,
              session.profile.tricksPerHand,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(
                  color: highlightDropZone
                      ? AppColors.goldBright
                      : Colors.transparent,
                ),
              ),
              child: TableLayout(
                seatCount: session.seatCount,
                center: TrickArea(
                  trick: session.tableTrick ??
                      Trick.empty(
                        leadSeat: 0,
                        expectedPlays: session.seatCount,
                      ),
                ),
                seatBuilder: (int seat) => SeatPanel(
                  // Only the player's own seat has the width for a row.
                  vertical: seat != session.humanSeat,
                  name: seat < seatNames.length ? seatNames[seat] : '',
                  tricksWon: tricks[seat],
                  cardsRemaining: handSizes[seat],
                  isActive: seat == active || seat == winner,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
