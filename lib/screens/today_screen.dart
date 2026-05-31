import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/exercises.dart';
import '../data/daily_backup.dart';
import '../data/storage.dart';
import '../main.dart' show bumpDataChanged, setLatestWriteDiagnostic;
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

class _TodayScreenState extends State<TodayScreen>
    with WidgetsBindingObserver {
  bool _done = false;
  int _streak = 0;
  bool _loading = true;
  Set<String> _completedExercises = {};
  Map<String, int> _timerSeconds = {};
  Map<String, int> _repCounts = {};
  int? _pRating;
  int? _alcoholYesterday;
  int? _backPain;
  int? _weightGrams;
  String _weightUnit = 'kg';
  String _yesterdayKey = '';
  Routine _routine = routines.first;
  List<ExerciseBlock> _blocks = const [];
  WeekProgram? _weekProgram;
  /// The system date the current state was loaded for. When the app comes
  /// back from background after midnight, this won't match `today` anymore
  /// and we reload.
  String _loadedForDate = '';
  /// Whether the outer workout section (progress + week + start + blocks) is
  /// expanded. Default collapsed so the screen stays tight at a glance; user
  /// taps the header to reveal the workout when they're ready to start.
  bool _workoutExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // First foreground of a new day → write that day's backup file if it
    // doesn't already exist. Past days' files are never touched.
    runDailyBackupIfNeeded();
    // If the date changed while backgrounded, blow away the stale state and
    // reload — otherwise yesterday's completion banner sticks around.
    final todayKey = formatDate(DateTime.now());
    if (todayKey != _loadedForDate) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final today = formatDate(DateTime.now());
    final yesterday =
        formatDate(DateTime.now().subtract(const Duration(days: 1)));
    final done = await isTodayComplete();
    final sessions = await getSessions();
    final completed = await getTodayCompletedExercises();
    final pRating = await getPRating(today);
    final alcoholYesterday = await getAlcoholRating(yesterday);
    final backPain = await getBackPainRating(today);
    final weightGrams = await getWeightGrams(today);
    final weightUnit = await getWeightUnit();
    final routineId = await getActiveRoutineId();
    final routine = routineById(routineId);

    // Resolve which blocks apply for today. Routines with a Program follow
    // a weekly schedule keyed off a per-routine start date (set lazily here).
    List<ExerciseBlock> blocks;
    WeekProgram? weekProgram;
    if (routine.hasProgram) {
      final start = await ensureProgramStartDate(routine.id);
      final sessionDates = sessions.map((s) => s.date).toSet();
      final week = routine.program!
          .currentWeek(start, DateTime.now(), sessionDates);
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

    if (mounted) {
      setState(() {
        _done = done;
        _streak = getCurrentStreak(sessions);
        _completedExercises = completed;
        _timerSeconds = timers;
        _repCounts = reps;
        _pRating = pRating;
        _alcoholYesterday = alcoholYesterday;
        _backPain = backPain;
        _weightGrams = weightGrams;
        _weightUnit = weightUnit;
        _yesterdayKey = yesterday;
        _routine = routine;
        _blocks = blocks;
        _weekProgram = weekProgram;
        _loadedForDate = today;
        _loading = false;
      });
    }
  }

  void _flash(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1200),
      backgroundColor: AppColors.accent,
    ));
  }

  Future<void> _setPRating(int value) async {
    final today = formatDate(DateTime.now());
    await setPRating(today, value);
    bumpDataChanged();
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() => _pRating = value);
      _flash('Saved p=$value for $today');
    }
  }

  Future<void> _setAlcoholYesterday(int value) async {
    if (_yesterdayKey.isEmpty) return;
    await setAlcoholRating(_yesterdayKey, value);
    // Verify the write actually landed in prefs. If readback != value,
    // the storage layer is lying about the write succeeding.
    final readback = await getAlcoholRating(_yesterdayKey);
    final allKeys = await debugCountFlexitKeys();
    final t = DateTime.now().toIso8601String().substring(11, 19);
    setLatestWriteDiagnostic(
        '$t wrote=$value readback=$readback keys=$allKeys ($_yesterdayKey)');
    bumpDataChanged();
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() => _alcoholYesterday = value);
      _flash(
          'wrote=$value readback=$readback keys=$allKeys for $_yesterdayKey');
    }
  }

  Future<void> _setBackPain(int value) async {
    final today = formatDate(DateTime.now());
    await setBackPainRating(today, value);
    bumpDataChanged();
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() => _backPain = value);
      _flash('Saved backpain=$value for $today');
    }
  }

  Future<void> _setWeightGrams(int? grams) async {
    final today = formatDate(DateTime.now());
    if (grams == null) {
      await clearWeight(today);
    } else {
      await setWeightGrams(today, grams);
    }
    bumpDataChanged();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _weightGrams = grams);
    // Visible confirmation so when this flow misbehaves we can see exactly
    // where: no snackbar = save never ran; snackbar without calendar fill =
    // calendar reload issue.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    if (grams == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Weight cleared'),
        duration: Duration(milliseconds: 800),
      ));
    } else {
      final shown = _weightUnit == 'kg'
          ? '${(grams / 1000).toStringAsFixed(1)} kg'
          : '${(grams / 453.59237).toStringAsFixed(1)} lb';
      messenger.showSnackBar(SnackBar(
        content: Text('Saved $shown'),
        duration: const Duration(milliseconds: 800),
      ));
    }
  }

  Future<void> _setWeightUnit(String unit) async {
    await setWeightUnit(unit);
    if (mounted) setState(() => _weightUnit = unit);
  }

  void _toggleWorkoutExpanded() {
    if (_done) return;
    setState(() => _workoutExpanded = !_workoutExpanded);
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
      // Stored in UTC so the timestamp reads correctly in any timezone.
      await saveSession(Session(
        date: today,
        completedAt: now.toUtc().toIso8601String(),
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
          // Order mirrors a typical day:
          //   1. drinks yesterday (logged on waking up)
          //   2. weight (post-toilet morning weigh-in)
          //   3. p (mood right now)
          //   4. exercises (the workout itself, with progress + week banner)
          //   5. back pain (logged after the session)
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _WeightCard(
                grams: _weightGrams,
                unit: _weightUnit,
                onChangeGrams: _setWeightGrams,
                onChangeUnit: _setWeightUnit,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _PRatingCard(
                value: _pRating,
                onSelect: _setPRating,
              ),
            ),
          ),
          // Whole exercise section folds into a single collapsible group —
          // header (and the done banner when finished) is the only thing
          // showing when collapsed; expanding reveals progress + week info +
          // the block list.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _WorkoutHeader(
                done: _done,
                expanded: _workoutExpanded && !_done,
                completedCount: completedCount,
                totalExercises: totalExercises,
                onTap: _toggleWorkoutExpanded,
              ),
            ),
          ),
          if (_workoutExpanded && !_done) ...[
            if (totalExercises > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completedCount / totalExercises,
                      backgroundColor: AppColors.cardBorder,
                      color: AppColors.accent,
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
          // Back pain after the workout — typically rated post-session.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: _BackPainCard(
                value: _backPain,
                onSelect: _setBackPain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockCard extends StatefulWidget {
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
  State<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<_BlockCard> {
  /// User tapped the block header to reveal its exercises. Forced back to
  /// `false` once every exercise in the block is done.
  bool _userExpanded = false;

  bool get _allDone => widget.block.exercises.every(
        (e) => e.atomicIds.every(widget.completedExercises.contains),
      );

  bool get _expanded => _userExpanded && !_allDone;

  int get _doneAtomicCount => widget.block.exercises.fold<int>(
      0,
      (sum, e) =>
          sum +
          e.atomicIds.where(widget.completedExercises.contains).length);

  int get _totalAtomicCount =>
      widget.block.exercises.fold<int>(0, (sum, e) => sum + e.atomicIds.length);

  @override
  void didUpdateWidget(covariant _BlockCard old) {
    super.didUpdateWidget(old);
    if (_allDone && _userExpanded) {
      // Defer to next frame so we don't mutate state during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _userExpanded = false);
      });
    }
  }

  void _toggleExpanded() {
    if (_allDone) return;
    setState(() => _userExpanded = !_userExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final allDone = _allDone;
    final expanded = _expanded;
    final done = _doneAtomicCount;
    final total = _totalAtomicCount;
    final accentColor = allDone ? AppColors.success : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: allDone
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  if (allDone)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          allDone
                              ? '${block.duration} · done'
                              : '${block.duration} · $done/$total done',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!allDone)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            ...block.exercises.map((e) => _ExerciseCard(
                  exercise: e,
                  completedExercises: widget.completedExercises,
                  timerSeconds: widget.timerSeconds,
                  repCounts: widget.repCounts,
                  onToggle: widget.onToggle,
                )),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
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
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  /// User has tapped the chevron / card to expand the body. Always overridden
  /// to `false` when the exercise is fully done — collapsed is the resting
  /// state when there's nothing to do.
  bool _userExpanded = false;

  bool get _isDone =>
      widget.exercise.atomicIds.every(widget.completedExercises.contains);

  bool get _isExpanded => _userExpanded && !_isDone;

  @override
  void didUpdateWidget(covariant _ExerciseCard old) {
    super.didUpdateWidget(old);
    // Auto-collapse when an exercise transitions to done.
    if (_isDone && _userExpanded) {
      // Defer to next frame so we don't mutate state mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _userExpanded = false);
      });
    }
  }

  void _toggleExpanded() {
    if (_isDone) return;
    setState(() => _userExpanded = !_userExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final completedExercises = widget.completedExercises;
    final onToggle = widget.onToggle;
    final atomicIds = exercise.atomicIds;
    final isDone = _isDone;
    final expanded = _isExpanded;
    final isMultiSet = exercise.sets > 1;
    final sides = exercise.sidesPerSet;
    final hasSides = sides > 1;
    final timer = exercise.timer;
    // Timer duration sources, in priority order: a user-configurable
    // TimerSpec, then a number parsed out of the duration label, then no
    // timer. Any value > 0 gets a tappable countdown button.
    final timerDuration = timer != null
        ? (widget.timerSeconds[timer.settingKey] ?? timer.defaultSeconds)
        : (exercise.parsedDurationSeconds ?? 0);
    final hasTimer = timerDuration > 0;
    final repsSpec = exercise.reps;
    final durationLabel = repsSpec != null
        ? '${exercise.sets} × ${widget.repCounts[repsSpec.settingKey] ?? repsSpec.defaultReps} reps'
        : exercise.duration;
    // Use the column-of-buttons layout whenever there are multiple sets OR a
    // timer is available — the timer button replaces the inline checkbox.
    final useColumnLayout = isMultiSet || hasTimer || hasSides;

    String labelFor(int setIdx, int sideIdx) {
      final hasSetLabel = isMultiSet;
      final hasSideLabel = hasSides;
      if (hasSetLabel && hasSideLabel) {
        return '${setIdx + 1}${sideIdx == 0 ? 'L' : 'R'}';
      }
      if (hasSetLabel) return '${setIdx + 1}';
      if (hasSideLabel) return sideIdx == 0 ? 'L' : 'R';
      return 'Go';
    }

    String notifBodyFor(int setIdx, int sideIdx) {
      final parts = <String>[exercise.name];
      if (isMultiSet) parts.add('set ${setIdx + 1}');
      if (hasSides) parts.add(sideIdx == 0 ? 'left side' : 'right side');
      parts.add('done');
      return parts.join(' · ');
    }

    return GestureDetector(
      // Single-set no-timer cards keep tap-to-mark-done (their buttons live
      // outside this widget); every other card toggles expanded on tap so the
      // whole row is an obvious target.
      onTap: useColumnLayout
          ? (isDone ? null : _toggleExpanded)
          : () => onToggle(exercise.id),
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
                        for (var s = 0;
                            s < (exercise.sets < 1 ? 1 : exercise.sets);
                            s++) ...[
                          if (s > 0) const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var k = 0; k < sides; k++) ...[
                                if (k > 0) const SizedBox(width: 4),
                                Builder(builder: (_) {
                                  final atomicId = atomicIds[s * sides + k];
                                  final label = labelFor(s, k);
                                  if (hasTimer) {
                                    return _TimerSetButton(
                                      key: ValueKey(
                                          '$atomicId@$timerDuration'),
                                      atomicId: atomicId,
                                      label: label,
                                      durationSeconds: timerDuration,
                                      notificationId: atomicId.hashCode,
                                      notificationBody: notifBodyFor(s, k),
                                      isDone:
                                          completedExercises.contains(atomicId),
                                      onComplete: () => onToggle(atomicId),
                                      onUndo: () => onToggle(atomicId),
                                    );
                                  }
                                  return _SetCheckbox(
                                    label: label,
                                    isDone:
                                        completedExercises.contains(atomicId),
                                    onTap: () => onToggle(atomicId),
                                  );
                                }),
                              ],
                            ],
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDone ? AppColors.success : AppColors.text,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.success,
                          ),
                        ),
                      ),
                      if (!isDone)
                        GestureDetector(
                          onTap: _toggleExpanded,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 0, 4),
                            child: Icon(
                              expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
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
                  if (expanded) ...[
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

class _WorkoutHeader extends StatelessWidget {
  final bool done;
  final bool expanded;
  final int completedCount;
  final int totalExercises;
  final VoidCallback onTap;

  const _WorkoutHeader({
    required this.done,
    required this.expanded,
    required this.completedCount,
    required this.totalExercises,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (done) {
      // Workout complete: a single tight banner replaces the entire section.
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(
              'All done for today',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    final subtitle = totalExercises > 0
        ? '$completedCount/$totalExercises done'
        : 'No exercises today';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.fitness_center,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S WORKOUT",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerSetButton extends StatefulWidget {
  final String atomicId;
  final String label;
  final int durationSeconds;
  final int notificationId;
  final String notificationBody;
  final bool isDone;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  const _TimerSetButton({
    super.key,
    required this.atomicId,
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
    _tryRestore();
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

  /// On mount, look up any in-flight end time persisted from a prior run.
  /// If it's in the future, resume ticking. If it's already past, fire
  /// completion (the notification has likely already shown).
  Future<void> _tryRestore() async {
    final end = await getTimerEnd(widget.atomicId);
    if (end == null) return;
    if (!mounted) return;
    if (!DateTime.now().isBefore(end)) {
      // Already elapsed while we were unmounted.
      await clearTimerEnd(widget.atomicId);
      TimerNotifications.instance.cancel(widget.notificationId);
      if (!mounted) return;
      if (!widget.isDone) {
        _fireCompletionCue();
        widget.onComplete();
      }
      return;
    }
    setState(() {
      _running = true;
      _endTime = end.toLocal();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkAndUpdate();
    });
  }

  void _checkAndUpdate() {
    if (!_running || _endTime == null) return;
    if (!DateTime.now().isBefore(_endTime!)) {
      _ticker?.cancel();
      TimerNotifications.instance.cancel(widget.notificationId);
      clearTimerEnd(widget.atomicId);
      setState(() {
        _running = false;
        _endTime = null;
      });
      _fireCompletionCue();
      widget.onComplete();
    } else {
      setState(() {});
    }
  }

  /// Distinctive multi-pulse cue so a foreground timer completion is
  /// noticeable even with the phone on silent. `vibrate()` is iOS's
  /// alarm-style buzz; the two `heavyImpact`s after it form a quick
  /// thump-thump rhythm. The background case is handled by the scheduled
  /// time-sensitive notification, which bypasses silent mode on iOS.
  void _fireCompletionCue() {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
    });
  }

  void _start() async {
    final end = DateTime.now().add(Duration(seconds: widget.durationSeconds));
    await setTimerEnd(widget.atomicId, end);
    if (!mounted) return;
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
    clearTimerEnd(widget.atomicId);
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
            color: selected
                ? AppColors.selectionRingOn(bg)
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.selectionHaloOn(bg),
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ]
              : null,
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

  /// Binary semantics: 0 = no drinks, 1 = drinks. Storage stays int-capable
  /// so legacy multi-level entries (2..4) still render on the calendar with
  /// their gradient color.
  static const _noDrinks = 0;
  static const _drinks = 1;

  @override
  Widget build(BuildContext context) {
    final selected = value;
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
          Text(
            'Drinks yesterday',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AlcoholBinaryButton(
                  label: 'No drinks',
                  selected: selected == _noDrinks,
                  fill: AppColors.alcoholColor(_noDrinks),
                  onTap: () => onSelect(_noDrinks),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AlcoholBinaryButton(
                  label: 'Drinks',
                  selected: selected != null && selected > 0,
                  fill: AppColors.alcoholColor(_drinks),
                  onTap: () => onSelect(_drinks),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlcoholBinaryButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color fill;
  final VoidCallback onTap;

  const _AlcoholBinaryButton({
    required this.label,
    required this.selected,
    required this.fill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 42,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.selectionRingOn(fill)
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.selectionHaloOn(fill),
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
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
            color: selected
                ? AppColors.selectionRingOn(fill)
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.selectionHaloOn(fill),
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ]
              : null,
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

class _WeightCard extends StatefulWidget {
  final int? grams;
  final String unit; // 'kg' or 'lb'
  final ValueChanged<int?> onChangeGrams;
  final ValueChanged<String> onChangeUnit;

  const _WeightCard({
    required this.grams,
    required this.unit,
    required this.onChangeGrams,
    required this.onChangeUnit,
  });

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayValue());
    _focusNode = FocusNode();
    // Commit whenever focus is lost — covers tapping the bottom-nav tab,
    // backgrounding the app, scrolling far enough that the field unmounts,
    // or any other "I'm done typing" path the TapRegion's onTapOutside
    // doesn't see.
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _WeightCard old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. unit toggle, or value set elsewhere).
    final next = _displayValue();
    if (_controller.text != next && !_focusNode.hasFocus) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    // Best-effort: if the user navigated away with the field still focused,
    // make sure their last typed value lands in storage.
    _commit(_controller.text);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _displayValue() {
    final g = widget.grams;
    if (g == null) return '';
    final v = widget.unit == 'kg' ? gramsToKg(g) : gramsToLb(g);
    return v.toStringAsFixed(1);
  }

  String _secondaryDisplay() {
    final g = widget.grams;
    if (g == null) return '';
    if (widget.unit == 'kg') {
      return '${gramsToLb(g).toStringAsFixed(1)} lb';
    }
    return '${gramsToKg(g).toStringAsFixed(1)} kg';
  }

  void _commit(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      widget.onChangeGrams(null);
      return;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    final grams = widget.unit == 'kg' ? kgToGrams(parsed) : lbToGrams(parsed);
    widget.onChangeGrams(grams);
  }

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
                'Weight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              _UnitToggle(
                unit: widget.unit,
                onChanged: widget.onChangeUnit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    isDense: true,
                    border: InputBorder.none,
                    suffixText: widget.unit,
                    suffixStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Commit on every keystroke so the prefs write is in
                  // flight long before any tab-tap reload races with it.
                  onChanged: _commit,
                  onSubmitted: _commit,
                  onTapOutside: (_) {
                    _focusNode.unfocus();
                  },
                ),
              ),
              if (widget.grams != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _secondaryDisplay(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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

class _UnitToggle extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onChanged;

  const _UnitToggle({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String value) {
      final selected = unit == value;
      return GestureDetector(
        onTap: selected ? null : () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [chip('kg'), const SizedBox(width: 2), chip('lb')],
      ),
    );
  }
}

