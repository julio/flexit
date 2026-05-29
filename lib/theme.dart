import 'package:flutter/material.dart';

class AppColors {
  // Dark palette
  static const _darkBg = Color(0xFF0A0A0A);
  static const _darkCard = Color(0xFF161616);
  static const _darkCardBorder = Color(0xFF252525);
  static const _darkText = Color(0xFFF5F5F5);
  static const _darkTextSecondary = Color(0xFF999999);
  static const _darkTextMuted = Color(0xFF555555);

  // Light palette
  static const _lightBg = Color(0xFFFAFAFA);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightCardBorder = Color(0xFFE5E5E5);
  static const _lightText = Color(0xFF1A1A1A);
  static const _lightTextSecondary = Color(0xFF555555);
  static const _lightTextMuted = Color(0xFFAAAAAA);

  // Shared accents (work on both backgrounds).
  static const accent = Color(0xFFFF6B35);
  static const accentDim = Color(0x20FF6B35);
  static const success = Color(0xFF34D399);
  static const successDim = Color(0x2034D399);
  static const missed = Color(0xFFEF4444);
  static const missedDim = Color(0x20EF4444);
  static const warning = Color(0xFFFACC15);
  static const warningDim = Color(0x20FACC15);

  // Mutable “current theme” slots. main.dart calls [applyDark] / [applyLight]
  // and rebuilds the tree via a ValueListenableBuilder.
  static Color bg = _darkBg;
  static Color card = _darkCard;
  static Color cardBorder = _darkCardBorder;
  static Color text = _darkText;
  static Color textSecondary = _darkTextSecondary;
  static Color textMuted = _darkTextMuted;
  static bool isDark = true;

  static void applyDark() {
    bg = _darkBg;
    card = _darkCard;
    cardBorder = _darkCardBorder;
    text = _darkText;
    textSecondary = _darkTextSecondary;
    textMuted = _darkTextMuted;
    isDark = true;
  }

  static void applyLight() {
    bg = _lightBg;
    card = _lightCard;
    cardBorder = _lightCardBorder;
    text = _lightText;
    textSecondary = _lightTextSecondary;
    textMuted = _lightTextMuted;
    isDark = false;
  }

  /// Maps a daily "p" rating in [-2, 2] to a heatmap color.
  /// 2 = white (excellent), -2 = red (horrible). Linear interpolation in RGB.
  static Color pColor(int value) {
    final clamped = value.clamp(-2, 2);
    final t = (clamped + 2) / 4.0;
    final channel = (255 * t).round();
    return Color.fromARGB(255, 255, channel, channel);
  }

  /// Fill color for alcohol level (0..4). 0 is white (no drinks — a clean
  /// day still paints the cell so the calendar reads at a glance).
  static const _alcoholPalette = <Color>[
    Color(0xFFFFFFFF), // 0 none
    Color(0xFFE9C46A), // 1 sip
    Color(0xFFE39B3B), // 2 a glass
    Color(0xFFD45A1A), // 3 a few glasses
    Color(0xFF8B1E1E), // 4 drunk
  ];

  static Color alcoholColor(int level) {
    final i = level.clamp(0, 4);
    return _alcoholPalette[i];
  }

  /// Lower-back pain heatmap, 0..10.
  /// 0 = light blue, 5 = red, 10 = dark purple. Two linear segments.
  static const _backPainStops = <Color>[
    Color(0xFF93C5FD), // 0 light blue
    Color(0xFFDC2626), // 5 red
    Color(0xFF4C1D95), // 10 dark purple
  ];

  static Color backPainColor(int value) {
    final v = value.clamp(0, 10);
    if (v <= 5) {
      return Color.lerp(_backPainStops[0], _backPainStops[1], v / 5.0)!;
    }
    return Color.lerp(_backPainStops[1], _backPainStops[2], (v - 5) / 5.0)!;
  }

  /// Picks a high-contrast outline color for a selected pill/tile sitting on
  /// [fill]. The rating selectors paint each tile a different color (a
  /// heatmap), so a single fixed selection ring (e.g. white) disappears on
  /// light fills. This returns black on light fills, white on dark — always
  /// visible.
  static Color selectionRingOn(Color fill) {
    return ThemeData.estimateBrightnessForColor(fill) == Brightness.light
        ? Colors.black87
        : Colors.white;
  }
}

ThemeData buildAppTheme({required bool dark}) {
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: dark
        ? const ColorScheme.dark(
            primary: AppColors.accent,
            surface: Color(0xFF161616),
          )
        : const ColorScheme.light(
            primary: AppColors.accent,
            surface: Color(0xFFFFFFFF),
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}

// Kept for backward compatibility with any older references.
final appTheme = buildAppTheme(dark: true);
