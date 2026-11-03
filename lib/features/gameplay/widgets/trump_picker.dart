import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/cards/suit.dart';
import 'felt_background.dart';
import 'suit_pip.dart';

/// Asks the contract winner which suit is trump.
///
/// Four big targets and nothing else on screen but the hand behind it. This
/// is the most consequential single tap in the mode -- it decides what every
/// card in the hand is worth -- so it gets room rather than a dropdown.
///
/// Naming a trump is compulsory, so there is no cancel. The panel cannot be
/// dismissed without answering, which matches the engine: no card may be
/// played until a suit is named.
final class TrumpPicker extends StatelessWidget {
  const TrumpPicker({
    required this.options,
    required this.strings,
    required this.bid,
    required this.onChoose,
    this.wasForced = false,
    super.key,
  });

  /// The suits the engine allows, which is all four.
  final List<Suit> options;

  final AppStrings strings;

  /// The contract this trump has to make.
  final int bid;

  /// Whether the contract was forced by a passed-out auction, which is worth
  /// saying: the player did not ask for it.
  final bool wasForced;

  final void Function(Suit trump) onChoose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(strings.gameplayTrumpTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            wasForced
                ? strings.gameplayForcedContract(bid)
                : strings.gameplayYourContract(bid),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Suit suit in options)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: _SuitTarget(
                    suit: suit,
                    onTap: () => onChoose(suit),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuitTarget extends StatelessWidget {
  const _SuitTarget({required this.suit, required this.onTap});

  final Suit suit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.goldDim),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Semantics(
            button: true,
            label: suit.turkishName,
            child: SizedBox(
              // Four of these plus their gaps have to fit the panel, which
              // is itself capped so the side seats stay visible beside it.
              width: 54,
              height: 64,
              child: Center(
                child: SuitPip(
                  suit: suit,
                  size: 32,
                  color: suit.isRed ? AppColors.cardRed : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
}
