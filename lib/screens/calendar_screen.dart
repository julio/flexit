import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../theme.dart';
import 'settings_screen.dart';

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
  String _measurement = calendarMeasurements.first;
  DateTime _focusedMonth = DateTime.now();
  String? _selectedDate;
  Set<String> _selectedDateExercises = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await getSessions();
    final exercisesByDate = await getAllCompletedExercises();
    final pRatings = await getAllPRatings();
    final alcoholRatings = await getAllAlcoholRatings();
    final backPainRatings = await getAllBackPainRatings();
    final measurement = await getCalendarMeasurement();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _exercisesByDate = exercisesByDate;
        _pRatings = pRatings;
        _alcoholRatings = alcoholRatings;
        _backPainRatings = backPainRatings;
        _measurement = measurement;
      });
    }
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
    if (mounted) {
      setState(() => _pRatings = {..._pRatings, date: value});
    }
  }

  Future<void> _setSelectedAlcohol(int value) async {
    final date = _selectedDate;
    if (date == null) return;
    await setAlcoholRating(date, value);
    if (mounted) {
      setState(() => _alcoholRatings = {..._alcoholRatings, date: value});
    }
  }

  Future<void> _setSelectedBackPain(int value) async {
    final date = _selectedDate;
    if (date == null) return;
    await setBackPainRating(date, value);
    if (mounted) {
      setState(() => _backPainRatings = {..._backPainRatings, date: value});
    }
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
    final validAtomicIds = dailyBlocks
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
        completedAt: DateTime.parse('${date}T12:00:00').toIso8601String(),
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
                                  : 'Daily 30',
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
      final isMissed = !isCompleted &&
          !isFuture &&
          !isToday &&
          firstSessionDate != null &&
          dateStr.compareTo(firstSessionDate) >= 0;

      var isPartial = false;
      if ((isMissed || isToday) && !isCompleted) {
        final validAtomicIds = dailyBlocks
            .expand((b) => b.exercises)
            .expand((e) => e.atomicIds)
            .toSet();
        final saved = _exercisesByDate[dateStr] ?? <String>{};
        final done = saved.intersection(validAtomicIds).length;
        final total = validAtomicIds.length;
        isPartial = total > 0 && done * 2 >= total;
      }

      // Pick a fill color for the cell based on the active measurement.
      // Every measurement now paints the cell — completion uses the same
      // treatment as p / drinks / back pain so the visual language matches.
      Color? cellFill;
      switch (_measurement) {
        case 'completion':
          if (isCompleted) {
            cellFill = AppColors.success;
          } else if (isPartial) {
            cellFill = AppColors.warning;
          } else if (isMissed) {
            cellFill = AppColors.missed;
          } else if (isToday) {
            cellFill = AppColors.accent;
          }
          break;
        case 'p':
          final pv = _pRatings[dateStr];
          if (pv != null) cellFill = AppColors.pColor(pv);
          break;
        case 'drinks':
          final av = _alcoholRatings[dateStr];
          if (av != null && av > 0) cellFill = AppColors.alcoholColor(av);
          break;
        case 'backpain':
          final bv = _backPainRatings[dateStr];
          if (bv != null) cellFill = AppColors.backPainColor(bv);
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
              '$day',
              style: TextStyle(
                fontSize: 14,
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
    final allExercises = dailyBlocks.expand((b) => b.exercises).toList();
    final totalAtomic =
        allExercises.fold<int>(0, (sum, e) => sum + e.sets);
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
                    : 'Daily 30',
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
            Text(
              'Future',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
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
          ],
          if (editable || hasExerciseData) ...[
            const SizedBox(height: 12),
            ...allExercises.map((e) {
              final doneSets =
                  e.atomicIds.where(_selectedDateExercises.contains).length;
              final done = doneSets == e.sets;
              final partial = doneSets > 0 && !done;
              final trailing = e.sets > 1
                  ? '$doneSets/${e.sets} sets'
                  : e.duration;
              final row = Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle
                          : partial
                              ? Icons.adjust
                              : Icons.radio_button_unchecked,
                      color: done
                          ? AppColors.success
                          : partial
                              ? AppColors.warning
                              : AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: done
                              ? AppColors.success
                              : partial
                                  ? AppColors.warning
                                  : AppColors.textMuted,
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
                            : partial
                                ? AppColors.warning
                                : AppColors.textMuted,
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
    final d = DateTime.parse(isoString);
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
                        color: value == v ? AppColors.text : Colors.transparent,
                        width: 2,
                      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      color: AppColors.alcoholColor(v) ?? AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == v ? AppColors.text : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v',
                      style: TextStyle(
                        color: v == 0
                            ? AppColors.textSecondary
                            : Colors.black87,
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
  };

  static const _icons = {
    'completion': Icons.check_circle_outline,
    'p': Icons.local_fire_department_outlined,
    'drinks': Icons.local_bar_outlined,
    'backpain': Icons.healing_outlined,
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
                        color: value == v ? AppColors.text : Colors.transparent,
                        width: 2,
                      ),
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
