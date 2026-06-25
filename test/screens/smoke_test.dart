import 'package:flutter_test/flutter_test.dart';

import 'package:flexit/screens/today_screen.dart';
import 'package:flexit/screens/calendar_screen.dart';
import 'package:flexit/screens/settings_screen.dart';
import 'package:flexit/screens/weight_chart_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness h;
  setUp(() async {
    h = await installTestHarness();
  });
  tearDown(() => h.dispose());

  testWidgets('TodayScreen renders', (tester) async {
    await pumpScreen(tester, const TodayScreen(), settle: true);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('CalendarScreen renders', (tester) async {
    await pumpScreen(tester, const CalendarScreen(), settle: true);
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen renders', (tester) async {
    await pumpScreen(tester, const SettingsScreen(), settle: true);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('WeightChartScreen renders', (tester) async {
    await pumpScreen(tester,
        const WeightChartScreen(weights: {'2026-06-01': 75000}, unit: 'kg'),
        settle: true);
    expect(find.byType(WeightChartScreen), findsOneWidget);
  });
}
