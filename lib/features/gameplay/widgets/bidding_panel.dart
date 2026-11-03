import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import 'felt_background.dart';

/// The auction, asked of the player.
///
/// Laid out like the declaration panel on purpose -- title, a grid of round
/// numbers, one wide button underneath -- because the gesture is the same one
/// and the hand stays on screen behind it either way. What differs is what
/// the numbers mean and that there is a standing bid to beat, so that is
/// what the panel says above the grid.
///
/// Only legal contracts are offered. A player cannot select an illegal bid
/// here because illegal bids are not drawn, which is the same guarantee the
/// card highlight gives: the engine would refuse it, so it is never offered.
final class BiddingPanel extends StatelessWidget {
  const BiddingPanel({
    required this.options,
    required this.strings,
    required this.onBid,
    required this.onPass,
    this.standingBid,
    this.standingBidderName,
    super.key,
  });

  /// The contracts the player may offer, from the engine.
  final List<int> options;

  final AppStrings strings;
  final void Function(int tricks) onBid;
  final VoidCallback onPass;

  /// The highest contract on the table, or null when nobody has bid.
  final int? standingBid;

  /// Who holds it, for the line above the grid.
  final String? standingBidderName;

  /// Four to a row, not five. The panel floats over the felt and the side
  /// seats have to stay visible beside it: who is still in the auction and
  /// who has passed is part of the question being asked.
  static const int _perRow = 4;
  static const double _chipSize = 48;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<List<int>> rows = <List<int>>[
      for (int start = 0; start < options.length; start += _perRow)
        options.sublist(
          start,
          start + _perRow > options.length ? options.length : start + _perRow,
        ),
    ];

    return AppPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(strings.gameplayBidTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            standingBid == null
                ? strings.gameplayNoBidYet
                : strings.gameplayStandingBid(
                    standingBidderName ?? '',
                    standingBid!,
                  ),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final List<int> row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final int option in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: _BidChip(
                        value: option,
                        onTap: () => onBid(option),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: _chipSize * _perRow,
            child: OutlinedButton(
              onPressed: onPass,
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.goldDim),
              ),
              child: Text(strings.gameplayPass),
            ),
          ),
        ],
      ),
    );
  }
}

/// One offerable contract.
class _BidChip extends StatelessWidget {
  const _BidChip({required this.value, required this.onTap});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceElevated,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.goldDim),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: BiddingPanel._chipSize,
            height: BiddingPanel._chipSize,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );
}
