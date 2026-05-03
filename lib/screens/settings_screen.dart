import 'package:flutter/material.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Exercise> get _timed => dailyBlocks
      .expand((b) => b.exercises)
      .where((e) => e.timer != null)
      .toList();

  List<Exercise> get _repped => dailyBlocks
      .expand((b) => b.exercises)
      .where((e) => e.reps != null)
      .toList();

  Future<void> _load() async {
    final timers = <String, int>{};
    for (final e in _timed) {
      final spec = e.timer!;
      timers[spec.settingKey] =
          await getTimerSeconds(spec.settingKey, spec.defaultSeconds);
    }
    final reps = <String, int>{};
    for (final e in _repped) {
      final spec = e.reps!;
      reps[spec.settingKey] =
          await getRepsCount(spec.settingKey, spec.defaultReps);
    }
    if (mounted) {
      setState(() {
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
                    final key = e.reps!.settingKey;
                    final reps = _repValues[key] ?? e.reps!.defaultReps;
                    return _RepSettingTile(
                      name: e.name,
                      sets: e.sets,
                      reps: reps,
                      onChanged: (r) => _updateReps(key, r),
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RepSettingTile extends StatelessWidget {
  final String name;
  final int sets;
  final int reps;
  final ValueChanged<int> onChanged;

  const _RepSettingTile({
    required this.name,
    required this.sets,
    required this.reps,
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                '$sets × $reps reps',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: reps.toDouble(),
            min: 5,
            max: 50,
            divisions: 45,
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                _format(seconds),
                style: const TextStyle(
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
