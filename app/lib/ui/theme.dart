import 'package:flutter/material.dart';

/// 찐후기 디자인 토큰 (Claude 디자인 캔버스 "찐후기 앱 디자인"과 같은 값).
class AppColors {
  static const ink = Color(0xFF121417);
  static const sub = Color(0xFF5B6168); // 흰 바탕 위 4.9:1
  static const line = Color(0xFFE3E5E8);
  static const border = Color(0xFFD5D8DC);
  static const ground = Color(0xFFF3F4F6);
  static const card = Color(0xFFFFFFFF);
  static const accent = Color(0xFFC93C1C); // 흰 글자 위 5.1:1
  static const accentSoft = Color(0xFFFBE3DA);
  static const accentText = Color(0xFF8F2A12);
  static const stripe = Color(0xFFF2A488);
  static const ok = Color(0xFF0B7A4B);
  static const gold = Color(0xFFFFD27A);
  static const disabledFill = Color(0xFFE3E5E8);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    outline: AppColors.border,
    outlineVariant: AppColors.line,
    error: const Color(0xFFB3261E),
  );
  const shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansKR',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        shape: shape14,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        disabledBackgroundColor: AppColors.disabledFill,
        disabledForegroundColor: AppColors.sub,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 54),
        foregroundColor: AppColors.ink,
        shape: shape14,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
      fillColor: AppColors.card,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.border,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.sub,
      indicatorColor: AppColors.ink,
      labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      dividerColor: AppColors.border,
    ),
  );
}
