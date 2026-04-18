import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0A0A);
  static const card = Color(0xFF161616);
  static const cardBorder = Color(0xFF252525);
  static const accent = Color(0xFFFF6B35);
  static const accentDim = Color(0x20FF6B35);
  static const success = Color(0xFF34D399);
  static const successDim = Color(0x2034D399);
  static const missed = Color(0xFFEF4444);
  static const missedDim = Color(0x20EF4444);
  static const warning = Color(0xFFFACC15);
  static const warningDim = Color(0x20FACC15);
  static const text = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF999999);
  static const textMuted = Color(0xFF555555);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.card,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bg,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AppColors.text,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.bg,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.textMuted,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
);
