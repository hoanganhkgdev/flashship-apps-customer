import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIGHTWEIGHT GLASS SURFACES
//
// Các tên class cũ được giữ lại để không làm xáo trộn hàng loạt màn hình,
// còn hiệu ứng kính được tạo bằng màu bán trong suốt và gradient tĩnh.
// Tuyệt đối không dùng BackdropFilter: blur ở các card trong vùng cuộn là
// nguyên nhân gây overdraw và raster chậm trên nhiều thiết bị Android.
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE9ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

/// Icon pseudo-glass dùng gradient tĩnh, không blur.
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
          color: color.withValues(alpha: .10),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Icon(icon, size: iconSize, color: color),
      );
}

/// Nền gradient tĩnh giúp surface bán trong suốt có chiều sâu mà không cần blur.
class LiquidBackdrop extends StatelessWidget {
  final Widget child;
  const LiquidBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F5F8)],
          ),
        ),
        child: child,
      );
}

/// Shared modal surface. Callers provide their own handle and scroll layout.
class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(top: false, child: child),
      );
}
