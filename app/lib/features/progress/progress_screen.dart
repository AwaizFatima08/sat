import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/ads_service.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/engine/scoring.dart';
import 'package:moduleup/features/practice/practice_screen.dart';
import 'package:moduleup/features/section/section.dart';
import 'package:moduleup/widgets/common.dart';

/// The progress board: score trend, papers, skill mastery, traps, pace,
/// streak and weekly goal.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final p = ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    if (bank == null) return const Center(child: CircularProgressIndicator());
    final now = ref.watch(clockProvider).now();
    final section = effectiveSection(ref);
    final bp = bank.bpOf(section);
    final all = breakdown(
      p.allResponses.where((r) => bank.items[r.itemId]?.section == section),
      bank.items,
    );
    final papers = [
      for (final r in p.papers)
        if ((bank.form(r.formId)?.section ?? 'rw') == section) r,
    ]..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));
    final pace = bp.moduleMinutes * 60 / bp.moduleItems;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.m),
            children: [
              const SectionSwitcher(),
              _HabitRow(progress: p, now: now),
              const SizedBox(height: AppSpace.m),
              SectionCard(
                title: 'Score trend',
                child: papers.isEmpty
                    ? const Text(
                        'Finish a full paper to see your estimated score here.',
                      )
                    : SizedBox(
                        height: 180,
                        child: _TrendChart(
                          points: [for (final r in papers) r.estimate],
                          target: p.profile?.targetScore,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpace.m),
              SectionCard(
                title: 'Skill mastery',
                child: Column(
                  children: [
                    for (final t in bp.typeOrder)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(bp.types[t]!.name),
                        trailing: MasteryDots(
                          levels: [
                            for (var l = 1; l <= 4; l++)
                              masteryFor(
                                type: t,
                                level: l,
                                drills: p.drills,
                                papers: p.papers,
                                items: bank.items,
                              ),
                          ],
                        ),
                        onTap: () => context.push('/practice/$t'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.m),
              SectionCard(
                title: 'Accuracy and pace by type',
                child: all.overall.total == 0
                    ? const Text('Answer some questions to see your accuracy.')
                    : Column(
                        children: [
                          for (final t in bp.typeOrder)
                            if (all.byType[t] case final tally?)
                              RatioBar(
                                label: bp.types[t]!.name,
                                tally: tally,
                                trailing:
                                    '${all.secondsByType[t]!.round()} s/q',
                              ),
                          const SizedBox(height: AppSpace.s),
                          Text(
                            'Target pace: about ${pace.round()} seconds per question.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpace.m),
              TrapProfileCard(
                counts: all.trapCounts,
                blueprint: bp,
              ),
            ],
          ),
        ),
        const BannerSlot(),
      ],
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.progress, required this.now});
  final ProgressSnapshot progress;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final goal = progress.profile?.weeklyGoal ?? 100;
    final week = progress.questionsThisWeek(now);
    final test = progress.profile?.testDate;
    final days = test == null
        ? null
        : DateTime(
            test.year,
            test.month,
            test.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: '${progress.streak(now)}',
            label: 'day streak',
            icon: Icons.local_fire_department,
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: _Stat(
            value: '$week/$goal',
            label: 'this week',
            icon: Icons.flag_outlined,
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: _Stat(
            value: days == null ? '—' : '${math.max(0, days)}',
            label: 'days to test',
            icon: Icons.event,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Score per paper with its ± band, plus the target line.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, this.target});
  final List<ScoreEstimate> points;
  final int? target;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Estimated scores in order: ${points.map((e) => e.score).join(', ')}'
        '${target == null ? '' : '. Target $target'}',
    excludeSemantics: true,
    child: CustomPaint(
      painter: _TrendPainter(points, target),
      size: Size.infinite,
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.target);
  final List<ScoreEstimate> points;
  final int? target;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 200.0;
    const hi = 800.0;
    const left = 36.0;
    final plot = Rect.fromLTRB(left, 8, size.width - 8, size.height - 16);
    double y(num v) => plot.bottom - plot.height * (v - lo) / (hi - lo);
    final grid = Paint()..color = AppColors.line;
    for (final v in [200, 400, 600, 800]) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      (TextPainter(
        text: TextSpan(
          text: '$v',
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).paint(canvas, Offset(0, y(v) - 6));
    }
    if (target case final t?) {
      canvas.drawLine(
        Offset(plot.left, y(t)),
        Offset(plot.right, y(t)),
        Paint()
          ..color = AppColors.correct
          ..strokeWidth = 1.5,
      );
    }
    final n = points.length;
    double x(int i) =>
        n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    final line = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final e = points[i];
      canvas.drawLine(
        Offset(x(i), y(e.low)),
        Offset(x(i), y(e.high)),
        Paint()
          ..color = AppColors.accentSoft
          ..strokeWidth = 8,
      );
      final pt = Offset(x(i), y(e.score));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(x(i), y(points[i].score)),
        4.5,
        Paint()..color = AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.target != target;
}
