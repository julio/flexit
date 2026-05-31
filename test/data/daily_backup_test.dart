import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexit/data/daily_backup.dart';
import 'package:flexit/data/storage.dart';

/// Test-only PathProvider impl that points the "documents directory" at a
/// temp directory we control, so the backup module's File I/O is reproducible.
class _TmpPathProvider extends PathProviderPlatform {
  final String docsPath;
  _TmpPathProvider(this.docsPath);
  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('flexit_backup_test_');
    PathProviderPlatform.instance = _TmpPathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({
      'flexit_p_2026-05-30': 1,
      'flexit_weight_2026-05-30': 75500,
    });
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('runDailyBackupIfNeeded writes a file for today on first call',
      () async {
    final now = DateTime(2026, 5, 31, 10, 15);
    final path = await runDailyBackupIfNeeded(now: now);
    expect(path, isNotNull);
    expect(path, endsWith('backup-2026-05-31.json'));
    expect(File(path!).existsSync(), isTrue);
  });

  test('second call on the same day is a no-op (immutable)', () async {
    final now = DateTime(2026, 5, 31, 10, 15);
    final firstPath = await runDailyBackupIfNeeded(now: now);
    final firstMtime = File(firstPath!).statSync().modified;
    // Mutate prefs after first backup.
    await setPRating('2026-05-30', 2);
    final secondPath =
        await runDailyBackupIfNeeded(now: now.add(const Duration(hours: 5)));
    expect(secondPath, isNull, reason: 'should not overwrite');
    final stillThere = File(firstPath).statSync().modified;
    expect(stillThere, firstMtime, reason: 'mtime did not change');
    // Confirm the file content reflects the FIRST snapshot (p=1), not the
    // mutated value (p=2).
    final contents = File(firstPath).readAsStringSync();
    expect(contents, contains('"value": 1'));
    expect(contents, isNot(contains('"value": 2')));
  });

  test('new day creates a separate file; yesterday is untouched', () async {
    final yesterday = DateTime(2026, 5, 31, 10);
    final today = DateTime(2026, 6, 1, 9);
    final yesterdayPath = await runDailyBackupIfNeeded(now: yesterday);
    expect(yesterdayPath, endsWith('backup-2026-05-31.json'));
    final todayPath = await runDailyBackupIfNeeded(now: today);
    expect(todayPath, endsWith('backup-2026-06-01.json'));
    expect(todayPath, isNot(yesterdayPath));
    expect(File(yesterdayPath!).existsSync(), isTrue);
  });

  test('listBackups returns files newest first', () async {
    await runDailyBackupIfNeeded(now: DateTime(2026, 5, 30));
    await runDailyBackupIfNeeded(now: DateTime(2026, 5, 31));
    await runDailyBackupIfNeeded(now: DateTime(2026, 6, 1));
    final files = await listBackups();
    expect(files.map((f) => f.uri.pathSegments.last).toList(), [
      'backup-2026-06-01.json',
      'backup-2026-05-31.json',
      'backup-2026-05-30.json',
    ]);
  });

  test('restoreFromBackup re-applies the snapshot', () async {
    final path =
        await runDailyBackupIfNeeded(now: DateTime(2026, 5, 31, 10));
    expect(path, isNotNull);

    // Wipe and then restore.
    SharedPreferences.setMockInitialValues({});
    expect(await getPRating('2026-05-30'), isNull);

    final n = await restoreFromBackup(File(path!));
    expect(n, 2);
    expect(await getPRating('2026-05-30'), 1);
    expect(await getWeightGrams('2026-05-30'), 75500);
  });
}
