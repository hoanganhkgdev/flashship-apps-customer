import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// A lightweight glass surface painted only inside the input container.
/// Labels, validation messages and counters keep their native Material layout.
class GlassInputBorder extends OutlineInputBorder {
  const GlassInputBorder({
    super.borderSide = const BorderSide(color: Color(0x33938A86)),
    super.borderRadius =
        const BorderRadius.all(Radius.circular(AppRadius.glass)),
    super.gapPadding,
  });

  @override
  GlassInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) =>
      GlassInputBorder(
        borderSide: borderSide ?? this.borderSide,
        borderRadius: borderRadius ?? this.borderRadius,
        gapPadding: gapPadding ?? this.gapPadding,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is GlassInputBorder) {
      return GlassInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        gapPadding: a.gapPadding + (gapPadding - a.gapPadding) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is GlassInputBorder) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint,
      {TextDirection? textDirection}) {
    final surface = borderRadius.toRRect(rect);
    canvas.drawRRect(
      surface,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(const Color(0x66FFFFFF), paint.color),
            paint.color
          ],
        ).createShader(rect),
    );
    // Inset reflection stays clear of the floating label's outline gap.
    canvas.drawRRect(
      surface.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xBFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }
}
