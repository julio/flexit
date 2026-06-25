import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/theme.dart';

/// Covers the parts of theme.dart the existing theme_test.dart leaves out:
/// the selection ring/halo contrast helpers and buildAppTheme.
void main() {
  group('AppColors.selectionRingOn', () {
    test('returns a dark stroke on a light fill', () {
      // White tile → the inner ring must be dark to be visible.
      expect(AppColors.selectionRingOn(const Color(0xFFFFFFFF)), Colors.black87);
    });

    test('returns a white stroke on a dark fill', () {
      expect(AppColors.selectionRingOn(const Color(0xFF000000)), Colors.white);
    });

    test('flips with the fill brightness across the alcohol palette', () {
      // level 0 (white) is light; level 4 (deep red) is dark.
      expect(AppColors.selectionRingOn(AppColors.alcoholColor(0)),
          Colors.black87);
      expect(
          AppColors.selectionRingOn(AppColors.alcoholColor(4)), Colors.white);
    });
  });

  group('AppColors.selectionHaloOn', () {
    tearDown(AppColors.applyDark); // leave the global theme as the default

    test('uses white in dark mode regardless of fill', () {
      AppColors.applyDark();
      expect(AppColors.selectionHaloOn(const Color(0xFFFFFFFF)), Colors.white);
      expect(AppColors.selectionHaloOn(const Color(0xFF000000)), Colors.white);
    });

    test('uses black87 in light mode regardless of fill', () {
      AppColors.applyLight();
      expect(
          AppColors.selectionHaloOn(const Color(0xFFFFFFFF)), Colors.black87);
      expect(
          AppColors.selectionHaloOn(const Color(0xFF000000)), Colors.black87);
    });
  });

  group('buildAppTheme', () {
    test('dark theme is Brightness.dark with the accent primary', () {
      AppColors.applyDark();
      final t = buildAppTheme(dark: true);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.brightness, Brightness.dark);
      expect(t.colorScheme.primary, AppColors.accent);
      expect(t.scaffoldBackgroundColor, AppColors.bg);
    });

    test('light theme is Brightness.light with the accent primary', () {
      AppColors.applyLight();
      final t = buildAppTheme(dark: false);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.brightness, Brightness.light);
      expect(t.colorScheme.primary, AppColors.accent);
      AppColors.applyDark();
    });

    test('app bar and bottom nav use the canvas background', () {
      AppColors.applyDark();
      final t = buildAppTheme(dark: true);
      expect(t.appBarTheme.backgroundColor, AppColors.bg);
      expect(t.appBarTheme.elevation, 0);
      expect(t.bottomNavigationBarTheme.selectedItemColor, AppColors.accent);
      expect(t.bottomNavigationBarTheme.type, BottomNavigationBarType.fixed);
    });

    test('the legacy appTheme export is a dark theme', () {
      expect(appTheme.brightness, Brightness.dark);
    });
  });
}
