import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/cards/card_sorting.dart';
import '../../core/cards/playing_card.dart';
import '../../core/persistence/app_settings.dart';
import '../../core/rules/rule_profile.dart';
import '../../core/rules/scoring_rules.dart';
import '../../games/spades_batak/spades_batak_engine.dart';
import 'match_controller.dart';
import 'match_session.dart';
import 'widgets/felt_background.dart';
import 'widgets/hand_fan.dart';
import 'widgets/hand_summary_sheet.dart';
import 'widgets/match_over_panel.dart';
import 'widgets/match_table.dart';
import 'widgets/score_strip.dart';
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
  static const SpadesBatakEngine _engine = SpadesBatakEngine();

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
    final List<String> seatNames = <String>[
      for (int seat = 0; seat < session.seatCount; seat++)
        strings.seatName(seat),
    ];

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
          ),
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: ScoreStrip(
                        seatNames: seatNames,
                        totals: session.totals,
                        leadingSeats: session.match.leadingSeats,
                        caption: _caption(strings, session),
                      ),
                    ),
                    Expanded(
                      // The table doubles as the drop zone, so a dragged card
                      // is played by letting go anywhere over it rather than
                      // onto a small target.
                      child: DragTarget<PlayingCard>(
                        onWillAcceptWithDetails:
                            (DragTargetDetails<PlayingCard> details) =>
                                session.isHumanTurn,
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
                          highlightDropZone: candidate.isNotEmpty,
                        ),
                      ),
                    ),
                    TurnStatusLine(session: session, strings: strings),
                    const SizedBox(height: AppSpacing.sm),
                    HandFan(
                      cards: CardSorting.forHandFan(
                        session.humanHand,
                        trump: session.hand?.trump ?? profile.fixedTrump,
                      ),
                      legalCards: _legalCards(session),
                      showHints: settings.showLegalMoveHints,
                      allowDrag: settings.allowDragToPlay,
                      onCardTap: session.isHumanTurn
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
                    title: strings.gameplayHandSummaryTitle,
                    actionLabel: strings.gameplayNextHand,
                    onContinue: () =>
                        ref.read(matchProvider.notifier).continueAfterHand(),
                  ),
                if (session.isOver)
                  MatchOverPanel(
                    strings: strings,
                    headline: _headline(strings, session),
                    detail: _detail(strings, session, seatNames),
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

  /// The cards the player may tap, straight from the engine.
  Set<PlayingCard> _legalCards(MatchSession session) {
    if (!session.isHumanTurn) {
      return const <PlayingCard>{};
    }
    return _engine.legalCards(session.match, session.humanSeat).toSet();
  }

  /// `Dagitim 3 / 8`, or the hand number plus the target score.
  String _caption(AppStrings strings, MatchSession session) {
    final BatakScoringRules rules = session.profile.scoringRules;
    return switch (rules.endCondition) {
      MatchEndCondition.fixedRounds =>
        strings.handProgress(session.displayHandNumber, rules.roundCount),
      MatchEndCondition.targetScore =>
        '${strings.handProgress(session.displayHandNumber, null)}'
            '   ${strings.targetScore(rules.targetScore)}',
    };
  }

  String _headline(AppStrings strings, MatchSession session) {
    if (session.winners.length > 1) {
      return strings.gameplayDraw;
    }
    return session.humanWon ? strings.gameplayYouWon : strings.gameplayYouLost;
  }

  String _detail(
    AppStrings strings,
    MatchSession session,
    List<String> seatNames,
  ) {
    final List<String> names = <String>[
      for (final int seat in session.winners)
        seat < seatNames.length ? seatNames[seat] : '',
    ];
    return names.length == 1
        ? strings.winnerLine(names.first)
        : names.join(', ');
  }

  Future<void> _confirmLeave(AppStrings strings) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(strings.gameplayLeaveConfirmTitle),
        content: Text(strings.gameplayLeaveConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.gameplayLeaveConfirmAction),
          ),
        ],
      ),
    );
    if (leave ?? false) {
      _leave();
    }
  }

  void _leave() {
    ref.read(matchProvider.notifier).leave();
    Navigator.of(context).pop();
  }
}
