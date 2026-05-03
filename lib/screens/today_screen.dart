import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../theme.dart';
import 'settings_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _done = false;
  int _streak = 0;
  bool _loading = true;
  Set<String> _completedExercises = {};
  Map<String, int> _timerSeconds = {};

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final done = await isTodayComplete();
    final sessions = await getSessions();
    final completed = await getTodayCompletedExercises();
    final timers = <String, int>{};
    for (final e in dailyBlocks.expand((b) => b.exercises)) {
      final spec = e.timer;
      if (spec == null) continue;
      timers[spec.settingKey] =
          await getTimerSeconds(spec.settingKey, spec.defaultSeconds);
    }
    if (mounted) {
      setState(() {
        _done = done;
        _streak = getCurrentStreak(sessions);
        _completedExercises = completed;
        _timerSeconds = timers;
        _loading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadState();
  }

  Future<void> _toggleExercise(String atomicId) async {
    final updated = Set<String>.from(_completedExercises);
    if (updated.contains(atomicId)) {
      updated.remove(atomicId);
    } else {
      updated.add(atomicId);
      HapticFeedback.mediumImpact();
    }

    await saveTodayCompletedExercises(updated);
    setState(() => _completedExercises = updated);

    // Auto-complete session when all exercises are done
    final allIds = dailyBlocks
        .expand((b) => b.exercises)
        .expand((e) => e.atomicIds)
        .toSet();
    final allDone = allIds.difference(updated).isEmpty;

    if (allDone && !_done) {
      final today = formatDate(DateTime.now());
      await saveSession(Session(
        date: today,
        completedAt: DateTime.now().toIso8601String(),
        type: 'daily',
      ));
      HapticFeedback.heavyImpact();
      await _loadState();
    } else if (!allDone && _done) {
      // Un-complete if user unchecks an exercise
      await removeSession(formatDate(DateTime.now()));
      await _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalExercises = dailyBlocks
        .expand((b) => b.exercises)
        .fold<int>(0, (sum, e) => sum + e.sets);
    final completedCount = _completedExercises.length;

    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _streak > 0 ? 140 : 120,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary),
                onPressed: _openSettings,
                tooltip: 'Settings',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily 15',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$completedCount/$totalExercises exercises',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Text(
                          ' \u00b7 ~15 min',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (_streak > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accentDim,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_streak day streak',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Progress bar
          if (totalExercises > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / totalExercises,
                    backgroundColor: AppColors.cardBorder,
                    color: _done ? AppColors.success : AppColors.accent,
                    minHeight: 4,
                  ),
                ),
              ),
            ),
          if (_done)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "All done for today",
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BlockCard(
                  block: dailyBlocks[index],
                  completedExercises: _completedExercises,
                  timerSeconds: _timerSeconds,
                  onToggle: _toggleExercise,
                ),
                childCount: dailyBlocks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final ExerciseBlock block;
  final Set<String> completedExercises;
  final Map<String, int> timerSeconds;
  final ValueChanged<String> onToggle;

  const _BlockCard({
    required this.block,
    required this.completedExercises,
    required this.timerSeconds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = block.exercises.every(
      (e) => e.atomicIds.every(completedExercises.contains),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (allDone)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_circle,
                            color: AppColors.success, size: 16),
                      ),
                    Text(
                      block.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: allDone ? AppColors.success : AppColors.accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  block.duration,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...block.exercises.map((e) => _ExerciseCard(
                exercise: e,
                completedExercises: completedExercises,
                timerSeconds: timerSeconds,
                onToggle: onToggle,
              )),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final Set<String> completedExercises;
  final Map<String, int> timerSeconds;
  final ValueChanged<String> onToggle;

  const _ExerciseCard({
    required this.exercise,
    required this.completedExercises,
    required this.timerSeconds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final atomicIds = exercise.atomicIds;
    final isDone = atomicIds.every(completedExercises.contains);
    final isMultiSet = exercise.sets > 1;
    final timer = exercise.timer;
    final timerDuration = timer == null
        ? 0
        : (timerSeconds[timer.settingKey] ?? timer.defaultSeconds);

    return GestureDetector(
      onTap: isMultiSet ? null : () => onToggle(exercise.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone ? AppColors.successDim : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 14),
              child: isMultiSet
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < atomicIds.length; i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          if (timer != null)
                            _TimerSetButton(
                              key: ValueKey(
                                  '${atomicIds[i]}@$timerDuration'),
                              label: '${i + 1}',
                              durationSeconds: timerDuration,
                              isDone:
                                  completedExercises.contains(atomicIds[i]),
                              onComplete: () => onToggle(atomicIds[i]),
                              onUndo: () => onToggle(atomicIds[i]),
                            )
                          else
                            _SetCheckbox(
                              label: '${i + 1}',
                              isDone:
                                  completedExercises.contains(atomicIds[i]),
                              onTap: () => onToggle(atomicIds[i]),
                            ),
                        ],
                      ],
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            isDone ? AppColors.success : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isDone
                              ? AppColors.success
                              : AppColors.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDone ? AppColors.success : AppColors.text,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise.duration,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDone
                          ? AppColors.success.withValues(alpha: 0.6)
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (!isDone) ...[
                    const SizedBox(height: 10),
                    Text(
                      exercise.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.cue,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (exercise.videoUrl != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(exercise.videoUrl!),
                            mode: LaunchMode.externalApplication),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Watch video',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerSetButton extends StatefulWidget {
  final String label;
  final int durationSeconds;
  final bool isDone;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  const _TimerSetButton({
    super.key,
    required this.label,
    required this.durationSeconds,
    required this.isDone,
    required this.onComplete,
    required this.onUndo,
  });

  @override
  State<_TimerSetButton> createState() => _TimerSetButtonState();
}

class _TimerSetButtonState extends State<_TimerSetButton> {
  Timer? _ticker;
  int _remaining = 0;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _remaining = widget.durationSeconds;
    });
    HapticFeedback.lightImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        _ticker?.cancel();
        setState(() => _running = false);
        HapticFeedback.heavyImpact();
        widget.onComplete();
      }
    });
  }

  void _cancel() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _remaining = 0;
    });
  }

  void _handleTap() {
    if (widget.isDone) {
      widget.onUndo();
      return;
    }
    if (_running) {
      _cancel();
      return;
    }
    _start();
  }

  String _formatRemaining(int s) {
    if (s >= 60) {
      final m = s ~/ 60;
      final r = s % 60;
      return '$m:${r.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.isDone;
    final showRunning = _running && !isDone;
    final progress = showRunning && widget.durationSeconds > 0
        ? 1.0 - (_remaining / widget.durationSeconds)
        : (isDone ? 1.0 : 0.0);

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: 48,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showRunning)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.cardBorder,
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 24,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success
                    : showRunning
                        ? Colors.transparent
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isDone
                      ? AppColors.success
                      : showRunning
                          ? AppColors.accent
                          : AppColors.textMuted,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(
                      showRunning
                          ? _formatRemaining(_remaining)
                          : widget.label,
                      style: TextStyle(
                        fontSize: showRunning ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: showRunning
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetCheckbox extends StatelessWidget {
  final String label;
  final bool isDone;
  final VoidCallback onTap;

  const _SetCheckbox({
    required this.label,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isDone ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isDone ? AppColors.success : AppColors.textMuted,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}
