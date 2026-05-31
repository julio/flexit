import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';

/// Append-only daily backups. Each calendar day gets exactly one file in the
/// app's documents directory; once written, it is never touched again by this
/// code path — past backups are immutable on the device.
///
/// Triggered on every app launch and on every foreground resume. If today's
/// file already exists, do nothing. If not, write a snapshot.
///
/// Files survive app updates. They are removed when the user deletes the app,
/// so for stronger durability the user should periodically pull them off the
/// device (Files → On My iPhone → FlexIt).

const _backupDirName = 'flexit_backups';

Future<Directory> _backupDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$_backupDirName');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

String _backupFileName(DateTime when) {
  final y = when.year.toString().padLeft(4, '0');
  final m = when.month.toString().padLeft(2, '0');
  final d = when.day.toString().padLeft(2, '0');
  return 'backup-$y-$m-$d.json';
}

/// If a backup for the given date does not already exist on disk, write the
/// current SharedPreferences snapshot to one. Returns the path written, or
/// null if today's backup was already present (no-op).
Future<String?> runDailyBackupIfNeeded({DateTime? now}) async {
  final today = now ?? DateTime.now();
  final dir = await _backupDir();
  final file = File('${dir.path}/${_backupFileName(today)}');
  // The contract: past backups are immutable. If a file for today already
  // exists, we never touch it — even if more data was added since.
  if (file.existsSync()) return null;
  final json = await exportAllJson();
  await file.writeAsString(json, flush: true);
  return file.path;
}

/// All backup file paths on disk, newest first.
Future<List<File>> listBackups() async {
  final dir = await _backupDir();
  if (!dir.existsSync()) return [];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  files.sort((a, b) => b.path.compareTo(a.path));
  return files;
}

/// Restore from a specific backup file. Reads it and feeds it through
/// [importAllJson]. Existing keys are overwritten where they overlap; keys
/// already in prefs that aren't in the backup are left untouched.
Future<int> restoreFromBackup(File file) async {
  final contents = await file.readAsString();
  return importAllJson(contents);
}
