import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/game_engine/trick/trick.dart';
import '../../../core/game_engine/trick/trick_play_state.dart';
import '../match_session.dart';
import 'seat_panel.dart';
import 'trick_area.dart';

/// Opponent seats, the trick in the middle, and the trump badge.
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int seat = 1; seat < session.seatCount; seat++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: SeatPanel(
                      vertical: true,
                      name: seatNames[seat],
                      tricksWon: tricks[seat],
                      cardsRemaining: handSizes[seat],
                      isActive: seat == active || seat == winner,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
              child: TrickArea(
                trick: session.tableTrick ??
                    Trick.empty(leadSeat: 0, expectedPlays: session.seatCount),
                trumpTitle: strings.gameplayTrumpLabel,
                trumpLabel:
                    (hand?.trump ?? session.profile.fixedTrump)?.turkishName ??
                        strings.gameplayNoTrump,
                progressLabel: strings.trickProgress(
                  session.displayTrickNumber,
                  session.profile.tricksPerHand,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SeatPanel(
            name: seatNames[session.humanSeat],
            tricksWon: tricks[session.humanSeat],
            cardsRemaining: handSizes[session.humanSeat],
            isActive: session.isHumanTurn ||
                session.humanSeat == session.highlightedWinner,
          ),
        ],
      ),
    );
  }
}
