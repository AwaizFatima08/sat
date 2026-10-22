import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/ads_service.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/auth/auth_screens.dart';
import 'package:moduleup/features/practice/drill_session.dart';
import 'package:moduleup/features/practice/practice_screen.dart';
import 'package:moduleup/widgets/common.dart';
import 'package:moduleup/widgets/question_view.dart';
import 'package:moduleup/widgets/rich_passage.dart';

/// One question type: lesson notes, then a card per level with its strategy,
/// worked example, try-it questions and the drill button.
class SkillScreen extends ConsumerWidget {
  const SkillScreen({required this.type, super.key});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final progress =
        ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    if (bank == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lesson = bank.lessons[type];
    final name = bank.blueprint.types[type]?.name ?? type;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Lesson'),
              Tab(text: 'Foundations'),
              Tab(text: 'Medium'),
              Tab(text: 'Advanced'),
              Tab(text: 'Challenge'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (lesson == null)
              const StateMessage(
                icon: Icons.menu_book_outlined,
                text: 'Lesson coming soon.',
              )
            else
              _LessonNotes(lesson: lesson),
            for (var level = 1; level <= 4; level++)
              _LevelTab(
                type: type,
                level: level,
                bank: bank,
                progress: progress,
                lesson: lesson,
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonNotes extends StatelessWidget {
  const _LessonNotes({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.m),
    children: [
      SectionCard(title: 'What it tests', child: RichLine(lesson.whatIsTested)),
      const SizedBox(height: AppSpace.m),
      SectionCard(title: 'How to spot it', child: RichLine(lesson.howToSpot)),
      const SizedBox(height: AppSpace.m),
      SectionCard(title: 'The method', child: _Numbered(lesson.method)),
      if (lesson.pitfalls.isNotEmpty) ...[
        const SizedBox(height: AppSpace.m),
        SectionCard(
          title: 'Common mistakes',
          child: _Numbered(lesson.pitfalls, bullets: true),
        ),
      ],
      if (lesson.usUk case final note?) ...[
        const SizedBox(height: AppSpace.m),
        SectionCard(
          title: 'American vs British English',
          child: RichLine(note),
        ),
      ],
    ],
  );
}

class _Numbered extends StatelessWidget {
  const _Numbered(this.lines, {this.bullets = false});
  final List<String> lines;
  final bool bullets;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, l) in lines.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Text(bullets ? '•' : '${i + 1}.')),
              Expanded(child: RichLine(l)),
            ],
          ),
        ),
    ],
  );
}

class _LevelTab extends ConsumerWidget {
  const _LevelTab({
    required this.type,
    required this.level,
    required this.bank,
    required this.progress,
    required this.lesson,
  });
  final String type;
  final int level;
  final ContentBank bank;
  final ProgressSnapshot progress;
  final Lesson? lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = lesson?.cards.where((c) => c.level == level).firstOrNull;
    final mastery = masteryFor(
      type: type,
      level: level,
      drills: progress.drills,
      papers: progress.papers,
      items: bank.items,
    );
    final drill = ref.read(drillProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: MasteryDots.colorOf(mastery),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Text(MasteryDots.labelOf(mastery)),
            const Spacer(),
            Text(
              '${bank.drillCount(type, level)} practice questions',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        if (card != null) ...[
          SectionCard(title: card.title, child: _Numbered(card.steps)),
          const SizedBox(height: AppSpace.m),
          OutlinedButton.icon(
            onPressed: () => unawaited(_openExample(context, card.example)),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Worked example'),
          ),
          const SizedBox(height: AppSpace.s),
          OutlinedButton.icon(
            onPressed: () {
              if (!requireAccount(context, ref)) return;
              if (drill.startTryIt(type, level, card.tryIt)) {
                unawaited(context.push('/drill'));
              }
            },
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Try it: 2 questions'),
          ),
          const SizedBox(height: AppSpace.m),
        ],
        _DrillButton(type: type, level: level),
      ],
    );
  }

  static Future<void> _openExample(BuildContext context, WorkedExample e) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Worked example')),
            body: QuestionView(
              content: contentOfExample(e),
              selected: e.answer,
              reveal: Reveal(answer: e.answer, why: e.walkthrough.join('\n\n')),
            ),
          ),
        ),
      );
}

/// Starts a 10-question drill. Challenge sets are limited per day; an
/// optional rewarded ad (shown only when one is loaded) adds one more.
class _DrillButton extends ConsumerStatefulWidget {
  const _DrillButton({required this.type, required this.level});
  final String type;
  final int level;

  @override
  ConsumerState<_DrillButton> createState() => _DrillButtonState();
}

class _DrillButtonState extends ConsumerState<_DrillButton> {
  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsServiceProvider);
    final challenge = widget.level == 4;
    final left = challenge ? ads.challengeSetsLeftToday() : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: left > 0 ? _start : null,
          icon: const Icon(Icons.bolt),
          label: const Text('Practice set: 10 questions'),
        ),
        if (challenge) ...[
          const SizedBox(height: AppSpace.s),
          Text(
            left > 0
                ? '$left Challenge ${left == 1 ? 'set' : 'sets'} left today.'
                : "You have used today's Challenge sets.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: ads.rewardedReady,
            builder: (context, ready, _) =>
                ready &&
                    ads.earnedChallengeSetsToday() <
                        maxEarnedChallengeSetsPerDay
                ? TextButton.icon(
                    onPressed: () => unawaited(_watch(ads)),
                    icon: const Icon(Icons.ondemand_video),
                    label: const Text('Watch an ad for 1 extra Challenge set'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Future<void> _start() async {
    if (!requireAccount(context, ref)) return;
    final ads = ref.read(adsServiceProvider);
    if (!ref
        .read(drillProvider.notifier)
        .startSkill(widget.type, widget.level)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions at this level yet.')),
      );
      return;
    }
    if (widget.level == 4) await ads.useChallengeSet();
    if (mounted) await context.push('/drill');
    if (mounted) setState(() {});
  }

  Future<void> _watch(AdsService ads) async {
    final outcome = await ads.showRewarded();
    if (!mounted) return;
    final msg = switch (outcome) {
      Rewarded() => 'Thanks! One extra Challenge set added for today.',
      Dismissed() => 'The ad was closed early, so no set was added.',
      NoFill() => 'No ad is available right now. Try again later.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
    debugPrint('rewarded outcome: $outcome');
  }
}
