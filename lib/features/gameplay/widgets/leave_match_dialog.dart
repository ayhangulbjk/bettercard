import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';

/// Asks whether to abandon the match in progress.
///
/// The question is asked at all because the opponents keep playing while the
/// table is open: a back gesture has to be a decision to abandon the match,
/// not a way to leave it running unseen.
///
/// Returns true only on an explicit yes, so a dismissed dialog keeps the
/// match.
Future<bool> showLeaveMatchDialog(
  BuildContext context,
  AppStrings strings,
) async {
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
  return leave ?? false;
}
