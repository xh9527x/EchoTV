import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// zgj皮肤 token（skin-zhenguojian 分支，实测取色）
/// 页面底 #FAF8F6 / 正文 #252328 / 次要 #68636C / 主色砖红 #AD3826
/// 选中 chip 底 #FFDAD4 + 字 #5D3F3A
class Zjg {
  static const Color pageBg = Color(0xFFFAF8F6);
  static const Color ink = Color(0xFF252328);
  static const Color sub = Color(0xFF68636C);
  static const Color faint = Color(0xFFA8A5A3);
  static const Color red = Color(0xFFAD3826);
  static const Color chipPink = Color(0xFFFFDAD4);
  static const Color chipPinkInk = Color(0xFF5D3F3A);
  static const Color chipBorder = Color(0xFFE6E0DB);
  static const Color searchBarBg = Color(0xFFF1ECE9);
  static const double cardRadius = 9.0;
  static const double chipRadius = 10.0;
}

class ZenTheme {
  // --- 色彩系统 (zgj皮肤 / iOS 17+ Style) ---

  // Light Theme Colors
  static const Color lightBackground = Zjg.pageBg;           // 暖白底
  static const Color lightSurface = Color(0xFFFFFFFF);      // 纯白容器
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Zjg.ink;            // 近黑文字
  static const Color lightTextSecondary = Zjg.sub;          // 灰次要文字
  static const Color lightTextTertiary = Zjg.faint;         // 浅灰三级文字
  static const Color lightAccent = Zjg.red;                 // 砖红主色

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000);     // 纯黑背景 (OLED Optimized)
  static const Color darkSurface = Color(0xFF1C1C1E);        // 深灰容器
  static const Color darkSurfaceElevated = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);    // 纯白文字
  static const Color darkTextSecondary = Color(0xFFAEAEB2);  // 浅灰次要文字
  static const Color darkTextTertiary = Color(0xFF636366);   // 深灰三级文字
  static const Color darkAccent = Color(0xFFC05A44);         // 暗色下砖红提亮，保证可见度

  static const Color accentBlue = Color(0xFF0A84FF);         // iOS 标准蓝色，用于链接或特定点缀

  // --- 字体设置 ---

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    final baseTheme = GoogleFonts.interTextTheme();
    return baseTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -1.0,
        fontSize: 32,
      ),
      displayMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -0.8,
        fontSize: 24,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        color: primaryColor,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: primaryColor,
        fontSize: 16,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primaryColor,
        fontSize: 15,
      ),
      bodyMedium: GoogleFonts.inter(
        color: primaryColor.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondaryColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        fontSize: 12,
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightAccent,
      cardColor: lightSurface,
      dividerColor: lightTextTertiary.withValues(alpha: 0.1),
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        onPrimary: Colors.white,
        secondary: lightTextSecondary,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightSurfaceElevated,
        outline: Color(0xFFD1D1D6),
      ),
      textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightAccent;
          return null;
        }),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkAccent,
      cardColor: darkSurface,
      dividerColor: darkTextTertiary.withValues(alpha: 0.1),
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        onPrimary: Colors.black,
        secondary: darkTextSecondary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkSurfaceElevated,
        outline: Color(0xFF38383A),
      ),
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentBlue; // 深色模式下开启状态使用亮蓝色轨道，非常醒目
          return null;
        }),
      ),
    );
  }
}