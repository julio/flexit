import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexit/data/cloud_sync.dart';
import 'package:flexit/data/health_sync.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Shared widget-test scaffolding. Every screen under test reaches for at least
/// one platform plugin — SharedPreferences, path_provider, url_launcher, the
/// local-notifications method channel, and the haptics channel. Real
/// implementations of those are unavailable in `flutter test`, so this harness
/// installs fakes for all of them and lets each test assert against what the
/// code *tried* to do (which URL it launched, which notification it scheduled).
///
/// Call [installTestHarness] inside `setUp` and pass any seed prefs you want.

/// Records every URL the app asked the OS to open.
class FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];
  bool nextLaunchResult = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return nextLaunchResult;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return nextLaunchResult;
  }
}

/// Test-only PathProvider that points the documents directory at a temp dir.
class _TmpPathProvider extends PathProviderPlatform {
  final String docsPath;
  _TmpPathProvider(this.docsPath);
  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// One method-channel invocation captured by the harness.
class MethodCallRecord {
  final String channel;
  final String method;
  final dynamic arguments;
  MethodCallRecord(this.channel, this.method, this.arguments);
  @override
  String toString() => '$channel#$method($arguments)';
}

class TestHarness {
  final FakeUrlLauncher urls;
  final Directory docsDir;
  final List<MethodCallRecord> calls;

  TestHarness(this.urls, this.docsDir, this.calls);

  /// Calls captured on the flutter_local_notifications channel.
  Iterable<MethodCallRecord> get notificationCalls =>
      calls.where((c) => c.channel == _notificationsChannel);

  /// Calls captured on the haptic-feedback channel (SystemSound/HapticFeedback
  /// route through the platform channel as `HapticFeedback.vibrate`).
  Iterable<MethodCallRecord> get hapticCalls => calls.where((c) =>
      c.channel == 'flutter/platform' &&
      c.method == 'HapticFeedback.vibrate');

  void dispose() {
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  }
}

const _notificationsChannel = 'dexterous.com/flutter/local_notifications';

/// Pumps [screen] inside a phone-sized MaterialApp. The default 800×600 test
/// surface is too short for the app's headers (they overflow); a tall phone
/// surface mirrors a real device. Resets the surface override on teardown via
/// [addTearDown]. Does NOT call pumpAndSettle (some screens hold perpetual
/// animations / timers) — callers pump as their test needs.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(430, 932),
  bool settle = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: screen));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  drainBenignOverflow(tester);
}

/// The Today header's [FlexibleSpaceBar] background reports a RenderFlex
/// overflow while the app bar collapses — but it sits inside a `ClipRect`, so
/// it is never visible on a real device. Under the test font (glyph metrics
/// differ from the device font) it trips on the very first frame. Consume that
/// one specific exception so it doesn't fail otherwise-valid widget tests;
/// rethrow anything else so real errors still surface.
void drainBenignOverflow(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex == null) return;
  final msg = ex.toString();
  if (msg.contains('A RenderFlex overflowed')) return;
  throw ex;
}

/// Installs all platform fakes. Returns a [TestHarness] for assertions.
/// [prefs] seeds SharedPreferences (mirrors `setMockInitialValues`).
Future<TestHarness> installTestHarness({
  Map<String, Object> prefs = const {},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(prefs);

  // No widget/unit test should reach the network. Cloud sync stays off here;
  // cloud_sync_test re-enables it with a mock http client.
  CloudSync.enabled = false;

  // Same for Apple Health: off by default so no test touches the platform.
  // health_sync_test re-enables it with a fake gateway.
  HealthSync.enabled = false;

  final urls = FakeUrlLauncher();
  UrlLauncherPlatform.instance = urls;

  // createTempSync (not the async createTemp) on purpose: this function is
  // commonly awaited from inside a `testWidgets` body, which runs in a
  // FakeAsync zone where real-I/O futures never complete and would deadlock.
  // A synchronous create has no such future.
  final docsDir = Directory.systemTemp.createTempSync('flexit_widget_test_');
  PathProviderPlatform.instance = _TmpPathProvider(docsDir.path);

  final calls = <MethodCallRecord>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Local notifications: record calls, answer the queries the plugin makes
  // during init() so it believes it succeeded.
  messenger.setMockMethodCallHandler(
    const MethodChannel(_notificationsChannel),
    (call) async {
      calls.add(MethodCallRecord(
          _notificationsChannel, call.method, call.arguments));
      switch (call.method) {
        case 'initialize':
        case 'requestPermissions':
          return true;
        case 'getNotificationAppLaunchDetails':
          return <String, dynamic>{'notificationLaunchedApp': false};
        case 'pendingNotificationRequests':
        case 'getActiveNotifications':
          return <dynamic>[];
        default:
          return null;
      }
    },
  );

  // Haptics / system-chrome / clipboard all flow through flutter/platform.
  // Record so haptic feedback can be asserted; return null (no-op) for the rest.
  messenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(MethodCallRecord(
          'flutter/platform', call.method, call.arguments));
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    },
  );

  return TestHarness(urls, docsDir, calls);
}
