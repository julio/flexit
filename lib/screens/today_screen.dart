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

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final done = await isTodayComplete();
    final sessions = await getSessions();
    if (mounted) {
      setState(() {
        _done = done;
        _streak = getCurrentStreak(sessions);
        _loading = false;
      });
    }
  }

  Future<void> _checkOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Check Out',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: const Text("Mark today's session as complete?",
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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

    final today = formatDate(DateTime.now());
    await saveSession(Session(
      date: today,
      completedAt: DateTime.now().toIso8601String(),
      type: isWeekendDay() ? 'weekend' : 'daily',
    ));
    HapticFeedback.heavyImpact();
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = getTodayBlocks();
    final isWeekend = isWeekendDay();
    final totalExercises =
        blocks.fold<int>(0, (sum, b) => sum + b.exercises.length);

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
                expandedHeight: _streak > 0 ? 130 : 110,
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
                        Text(
                          '$totalExercises exercises \u00b7 ${isWeekend ? "~25 min" : "~15 min"}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
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
                    (context, index) =>
                        _BlockCard(block: blocks[index]),
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
  const _BlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  block.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
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
          ...block.exercises.map((e) => _ExerciseCard(exercise: e)),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            exercise.duration,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
      ),
    );
  }
}
