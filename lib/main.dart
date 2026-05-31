import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/daily_backup.dart';
import 'data/storage.dart';
import 'screens/today_screen.dart';
import 'screens/calendar_screen.dart';
import 'services/notifications.dart';
import 'theme.dart';

/// Global notifier so any screen can flip the theme and the app rebuilds.
final ValueNotifier<bool> themeIsDark = ValueNotifier<bool>(true);

/// Bumped any time a save lands. The Calendar screen listens and reruns
/// its loader so a write on the Today screen shows up in the calendar grid
/// without depending on the bottom-nav tap to trigger a reload.
final ValueNotifier<int> dataChangedCounter = ValueNotifier<int>(0);

void bumpDataChanged() => dataChangedCounter.value++;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One-shot data migration for the per-side atomic ID format change.
  await migrateCompletionPerSideV1();
  // Append-only daily backup. If today's snapshot already exists on disk we
  // leave it alone — past backups are immutable. Otherwise write the current
  // SharedPreferences state to a new file. Runs once on every cold start.
  await runDailyBackupIfNeeded();
  final dark = await getDarkMode();
  themeIsDark.value = dark;
  if (dark) {
    AppColors.applyDark();
  } else {
    AppColors.applyLight();
  }
  await TimerNotifications.instance.init();
  runApp(const FlexItApp());
}

void _applyStatusBarStyle(bool dark) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  ));
}

class FlexItApp extends StatelessWidget {
  const FlexItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeIsDark,
      builder: (_, dark, __) {
        if (dark) {
          AppColors.applyDark();
        } else {
          AppColors.applyLight();
        }
        _applyStatusBarStyle(dark);
        return MaterialApp(
          title: 'FlexIt',
          theme: buildAppTheme(dark: dark),
          debugShowCheckedModeBanner: false,
          home: const HomeShell(),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final _calendarKey = GlobalKey<CalendarScreenState>();

  @override
  void initState() {
    super.initState();
    // Belt-and-suspenders: in addition to Calendar's own listener on
    // dataChangedCounter, HomeShell also force-reloads Calendar on every
    // bump. If the in-Calendar listener somehow fails to fire (lifecycle,
    // GlobalKey timing), this path still propagates the save.
    dataChangedCounter.addListener(_forceCalendarReload);
  }

  @override
  void dispose() {
    dataChangedCounter.removeListener(_forceCalendarReload);
    super.dispose();
  }

  void _forceCalendarReload() {
    _calendarKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const TodayScreen(),
          CalendarScreen(key: _calendarKey),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) async {
            // Drop focus from any active text field FIRST. The weight card's
            // FocusNode listener commits on focus loss, so this forces any
            // pending value to flush to prefs before the Calendar reload
            // reads it.
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _currentIndex = i);
            if (i == 1) {
              // Give the prefs writes a beat (SharedPreferences setInt is
              // method-channel-async). 150ms is comfortably above the typical
              // write latency on iOS without being user-perceptible.
              await Future.delayed(const Duration(milliseconds: 150));
              _calendarKey.currentState?.reload();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.wb_sunny_outlined),
              activeIcon: Icon(Icons.wb_sunny),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
          ],
        ),
      ),
    );
  }
}
