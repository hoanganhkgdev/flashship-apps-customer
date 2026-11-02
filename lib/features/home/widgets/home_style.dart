import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Home-only tokens: other screens keep the existing application theme.
abstract final class HomeStyle {
  static const orange = Color(0xFFFF5A1F);
  static const orangeLight = Color(0xFFFF8A55);
  static const background = Color(0xFFF6F7F9);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF667085);
  static const peach = Color(0xFFFFEDE6);
  static const radius = BorderRadius.all(Radius.circular(22));

  /// Bán kính thẻ kiểu phẳng, khớp AppRadius.card.
  static const cardRadius = BorderRadius.all(Radius.circular(AppRadius.card));

  /// Thẻ kiểu phẳng không đổ bóng — giữ tên để các nơi gọi không phải đổi.
  static const shadow = <BoxShadow>[];

  // Flat/bordered card tokens — dùng cho các phần đang chuyển sang style
  // "Flat & Warm" (viền mỏng thay đổ bóng), bắt đầu từ header.
  static const divider = Color(0xFFE7EAF0);
  static const card = Colors.white;
  static const cardMuted = Color(0xFFF8F9FB);
  static final border = Border.all(color: divider);
  static const title =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink);
}
