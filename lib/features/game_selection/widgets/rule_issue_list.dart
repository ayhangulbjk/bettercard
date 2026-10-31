import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/rules/rule_validation.dart';
import '../../gameplay/widgets/felt_background.dart';

/// Shows the rule validator's verdict.
final class RuleIssueList extends StatelessWidget {
  const RuleIssueList({
    required this.issues,
    required this.emptyMessage,
    super.key,
  });

  final List<RuleIssue> issues;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (issues.isEmpty) {
      return AppPanel(
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(emptyMessage, style: text.bodyMedium)),
          ],
        ),
      );
    }
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: issues
            .map(
              (RuleIssue issue) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      issue.isError
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      color:
                          issue.isError ? AppColors.danger : AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        issue.turkishMessage,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
