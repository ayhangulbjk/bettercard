import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/simulation/headless_simulator.dart';
import '../../core/simulation/simulation_config.dart';
import '../../core/simulation/simulation_report.dart';
import '../gameplay/widgets/felt_background.dart';
import '../gameplay/widgets/placeholder_banner.dart';

/// Runs the headless simulator from inside the app.
///
/// This exists so the AI work is measurable from day one rather than asserted.
/// Today it can only run the legal-random baseline through the shared trick
/// core, which is a correctness and throughput check, not a strength claim --
/// and the screen says so.
final class AiLabScreen extends ConsumerStatefulWidget {
  const AiLabScreen({super.key});

  @override
  ConsumerState<AiLabScreen> createState() => _AiLabScreenState();
}

class _AiLabScreenState extends ConsumerState<AiLabScreen> {
  static const List<int> _handCountOptions = <int>[50, 250, 1000];

  int _handCount = 250;
  bool _running = false;
  SimulationReport? _report;

  Future<void> _run() async {
    setState(() => _running = true);
    // Yield one frame so the button reaches its pressed state before the
    // synchronous batch begins. The batch itself is deliberately NOT moved to
    // an isolate here: at these sizes it is milliseconds, and introducing an
    // isolate before any search policy exists would be untested machinery.
    await Future<void>.delayed(Duration.zero);
    final SimulationReport report = const HeadlessSimulator().runRandomBaseline(
      SimulationConfig(handCount: _handCount, playerCount: 4),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _report = report;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final SimulationReport? report = _report;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(strings.aiLabTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.thumbZoneReserve,
            ),
            children: <Widget>[
              PlaceholderBanner(
                title: 'Güç iddiası yok',
                message: strings.aiLabNoStrengthClaim,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.aiLabHandCount, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: _handCountOptions
                    .map(
                      (int count) => ChoiceChip(
                        label: Text('$count'),
                        selected: count == _handCount,
                        onSelected: _running
                            ? null
                            : (bool _) => setState(() => _handCount = count),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _running ? null : _run,
                child: Text(
                  _running ? strings.aiLabRunning : strings.aiLabRunBaseline,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (report != null) _ReportPanel(report: report),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.report});

  final SimulationReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool clean = report.totalIllegalAttempts == 0;
    return AppPanel(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                clean ? Icons.verified_outlined : Icons.error_outline_rounded,
                size: 18,
                color: clean ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  clean ? 'Kural dışı hamle yok' : 'Kural dışı hamle bulundu',
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.describe(),
            style: text.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
