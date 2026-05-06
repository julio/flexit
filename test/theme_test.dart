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
}
