import 'package:flutter_test/flutter_test.dart';

import 'package:flexit/main.dart' show themeIsDark;
import 'package:flexit/main.dart' as app show main;
import 'package:flexit/theme.dart';

import 'helpers/test_harness.dart';

/// The light-mode boot of `main()` lives in its own file (its own test isolate)
/// on purpose: launching the full real app via `main()` twice in a single
/// isolate pollutes the fake-async clock (a Ticker started under `runAsync`'s
/// real clock then ticked under the fake clock trips
/// `elapsedInSeconds >= 0`). Isolation gives each boot a fresh clock.
///
/// Seeding dark-mode = false drives main()'s `AppColors.applyLight()` branch,
/// the one line the dark-default boot in main_test.dart can't reach.
void main() {
  testWidgets('main() applies the light palette when dark mode is off',
      (tester) async {
    final h = await installTestHarness(prefs: {'flexit_dark_mode': false});
    addTearDown(h.dispose);
    addTearDown(() => themeIsDark.value = true);

    await tester.runAsync(() async {
      app.main();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    drainBenignOverflow(tester);

    expect(themeIsDark.value, isFalse);
    expect(AppColors.isDark, isFalse);
  });
}
