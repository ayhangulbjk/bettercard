import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/cards/card_sorting.dart';
import '../../core/cards/playing_card.dart';
import '../../core/cards/suit.dart';
import '../../core/persistence/app_settings.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/table/seat_names.dart';
import 'match_controller.dart';
import 'match_labels.dart';
import 'match_pacing.dart';
import 'match_session.dart';
import 'match_turn.dart';
import 'widgets/bidding_panel.dart';
import 'widgets/declaration_panel.dart';
import 'widgets/dummy_hand_view.dart';
import 'widgets/felt_background.dart';
import 'widgets/hand_fan.dart';
import 'widgets/hand_summary_sheet.dart';
import 'widgets/leave_match_dialog.dart';
import 'widgets/match_over_panel.dart';
import 'widgets/match_table.dart';
import 'widgets/score_sheet_panel.dart';
import 'widgets/trump_picker.dart';
import 'widgets/turn_status_line.dart';

/// The live table.
///
/// Reads the match from [matchProvider] and sends taps back to it as commands.
/// It decides nothing about the rules: which cards are tappable comes from the
/// engine's legal-move list, so the highlight and the engine cannot disagree.
///
/// The match must already be started by whoever opened this screen, which
/// keeps the screen free of setup arguments and lets a resumed match arrive the
/// same way a new one does.
final class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  /// Whether the scoreboard is open over the table.
  ///
  /// Screen state, not match state: closing the app with it open should not
  /// reopen it, and the controller has no business knowing a sheet is up.
  bool _showScores = false;

  /// The player's hand in fan order, as it was when the hand was dealt.
  ///
  /// Kept for the whole hand so the cards that are left keep their places
  /// instead of closing up after every trick; see [HandFan]. Presentation
  /// state, which is why it lives here and not in the session.
  List<PlayingCard?> _slots = const <PlayingCard?>[];

  /// Which hand [_slots] belongs to, so a new deal rebuilds it.
  int? _slotsHandIndex;

  /// The same, for the open hand across the table.
  ///
  /// Kept for the same reason the player's own is: a fan that re-flowed after
  /// every trick would move the card the player was about to tap, and the
  /// open hand is tapped by the declarer exactly as often as its own.
  List<PlayingCard?> _dummySlots = const <PlayingCard?>[];
  int? _dummySlotsHandIndex;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final MatchSession? session = ref.watch(matchProvider);
    final AppSettings settings = ref.watch(settingsProvider);

    if (session == null) {
      // No table open: either nothing started it, or the player just left.
      return FeltBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(strings.appTitle)),
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(strings.commonBack),
            ),
          ),
        ),
      );
    }

    final RuleProfile profile = session.profile;
    // Named from the match seed, so a resumed match seats the same people.
    final List<String> seatNames = SeatNames.forMatch(
      seed: session.dealSeed,
      seatCount: session.seatCount,
      humanSeat: session.humanSeat,
      humanName: strings.seatSelf,
    );

    return PopScope<void>(
      // The opponents keep playing while this screen is alive, so a back
      // gesture has to be an explicit decision to abandon the match rather
      // than a way to leave it running unseen.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) {
          _confirmLeave(strings);
        }
      },
      child: FeltBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(profile.mode.turkishShortName),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: strings.gameplayLeaveMatch,
              onPressed: () => _confirmLeave(strings),
            ),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.leaderboard_rounded),
                tooltip: strings.gameplayScoreboardTooltip,
                onPressed: () => setState(() => _showScores = !_showScores),
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Expanded(
                      // The table doubles as the drop zone, so a dragged card
                      // is played by letting go anywhere over it rather than
                      // onto a small target.
                      child: DragTarget<PlayingCard>(
                        onWillAcceptWithDetails:
                            (DragTargetDetails<PlayingCard> details) =>
                                session.isPlayingOwnHand,
                        onAcceptWithDetails:
                            (DragTargetDetails<PlayingCard> details) =>
                                _play(details.data, settings),
                        builder: (
                          BuildContext context,
                          List<PlayingCard?> candidate,
                          List<Object?> rejected,
                        ) =>
                            MatchTable(
                          session: session,
                          strings: strings,
                          seatNames: seatNames,
                          gatherDuration: MatchPacing(settings).trickGather,
                          highlightDropZone: candidate.isNotEmpty,
                          farEdge:
                              _openHand(session, strings, seatNames, settings),
                        ),
                      ),
                    ),
                    TurnStatusLine(session: session, strings: strings),
                    const SizedBox(height: AppSpacing.sm),
                    HandFan(
                      cards: _handSlots(session),
                      legalCards: _legalCards(session, session.humanSeat),
                      showHints: settings.showLegalMoveHints,
                      // Dragging plays from the player's own hand onto the
                      // felt. The open hand opposite is tapped instead: a
                      // drag from the far edge across the trick would be
                      // indistinguishable from one out of the player's own
                      // fan, which is the one thing that must stay obvious.
                      allowDrag:
                          settings.allowDragToPlay && session.isPlayingOwnHand,
                      onCardTap: session.isPlayingOwnHand
                          ? (PlayingCard card) => _play(card, settings)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
                if (session.phase == MatchPhase.handSummary &&
                    session.lastHandScore != null)
                  HandSummarySheet(
                    strings: strings,
                    score: session.lastHandScore!,
                    totals: session.totals,
                    seatNames: seatNames,
                    title: MatchLabels.handTitle(strings, session),
                    actionLabel: strings.gameplayNextHand,
                    onContinue: () =>
                        ref.read(matchProvider.notifier).continueAfterHand(),
                  ),
                // Floated over the felt rather than stacked above the fan:
                // the player decides by looking at their cards, so the hand
                // stays on screen at full size and the picker takes the
                // table's space, which is idle during the declaration round.
                // The auction, the trump choice and the declaration round all
                // float over the felt rather than stacking above the fan: the
                // player decides by looking at their cards, so the hand stays
                // on screen at full size and the panel takes the table's
                // space, which is idle while a question is open.
                if (session.isAwaitingBid)
                  _overlay(
                    BiddingPanel(
                      options: session.legalBids,
                      strings: strings,
                      standingBid: session.standingBid,
                      standingBidderName: session.standingBidder == null
                          ? null
                          : seatNames[session.standingBidder!],
                      onBid: (int tricks) => _bid(tricks, settings),
                      onPass: () => _pass(settings),
                    ),
                    maxWidth: 282,
                  ),
                if (session.isAwaitingTrump)
                  _overlay(
                    TrumpPicker(
                      options: session.legalTrumps,
                      strings: strings,
                      bid: session.contractBid ?? 0,
                      wasForced: session.contractWasForced,
                      onChoose: (Suit trump) => _chooseTrump(trump, settings),
                    ),
                    maxWidth: 282,
                  ),
                if (session.isAwaitingDeclaration)
                  _overlay(
                    DeclarationPanel(
                      options: MatchTurn.legalDeclarations(session),
                      strings: strings,
                      onDeclare: (int tricks) => _declare(tricks, settings),
                    ),
                  ),
                if (_showScores)
                  ScoreSheetPanel(
                    session: session,
                    strings: strings,
                    seatNames: seatNames,
                    caption: MatchLabels.caption(strings, session),
                    onClose: () => setState(() => _showScores = false),
                  ),
                if (session.isOver)
                  MatchOverPanel(
                    strings: strings,
                    headline: MatchLabels.headline(strings, session),
                    detail: MatchLabels.detail(strings, session, seatNames),
                    seatNames: seatNames,
                    totals: session.totals,
                    onRematch: () => ref.read(matchProvider.notifier).rematch(),
                    onLeave: _leave,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Floats a question over the felt, where the table is idle anyway.
  ///
  /// Width-capped so the side seats stay visible beside it. Who is still in
  /// the auction and who has passed is part of the question being asked, so a
  /// panel that covered those rails would be hiding its own context.
  Widget _overlay(Widget child, {double maxWidth = 400}) => Align(
        alignment: const Alignment(0, -0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      );

  /// Offers a contract, with the same touch feedback a card play gets.
  void _bid(int tricks, AppSettings settings) {
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    ref.read(matchProvider.notifier).bid(tricks);
  }

  /// Withdraws from the auction. Final for the hand, so it gets the heavier
  /// feedback a committed decision deserves.
  void _pass(AppSettings settings) {
    if (settings.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    ref.read(matchProvider.notifier).pass();
  }

  /// Names the trump for the hand.
  void _chooseTrump(Suit trump, AppSettings settings) {
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    ref.read(matchProvider.notifier).chooseTrump(trump);
  }

  /// Plays [card], with the touch feedback the player asked for.
  ///
  /// The haptic fires here rather than in the controller: it is feedback for a
  /// gesture, so it belongs to the gesture, and the controller stays free of
  /// device APIs. It is a system call, not a plugin, so it needs nothing in
  /// the native host project.
  void _play(PlayingCard card, AppSettings settings) {
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    ref.read(matchProvider.notifier).playCard(card);
  }

  /// Records the player's declaration, with the same touch feedback a card
  /// play gets: it is the same kind of commitment.
  void _declare(int tricks, AppSettings settings) {
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    ref.read(matchProvider.notifier).declare(tricks);
  }

  /// The open hand across the table, or null when there is none to show.
  ///
  /// Shown whenever it is face up, whoever is playing it. When the player is
  /// the declarer the cards are tappable on the open hand's turn; when a bot
  /// is the declarer and the open hand is the **player's own**, the same
  /// cards are shown and nothing responds -- which is the classic rule, and
  /// the caption says so rather than leaving a hand that ignores taps.
  Widget? _openHand(
    MatchSession session,
    AppStrings strings,
    List<String> seatNames,
    AppSettings settings,
  ) {
    final int? dummy = session.dummySeat;
    if (!session.isDummyRevealed || dummy == null) {
      return null;
    }
    final bool mine = session.isPlayingDummyHand;
    final String caption;
    if (session.humanIsDummy) {
      final int? declarer = session.declarerSeat;
      caption = strings.dummyYoursCaption(
        declarer != null && declarer < seatNames.length
            ? seatNames[declarer]
            : '',
      );
    } else {
      final String name = dummy < seatNames.length ? seatNames[dummy] : '';
      caption = mine
          ? strings.dummyPartnerTurnCaption(name)
          : strings.dummyPartnerCaption(name);
    }
    return DummyHandView(
      cards: _dummyHandSlots(session),
      caption: caption,
      legalCards: _legalCards(session, dummy),
      showHints: settings.showLegalMoveHints,
      onCardTap: mine ? (PlayingCard card) => _play(card, settings) : null,
    );
  }

  /// The open hand as fan slots.
  List<PlayingCard?> _dummyHandSlots(MatchSession session) {
    final List<PlayingCard> inHand = session.dummyHand;
    final int handIndex = session.match.handIndex;
    if (_dummySlotsHandIndex != handIndex ||
        inHand.length > _dummySlots.length) {
      _dummySlots = CardSorting.bySuitStrongestFirst(inHand);
      _dummySlotsHandIndex = handIndex;
      return _dummySlots;
    }
    final Set<PlayingCard> remaining = inHand.toSet();
    return <PlayingCard?>[
      for (final PlayingCard? card in _dummySlots)
        if (card != null && remaining.contains(card)) card else null,
    ];
  }

  /// The player's hand as fan slots: dealt order, holes where cards have
  /// already been played.
  ///
  /// Memoised per hand rather than recomputed from what is left, which is the
  /// whole point: sorting the remaining cards every build is what made the
  /// fan close up after each trick. The layout is rebuilt when the engine
  /// deals a new hand, and also when the hand is somehow larger than the
  /// slots -- which is what a match resumed mid-hand looks like, since the
  /// save restores cards but not the arrangement they were last seen in.
  List<PlayingCard?> _handSlots(MatchSession session) {
    final List<PlayingCard> inHand = session.humanHand;
    final int handIndex = session.match.handIndex;
    if (_slotsHandIndex != handIndex || inHand.length > _slots.length) {
      _slots = CardSorting.bySuitStrongestFirst(inHand);
      _slotsHandIndex = handIndex;
      return _slots;
    }
    final Set<PlayingCard> remaining = inHand.toSet();
    return <PlayingCard?>[
      for (final PlayingCard? card in _slots)
        if (card != null && remaining.contains(card)) card else null,
    ];
  }

  /// The cards the player may tap in [seat]'s hand, straight from the engine.
  ///
  /// Empty unless the player is the one choosing **and** that hand is the one
  /// on turn. Both halves matter in a partnership deal: a declarer looking at
  /// two hands must see highlights on exactly the one it is playing from, or
  /// the highlight stops meaning anything.
  Set<PlayingCard> _legalCards(MatchSession session, int seat) {
    if (!session.isHumanTurn || session.seatToPlay != seat) {
      return const <PlayingCard>{};
    }
    return session.match.legalCards(seat).toSet();
  }

  Future<void> _confirmLeave(AppStrings strings) async {
    if (await showLeaveMatchDialog(context, strings) && mounted) {
      _leave();
    }
  }

  void _leave() {
    ref.read(matchProvider.notifier).leave();
    Navigator.of(context).pop();
  }
}
