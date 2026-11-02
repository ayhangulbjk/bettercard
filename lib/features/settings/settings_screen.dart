import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/persistence/app_settings.dart';
import '../gameplay/widgets/felt_background.dart';
import '../gameplay/widgets/placeholder_banner.dart';

/// Preferences.
///
/// Every control here is wired to the real settings model and takes effect
/// immediately. What is not real yet is persistence across restarts: the
/// in-memory repository is bound until the native host folders exist, and the
/// banner says so rather than letting the screen imply otherwise.
final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);
    final TextTheme text = Theme.of(context).textTheme;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(strings.settingsTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.thumbZoneReserve,
            ),
            children: <Widget>[
              const PlaceholderBanner(
                title: 'Kalıcı kayıt yok',
                message: 'Ayarlar şu anda yalnızca uygulama açıkken saklanır. '
                    'Diske kayıt, platform klasörleri oluşturulduğunda '
                    'eklenecek.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.settingsPresentation, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              AppPanel(
                child: Column(
                  children: <Widget>[
                    _SpeedRow(
                      label: strings.settingsAnimationSpeed,
                      current: settings.animationSpeed,
                      strings: strings,
                      onChanged: (AnimationSpeed speed) => controller.update(
                        (AppSettings s) => s.copyWith(animationSpeed: speed),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.settingsQuickPlay,
                          style: text.bodyLarge),
                      value: settings.quickPlay,
                      onChanged: (bool value) => controller.update(
                        (AppSettings s) => s.copyWith(quickPlay: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        strings.settingsLegalHints,
                        style: text.bodyLarge,
                      ),
                      subtitle: Text(
                        strings.settingsLegalHintsDetail,
                        style: text.bodySmall,
                      ),
                      value: settings.showLegalMoveHints,
                      onChanged: (bool value) => controller.update(
                        (AppSettings s) =>
                            s.copyWith(showLegalMoveHints: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        strings.settingsDragToPlay,
                        style: text.bodyLarge,
                      ),
                      value: settings.allowDragToPlay,
                      onChanged: (bool value) => controller.update(
                        (AppSettings s) => s.copyWith(allowDragToPlay: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.settingsGeneral, style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              AppPanel(
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.settingsSound, style: text.bodyLarge),
                      // Disabled rather than hidden: the preference exists and
                      // is stored, but no audio ships in this build, so a
                      // working switch would promise a sound that never plays.
                      subtitle: Text(
                        strings.settingsSoundUnavailable,
                        style: text.bodySmall,
                      ),
                      value: false,
                      onChanged: null,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(strings.settingsHaptics, style: text.bodyLarge),
                      value: settings.hapticsEnabled,
                      onChanged: (bool value) => controller.update(
                        (AppSettings s) => s.copyWith(hapticsEnabled: value),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(strings.settingsLanguage, style: text.bodyLarge),
                      trailing: Text('Türkçe', style: text.titleMedium),
                      subtitle: Text(
                        'İngilizce desteği için altyapi hazir, metinler henüz '
                        'eklenmedi.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.label,
    required this.current,
    required this.strings,
    required this.onChanged,
  });

  final String label;
  final AnimationSpeed current;
  final AppStrings strings;
  final ValueChanged<AnimationSpeed> onChanged;

  String _name(AnimationSpeed speed) => switch (speed) {
        AnimationSpeed.slow => strings.speedSlow,
        AnimationSpeed.normal => strings.speedNormal,
        AnimationSpeed.fast => strings.speedFast,
        AnimationSpeed.instant => strings.speedInstant,
      };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: AnimationSpeed.values
                .map(
                  (AnimationSpeed speed) => ChoiceChip(
                    label: Text(_name(speed)),
                    selected: speed == current,
                    onSelected: (bool _) => onChanged(speed),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
}
