import 'package:flutter/material.dart';

import '../core/rules/game_mode.dart';
import '../features/ai_lab/ai_lab_screen.dart';
import '../features/game_selection/game_setup_screen.dart';
import '../features/gameplay/match_screen.dart';
import '../features/gameplay/table_preview_screen.dart';
import '../features/home/home_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/statistics/statistics_screen.dart';

/// Named routes.
///
/// Plain `Navigator` with named routes rather than a routing package: the app
/// is a handful of full-screen destinations with no deep links, no URLs and no
/// web target, so a router dependency would add a concept without solving a
/// problem here.
abstract final class AppRoutes {
  static const String home = '/';
  static const String gameSetup = '/setup';
  static const String tablePreview = '/table-preview';
  static const String match = '/match';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
  static const String rules = '/rules';
  static const String aiLab = '/ai-lab';

  /// Resolves [route] to a page.
  ///
  /// Every case is written `AppRoutes.x` on purpose. A bare identifier in a
  /// pattern position is a *variable* pattern in Dart 3, which would bind and
  /// match anything; only a qualified reference is a constant pattern.
  static Route<void> onGenerateRoute(RouteSettings route) {
    final Object? args = route.arguments;
    return switch (route.name) {
      AppRoutes.gameSetup => _page(
          GameSetupScreen(mode: args! as GameMode),
          route,
        ),
      AppRoutes.tablePreview => _page(
          TablePreviewScreen(mode: args! as GameMode),
          route,
        ),
      // The match screen takes no arguments: whoever opens it has already
      // started the match on the controller, so a resumed match and a fresh
      // one arrive the same way.
      AppRoutes.match => _page(const MatchScreen(), route),
      AppRoutes.settings => _page(const SettingsScreen(), route),
      AppRoutes.statistics => _page(const StatisticsScreen(), route),
      AppRoutes.rules => _page(const RulesScreen(), route),
      AppRoutes.aiLab => _page(const AiLabScreen(), route),
      _ => _page(const HomeScreen(), route),
    };
  }

  static Route<void> _page(Widget child, RouteSettings route) =>
      MaterialPageRoute<void>(
        builder: (BuildContext context) => child,
        settings: route,
      );
}
