import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/theme.dart';

void main() {
  group('AppColors.pColor', () {
    test('2 maps to white', () {
      expect(AppColors.pColor(2), const Color(0xFFFFFFFF));
    });

    test('-2 maps to pure red', () {
      expect(AppColors.pColor(-2), const Color(0xFFFF0000));
    });

    test('0 is the midpoint between white and red', () {
      final c = AppColors.pColor(0);
      expect(c.r, 1.0); // red channel always full
      expect(c.g, closeTo(128 / 255, 0.01));
      expect(c.b, closeTo(128 / 255, 0.01));
    });

    test('1 is between white and midpoint', () {
      final c = AppColors.pColor(1);
      expect(c.g, closeTo(191 / 255, 0.01));
      expect(c.b, closeTo(191 / 255, 0.01));
    });

    test('-1 is between midpoint and red', () {
      final c = AppColors.pColor(-1);
      expect(c.g, closeTo(64 / 255, 0.01));
      expect(c.b, closeTo(64 / 255, 0.01));
    });

    test('clamps values outside [-2, 2]', () {
      expect(AppColors.pColor(5), AppColors.pColor(2));
      expect(AppColors.pColor(-5), AppColors.pColor(-2));
    });
  });

  group('AppColors.alcoholColor', () {
    test('level 0 is white (no drinks)', () {
      expect(AppColors.alcoholColor(0), const Color(0xFFFFFFFF));
    });

    test('clamps negative levels to the level-0 color (white)', () {
      expect(AppColors.alcoholColor(-1), AppColors.alcoholColor(0));
    });

    test('levels 0..4 return five distinct colors', () {
      final colors = [0, 1, 2, 3, 4].map(AppColors.alcoholColor).toSet();
      expect(colors.length, 5);
    });

    test('clamps levels above 4 to the level-4 color', () {
      expect(AppColors.alcoholColor(99), AppColors.alcoholColor(4));
    });
  });

  group('AppColors.backPainColor', () {
    test('0 is light blue (the low-pain stop)', () {
      expect(AppColors.backPainColor(0), const Color(0xFF93C5FD));
    });

    test('5 is red (the mid-pain stop)', () {
      expect(AppColors.backPainColor(5), const Color(0xFFDC2626));
    });

    test('10 is dark purple (the high-pain stop)', () {
      expect(AppColors.backPainColor(10), const Color(0xFF4C1D95));
    });

    test('clamps values below 0 to the level-0 color', () {
      expect(AppColors.backPainColor(-99), AppColors.backPainColor(0));
    });

    test('clamps values above 10 to the level-10 color', () {
      expect(AppColors.backPainColor(99), AppColors.backPainColor(10));
    });

    test('returns 11 distinct colors across 0..10', () {
      final colors = List.generate(11, AppColors.backPainColor).toSet();
      expect(colors.length, 11);
    });
  });

  group('AppColors light/dark theme', () {
    test('applyDark uses dark backgrounds', () {
      AppColors.applyDark();
      expect(AppColors.isDark, isTrue);
      expect(AppColors.bg, const Color(0xFF0A0A0A));
    });

    test('applyLight uses light backgrounds', () {
      AppColors.applyLight();
      expect(AppColors.isDark, isFalse);
      expect(AppColors.bg, const Color(0xFFFAFAFA));
      // Restore for other tests.
      AppColors.applyDark();
    });
  });
}
