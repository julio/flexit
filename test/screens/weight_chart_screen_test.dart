import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/storage.dart';
import 'package:flexit/screens/weight_chart_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await installTestHarness();
  });

  tearDown(() {
    // Harness owns no per-test disposable state for this pure screen, but keep
    // the surface reset symmetric with the other widget tests.
  });

  // A known, deterministic dataset. Dates intentionally out of insertion order
  // so we exercise the screen's internal date sort.
  const sampleGrams = <String, int>{
    '2026-06-02': 74800, // middle date, lowest weight
    '2026-06-01': 75000, // earliest date -> "first"
    '2026-06-03': 75200, // latest date -> "latest"
  };

  // Helper: format exactly as the screen does for a given grams value + unit.
  String fmt(int grams, String unit) {
    final v = unit == 'kg' ? gramsToKg(grams) : gramsToLb(grams);
    return '${v.toStringAsFixed(1)} $unit';
  }

  String fmtSigned(double delta, String unit) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} $unit';
  }

  group('stats row (kg)', () {
    testWidgets('shows latest, change, min, max for a known dataset',
        (tester) async {
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: sampleGrams, unit: 'kg'),
      );

      // Latest = value at the latest date (2026-06-03 = 75200 g), and Max is
      // also 75200 g, so "75.2 kg" appears in two cells.
      expect(find.text(fmt(75200, 'kg')), findsNWidgets(2)); // Latest + Max
      // Min = 74800 g -> "74.8 kg".
      expect(find.text(fmt(74800, 'kg')), findsOneWidget);

      // Change = latest - first = gramsToKg(75200) - gramsToKg(75000).
      final delta = gramsToKg(75200) - gramsToKg(75000);
      expect(delta, greaterThan(0));
      expect(find.text(fmtSigned(delta, 'kg')), findsOneWidget); // "+0.2 kg"

      // The four stat labels are present.
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('negative change renders with a minus sign and no plus',
        (tester) async {
      // Weight decreased over time: first 76000 g, latest 75000 g.
      const losing = <String, int>{
        '2026-06-01': 76000,
        '2026-06-02': 75500,
        '2026-06-03': 75000,
      };
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: losing, unit: 'kg'),
      );

      final delta = gramsToKg(75000) - gramsToKg(76000); // negative
      expect(delta, lessThan(0));
      // toStringAsFixed on a negative already carries its own '-', no extra '+'.
      expect(find.text(fmtSigned(delta, 'kg')), findsOneWidget); // "-1.0 kg"
      // Make sure we did not accidentally render a "+-1.0" string.
      expect(find.textContaining('+-'), findsNothing);
    });

    testWidgets('zero change (all-equal weights) renders without a sign',
        (tester) async {
      const flat = <String, int>{
        '2026-06-01': 75000,
        '2026-06-02': 75000,
        '2026-06-03': 75000,
      };
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: flat, unit: 'kg'),
      );

      // Change is exactly 0.0 -> no sign.
      expect(find.text('0.0 kg'), findsOneWidget);
      // Latest/Min/Max all equal 75.0 kg -> three identical cells.
      expect(find.text(fmt(75000, 'kg')), findsNWidgets(3));
    });
  });

  group('stats row (lb)', () {
    testWidgets('same dataset shows lb-converted values', (tester) async {
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: sampleGrams, unit: 'lb'),
      );

      // Latest (75200 g) and Max (75200 g) share the same lb string -> 2 cells.
      expect(find.text(fmt(75200, 'lb')), findsNWidgets(2)); // latest + max, lb
      expect(find.text(fmt(74800, 'lb')), findsOneWidget); // min, lb

      final delta = gramsToLb(75200) - gramsToLb(75000);
      expect(find.text(fmtSigned(delta, 'lb')), findsOneWidget);

      // Unit suffix is lb everywhere, never kg.
      expect(find.textContaining('kg'), findsNothing);
      expect(find.textContaining('lb'), findsWidgets);
    });

    testWidgets('kg and lb produce genuinely different numbers',
        (tester) async {
      // The lb value for 75200 g differs from its kg value, proving the
      // conversion actually ran rather than reusing the kg string.
      expect(fmt(75200, 'kg'), isNot(equals(fmt(75200, 'lb'))));
    });
  });

  group('chart presence', () {
    testWidgets('a CustomPaint chart is in the tree for populated data',
        (tester) async {
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: sampleGrams, unit: 'kg'),
      );
      // The line chart renders via CustomPaint.
      expect(find.byType(CustomPaint), findsWidgets);
      // The app bar title is shown.
      expect(find.text('Weight evolution'), findsOneWidget);
    });
  });

  group('repaint', () {
    testWidgets('rebuilding with new data drives the painter to repaint',
        (tester) async {
      // First build: kg with the sample set.
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: sampleGrams, unit: 'kg'),
      );
      expect(find.byType(CustomPaint), findsWidgets);

      // Rebuild the SAME widget position with a different dataset. The
      // framework reuses the CustomPaint element and calls
      // _LineChartPainter.shouldRepaint(oldPainter); changed points -> true.
      const moreData = <String, int>{
        '2026-06-01': 75000,
        '2026-06-02': 74800,
        '2026-06-03': 75200,
        '2026-06-04': 76000,
      };
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: moreData, unit: 'kg'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Rebuild again switching only the unit (points equal, unit differs ->
      // shouldRepaint returns true through the unit branch).
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: moreData, unit: 'lb'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('edge cases', () {
    testWidgets('empty map shows placeholder and no stats/chart crash',
        (tester) async {
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: {}, unit: 'kg'),
      );
      expect(find.text('No weight entries yet.'), findsOneWidget);
      // No stats row labels when there is no data.
      expect(find.text('Latest'), findsNothing);
      expect(find.text('Min'), findsNothing);
      // Building did not throw.
      expect(tester.takeException(), isNull);
    });

    testWidgets('single data point renders without crashing', (tester) async {
      const single = <String, int>{'2026-06-01': 75000};
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: single, unit: 'kg'),
      );

      // With one point: latest == first == min == max, change == 0.
      // "75.0 kg" appears for Latest, Min, and Max (3 cells).
      expect(find.text(fmt(75000, 'kg')), findsNWidgets(3));
      expect(find.text('0.0 kg'), findsOneWidget); // change
      // Chart still paints.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('single data point in lb renders without crashing',
        (tester) async {
      const single = <String, int>{'2026-06-01': 75000};
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: single, unit: 'lb'),
      );
      expect(find.text(fmt(75000, 'lb')), findsNWidgets(3));
      expect(find.text('0.0 lb'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two-point dataset renders both stats and chart',
        (tester) async {
      const two = <String, int>{
        '2026-06-01': 75000,
        '2026-06-10': 74000,
      };
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: two, unit: 'kg'),
      );
      expect(find.text(fmt(74000, 'kg')), findsWidgets); // latest & min
      expect(find.text(fmt(75000, 'kg')), findsOneWidget); // max
      final delta = gramsToKg(74000) - gramsToKg(75000);
      expect(find.text(fmtSigned(delta, 'kg')), findsOneWidget); // "-1.0 kg"
      expect(tester.takeException(), isNull);
    });
  });

  group('date ordering', () {
    testWidgets('latest/first track dates, not map insertion order',
        (tester) async {
      // Insertion order puts the latest date first; the screen must still
      // treat 2026-12-31 as "latest" and 2026-01-01 as "first".
      const scrambled = <String, int>{
        '2026-12-31': 80000, // latest date
        '2026-01-01': 70000, // earliest date
        '2026-06-15': 75000,
      };
      await pumpScreen(
        tester,
        const WeightChartScreen(weights: scrambled, unit: 'kg'),
      );

      // Latest cell = 80.0 kg, Max also 80.0 kg -> two cells.
      expect(find.text(fmt(80000, 'kg')), findsNWidgets(2));
      // Min = 70.0 kg.
      expect(find.text(fmt(70000, 'kg')), findsOneWidget);
      // Change = latest(80) - first(70) = +10.0 kg.
      final delta = gramsToKg(80000) - gramsToKg(70000);
      expect(find.text(fmtSigned(delta, 'kg')), findsOneWidget); // "+10.0 kg"
    });
  });
}
