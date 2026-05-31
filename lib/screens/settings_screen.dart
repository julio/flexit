import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/daily_backup.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../main.dart' show themeIsDark;
import '../models/exercise.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, int> _timerValues = {};
  final Map<String, int> _repValues = {};
  Routine _routine = routines.first;
  DateTime? _programStart;
  Set<String> _sessionDates = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Exercise> get _timed => _routine.blocks
      .expand((b) => b.exercises)
      .where((e) => e.timer != null)
      .toList();

  List<Exercise> get _repped => _routine.blocks
      .expand((b) => b.exercises)
      .where((e) => e.reps != null)
      .toList();

  Future<void> _load() async {
    final routineId = await getActiveRoutineId();
    final routine = routineById(routineId);
    final programStart =
        routine.hasProgram ? await getProgramStartDate(routine.id) : null;
    final sessions = await getSessions();
    final timers = <String, int>{};
    for (final e in routine.blocks
        .expand((b) => b.exercises)
        .where((e) => e.timer != null)) {
      final spec = e.timer!;
      timers[spec.settingKey] =
          await getTimerSeconds(spec.settingKey, spec.defaultSeconds);
    }
    final reps = <String, int>{};
    for (final e in routine.blocks
        .expand((b) => b.exercises)
        .where((e) => e.reps != null)) {
      final spec = e.reps!;
      reps[spec.settingKey] =
          await getRepsCount(spec.settingKey, spec.defaultReps);
    }
    if (mounted) {
      setState(() {
        _routine = routine;
        _programStart = programStart;
        _sessionDates = sessions.map((s) => s.date).toSet();
        _timerValues
          ..clear()
          ..addAll(timers);
        _repValues
          ..clear()
          ..addAll(reps);
        _loading = false;
      });
    }
  }

  Future<void> _pickProgramStartDate() async {
    final initial = _programStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Program start date',
    );
    if (picked != null) {
      await setProgramStartDate(_routine.id, picked);
      await _load();
    }
  }

  Future<void> _toggleDarkMode(bool dark) async {
    await setDarkMode(dark);
    themeIsDark.value = dark;
  }

  Future<void> _selectRoutine(String id) async {
    await setActiveRoutineId(id);
    await _load();
  }

  Future<void> _showBackupsList() async {
    final files = await listBackups();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        if (files.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No backups yet. The first backup is written the next time '
              'the app cold-starts or comes back from background.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final f = files[i];
            final name = f.uri.pathSegments.last;
            final size = f.statSync().size;
            return GestureDetector(
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                if (!mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: Text(
                      'Restore from $name?',
                      style: TextStyle(color: AppColors.text, fontSize: 16),
                    ),
                    content: Text(
                      'Existing values will be overwritten where the backup '
                      'has entries. Newer values not present in this backup '
                      'are kept as-is.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Restore',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                try {
                  final n = await restoreFromBackup(f);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Restored $n keys from $name. Switch tabs to refresh.'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: AppColors.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                            color: AppColors.text, fontSize: 14),
                      ),
                    ),
                    Text(
                      '${(size / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportToClipboard() async {
    final json = await exportAllJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    final bytes = json.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $bytes characters of backup to clipboard. '
            'Paste into Notes / iCloud / email immediately.'),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
      return;
    }
    try {
      final count = await importAllJson(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $count keys. Switch tabs to refresh.'),
          duration: const Duration(seconds: 5),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _updateTimer(String key, int seconds) async {
    setState(() => _timerValues[key] = seconds);
    await setTimerSeconds(key, seconds);
  }

  Future<void> _updateReps(String key, int reps) async {
    setState(() => _repValues[key] = reps);
    await setRepsCount(key, reps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                const _SectionHeader('ROUTINE'),
                const SizedBox(height: 12),
                ...routines.map((r) => _RoutineTile(
                      routine: r,
                      selected: r.id == _routine.id,
                      onTap: () => _selectRoutine(r.id),
                    )),
                if (_routine.hasProgram && _programStart != null)
                  _ProgramStartTile(
                    routine: _routine,
                    startDate: _programStart!,
                    sessionDates: _sessionDates,
                    onTap: _pickProgramStartDate,
                  ),
                const SizedBox(height: 16),
                const _SectionHeader('APPEARANCE'),
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: themeIsDark,
                  builder: (_, dark, __) => _ToggleTile(
                    label: 'Dark mode',
                    description:
                        'Toggle between dark and light themes for the whole app.',
                    value: dark,
                    onChanged: _toggleDarkMode,
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionHeader('DATA'),
                const SizedBox(height: 12),
                _ActionTile(
                  label: 'Daily backups on device',
                  description:
                      'One file per day, written automatically the first time the app starts up or comes back from background that day. Past backups are never overwritten. Tap to list and optionally restore.',
                  icon: Icons.history_toggle_off,
                  onTap: _showBackupsList,
                ),
                _ActionTile(
                  label: 'Back up to clipboard',
                  description:
                      'On-demand copy of every flexit_* key as JSON. Useful if you want to stash a backup off the device — paste into Notes / email / iCloud Drive.',
                  icon: Icons.ios_share,
                  onTap: _exportToClipboard,
                ),
                _ActionTile(
                  label: 'Restore from clipboard',
                  description:
                      'Reads a JSON backup from the clipboard and writes every flexit_* key back into storage. Existing keys are overwritten where they overlap; nothing is deleted.',
                  icon: Icons.download_outlined,
                  onTap: _importFromClipboard,
                ),
                const SizedBox(height: 16),
                if (_timed.isNotEmpty) ...[
                  const _SectionHeader('TIMERS'),
                  const SizedBox(height: 12),
                  ..._timed.map((e) {
                    final key = e.timer!.settingKey;
                    final seconds =
                        _timerValues[key] ?? e.timer!.defaultSeconds;
                    return _TimerSettingTile(
                      name: e.name,
                      seconds: seconds,
                      onChanged: (s) => _updateTimer(key, s),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (_repped.isNotEmpty) ...[
                  const _SectionHeader('REPS'),
                  const SizedBox(height: 12),
                  ..._repped.map((e) {
                    final spec = e.reps!;
                    final reps = _repValues[spec.settingKey] ?? spec.defaultReps;
                    return _RepSettingTile(
                      name: e.name,
                      sets: e.sets,
                      reps: reps,
                      minReps: spec.minReps,
                      maxReps: spec.maxReps,
                      onChanged: (r) => _updateReps(spec.settingKey, r),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _RepSettingTile extends StatelessWidget {
  final String name;
  final int sets;
  final int reps;
  final int minReps;
  final int maxReps;
  final ValueChanged<int> onChanged;

  const _RepSettingTile({
    required this.name,
    required this.sets,
    required this.reps,
    required this.minReps,
    required this.maxReps,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                '$sets × $reps reps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: reps.clamp(minReps, maxReps).toDouble(),
            min: minReps.toDouble(),
            max: maxReps.toDouble(),
            divisions: maxReps - minReps,
            activeColor: AppColors.accent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _TimerSettingTile extends StatelessWidget {
  final String name;
  final int seconds;
  final ValueChanged<int> onChanged;

  const _TimerSettingTile({
    required this.name,
    required this.seconds,
    required this.onChanged,
  });

  String _format(int s) {
    if (s < 60) return '$s sec';
    final m = s ~/ 60;
    final r = s % 60;
    if (r == 0) return '$m min';
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                _format(seconds),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: seconds.toDouble(),
            min: 15,
            max: 300,
            divisions: 57,
            activeColor: AppColors.accent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final Routine routine;
  final bool selected;
  final VoidCallback onTap;

  const _RoutineTile({
    required this.routine,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = routine.blocks.fold<int>(0, (sum, b) {
      final n = int.tryParse(b.duration.split(' ').first) ?? 0;
      return sum + n;
    });
    final exerciseCount =
        routine.blocks.fold<int>(0, (sum, b) => sum + b.exercises.length);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.accent : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$exerciseCount exercises · ~$totalMinutes min',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramStartTile extends StatelessWidget {
  final Routine routine;
  final DateTime startDate;
  final Set<String> sessionDates;
  final VoidCallback onTap;

  const _ProgramStartTile({
    required this.routine,
    required this.startDate,
    required this.sessionDates,
    required this.onTap,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final program = routine.program!;
    final week =
        program.currentWeek(startDate, DateTime.now(), sessionDates);
    final cappedWeek = week.clamp(1, program.weeks.length);
    final isMaintenance = week > program.weeks.length;
    final label = isMaintenance
        ? 'Week $week (maintenance, using Week $cappedWeek dose)'
        : 'Week $week of ${program.weeks.length}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.event, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program start',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDate(startDate)} · $label',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
