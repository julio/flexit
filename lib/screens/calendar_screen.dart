import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../main.dart' show dataChangedCounter, bumpDataChanged;
import '../models/exercise.dart';
import '../models/session.dart';
import '../theme.dart';
import 'settings_screen.dart';
import 'weight_chart_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  List<Session> _sessions = [];
  Map<String, Set<String>> _exercisesByDate = {};
  Map<String, int> _pRatings = {};
  Map<String, int> _alcoholRatings = {};
  Map<String, int> _backPainRatings = {};
  Map<String, int> _weightGrams = {};
  String _weightUnit = 'kg';
  String _measurement = calendarMeasurements.first;
  Routine _routine = routines.first;
  DateTime? _programStart;
  DateTime _focusedMonth = DateTime.now();
  String? _selectedDate;
  Set<String> _selectedDateExercises = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // When the Today screen (or anywhere else) bumps the counter after a
    // save, re-read all the data so the calendar grid reflects it. No need
    // to wait for a tab tap.
    dataChangedCounter.addListener(_loadSessions);
  }

  @override
  void dispose() {
    dataChangedCounter.removeListener(_loadSessions);
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await getSessions();
    final exercisesByDate = await getAllCompletedExercises();
    final pRatings = await getAllPRatings();
    final alcoholRatings = await getAllAlcoholRatings();
    final backPainRatings = await getAllBackPainRatings();
    final weightGrams = await getAllWeightGrams();
    final weightUnit = await getWeightUnit();
    final measurement = await getCalendarMeasurement();
    final routineId = await getActiveRoutineId();
    final routine = routineById(routineId);
    final programStart =
        routine.hasProgram ? await getProgramStartDate(routine.id) : null;
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _exercisesByDate = exercisesByDate;
        _pRatings = pRatings;
        _alcoholRatings = alcoholRatings;
        _backPainRatings = backPainRatings;
        _weightGrams = weightGrams;
        _weightUnit = weightUnit;
        _measurement = measurement;
        _routine = routine;
        _programStart = programStart;
      });
      // Diagnostic — tells us at the moment of reload exactly what the
      // calendar pulled out of prefs for today's weight.
      final todayStr = formatDate(DateTime.now());
      final g = weightGrams[todayStr];
      final shown = g == null
          ? '—'
          : (weightUnit == 'kg'
              ? '${(g / 1000).toStringAsFixed(1)} kg'
              : '${(g / 453.59237).toStringAsFixed(1)} lb');
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
        content: Text(
            'Reload · ${weightGrams.length} weights · today: $shown'),
        duration: const Duration(milliseconds: 1500),
      ));
    }
  }

  /// Resolves the block list (and atomic IDs) that applies for [dateStr] given
  /// the active routine. For program-based routines this picks the right week;
  /// for fixed routines it just returns the routine's blocks.
  List<ExerciseBlock> _blocksForDate(String dateStr) {
    if (!_routine.hasProgram || _programStart == null) {
      return _routine.blocks;
    }
    final date = DateTime.parse(dateStr);
    final sessionDates = _sessions.map((s) => s.date).toSet();
    final week = _routine.program!
        .currentWeek(_programStart!, date, sessionDates);
    return _routine.program!.blocksForWeek(week);
  }

  Future<void> _cycleMeasurement(int delta) async {
    final i = calendarMeasurements.indexOf(_measurement);
    final next = calendarMeasurements[
        (i + delta + calendarMeasurements.length) %
            calendarMeasurements.length];
    setState(() => _measurement = next);
    await setCalendarMeasurement(next);
  }

  Future<void> _selectDate(String dateStr) async {
    final exercises = await getCompletedExercises(dateStr);
    if (mounted) {
      setState(() {
        _selectedDate = dateStr;
        _selectedDateExercises = exercises;
      });
    }
  }

  Future<void> _setSelectedPRating(int value) async {
    final date = _selectedDate;
    if (date == null) return;
    await setPRating(date, value);
    bumpDataChanged();
    if (mounted) {
      setState(() => _pRatings = {..._pRatings, date: value});
    }
  }

  Future<void> _setSelectedAlcohol(int value) async {
    final date = _selectedDate;
    if (date == null) return;
    await setAlcoholRating(date, value);
    bumpDataChanged();
    if (mounted) {
      setState(() => _alcoholRatings = {..._alcoholRatings, date: value});
    }
  }

  Future<void> _setSelectedBackPain(int value) async {
    final date = _selectedDate;
    if (date == null) return;
    await setBackPainRating(date, value);
    bumpDataChanged();
    if (mounted) {
      setState(() => _backPainRatings = {..._backPainRatings, date: value});
    }
  }

  Future<void> _setSelectedWeight(int? grams) async {
    final date = _selectedDate;
    if (date == null) return;
    if (grams == null) {
      await clearWeight(date);
      if (mounted) {
        setState(() => _weightGrams = {..._weightGrams}..remove(date));
      }
    } else {
      await setWeightGrams(date, grams);
      if (mounted) {
        setState(() => _weightGrams = {..._weightGrams, date: grams});
      }
    }
    bumpDataChanged();
  }

  /// Long-press shortcut on a day cell: pop a sheet with just the value
  /// selector for the currently-active measurement.
  Future<void> _quickEditForDate(String dateStr) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setSheetState) {
            Widget body;
            switch (_measurement) {
              case 'p':
                body = _CompactPRating(
                  value: _pRatings[dateStr],
                  onSelect: (v) async {
                    await setPRating(dateStr, v);
                    setSheetState(() {});
                    setState(() => _pRatings = {..._pRatings, dateStr: v});
                  },
                );
                break;
              case 'drinks':
                body = _CompactAlcohol(
                  value: _alcoholRatings[dateStr],
                  onSelect: (v) async {
                    await setAlcoholRating(dateStr, v);
                    setSheetState(() {});
                    setState(() =>
                        _alcoholRatings = {..._alcoholRatings, dateStr: v});
                  },
                );
                break;
              case 'backpain':
                body = _CompactBackPain(
                  value: _backPainRatings[dateStr],
                  onSelect: (v) async {
                    await setBackPainRating(dateStr, v);
                    setSheetState(() {});
                    setState(() =>
                        _backPainRatings = {..._backPainRatings, dateStr: v});
                  },
                );
                break;
              case 'weight':
                body = _CompactWeight(
                  grams: _weightGrams[dateStr],
                  unit: _weightUnit,
                  onChange: (g) async {
                    if (g == null) {
                      await clearWeight(dateStr);
                    } else {
                      await setWeightGrams(dateStr, g);
                    }
                    setSheetState(() {});
                    setState(() {
                      final next = {..._weightGrams};
                      if (g == null) {
                        next.remove(dateStr);
                      } else {
                        next[dateStr] = g;
                      }
                      _weightGrams = next;
                    });
                  },
                );
                break;
              default:
                body = const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20 + MediaQuery.of(innerCtx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    _formatDisplayDate(dateStr),
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  body,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleSelectedExercise(Exercise exercise) async {
    final date = _selectedDate;
    if (date == null) return;
    final next = {..._selectedDateExercises};
    final atomicIds = exercise.atomicIds.toSet();
    final alreadyAllDone = atomicIds.every(next.contains);
    if (alreadyAllDone) {
      next.removeAll(atomicIds);
    } else {
      next.addAll(atomicIds);
    }
    await saveCompletedExercises(date, next);
    await _reconcileSession(date, next);
    if (mounted) {
      final sessions = await getSessions();
      setState(() {
        _sessions = sessions;
        _selectedDateExercises = next;
        if (next.isEmpty) {
          _exercisesByDate = {..._exercisesByDate}..remove(date);
        } else {
          _exercisesByDate = {..._exercisesByDate, date: next};
        }
      });
    }
  }

  /// Save or remove a "retroactive" session for [date] based on whether every
  /// atomic set is checked. A retroactive session is one we created here (no
  /// startedAt); we never touch real sessions that have a startedAt timestamp.
  Future<void> _reconcileSession(String date, Set<String> done) async {
    final validAtomicIds = _blocksForDate(date)
        .expand((b) => b.exercises)
        .expand((e) => e.atomicIds)
        .toSet();
    final allDone = validAtomicIds.isNotEmpty &&
        validAtomicIds.every(done.contains);
    final existing = _sessions.where((s) => s.date == date).firstOrNull;
    final isRetroactive = existing != null && existing.startedAt == null;

    if (allDone && existing == null) {
      await saveSession(Session(
        date: date,
        // Local-noon-on-date, stored as UTC so the display reads as 12:00 PM
        // in whatever timezone the user reads it from.
        completedAt:
            DateTime.parse('${date}T12:00:00').toUtc().toIso8601String(),
        type: 'daily',
      ));
    } else if (!allDone && isRetroactive) {
      await removeSession(date);
    }
  }

  void reload() => _loadSessions();

  @override
  Widget build(BuildContext context) {
    final currentStreak = getCurrentStreak(_sessions);
    final longestStreak = getLongestStreak(_sessions);
    final totalSessions = _sessions.length;
    final sessionDates = _sessions.map((s) => s.date).toSet();
    final today = formatDate(DateTime.now());

    final selectedSession = _selectedDate != null
        ? _sessions.where((s) => s.date == _selectedDate).firstOrNull
        : null;

    final recentSessions = [..._sessions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadSessions();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Stats row
          Row(
            children: [
              _StatBox(
                  label: 'Current\nStreak',
                  value: '$currentStreak',
                  accent: true),
              const SizedBox(width: 10),
              _StatBox(label: 'Longest\nStreak', value: '$longestStreak'),
              const SizedBox(width: 10),
              _StatBox(label: 'Total\nSessions', value: '$totalSessions'),
            ],
          ),
          const SizedBox(height: 16),

          // Measurement switcher — tap or swipe the pill to cycle through
          // completion / p / drinks / back pain. Only one is rendered on the
          // grid at a time.
          _MeasurementPill(
            measurement: _measurement,
            onPrev: () => _cycleMeasurement(-1),
            onNext: () => _cycleMeasurement(1),
          ),
          if (_measurement == 'weight') ...[
            const SizedBox(height: 8),
            // Inline diagnostic: shows exactly what the calendar has in its
            // weight map, including today's lookup. If you save 75.5 on Today
            // and this still reads "today: —", the calendar isn't picking up
            // the save (reload race / state issue). If this reads the right
            // value but the cell still doesn't fill, it's a render bug.
            Builder(builder: (_) {
              final todayStr = formatDate(DateTime.now());
              final g = _weightGrams[todayStr];
              final shown = g == null
                  ? '—'
                  : (_weightUnit == 'kg'
                      ? '${(g / 1000).toStringAsFixed(1)} kg'
                      : '${(g / 453.59237).toStringAsFixed(1)} lb');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'debug · ${_weightGrams.length} entries · today: $shown',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              );
            }),
          ],
          if (_measurement == 'weight' && _weightGrams.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WeightChartScreen(
                      weights: _weightGrams,
                      unit: _weightUnit,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart,
                        color: AppColors.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'View evolution chart',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Calendar
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                // Month header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: AppColors.accent),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                                _focusedMonth.year, _focusedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        _monthName(_focusedMonth),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: AppColors.accent),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                                _focusedMonth.year, _focusedMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Day of week headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                _buildCalendarGrid(sessionDates, today),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Selected date detail
          if (_selectedDate != null) ...[
            const SizedBox(height: 12),
            _buildSelectedDateDetail(
              selectedSession: selectedSession,
              isToday: _selectedDate == today,
              sessionDates: sessionDates,
            ),
          ],

          const SizedBox(height: 24),
          Text(
            'RECENT SESSIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          if (recentSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No sessions yet. Complete your first workout!',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            ...recentSessions.take(10).map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDisplayDate(s.date),
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              s.type == 'weekend'
                                  ? 'Weekend deep session'
                                  : _routine.title,
                              if (s.duration != null)
                                _formatDuration(s.duration!),
                            ].join(' · '),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _formatTime(s.completedAt),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Set<String> sessionDates, String today) {
    final firstOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // Dart: Mon=1..Sun=7. We want Sun=0..Sat=6 so weeks start on Sunday.
    final startWeekday = firstOfMonth.weekday % 7;

    final sortedSessionDates = sessionDates.toList()..sort();
    final firstSessionDate =
        sortedSessionDates.isNotEmpty ? sortedSessionDates.first : null;

    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dateStr = formatDate(date);
      final isCompleted = sessionDates.contains(dateStr);
      final isToday = dateStr == today;
      final isSelected = dateStr == _selectedDate;
      final isFuture = date.isAfter(DateTime.now());
      final isTrackedDay = !isFuture &&
          firstSessionDate != null &&
          dateStr.compareTo(firstSessionDate) >= 0;

      // Completion ratio for the gradient: 1.0 means a full session for the
      // day, 0.0 means nothing logged. Days before the user's first session
      // and future days don't get a ratio (no fill).
      double? completionRatio;
      if (isTrackedDay) {
        if (isCompleted) {
          completionRatio = 1.0;
        } else {
          final validAtomicIds = _blocksForDate(dateStr)
              .expand((b) => b.exercises)
              .expand((e) => e.atomicIds)
              .toSet();
          final saved = _exercisesByDate[dateStr] ?? <String>{};
          final done = saved.intersection(validAtomicIds).length;
          final total = validAtomicIds.length;
          completionRatio = total > 0 ? done / total : 0.0;
        }
      }

      // Pick a fill color for the cell based on the active measurement.
      // Every measurement now paints the cell — completion uses the same
      // treatment as p / drinks / back pain so the visual language matches.
      // Weight has no natural heatmap; we replace the day number with the
      // weight value as the cell content instead.
      Color? cellFill;
      String? weightLabel;
      switch (_measurement) {
        case 'completion':
          // Continuous gradient: red (0% done) → green (100%). Applied
          // retroactively to past days based on the saved exercise set.
          if (completionRatio != null) {
            cellFill = Color.lerp(
                AppColors.missed, AppColors.success, completionRatio)!;
          }
          break;
        case 'p':
          final pv = _pRatings[dateStr];
          if (pv != null) cellFill = AppColors.pColor(pv);
          break;
        case 'drinks':
          // Binary fill: any non-zero value = drank (red); 0 = didn't drink
          // (white); null/missing = empty cell. Legacy multi-level entries
          // (2..4 from the old scale) collapse to red here.
          final av = _alcoholRatings[dateStr];
          if (av != null) {
            cellFill = av > 0 ? AppColors.missed : Colors.white;
          }
          break;
        case 'backpain':
          final bv = _backPainRatings[dateStr];
          if (bv != null) cellFill = AppColors.backPainColor(bv);
          break;
        case 'weight':
          final g = _weightGrams[dateStr];
          if (g != null) {
            final v = _weightUnit == 'kg' ? gramsToKg(g) : gramsToLb(g);
            weightLabel = v.toStringAsFixed(1);
            cellFill = AppColors.accent.withValues(alpha: 0.25);
          }
          break;
      }

      final Color dayColor;
      if (cellFill != null) {
        // Painted cell: pick legible text for the fill brightness.
        dayColor = ThemeData.estimateBrightnessForColor(cellFill) ==
                Brightness.dark
            ? Colors.white
            : Colors.black87;
      } else if (isFuture) {
        dayColor = AppColors.textMuted;
      } else {
        dayColor = isToday ? AppColors.accent : AppColors.text;
      }
      final boldDay = isToday || (cellFill != null);
      final cellText = weightLabel ?? '$day';
      final cellFontSize = weightLabel != null ? 12.0 : 14.0;

      cells.add(
        GestureDetector(
          onTap: () => _selectDate(dateStr),
          // Long-press jumps straight to the value editor for the active
          // measurement (no need to open the full past-day editor). Disabled
          // for completion (use tap → per-exercise toggles instead) and for
          // future days.
          onLongPress: (_measurement == 'completion' || isFuture)
              ? null
              : () => _quickEditForDate(dateStr),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: cellFill,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppColors.accent, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              cellText,
              style: TextStyle(
                fontSize: cellFontSize,
                fontWeight: boldDay ? FontWeight.w700 : FontWeight.w400,
                color: dayColor,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        children: cells,
      ),
    );
  }

  Widget _buildSelectedDateDetail({
    required Session? selectedSession,
    required bool isToday,
    required Set<String> sessionDates,
  }) {
    final date = _selectedDate!;
    final isFuture = DateTime.parse(date).isAfter(DateTime.now());
    final editable = !isToday && !isFuture;
    final allExercises =
        _blocksForDate(date).expand((b) => b.exercises).toList();
    // Use atomicIds.length, not e.sets — per-side exercises produce more
    // atomic IDs than they have "sets" (e.g. sets=2 sides=2 → 4 atomic IDs),
    // so summing e.sets undercounts the denominator and would let the day
    // read "40/35 done" when fully completed.
    final totalAtomic = allExercises.fold<int>(
        0, (sum, e) => sum + e.atomicIds.length);
    final completedCount = allExercises.fold<int>(
        0,
        (sum, e) =>
            sum +
            e.atomicIds.where(_selectedDateExercises.contains).length);
    final hasExerciseData = _selectedDateExercises.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDisplayDate(date),
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (selectedSession != null)
            Text(
              [
                'Completed at ${_formatTime(selectedSession.completedAt)}',
                selectedSession.type == 'weekend'
                    ? 'Weekend deep session'
                    : _routine.title,
                if (selectedSession.duration != null)
                  'took ${_formatDuration(selectedSession.duration!)}',
              ].join(' · '),
              style: TextStyle(color: AppColors.success, fontSize: 13),
            )
          else if (isToday)
            Text(
              hasExerciseData
                  ? 'In progress · $completedCount/$totalAtomic done'
                  : 'In progress',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else if (isFuture)
            Builder(builder: (_) {
              final parts = <String>['Upcoming'];
              if (_routine.hasProgram && _programStart != null) {
                final sessionDates = _sessions.map((s) => s.date).toSet();
                final week = _routine.program!.currentWeek(
                    _programStart!, DateTime.parse(date), sessionDates);
                final wp = _routine.program!.weekProgram(week);
                parts.add('Week $week · ${wp.phase}');
                parts.add('Walk: ${wp.walkingTarget}');
              }
              return Text(
                parts.join(' · '),
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
              );
            })
          else
            Text(
              hasExerciseData
                  ? 'Missed · $completedCount/$totalAtomic done'
                  : 'Missed',
              style: TextStyle(color: AppColors.missed, fontSize: 13),
            ),
          if (editable) ...[
            const SizedBox(height: 14),
            _CompactPRating(
              value: _pRatings[date],
              onSelect: _setSelectedPRating,
            ),
            const SizedBox(height: 10),
            _CompactAlcohol(
              value: _alcoholRatings[date],
              onSelect: _setSelectedAlcohol,
            ),
            const SizedBox(height: 10),
            _CompactBackPain(
              value: _backPainRatings[date],
              onSelect: _setSelectedBackPain,
            ),
            const SizedBox(height: 10),
            _CompactWeight(
              grams: _weightGrams[date],
              unit: _weightUnit,
              onChange: _setSelectedWeight,
            ),
          ],
          if (editable || hasExerciseData || isFuture) ...[
            const SizedBox(height: 12),
            ...allExercises.map((e) {
              final atomicCount = e.atomicIds.length;
              final doneUnits =
                  e.atomicIds.where(_selectedDateExercises.contains).length;
              final done = doneUnits == atomicCount;
              final partial = doneUnits > 0 && !done;
              // Per-side exercises have more atomic IDs than sets (e.g. sets=2
              // sides=2 → 4 units), so we compare against atomicIds.length
              // rather than e.sets — otherwise a fully completed multi-side
              // exercise would forever read as "partial".
              final trailing = atomicCount > 1
                  ? '$doneUnits/$atomicCount'
                  : e.duration;
              final stateColor = done
                  ? AppColors.success
                  : partial
                      ? AppColors.warning
                      : AppColors.missed;
              final row = Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle
                          : partial
                              ? Icons.adjust
                              : Icons.cancel,
                      color: stateColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: stateColor,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.success,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: TextStyle(
                        fontSize: 11,
                        color: done
                            ? AppColors.success.withValues(alpha: 0.6)
                            : stateColor,
                      ),
                    ),
                  ],
                ),
              );
              if (!editable) return row;
              return InkWell(
                onTap: () => _toggleSelectedExercise(e),
                borderRadius: BorderRadius.circular(8),
                child: row,
              );
            }),
          ],
        ],
      ),
    );
  }

  String _monthName(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _formatDisplayDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String _formatTime(String isoString) {
    // `DateTime.parse` keeps UTC strings (with `Z`) in UTC and treats
    // unsuffixed strings as local. `toLocal()` then renders both in the
    // user's *current* timezone — so a session done at 10 PM PDT shows as
    // 6 AM (the next day) when viewed in Lisbon.
    final d = DateTime.parse(isoString).toLocal();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:${d.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}

class _CompactPRating extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _CompactPRating({required this.value, required this.onSelect});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'P',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (value != null)
              Text(
                _labels[value]!,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final v in _options) ...[
              if (v != _options.first) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.pColor(v),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == v
                            ? AppColors.selectionRingOn(AppColors.pColor(v))
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: value == v
                          ? [
                              BoxShadow(
                                color: AppColors.selectionHaloOn(
                                    AppColors.pColor(v)),
                                spreadRadius: 2,
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      v > 0 ? '+$v' : '$v',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompactAlcohol extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _CompactAlcohol({required this.value, required this.onSelect});

  // Binary: 0 (no drinks) or 1 (drinks). Storage stays int-capable so legacy
  // multi-level entries still render on the calendar with their gradient.

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int target, {required bool selected}) {
      final fill = AppColors.alcoholColor(target);
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(target),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
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
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRINKS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            chip('No drinks', 0, selected: value == 0),
            const SizedBox(width: 6),
            chip('Drinks', 1, selected: value != null && value! > 0),
          ],
        ),
      ],
    );
  }
}

