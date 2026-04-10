import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/exercises.dart';
import '../data/storage.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final done = await isTodayComplete();
    final sessions = await getSessions();
    final completed = await getTodayCompletedExercises();
    if (mounted) {
      setState(() {
        _done = done;
        _streak = getCurrentStreak(sessions);
        _completedExercises = completed;
        _loading = false;
      });
    }
  }

  Future<void> _toggleExercise(String exerciseId) async {
    final updated = Set<String>.from(_completedExercises);
    if (updated.contains(exerciseId)) {
      updated.remove(exerciseId);
    } else {
      updated.add(exerciseId);
      HapticFeedback.mediumImpact();
    }

    await saveTodayCompletedExercises(updated);
    setState(() => _completedExercises = updated);

    // Auto check-out when all exercises are done
    if (!_done) {
      final blocks = getTodayBlocks();
      final allIds = blocks.expand((b) => b.exercises).map((e) => e.id).toSet();
      if (allIds.difference(updated).isEmpty) {
        await _doCheckOut();
      }
    }
  }

  Future<void> _doCheckOut() async {
    final today = formatDate(DateTime.now());
    await saveSession(Session(
      date: today,
      completedAt: DateTime.now().toIso8601String(),
      type: isWeekendDay() ? 'weekend' : 'daily',
    ));
    HapticFeedback.heavyImpact();
    await _loadState();
  }

  Future<void> _checkOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Check Out',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: const Text("Mark today's session as complete?",
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Done!',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _doCheckOut();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = getTodayBlocks();
    final isWeekend = isWeekendDay();
    final totalExercises =
        blocks.fold<int>(0, (sum, b) => sum + b.exercises.length);
    final completedCount = _completedExercises.length;

    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: _streak > 0 ? 140 : 120,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWeekend ? 'Weekend Deep Session' : 'Daily 15',
                          style: const TextStyle(
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
                            Text(
                              ' \u00b7 ${isWeekend ? "~25 min" : "~15 min"}',
                              style: const TextStyle(
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
              if (!_done && totalExercises > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completedCount / totalExercises,
                        backgroundColor: AppColors.cardBorder,
                        color: completedCount == totalExercises
                            ? AppColors.success
                            : AppColors.accent,
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
                            color:
                                AppColors.success.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        "Today's session complete",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _BlockCard(
                      block: blocks[index],
                      completedExercises: _completedExercises,
                      onToggle: _toggleExercise,
                    ),
                    childCount: blocks.length,
                  ),
                ),
              ),
            ],
          ),
          if (!_done)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: GestureDetector(
                onTap: _checkOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Check Out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
  final ValueChanged<String> onToggle;

  const _BlockCard({
    required this.block,
    required this.completedExercises,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final blockDoneCount =
        block.exercises.where((e) => completedExercises.contains(e.id)).length;
    final allDone = blockDoneCount == block.exercises.length;

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
                isDone: completedExercises.contains(e.id),
                onToggle: () => onToggle(e.id),
              )),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isDone;
  final VoidCallback onToggle;

  const _ExerciseCard({
    required this.exercise,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
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
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
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
