import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/suit.dart';
import '../../../core/game_engine/auction/auction_state.dart';
import '../../../core/game_engine/trick/trick.dart';
import '../../../core/game_engine/trick/trick_play_state.dart';
import '../match_session.dart';
import 'contract_pill.dart';
import 'seat_panel.dart';
import 'table_layout.dart';
import 'team_status_bar.dart';
import 'trick_area.dart';
import 'trump_badge.dart';

/// The table: a seat on each of the four edges, the trick in the middle.
///
/// In a partnership deal the far edge does double duty. Normally it is the
/// seat across the felt; once the declarer's partner lays its hand face up,
/// that is the hand, and it is drawn where it belongs -- at the seat holding
/// it -- rather than in a second fan beside the player's own, where the two
/// would be impossible to tell apart.
final class MatchTable extends StatelessWidget {
  const MatchTable({
    required this.session,
    required this.strings,
    required this.seatNames,
    required this.gatherDuration,
    this.farEdge,
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

  /// Replaces the seat across the felt, for the open hand.
  ///
  /// Built by the screen rather than here because it is interactive: which
  /// cards are legal and whether a tap does anything are questions about the
  /// session, and the screen is what already answers them for the player's
  /// own fan.
  final Widget? farEdge;

  /// Whether a card is being dragged over the table right now.
  final bool highlightDropZone;

  /// What a seat has said in the auction, while one is running.
  ///
  /// Only during the auction: once the contract is settled the bar above says
  /// who holds it, and leaving stale calls on the rails would compete with
  /// that. A seat that has passed keeps saying so, because a pass is
  /// permanent and that is the thing a player needs to remember.
  static String? _auctionLabel(
    MatchSession session,
    AppStrings strings,
    int seat,
  ) {
    if (!session.isBidding) {
      return null;
    }
    for (final AuctionCall call in session.auctionCalls.reversed) {
      if (call.seat == seat) {
        return call.isPass ? strings.gameplayPassed : '${call.tricks}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TrickPlayState? hand = session.hand;
    final List<int> tricks = session.tricksThisHand;
    final List<int?> declarations = session.declarations;
    // Nobody is to move while a scored hand is on screen, so no seat is lit.
    final int? active = session.isShowingFinishedHand
        ? null
        : (session.match.seatToAct ?? hand?.turnSeat);
    final int? winner = session.highlightedWinner;
    final Suit? trump = session.trump;
    final Widget? header = _header();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xs),
          if (header != null) ...<Widget>[
            header,
            const SizedBox(height: AppSpacing.xs),
          ],
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
                farEdge: farEdge,
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
                  contract: _auctionLabel(session, strings, seat),
                  isActive: seat == active || seat == winner,
                  isPartner: session.hasTeams &&
                      seat != session.humanSeat &&
                      session.teamOf(seat) == session.humanTeam,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What sits above the table.
  ///
  /// A partnership deal gets the two team totals and the state of the hand,
  /// because those are the numbers that decide it. A solo deal gets the
  /// contract on its own, and a mode with no contract gets nothing: an empty
  /// pill would be a row of a portrait phone spent on a blank.
  Widget? _header() {
    if (session.hasTeams) {
      return TeamStatusBar(
        session: session,
        strings: strings,
        seatNames: seatNames,
      );
    }
    final int? declarer = session.declarerSeat;
    final int? bid = session.contractBid;
    if (declarer == null || bid == null) {
      return null;
    }
    return ContractPill(
      label: strings.gameplayContractLine(
        declarer < seatNames.length ? seatNames[declarer] : '',
        bid,
      ),
    );
  }
}
