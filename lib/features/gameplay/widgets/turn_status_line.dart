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
    final bool yours = session.isHumanTurn;

    return SizedBox(
      height: 22,
      child: Text(
        rejection ??
            (yours ? strings.gameplayYourTurn : strings.gameplayWaiting),
        style: text.labelSmall?.copyWith(
          color: rejection != null
              ? AppColors.warning
              : (yours ? AppColors.goldBright : AppColors.textMuted),
        ),
      ),
    );
  }
}
