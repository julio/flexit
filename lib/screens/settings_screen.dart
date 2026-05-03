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
  final Map<String, int> _values = {};
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

  Future<void> _load() async {
    final values = <String, int>{};
    for (final e in _timed) {
      final spec = e.timer!;
      values[spec.settingKey] =
          await getTimerSeconds(spec.settingKey, spec.defaultSeconds);
    }
    if (mounted) {
      setState(() {
        _values
          ..clear()
          ..addAll(values);
        _loading = false;
      });
    }
  }

  Future<void> _update(String key, int seconds) async {
    setState(() => _values[key] = seconds);
    await setTimerSeconds(key, seconds);
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
                const Text(
                  'TIMERS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ..._timed.map((e) {
                  final key = e.timer!.settingKey;
                  final seconds = _values[key] ?? e.timer!.defaultSeconds;
                  return _TimerSettingTile(
                    name: e.name,
                    seconds: seconds,
                    onChanged: (s) => _update(key, s),
                  );
                }),
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
