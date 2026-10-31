import 'package:flutter/material.dart';

/// The project's colour vocabulary.
///
/// A deep forest-green felt with restrained gold is the look a Turkish card
/// table actually has, and it deliberately avoids the saturated reds, neon and
/// coin motifs of casino apps. Gold is used as an accent on a few elements
/// only; spreading it everywhere is what makes an interface look cheap.
abstract final class AppColors {
  // Felt.
  static const Color feltDeep = Color(0xFF0B2B21);
  static const Color feltBase = Color(0xFF113C2D);
  static const Color feltRaised = Color(0xFF17503B);
  static const Color feltEdge = Color(0xFF071A14);

  // Surfaces above the felt.
  static const Color surface = Color(0xFF13241E);
  static const Color surfaceElevated = Color(0xFF1B3129);
  static const Color surfaceSunken = Color(0xFF0C1A15);

  // Gold accents.
  static const Color gold = Color(0xFFD4AF6A);
  static const Color goldBright = Color(0xFFF0D49A);
  static const Color goldDim = Color(0xFF8C7342);

  // Text.
  static const Color textPrimary = Color(0xFFF4EFE3);
  static const Color textSecondary = Color(0xFFBFC9C2);
  static const Color textMuted = Color(0xFF8A968F);
  static const Color textOnCard = Color(0xFF17201C);

  // Card faces.
  static const Color cardFace = Color(0xFFF7F3E8);
  static const Color cardFaceShadow = Color(0xFFDCD5C4);
  static const Color cardRed = Color(0xFFB3252B);
  static const Color cardBlack = Color(0xFF1A1A1A);
  static const Color cardBackPrimary = Color(0xFF1E4C58);
  static const Color cardBackPattern = Color(0xFF2E6E7E);

  // Status.
  static const Color success = Color(0xFF4FA87A);
  static const Color warning = Color(0xFFD9A441);
  static const Color danger = Color(0xFFC25450);
  static const Color info = Color(0xFF5B8FB9);

  /// Highlight ring drawn around a legally playable card.
  static const Color legalMoveGlow = Color(0xFF7FD4A8);

  /// Overlay used to dim a card the player may not play.
  static const Color illegalMoveVeil = Color(0x99071A14);
}
