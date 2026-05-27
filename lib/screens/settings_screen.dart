import 'package:flutter/material.dart';
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

  Future<void> _toggleDarkMode(bool dark) async {
    await setDarkMode(dark);
    themeIsDark.value = dark;
  }

  Future<void> _selectRoutine(String id) async {
    await setActiveRoutineId(id);
    await _load();
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
