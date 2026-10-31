import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';

/// Marks a screen or region as not-yet-functional.
///
/// The project rule is that incomplete functionality is never presented as
/// working. This banner is how that rule is kept visible in the product
/// itself, not just in the documentation: any screen that shows mock data
/// shows this too.
final class PlaceholderBanner extends StatelessWidget {
  const PlaceholderBanner({required this.message, this.title, super.key});

  /// Short Turkish heading. Defaults to a generic preview label.
  final String? title;

  /// What exactly is not real yet.
  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0x1FD9A441),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.warning, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.construction_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title ?? 'Önizleme',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
