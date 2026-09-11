import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID GLASS — kính mờ trong suốt kiểu iOS 26, dùng chung toàn app: nền
// phía sau được làm mờ qua lớp kính, viền sáng mảnh phản chiếu ánh sáng, đổ
// bóng mềm bên dưới. Bắt nguồn từ màn Home, tách ra đây để mọi màn hình
// dùng chung một hệ thống.
// ─────────────────────────────────────────────────────────────────────────────

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 14)),
      ]),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .50),
                      Colors.white.withValues(alpha: .25),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .75), width: 1.2),
                ),
              ),
            ),
            // Vệt sáng phản chiếu mảnh dọc theo cạnh trên — đặc trưng của
            // hiệu ứng kính "liquid glass".
            Positioned(
              top: 1,
              left: borderRadius.topLeft.x,
              right: borderRadius.topRight.x,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: .95),
                    Colors.white.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ]),
        ),
      ),
    );
  }
}

/// Icon surface using the same translucency and highlight as glass cards.
class GlassIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const GlassIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize = 19,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .62),
              color.withValues(alpha: .14),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .82),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: color),
      );
}

/// Nền nhiều "quầng" màu mềm loang phía sau các lớp kính, để hiệu ứng làm mờ
/// của Liquid Glass có gì đó để khúc xạ — kính trong suốt trên nền trắng
/// trơn sẽ không thấy hiệu ứng.
class LiquidBackdrop extends StatelessWidget {
  final Widget child;
  const LiquidBackdrop({super.key, required this.child});

  static Widget _blob(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFFF4F1EA))),
      Positioned(
          top: -70, left: -60, child: _blob(260, const Color(0xFFFF7A3D), .5)),
      Positioned(
          top: 140,
          right: -100,
          child: _blob(320, const Color(0xFF20C4C6), .4)),
      Positioned(
          bottom: -50,
          left: -50,
          child: _blob(260, const Color(0xFFFFC24A), .38)),
      Positioned(
          bottom: 220,
          right: -70,
          child: _blob(220, const Color(0xFFFF6F91), .32)),
      child,
    ]);
  }
}

/// Shared modal surface. Callers provide their own handle and scroll layout.
class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LiquidGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(top: false, child: child),
        ),
      );
}
