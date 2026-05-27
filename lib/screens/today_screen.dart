import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../models/session.dart';
import '../services/notifications.dart';
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
  Map<String, int> _repCounts = {};
  DateTime? _startTime;
  Duration? _finalElapsed;
  Timer? _ticker;
  Duration _pauseTotal = Duration.zero;
  DateTime? _pauseStartedAt;
  int? _pRating;
  int? _alcoholYesterday;
  int? _backPain;
  String _yesterdayKey = '';
  Routine _routine = routines.first;
  List<ExerciseBlock> _blocks = const [];
  WeekProgram? _weekProgram;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final today = formatDate(DateTime.now());
    final yesterday =
        formatDate(DateTime.now().subtract(const Duration(days: 1)));
    final done = await isTodayComplete();
    final sessions = await getSessions();
    final completed = await getTodayCompletedExercises();
    final startTime = await getStartTime(today);
    final pauseTotal = await getPauseTotal(today);
    final pauseStartedAt = await getPauseStartedAt(today);
    final pRating = await getPRating(today);
    final alcoholYesterday = await getAlcoholRating(yesterday);
    final backPain = await getBackPainRating(today);
    final routineId = await getActiveRoutineId();
    final routine = routineById(routineId);

    // Resolve which blocks apply for today. Routines with a Program follow
    // a weekly schedule keyed off a per-routine start date (set lazily here).
    List<ExerciseBlock> blocks;
    WeekProgram? weekProgram;
    if (routine.hasProgram) {
      final start = await ensureProgramStartDate(routine.id);
      final week = routine.program!.currentWeek(start, DateTime.now());
      blocks = routine.program!.blocksForWeek(week);
      weekProgram = routine.program!.weekProgram(week);
    } else {
      blocks = routine.blocks;
    }

    final timers = <String, int>{};
    final reps = <String, int>{};
    for (final e in blocks.expand((b) => b.exercises)) {
      if (e.timer != null) {
        timers[e.timer!.settingKey] =
            await getTimerSeconds(e.timer!.settingKey, e.timer!.defaultSeconds);
      }
      if (e.reps != null) {
        reps[e.reps!.settingKey] =
            await getRepsCount(e.reps!.settingKey, e.reps!.defaultReps);
      }
    }

    Duration? finalElapsed;
    if (done) {
      final session =
          sessions.where((s) => s.date == today).firstOrNull;
      finalElapsed = session?.duration;
    }

    if (mounted) {
      setState(() {
        _done = done;
        _streak = getCurrentStreak(sessions);
        _completedExercises = completed;
        _timerSeconds = timers;
        _repCounts = reps;
        _startTime = startTime;
        _pauseTotal = pauseTotal;
        _pauseStartedAt = pauseStartedAt;
        _finalElapsed = finalElapsed;
        _pRating = pRating;
        _alcoholYesterday = alcoholYesterday;
        _backPain = backPain;
        _yesterdayKey = yesterday;
        _routine = routine;
        _blocks = blocks;
        _weekProgram = weekProgram;
        _loading = false;
      });
      _updateTicker();
    }
  }

  Future<void> _setPRating(int value) async {
    final today = formatDate(DateTime.now());
    await setPRating(today, value);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _pRating = value);
  }

  Future<void> _setAlcoholYesterday(int value) async {
    if (_yesterdayKey.isEmpty) return;
    await setAlcoholRating(_yesterdayKey, value);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _alcoholYesterday = value);
  }

  Future<void> _setBackPain(int value) async {
    final today = formatDate(DateTime.now());
    await setBackPainRating(today, value);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _backPain = value);
  }

  void _updateTicker() {
    _ticker?.cancel();
    // Only tick while a session is running and NOT paused — when paused the
    // display is frozen at the pause moment.
    if (_startTime != null && !_done && _pauseStartedAt == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Total paused duration including any in-progress pause as of [at].
  Duration _totalPause(DateTime at) {
    if (_pauseStartedAt == null) return _pauseTotal;
    return _pauseTotal + at.difference(_pauseStartedAt!);
  }

  Future<void> _togglePause() async {
    if (_startTime == null || _done) return;
    final today = formatDate(DateTime.now());
    final now = DateTime.now();
    if (_pauseStartedAt == null) {
      // Pause now.
      await setPauseStartedAt(today, now);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _pauseStartedAt = now);
    } else {
      // Resume: roll the current pause into the accumulated total.
      final addition = now.difference(_pauseStartedAt!);
      final newTotal = _pauseTotal + addition;
      await setPauseTotal(today, newTotal);
      await clearPauseStartedAt(today);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _pauseTotal = newTotal;
        _pauseStartedAt = null;
      });
    }
    _updateTicker();
  }

  Future<void> _start() async {
    final now = DateTime.now();
    final today = formatDate(now);
    await setStartTime(today, now);
    // Starting a brand-new session resets any leftover pause state.
    await clearPauseState(today);
    if (!mounted) return;
    setState(() {
      _startTime = now;
      _pauseTotal = Duration.zero;
      _pauseStartedAt = null;
    });
    _updateTicker();
    HapticFeedback.mediumImpact();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadState();
  }

  Future<bool?> _confirmUndo() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Undo this completion?',
            style: TextStyle(color: AppColors.text, fontSize: 17)),
        content: Text(
          'You already marked this as done.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Undo',
                style: TextStyle(
                    color: AppColors.missed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleExercise(String atomicId) async {
    final updated = Set<String>.from(_completedExercises);
    if (updated.contains(atomicId)) {
      final confirmed = await _confirmUndo();
      if (confirmed != true) return;
      updated.remove(atomicId);
    } else {
      updated.add(atomicId);
      HapticFeedback.mediumImpact();
    }

    await saveTodayCompletedExercises(updated);
    setState(() => _completedExercises = updated);

    // Auto-complete session when all exercises are done
    final allIds = _blocks
        .expand((b) => b.exercises)
        .expand((e) => e.atomicIds)
        .toSet();
    final allDone = allIds.difference(updated).isEmpty;

    if (allDone && !_done) {
      final now = DateTime.now();
      final today = formatDate(now);
      // Push startedAt forward by the total paused time so the resulting
      // duration (completedAt − startedAt) reflects active time only.
      String? adjustedStart;
      if (_startTime != null) {
        adjustedStart =
            _startTime!.add(_totalPause(now)).toIso8601String();
      }
      await saveSession(Session(
        date: today,
        completedAt: now.toIso8601String(),
        type: 'daily',
        startedAt: adjustedStart,
      ));
      await clearPauseState(today);
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
    final validAtomicIds = _blocks
        .expand((b) => b.exercises)
        .expand((e) => e.atomicIds)
        .toSet();
    final totalExercises = validAtomicIds.length;
    final completedCount =
        _completedExercises.intersection(validAtomicIds).length;
    final estimatedMinutes = _blocks.fold<int>(0, (sum, b) {
      final n = int.tryParse(b.duration.split(' ').first) ?? 0;
      return sum + n;
    });

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
                icon: Icon(Icons.settings_outlined,
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
                    Text(
                      _routine.title,
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
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          ' \u00b7 ~$estimatedMinutes min',
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
                          style: TextStyle(
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
          if (_weekProgram != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _WeekBanner(week: _weekProgram!),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _PRatingCard(
                value: _pRating,
                onSelect: _setPRating,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _AlcoholCard(
                value: _alcoholYesterday,
                onSelect: _setAlcoholYesterday,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _BackPainCard(
                value: _backPain,
                onSelect: _setBackPain,
              ),
            ),
          ),
          if (!_done)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _startTime == null
                    ? _StartButton(onPressed: _start)
                    : _RunningClock(
                        startTime: _startTime!,
                        pauseTotal: _pauseTotal,
                        pauseStartedAt: _pauseStartedAt,
                        onPauseToggle: _togglePause,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _finalElapsed != null
                            ? 'Done in ${_formatElapsed(_finalElapsed!)}'
                            : 'All done for today',
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
                  block: _blocks[index],
                  completedExercises: _completedExercises,
                  timerSeconds: _timerSeconds,
                  repCounts: _repCounts,
                  onToggle: _toggleExercise,
                ),
                childCount: _blocks.length,
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
  final Map<String, int> repCounts;
  final ValueChanged<String> onToggle;

  const _BlockCard({
    required this.block,
    required this.completedExercises,
    required this.timerSeconds,
    required this.repCounts,
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
                  style: TextStyle(
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
                repCounts: repCounts,
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
  final Map<String, int> repCounts;
  final ValueChanged<String> onToggle;

  const _ExerciseCard({
    required this.exercise,
    required this.completedExercises,
    required this.timerSeconds,
    required this.repCounts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final atomicIds = exercise.atomicIds;
    final isDone = atomicIds.every(completedExercises.contains);
    final isMultiSet = exercise.sets > 1;
    final timer = exercise.timer;
    // Timer duration sources, in priority order: a user-configurable
    // TimerSpec, then a number parsed out of the duration label, then no
    // timer. Any value > 0 gets a tappable countdown button.
    final timerDuration = timer != null
        ? (timerSeconds[timer.settingKey] ?? timer.defaultSeconds)
        : (exercise.parsedDurationSeconds ?? 0);
    final hasTimer = timerDuration > 0;
    final repsSpec = exercise.reps;
    final durationLabel = repsSpec != null
        ? '${exercise.sets} × ${repCounts[repsSpec.settingKey] ?? repsSpec.defaultReps} reps'
        : exercise.duration;
    // Use the column-of-buttons layout whenever there are multiple sets OR a
    // timer is available — the timer button replaces the inline checkbox.
    final useColumnLayout = isMultiSet || hasTimer;

    return GestureDetector(
      onTap: useColumnLayout ? null : () => onToggle(exercise.id),
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
              child: useColumnLayout
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < atomicIds.length; i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          if (hasTimer)
                            _TimerSetButton(
                              key: ValueKey(
                                  '${atomicIds[i]}@$timerDuration'),
                              label: isMultiSet ? '${i + 1}' : 'Go',
                              durationSeconds: timerDuration,
                              notificationId: atomicIds[i].hashCode,
                              notificationBody: isMultiSet
                                  ? '${exercise.name} · set ${i + 1} done'
                                  : '${exercise.name} done',
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
                    durationLabel,
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
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.cue,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => launchUrl(
                          Uri.parse(exercise.effectiveVideoUrl),
                          mode: LaunchMode.externalApplication),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.accentDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              exercise.videoUrl != null
                                  ? Icons.play_circle_outline
                                  : Icons.search,
                              color: AppColors.accent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              exercise.videoUrl != null
                                  ? 'Watch video'
                                  : 'Find on YouTube',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

String _formatElapsed(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text(
              'Start',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningClock extends StatelessWidget {
  final DateTime startTime;
  final Duration pauseTotal;
  final DateTime? pauseStartedAt;
  final VoidCallback onPauseToggle;

  const _RunningClock({
    required this.startTime,
    required this.pauseTotal,
    required this.pauseStartedAt,
    required this.onPauseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final paused = pauseStartedAt != null;
    // Frozen at the pause moment when paused; live wall-clock otherwise.
    final reference = paused ? pauseStartedAt! : DateTime.now();
    final elapsed = reference.difference(startTime) - pauseTotal;
    final clamped = elapsed.isNegative ? Duration.zero : elapsed;

    final fg = paused ? AppColors.warning : AppColors.accent;
    final bg = paused
        ? AppColors.warningDim
        : AppColors.accentDim;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            paused ? Icons.pause_circle_outline : Icons.timer_outlined,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  _formatElapsed(clamped),
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (paused) ...[
                  const SizedBox(width: 8),
                  Text(
                    'paused',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onPauseToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    paused ? Icons.play_arrow : Icons.pause,
                    color: fg,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    paused ? 'Resume' : 'Pause',
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerSetButton extends StatefulWidget {
  final String label;
  final int durationSeconds;
  final int notificationId;
  final String notificationBody;
  final bool isDone;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  const _TimerSetButton({
    super.key,
    required this.label,
    required this.durationSeconds,
    required this.notificationId,
    required this.notificationBody,
    required this.isDone,
    required this.onComplete,
    required this.onUndo,
  });

  @override
  State<_TimerSetButton> createState() => _TimerSetButtonState();
}

class _TimerSetButtonState extends State<_TimerSetButton>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime? _endTime;
  bool _running = false;

  int get _remaining {
    if (_endTime == null) return 0;
    final r = _endTime!.difference(DateTime.now()).inSeconds;
    return r > 0 ? r : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAndUpdate();
  }

  void _checkAndUpdate() {
    if (!_running || _endTime == null) return;
    if (!DateTime.now().isBefore(_endTime!)) {
      _ticker?.cancel();
      TimerNotifications.instance.cancel(widget.notificationId);
      setState(() {
        _running = false;
        _endTime = null;
      });
      HapticFeedback.heavyImpact();
      widget.onComplete();
    } else {
      setState(() {});
    }
  }

  void _start() {
    final end = DateTime.now().add(Duration(seconds: widget.durationSeconds));
    setState(() {
      _running = true;
      _endTime = end;
    });
    HapticFeedback.lightImpact();
    TimerNotifications.instance.schedule(
      id: widget.notificationId,
      title: 'Timer done',
      body: widget.notificationBody,
      fireAt: end,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkAndUpdate();
    });
  }

  void _cancel() {
    _ticker?.cancel();
    TimerNotifications.instance.cancel(widget.notificationId);
    setState(() {
      _running = false;
      _endTime = null;
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}

class _PRatingCard extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _PRatingCard({required this.value, required this.onSelect});

  static const _options = [2, 1, 0, -1, -2];
  static const _labels = {
    2: 'excellent',
    1: 'good',
    0: 'ok',
    -1: 'bad',
    -2: 'horrible',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How was p today?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              if (value != null)
                Text(
                  _labels[value]!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final v in _options) ...[
                if (v != _options.first) const SizedBox(width: 6),
                Expanded(
                  child: _PRatingButton(
                    value: v,
                    selected: value == v,
                    onTap: () => onSelect(v),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PRatingButton extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _PRatingButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.pColor(value);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.text : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value > 0 ? '+$value' : '$value',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AlcoholCard extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _AlcoholCard({required this.value, required this.onSelect});

  static const _options = [0, 1, 2, 3, 4];
  static const _labels = {
    0: 'none',
    1: 'a sip',
    2: 'a glass',
    3: 'a few glasses',
    4: 'drunk',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drinks yesterday',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              if (value != null)
                Text(
                  _labels[value]!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final v in _options) ...[
                if (v != _options.first) const SizedBox(width: 6),
                Expanded(
                  child: _AlcoholButton(
                    level: v,
                    selected: value == v,
                    onTap: () => onSelect(v),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AlcoholButton extends StatelessWidget {
  final int level;
  final bool selected;
  final VoidCallback onTap;

  const _AlcoholButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.alcoholColor(level);
    final textColor = Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.text : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BackPainCard extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _BackPainCard({required this.value, required this.onSelect});

  static const _labels = {
    0: 'none',
    1: 'a twinge',
    2: 'minor',
    3: 'noticeable',
    4: 'nagging',
    5: 'moderate',
    6: 'distracting',
    7: 'bad',
    8: 'very bad',
    9: 'severe',
    10: 'agony',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lower back pain',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              if (value != null)
                Text(
                  '${value!} · ${_labels[value]!}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var v = 0; v <= 10; v++) ...[
                if (v != 0) const SizedBox(width: 4),
                Expanded(
                  child: _BackPainButton(
                    level: v,
                    selected: value == v,
                    onTap: () => onSelect(v),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BackPainButton extends StatelessWidget {
  final int level;
  final bool selected;
  final VoidCallback onTap;

  const _BackPainButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.backPainColor(level);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.text : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WeekBanner extends StatelessWidget {
  final WeekProgram week;
  const _WeekBanner({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Week ${week.weekNumber}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  week.phase,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            week.theme,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.directions_walk,
                  color: AppColors.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                'Walk: ${week.walkingTarget}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

