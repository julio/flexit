import 'package:flutter/material.dart';
import '../data/storage.dart';
import '../models/session.dart';
import '../theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Session> _sessions = [];
  DateTime _focusedMonth = DateTime.now();
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await getSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

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
      appBar: AppBar(title: const Text('Calendar')),
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
          const SizedBox(height: 20),

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
                        style: const TextStyle(
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
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: const TextStyle(
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
            Container(
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
                    _formatDisplayDate(_selectedDate!),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (selectedSession != null)
                    Text(
                      'Completed at ${_formatTime(selectedSession.completedAt)} \u00b7 ${selectedSession.type == 'weekend' ? 'Weekend deep session' : 'Daily 15'}',
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 13),
                    )
                  else if (_selectedDate == today)
                    const Text(
                      'In progress',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    )
                  else
                    const Text(
                      'Missed',
                      style:
                          TextStyle(color: AppColors.missed, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text(
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
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
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
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.type == 'weekend'
                                ? 'Weekend deep session'
                                : 'Daily 15',
                            style: const TextStyle(
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
                            style: const TextStyle(
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
    final startWeekday = firstOfMonth.weekday - 1;

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

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = dateStr),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppColors.accent, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isToday || isCompleted ? FontWeight.w700 : FontWeight.w400,
                    color: isCompleted
                        ? AppColors.success
                        : isMissed
                            ? AppColors.missed
                            : isToday
                                ? AppColors.accent
                                : isFuture
                                    ? AppColors.textMuted
                                    : AppColors.text,
                  ),
                ),
                const SizedBox(height: 1),
                if (isCompleted)
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 14)
                else if (isMissed)
                  const Icon(Icons.cancel, color: AppColors.missed, size: 14)
                else if (isToday)
                  Icon(Icons.radio_button_unchecked,
                      color: AppColors.accent.withValues(alpha: 0.6), size: 14)
                else
                  const SizedBox(height: 14),
              ],
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
              style: const TextStyle(
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
