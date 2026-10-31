import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_strings.dart';
import 'providers.dart';
import 'routes.dart';
import 'theme/app_theme.dart';

/// Application root.
final class BatakKingApp extends ConsumerWidget {
  const BatakKingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    return MaterialApp(
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (BuildContext context, Widget? child) {
        // Clamp text scaling so a very large system font cannot push cards and
        // score panels off a small portrait screen, while still honouring the
        // player's accessibility preference up to a readable ceiling.
        final MediaQueryData media = MediaQuery.of(context);
        final double scale = media.textScaler.scale(1).clamp(1.0, 1.35);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
