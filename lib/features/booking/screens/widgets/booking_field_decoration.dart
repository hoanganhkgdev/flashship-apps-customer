import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/widgets/home_style.dart';

/// Kiểu ô nhập phẳng dùng chung cho các form đặt đơn.
InputDecoration bookingFieldDecoration({
  String? label,
  String? hint,
  String? helper,
  String? errorText,
  IconData? prefixIcon,
  String? suffixText,
  bool alignLabelWithHint = false,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    errorText: errorText,
    suffixText: suffixText,
    alignLabelWithHint: alignLabelWithHint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: HomeStyle.muted),
    filled: true,
    fillColor: HomeStyle.cardMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(HomeStyle.divider),
    enabledBorder: border(HomeStyle.divider),
    focusedBorder: border(HomeStyle.orange, 1.5),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
  );
}