class _MeasurementPill extends StatelessWidget {
  final String measurement;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MeasurementPill({
    required this.measurement,
    required this.onPrev,
    required this.onNext,
  });

  static const _labels = {
    'completion': 'Completion',
    'p': 'p rating',
    'drinks': 'Drinks',
    'backpain': 'Back pain',
    'weight': 'Weight',
  };

  static const _icons = {
    'completion': Icons.check_circle_outline,
    'p': Icons.local_fire_department_outlined,
    'drinks': Icons.local_bar_outlined,
    'backpain': Icons.healing_outlined,
    'weight': Icons.monitor_weight_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -250) {
          onNext();
        } else if (v > 250) {
          onPrev();
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: AppColors.accent),
              tooltip: 'Previous',
              onPressed: onPrev,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icons[measurement] ?? Icons.circle_outlined,
                      color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _labels[measurement] ?? measurement,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: AppColors.accent),
              tooltip: 'Next',
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactBackPain extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;

  const _CompactBackPain({required this.value, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BACK PAIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (value != null)
              Text(
                '${value!}',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var v = 0; v <= 10; v++) ...[
              if (v != 0) const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.backPainColor(v),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: value == v
                            ? AppColors.selectionRingOn(
                                AppColors.backPainColor(v))
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: value == v
                          ? [
                              BoxShadow(
                                color: AppColors.selectionHaloOn(
                                    AppColors.backPainColor(v)),
                                spreadRadius: 2,
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompactWeight extends StatefulWidget {
  final int? grams;
  final String unit;
  final ValueChanged<int?> onChange;

  const _CompactWeight({
    required this.grams,
    required this.unit,
    required this.onChange,
  });

  @override
  State<_CompactWeight> createState() => _CompactWeightState();
}

class _CompactWeightState extends State<_CompactWeight> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _display());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _CompactWeight old) {
    super.didUpdateWidget(old);
    final next = _display();
    if (_controller.text != next && !_focusNode.hasFocus) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _commit(_controller.text);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _display() {
    final g = widget.grams;
    if (g == null) return '';
    final v = widget.unit == 'kg' ? gramsToKg(g) : gramsToLb(g);
    return v.toStringAsFixed(1);
  }

  void _commit(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      widget.onChange(null);
      return;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    final grams =
        widget.unit == 'kg' ? kgToGrams(parsed) : lbToGrams(parsed);
    widget.onChange(grams);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grams;
    final secondary = g == null
        ? ''
        : (widget.unit == 'kg'
            ? '${gramsToLb(g).toStringAsFixed(1)} lb'
            : '${gramsToKg(g).toStringAsFixed(1)} kg');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WEIGHT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (g != null)
              Text(
                secondary,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: _commit,
            onSubmitted: _commit,
            onTapOutside: (_) {
              _focusNode.unfocus();
            },
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StatBox(
      {required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent ? AppColors.accentDim : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: accent
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: accent ? AppColors.accent : AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
