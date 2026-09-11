import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_input_border.dart';
import 'app_radius.dart';

export 'app_radius.dart';

/// Token màu dùng chung toàn app — theo đúng style app shop (nền kem ấm,
/// cam san hô làm chủ đạo, card viền phẳng không đổ bóng). Đổi giá trị ở
/// đây sẽ tự áp dụng cho mọi nơi đang dùng AppColors.xxx, không cần sửa
/// từng màn hình.
class AppColors {
  static const primary = Color(0xFFF56333);
  static const primaryDark = Color(0xFFC74007);
  static const primarySoft = Color(0xFFFFE5D9);
  static const accent2 = Color(0xFF00B3B5);
  static const accent2Soft = Color(0xFFD1F3F2);
  static const background = Color(0xFFFBF5F1);
  static const surface = Color(0xFFFFFDFB);
  static const surfaceAlt = Color(0xFFF5EDE8);
  static const textPrimary = Color(0xFF1C1410);
  static const textSecondary = Color(0xFF5F5651);
  static const textTertiary = Color(0xFF938A86);
  static const divider = Color(0xFFE5DCD7);
  static const success = Color(0xFF218A45);
  static const danger = Color(0xFFCC3336);
  static const warning = Color(0xFFAC6900);
  static const info = Color(0xFF1F6DD8);
  static const successSoft = Color(0xFFD9F3DD);
  static const dangerSoft = Color(0xFFFFE5E1);
  static const warningSoft = Color(0xFFFFECC9);
  static const infoSoft = Color(0xFFDDECFF);

  // Per-service colors — riêng của customer (đa dịch vụ, app shop không có)
  static const delivery = primary;
  static const shopping = accent2;
  static const topup = success;
  static const bike = warning;
  static const motor = info;
  static const car = Color(0xFF7C5CFC);

  static Color serviceColor(String type) {
    switch (type) {
      case 'delivery':
        return delivery;
      case 'shopping':
        return shopping;
      case 'topup':
        return topup;
      case 'bike':
        return bike;
      case 'motor':
        return motor;
      case 'car':
        return car;
      default:
        return primary;
    }
  }

  static Color serviceBg(String type) =>
      serviceColor(type).withValues(alpha: 0.12);
}

/// Khoảng cách dùng chung — tránh số lẻ rải rác khắp nơi.
class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Thang chữ chuẩn cho giao diện mobile.
/// Thang font size chuẩn theo bậc chẵn 2pt — cách các app thương mại hay dùng
/// (Material/HIG type scale), thay vì số lẻ tùy tiện (11, 13, 15, 17...).
class AppFontSize {
  static const caption = 12.0;
  static const body = 14.0;
  static const bodyLarge = 16.0;
  static const title = 18.0;
  static const titleLarge = 20.0;
  static const display = 22.0;
  static const heading = 24.0;
  static const xlarge = 28.0;
  static const xxlarge = 32.0;
  static const hero = 52.0;
}

class AppTheme {
  static InputDecorationTheme get glassInputDecoration => InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0x18FFFFFF);
          }
          if (states.contains(WidgetState.error)) {
            return const Color(0x33FFE5E1);
          }
          return states.contains(WidgetState.focused)
              ? const Color(0x80FFFFFF)
              : const Color(0x40FFFFFF);
        }),
        border: const GlassInputBorder(),
        enabledBorder: const GlassInputBorder(),
        disabledBorder: const GlassInputBorder(
          borderSide: BorderSide(color: Color(0x18938A86)),
        ),
        focusedBorder: const GlassInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: const GlassInputBorder(
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const GlassInputBorder(
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSize.bodyLarge,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle:
            WidgetStateTextStyle.resolveWith((states) => TextStyle(
                  color: states.contains(WidgetState.error)
                      ? AppColors.danger
                      : states.contains(WidgetState.focused)
                          ? AppColors.primary
                          : AppColors.textSecondary,
                )),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        errorMaxLines: 3,
      );

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    final base = ThemeData(colorScheme: colorScheme).textTheme;
    final textTheme = GoogleFonts.interTextTheme(base)
        .copyWith(
          headlineLarge: const TextStyle(fontSize: AppFontSize.xxlarge),
          headlineMedium: const TextStyle(fontSize: AppFontSize.xlarge),
          headlineSmall: const TextStyle(fontSize: AppFontSize.heading),
          titleLarge: const TextStyle(fontSize: AppFontSize.titleLarge),
          titleMedium: const TextStyle(fontSize: AppFontSize.bodyLarge),
          titleSmall: const TextStyle(fontSize: AppFontSize.body),
          bodyLarge: const TextStyle(fontSize: AppFontSize.bodyLarge),
          bodyMedium: const TextStyle(fontSize: AppFontSize.body),
          bodySmall: const TextStyle(fontSize: AppFontSize.caption),
          labelLarge: const TextStyle(fontSize: AppFontSize.body),
          labelMedium: const TextStyle(fontSize: AppFontSize.caption),
          labelSmall: const TextStyle(fontSize: AppFontSize.caption),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Cards ────────────────────────────────────────────────────────────
      // Phẳng, viền mỏng thay đổ bóng — đồng bộ card của app shop.
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── FilledButton ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          elevation: 0,
          textStyle: TextStyle(
            fontSize: AppFontSize.bodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── ElevatedButton (đồng nhất với FilledButton) ────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: TextStyle(
            fontSize: AppFontSize.bodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          side: const BorderSide(color: AppColors.divider),
          textStyle: TextStyle(
            fontSize: AppFontSize.bodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          foregroundColor: AppColors.primary,
          textStyle: TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      inputDecorationTheme: glassInputDecoration,

      // ── BottomSheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.glass)),
        ),
        showDragHandle: true,
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.divider),
        ),
        side: BorderSide.none,
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: AppFontSize.body,
        ),
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
    );
  }
}
