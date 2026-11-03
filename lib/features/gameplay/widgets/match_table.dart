import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/suit.dart';
import '../../../core/game_engine/trick/trick.dart';
import '../../../core/game_engine/trick/trick_play_state.dart';
import '../match_session.dart';
import 'seat_panel.dart';
import 'table_layout.dart';
import 'trick_area.dart';
import 'trick_status_pill.dart';
import 'trump_badge.dart';

/// The table: a seat on each of the four edges, the trick in the middle.
final class MatchTable extends StatelessWidget {
  const MatchTable({
    required this.session,
    required this.strings,
    required this.seatNames,
    required this.gatherDuration,
    this.highlightDropZone = false,
    super.key,
  });

  final MatchSession session;
  final AppStrings strings;
  final List<String> seatNames;

  /// How long a finished trick takes to travel to its winner. Comes from the
  /// controller's pacing so the animation and the wait that follows it are
  /// the same length.
  final Duration gatherDuration;

  /// Whether a card is being dragged over the table right now.
  final bool highlightDropZone;

  @override
  Widget build(BuildContext context) {
    final TrickPlayState? hand = session.hand;
    final List<int> tricks = session.tricksThisHand;
    final List<int?> declarations = session.declarations;
    // Nobody is to move while a scored hand is on screen, so no seat is lit.
    final int? active = session.isShowingFinishedHand
        ? null
        : (session.match.declaringSeat ?? hand?.turnSeat);
    final int? winner = session.highlightedWinner;
    final Suit? trump = hand?.trump ?? session.profile.fixedTrump;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xs),
          TrickStatusPill(
            progressLabel: strings.trickProgress(
              session.displayTrickNumber,
              session.profile.tricksPerHand,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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
                overlay: TrumpBadge(
                  trump: trump,
                  label: '${strings.gameplayTrumpLabel}: '
                      '${trump?.turkishName ?? strings.gameplayNoTrump}',
                ),
                center: TrickArea(
                  trick: session.tableTrick ??
                      Trick.empty(
                        leadSeat: 0,
                        expectedPlays: session.seatCount,
                      ),
                  winnerSeat: winner,
                  gathering: session.isGatheringTrick,
                  gatherDuration: gatherDuration,
                ),
                seatBuilder: (int seat, SeatEdge edge) => SeatPanel(
                  edge: edge,
                  name: seat < seatNames.length ? seatNames[seat] : '',
                  tricksWon: tricks[seat],
                  declaration:
                      seat < declarations.length ? declarations[seat] : null,
                  awaitingDeclaration: session.isDeclaring &&
                      seat < declarations.length &&
                      declarations[seat] == null,
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
