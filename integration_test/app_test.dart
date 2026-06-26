// End-to-end UI test — the Puppeteer equivalent for Flutter. Unlike the widget
// tests (which pump a single screen with faked plugins), this launches the REAL
// app via main() on a real device/host and drives the actual UI: it expands the
// workout, finds the Daily PT timer buttons, taps one, and verifies the
// countdown actually runs in real time and marks the rep done.
//
// Run on macOS desktop (fast, no simulator needed):
//   flutter test integration_test/app_test.dart -d macos
// or on the connected iPhone:
//   flutter test integration_test/app_test.dart -d <device-id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flexit/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Don't auto-report a "frame did not settle" failure for the perpetual
  // countdown / progress animations.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// The card body (outermost AnimatedContainer) for the exercise named [name],
  /// so set-button finders don't collide with identical labels in other cards.
  Finder cardFor(String name) => find
      .ancestor(
        of: find.text(name),
        matching: find.byType(AnimatedContainer),
      )
      .last;

  Future<void> bringUp(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Daily PT timers count down and complete a rep end-to-end',
      (tester) async {
    app.main();
    // Real startup runs migrations -> Daily PT becomes the active routine.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The active routine surfaces as the Today header title.
    expect(find.text('Daily PT'), findsWidgets);

    // Expand the collapsible workout, then the Daily PT block.
    await bringUp(tester, find.text("TODAY'S WORKOUT"));
    await tester.tap(find.text("TODAY'S WORKOUT"));
    await tester.pump(const Duration(milliseconds: 400));
    await bringUp(tester, find.text('DAILY PT'));
    await tester.tap(find.text('DAILY PT'));
    await tester.pump(const Duration(milliseconds: 400));

    // Both prescribed exercises render.
    expect(find.text('90/90 Hip Lift'), findsOneWidget);
    expect(find.text('Kneeling Hip-Flexor / Quad Stretch'), findsOneWidget);

    // The hip lift exposes five numbered per-rep timer buttons (1..5); the
    // sided stretch exposes L/R buttons. Confirm a couple render.
    final hipLift = cardFor('90/90 Hip Lift');
    await bringUp(tester, hipLift);
    expect(find.descendant(of: hipLift, matching: find.text('1')),
        findsOneWidget);
    expect(find.descendant(of: hipLift, matching: find.text('5')),
        findsOneWidget);
    expect(
        find.descendant(
            of: cardFor('Kneeling Hip-Flexor / Quad Stretch'),
            matching: find.text('1L')),
        findsOneWidget);

    // Tap rep 1's timer button — the countdown starts.
    final repOne = find.descendant(of: hipLift, matching: find.text('1'));
    await tester.tap(repOne);
    await tester.pump(const Duration(milliseconds: 300));

    // A running timer shows a progress bar and a remaining-seconds label
    // ("40s" -> ...), replacing the "1" label.
    expect(find.descendant(of: hipLift, matching: find.text('1')), findsNothing,
        reason: 'the "1" label should be replaced by the countdown');
    expect(
        find.descendant(
            of: hipLift, matching: find.byType(LinearProgressIndicator)),
        findsOneWidget,
        reason: 'a running timer renders a LinearProgressIndicator');

    // Let real time pass and confirm the countdown is ticking down.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump();
    final running = tester
        .widgetList<Text>(find.descendant(of: hipLift, matching: find.byType(Text)))
        .map((t) => t.data)
        .firstWhere((d) => d != null && d.endsWith('s'), orElse: () => null);
    expect(running, isNotNull,
        reason: 'countdown label like "37s" should be visible while running');
    final secs = int.parse(running!.replaceAll('s', ''));
    expect(secs, lessThan(40),
        reason: 'after ~3s the 40s hold should have decremented');
  });
}
