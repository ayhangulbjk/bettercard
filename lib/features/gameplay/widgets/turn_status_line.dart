import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../match_session.dart';

/// Whose turn it is, or why a move was refused.
final class TurnStatusLine extends StatelessWidget {
  const TurnStatusLine({
    required this.session,
    required this.strings,
    super.key,
  });

  final MatchSession session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? rejection = session.rejection == null
        ? null
        : strings.moveRejected(session.rejection!);
    final bool yours = session.isHumanTurn ||
        session.isAwaitingDeclaration ||
        session.isAwaitingBid ||
        session.isAwaitingTrump;

    final String status;
    if (session.isAwaitingDeclaration ||
        session.isAwaitingBid ||
        session.isAwaitingTrump) {
      // The panel over the table asks the question in full. Repeating it here
      // printed the same sentence twice on one screen.
      status = '';
    } else if (session.isDeclaring) {
      status = strings.gameplayDeclaring;
    } else if (session.isBidding) {
      status = strings.gameplayWaitingForBids;
    } else if (session.isChoosingTrump) {
      status = strings.gameplayWaitingForTrump;
    } else {
      status = yours ? strings.gameplayYourTurn : strings.gameplayWaiting;
    }

    return SizedBox(
      height: 22,
      child: Text(
        rejection ?? status,
        style: text.labelSmall?.copyWith(
          color: rejection != null
              ? AppColors.warning
              : (yours ? AppColors.goldBright : AppColors.textMuted),
        ),
      ),
    );
  }
}
