import 'package:meta/meta.dart';

import '../ai/ai_difficulty.dart';

/// How fast card and trick animations run.
enum AnimationSpeed {
  slow(1.6),
  normal(1.0),
  fast(0.55),
  instant(0.0);

  const AnimationSpeed(this.multiplier);

  /// Duration multiplier applied to every animation. Zero skips animation
  /// entirely, which is what players who want maximum pace ask for.
  final double multiplier;

  bool get isInstant => multiplier == 0;
}

/// Table felt options.
enum TableTheme {
  emerald('Zümrüt'),
  forest('Orman'),
  midnight('Gece'),
  burgundy('Bordo');

  const TableTheme(this.turkishName);

  final String turkishName;
}

/// Card back options.
enum CardBackStyle {
  classicBlue('Klasik Mavi'),
  goldLattice('Altın Kafes'),
  deepGreen('Koyu Yeşil');

  const CardBackStyle(this.turkishName);

  final String turkishName;
}

/// Player-owned preferences.
///
/// Distinct from a [RuleProfile]: these never affect the outcome of a game, so
/// changing them mid-match is safe. Anything that changes legality or scoring
/// belongs in the rule profile, which is frozen when a match starts.
@immutable
class AppSettings {
  const AppSettings({
    this.playerName = 'Oyuncu',
    this.localeCode = 'tr',
    this.aiDifficulty = AiDifficulty.normal,
    this.animationSpeed = AnimationSpeed.normal,
    this.tableTheme = TableTheme.emerald,
    this.cardBackStyle = CardBackStyle.classicBlue,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.quickPlay = false,
    this.showLegalMoveHints = true,
    this.allowDragToPlay = true,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  /// Defaults for a fresh install.
  static const AppSettings defaults = AppSettings();

  final String playerName;
  final String localeCode;
  final AiDifficulty aiDifficulty;
  final AnimationSpeed animationSpeed;
  final TableTheme tableTheme;
  final CardBackStyle cardBackStyle;
  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Skips non-essential pauses between tricks.
  final bool quickPlay;

  /// Whether playable cards are highlighted. This only surfaces information
  /// the player already has a right to; it never reveals a hidden hand.
  final bool showLegalMoveHints;

  /// Whether cards can be dragged as well as tapped.
  final bool allowDragToPlay;

  final int schemaVersion;

  AppSettings copyWith({
    String? playerName,
    String? localeCode,
    AiDifficulty? aiDifficulty,
    AnimationSpeed? animationSpeed,
    TableTheme? tableTheme,
    CardBackStyle? cardBackStyle,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? quickPlay,
    bool? showLegalMoveHints,
    bool? allowDragToPlay,
  }) =>
      AppSettings(
        playerName: playerName ?? this.playerName,
        localeCode: localeCode ?? this.localeCode,
        aiDifficulty: aiDifficulty ?? this.aiDifficulty,
        animationSpeed: animationSpeed ?? this.animationSpeed,
        tableTheme: tableTheme ?? this.tableTheme,
        cardBackStyle: cardBackStyle ?? this.cardBackStyle,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        quickPlay: quickPlay ?? this.quickPlay,
        showLegalMoveHints: showLegalMoveHints ?? this.showLegalMoveHints,
        allowDragToPlay: allowDragToPlay ?? this.allowDragToPlay,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'playerName': playerName,
        'localeCode': localeCode,
        'aiDifficulty': aiDifficulty.name,
        'animationSpeed': animationSpeed.name,
        'tableTheme': tableTheme.name,
        'cardBackStyle': cardBackStyle.name,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'quickPlay': quickPlay,
        'showLegalMoveHints': showLegalMoveHints,
        'allowDragToPlay': allowDragToPlay,
      };

  /// Reads settings, falling back to a default for any field that is missing
  /// or unrecognised. Settings are a convenience, so a corrupt entry should
  /// degrade to the default rather than block startup.
  static AppSettings fromJson(Map<String, Object?> json) => AppSettings(
        schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
        playerName: json['playerName'] as String? ?? 'Oyuncu',
        localeCode: json['localeCode'] as String? ?? 'tr',
        aiDifficulty: _byName(
          AiDifficulty.values,
          json['aiDifficulty'],
          AiDifficulty.normal,
        ),
        animationSpeed: _byName(
          AnimationSpeed.values,
          json['animationSpeed'],
          AnimationSpeed.normal,
        ),
        tableTheme: _byName(
          TableTheme.values,
          json['tableTheme'],
          TableTheme.emerald,
        ),
        cardBackStyle: _byName(
          CardBackStyle.values,
          json['cardBackStyle'],
          CardBackStyle.classicBlue,
        ),
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        quickPlay: json['quickPlay'] as bool? ?? false,
        showLegalMoveHints: json['showLegalMoveHints'] as bool? ?? true,
        allowDragToPlay: json['allowDragToPlay'] as bool? ?? true,
      );

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.playerName == playerName &&
      other.localeCode == localeCode &&
      other.aiDifficulty == aiDifficulty &&
      other.animationSpeed == animationSpeed &&
      other.tableTheme == tableTheme &&
      other.cardBackStyle == cardBackStyle &&
      other.soundEnabled == soundEnabled &&
      other.hapticsEnabled == hapticsEnabled &&
      other.quickPlay == quickPlay &&
      other.showLegalMoveHints == showLegalMoveHints &&
      other.allowDragToPlay == allowDragToPlay &&
      other.schemaVersion == schemaVersion;

  @override
  int get hashCode => Object.hash(
        playerName,
        localeCode,
        aiDifficulty,
        animationSpeed,
        tableTheme,
        cardBackStyle,
        soundEnabled,
        hapticsEnabled,
        quickPlay,
        showLegalMoveHints,
        allowDragToPlay,
        schemaVersion,
      );
}
