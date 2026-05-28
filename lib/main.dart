import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/storage.dart';
import 'screens/today_screen.dart';
import 'screens/calendar_screen.dart';
import 'services/notifications.dart';
import 'theme.dart';

/// Global notifier so any screen can flip the theme and the app rebuilds.
final ValueNotifier<bool> themeIsDark = ValueNotifier<bool>(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One-shot data migration for the per-side atomic ID format change.
  await migrateCompletionPerSideV1();
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
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 1) _calendarKey.currentState?.reload();
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
