import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/auth/auth_screens.dart';
import 'package:moduleup/features/practice/drill_session.dart';
import 'package:moduleup/features/section/section.dart';

/// The Practice tab: skills by domain, quizzes, timed module, mistakes.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final progress =
        ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    if (bank == null) return const Center(child: CircularProgressIndicator());
    final now = ref.watch(clockProvider).now();
    final due = progress.dueMistakes(now).length;
    final drill = ref.read(drillProvider.notifier);
    final section = effectiveSection(ref);
    final bp = bank.bpOf(section);
    void start(bool Function() begin) {
      if (!requireAccount(context, ref)) return;
      if (begin()) {
        unawaited(context.push('/drill'));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No questions available for this set yet.'),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        const SectionSwitcher(),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickCard(
                  icon: Icons.timer_outlined,
                  title: 'Timed module',
                  subtitle:
                      '${bp.moduleItems} questions · ${bp.moduleMinutes} min',
                  onTap: () =>
                      start(() => drill.startModulePractice(section: section)),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: _QuickCard(
                  icon: Icons.replay,
                  title: 'Mistakes',
                  subtitle: due == 0 ? 'Nothing due' : '$due due today',
                  onTap: due == 0 ? null : () => start(drill.startMistakes),
                ),
              ),
            ],
          ),
        ),
        for (final d in bp.domains.entries) ...[
          const SizedBox(height: AppSpace.l),
          Row(
            children: [
              Expanded(
                child: Text(
                  d.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => start(() => drill.startDomainQuiz(d.key)),
                child: const Text('Quiz · 15 q'),
              ),
            ],
          ),
          for (final t in bp.typeOrder)
            if (bp.types[t]!.domain == d.key)
              _SkillTile(type: t, bank: bank, progress: progress),
        ],
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: onTap == null ? AppColors.muted : AppColors.accent,
            ),
            const SizedBox(height: AppSpace.s),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.type,
    required this.bank,
    required this.progress,
  });
  final String type;
  final ContentBank bank;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final levels = [
      for (var l = 1; l <= 4; l++)
        masteryFor(
          type: type,
          level: l,
          drills: progress.drills,
          papers: progress.papers,
          items: bank.items,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s),
      child: Card(
        child: ListTile(
          title: Text(bank.bpOfType(type).types[type]!.name),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: MasteryDots(levels: levels),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/practice/$type'),
        ),
      ),
    );
  }
}

/// Four dots, one per level, filled by mastery.
class MasteryDots extends StatelessWidget {
  const MasteryDots({required this.levels, super.key});
  final List<Mastery> levels;

  static Color colorOf(Mastery m) => switch (m) {
    Mastery.notStarted => AppColors.line,
    Mastery.familiar => const Color(0xFF9DB4F5),
    Mastery.proficient => AppColors.accent,
    Mastery.mastered => AppColors.correct,
  };

  static String labelOf(Mastery m) => switch (m) {
    Mastery.notStarted => 'Not started',
    Mastery.familiar => 'Familiar',
    Mastery.proficient => 'Proficient',
    Mastery.mastered => 'Mastered',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: [
      for (var i = 0; i < levels.length; i++)
        'level ${i + 1} ${labelOf(levels[i])}',
    ].join(', '),
    excludeSemantics: true,
    child: Row(
      children: [
        for (final m in levels)
          Container(
            width: 28,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: colorOf(m),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}
