import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flexit/data/storage.dart';
import 'package:flexit/screens/today_screen.dart';

import '../helpers/test_harness.dart';

/// Regression: the daily metric-card headers (p-rating, back-pain) put a
/// trailing "value · label" Text next to the title in a `spaceBetween` Row.
/// With the trailing Text unconstrained, a selected long label on a narrow
/// device overflowed the header row (the trailing label and title together
/// exceeded the row width). The trailing Text is now wrapped in `Flexible` +
/// ellipsis. This test pumps the Today screen on a narrow surface with the
/// longest-label ratings selected and asserts the header rows
/// (today_screen.dart:1316 p-rating, :1560 back-pain) don't overflow.
void main() {
  late TestHarness h;
  final today = formatDate(DateTime.now());

  setUp(() async {
    h = await installTestHarness(prefs: {
      // Select ratings whose labels are at their widest.
      'flexit_bp_$today': 7,
      'flexit_p_$today': -2,
    });
  });
  tearDown(() => h.dispose());

  testWidgets('metric-card headers do not overflow on a narrow device',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    // A small/old phone width (≈ iPhone SE) — the narrowest the app targets.
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Collect every layout error raised this frame, not just the first.
    final errors = <String>[];
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());

    await tester.pumpWidget(const MaterialApp(home: TodayScreen()));
    await tester.pumpAndSettle();
    FlutterError.onError = priorOnError;
    for (var ex = tester.takeException(); ex != null;) {
      errors.add(ex.toString());
      ex = tester.takeException();
    }

    // Pin to the two metric-card header rows specifically (by source line) so
    // this test is about the fixed bug, not unrelated layout at small widths.
    // The app-bar FlexibleSpaceBar overflow is clipped and pre-existing.
    final headerOverflows = errors.where((e) =>
        e.contains('overflowed') &&
        (e.contains('today_screen.dart:1316') ||
            e.contains('today_screen.dart:1560')));
    expect(headerOverflows, isEmpty,
        reason: 'a metric-card header Row overflowed:\n'
            '${headerOverflows.join('\n---\n')}');
  });
}
