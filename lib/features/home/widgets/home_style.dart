import 'package:flutter/material.dart';

/// Home-only tokens: other screens keep the existing application theme.
abstract final class HomeStyle {
  static const orange = Color(0xFFFF6B00);
  static const orangeLight = Color(0xFFFF8A3D);
  static const background = Color(0xFFF1F5FA);
  static const ink = Color(0xFF141B2E);
  static const muted = Color(0xFF657087);
  static const peach = Color(0xFFFFF0E6);
  static const radius = BorderRadius.all(Radius.circular(18));
  static const shadow = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 5)),
  ];

  // Flat/bordered card tokens — dùng cho các phần đang chuyển sang style
  // "Flat & Warm" (viền mỏng thay đổ bóng), bắt đầu từ header.
  static const divider = Color(0xFFE5DCD7);
  static const card = Colors.white;
  static const cardMuted = Color(0xFFF5EDE8);
  static final border = Border.all(color: divider);
  static const title =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink);
}
