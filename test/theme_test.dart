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
    test('level 0 returns null (no marker)', () {
      expect(AppColors.alcoholColor(0), isNull);
    });

    test('negative levels return null', () {
      expect(AppColors.alcoholColor(-1), isNull);
    });

    test('levels 1..4 return distinct colors', () {
      final colors = [1, 2, 3, 4].map(AppColors.alcoholColor).toSet();
      expect(colors.length, 4);
      expect(colors.contains(null), isFalse);
    });

    test('clamps levels above 4 to the level-4 color', () {
      expect(AppColors.alcoholColor(99), AppColors.alcoholColor(4));
    });
  });
}
