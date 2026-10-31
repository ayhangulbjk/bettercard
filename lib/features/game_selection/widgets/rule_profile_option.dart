import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/rule_profile.dart';
import '../../gameplay/widgets/felt_background.dart';

/// A selectable rule preset row.
final class RuleProfileOption extends StatelessWidget {
  const RuleProfileOption({
    required this.profile,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final RuleProfile profile;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            child: AppPanel(
              accent: selected,
              child: Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color:
                        selected ? AppColors.goldBright : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      profile.turkishName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
