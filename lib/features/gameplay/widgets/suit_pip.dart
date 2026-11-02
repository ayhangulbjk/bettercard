import 'package:flutter/material.dart';

import '../../../core/cards/suit.dart';

/// A suit pip, drawn as a path rather than typed as a character.
///
/// The Unicode pips are not in every font. Roboto, the Android default, has no
/// U+2660 family of its own: a device renders them only if the system fallback
/// chain happens to supply them, and the headless screenshot harness -- where
/// this app's layout is reviewed -- draws them as empty boxes. A card game
/// whose suits might not render is not a risk worth taking for four shapes, so
/// they are painted.
///
/// Drawing them also makes them themeable (a red/black pair today, four
/// colours if a profile ever asks for it) and keeps them crisp at any size,
/// which a glyph scaled to a 10-logical-pixel corner index is not.
final class SuitPip extends StatelessWidget {
  const SuitPip({
    required this.suit,
    required this.size,
    required this.color,
    super.key,
  });

  final Suit suit;

  /// Width of the pip. Height follows the shape's own proportion.
  final double size;

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SuitPainter(suit: suit, color: color),
          isComplex: false,
        ),
      );
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter({required this.suit, required this.color});

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.drawPath(_pathFor(suit, size), paint);
  }

  /// Shapes are expressed as fractions of [size], so one set of control points
  /// serves the corner index and the large watermark alike.
  static Path _pathFor(Suit suit, Size size) {
    final double w = size.width;
    final double h = size.height;
    return switch (suit) {
      Suit.spades => Path()
        ..moveTo(w * 0.50, h * 0.04)
        ..cubicTo(w * 0.50, h * 0.30, w * 0.04, h * 0.36, w * 0.04, h * 0.60)
        ..cubicTo(w * 0.04, h * 0.79, w * 0.27, h * 0.85, w * 0.41, h * 0.73)
        ..cubicTo(w * 0.43, h * 0.86, w * 0.38, h * 0.93, w * 0.29, h * 0.98)
        ..lineTo(w * 0.71, h * 0.98)
        ..cubicTo(w * 0.62, h * 0.93, w * 0.57, h * 0.86, w * 0.59, h * 0.73)
        ..cubicTo(w * 0.73, h * 0.85, w * 0.96, h * 0.79, w * 0.96, h * 0.60)
        ..cubicTo(w * 0.96, h * 0.36, w * 0.50, h * 0.30, w * 0.50, h * 0.04)
        ..close(),
      Suit.hearts => Path()
        ..moveTo(w * 0.50, h * 0.96)
        ..cubicTo(w * 0.04, h * 0.62, w * 0.04, h * 0.22, w * 0.27, h * 0.12)
        ..cubicTo(w * 0.41, h * 0.06, w * 0.50, h * 0.17, w * 0.50, h * 0.27)
        ..cubicTo(w * 0.50, h * 0.17, w * 0.59, h * 0.06, w * 0.73, h * 0.12)
        ..cubicTo(w * 0.96, h * 0.22, w * 0.96, h * 0.62, w * 0.50, h * 0.96)
        ..close(),
      Suit.diamonds => Path()
        ..moveTo(w * 0.50, h * 0.03)
        ..cubicTo(w * 0.62, h * 0.28, w * 0.78, h * 0.42, w * 0.92, h * 0.50)
        ..cubicTo(w * 0.78, h * 0.58, w * 0.62, h * 0.72, w * 0.50, h * 0.97)
        ..cubicTo(w * 0.38, h * 0.72, w * 0.22, h * 0.58, w * 0.08, h * 0.50)
        ..cubicTo(w * 0.22, h * 0.42, w * 0.38, h * 0.28, w * 0.50, h * 0.03)
        ..close(),
      // Three lobes plus a stem. Overlapping subpaths fill as one shape under
      // the default non-zero winding rule, so no boolean union is needed.
      Suit.clubs => Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(w * 0.50, h * 0.26),
            radius: w * 0.23,
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(w * 0.24, h * 0.60),
            radius: w * 0.23,
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(w * 0.76, h * 0.60),
            radius: w * 0.23,
          ),
        )
        ..moveTo(w * 0.32, h * 0.98)
        ..cubicTo(w * 0.45, h * 0.88, w * 0.48, h * 0.72, w * 0.47, h * 0.55)
        ..lineTo(w * 0.53, h * 0.55)
        ..cubicTo(w * 0.52, h * 0.72, w * 0.55, h * 0.88, w * 0.68, h * 0.98)
        ..close(),
    };
  }

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}
