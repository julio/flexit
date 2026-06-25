import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flexit/main.dart';
import 'package:flexit/screens/today_screen.dart';
import 'package:flexit/screens/calendar_screen.dart';
import 'package:flexit/theme.dart';

import 'helpers/test_harness.dart';

/// Covers the app shell in main.dart: the data-change notifier, FlexItApp's
/// theme wiring, and HomeShell's bottom-nav tab switching (the IndexedStack
/// that keeps both screens alive). main() itself (runApp + plugin init) isn't
/// unit-testable, but everything it wires up is.
void main() {
  late TestHarness h;
  setUp(() async {
    h = await installTestHarness();
  });
  tearDown(() => h.dispose());

  group('bumpDataChanged', () {
    test('increments the dataChangedCounter notifier', () {
      final before = dataChangedCounter.value;
      bumpDataChanged();
      expect(dataChangedCounter.value, before + 1);
      bumpDataChanged();
      expect(dataChangedCounter.value, before + 2);
    });
  });

  // FlexItApp supplies its own MaterialApp, so it's pumped directly (not via
  // pumpScreen, which would nest a second MaterialApp).
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FlexItApp());
    await tester.pumpAndSettle();
    drainBenignOverflow(tester);
  }

  group('FlexItApp', () {
    testWidgets('builds a MaterialApp hosting the HomeShell', (tester) async {
      await pumpApp(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('theme follows the themeIsDark notifier', (tester) async {
      themeIsDark.value = false;
      await pumpApp(tester);
      expect(AppColors.isDark, isFalse);

      themeIsDark.value = true;
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);
      expect(AppColors.isDark, isTrue);
    });
  });

  group('HomeShell bottom navigation', () {
    testWidgets('starts on the Today tab', (tester) async {
      await pumpScreen(tester, const HomeShell(), settle: true);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Calendar'), findsWidgets);
    });

    testWidgets('keeps both screens mounted via IndexedStack', (tester) async {
      await pumpScreen(tester, const HomeShell(), settle: true);
      // IndexedStack builds both children even when one is offstage.
      expect(find.byType(IndexedStack), findsOneWidget);
      // IndexedStack keeps the inactive child mounted but offstage, so the
      // finder must look past Offstage.
      expect(find.byType(TodayScreen, skipOffstage: false), findsOneWidget);
      expect(
          find.byType(CalendarScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping Calendar switches the active tab', (tester) async {
      await pumpScreen(tester, const HomeShell(), settle: true);
      await tester.tap(find.text('Calendar').last);
      // The nav handler awaits a 150ms prefs-flush delay before reloading.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 1);
    });

    testWidgets('tapping back to Today restores index 0', (tester) async {
      await pumpScreen(tester, const HomeShell(), settle: true);
      await tester.tap(find.text('Calendar').last);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 0);
    });
  });
}
