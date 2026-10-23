import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/features/math/math_tools.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/ads_service.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/paper/test_screen.dart' show formatClock;
import 'package:moduleup/features/practice/drill_session.dart';
import 'package:moduleup/widgets/common.dart';
import 'package:moduleup/widgets/math_question_view.dart';

/// A practice set in progress, then its results.
class DrillScreen extends ConsumerWidget {
  const DrillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(drillProvider);
    if (s == null) {
      return const Scaffold(
        body: StateMessage(
          icon: Icons.inbox_outlined,
          text: 'No practice set open.',
        ),
      );
    }
    final n = ref.read(drillProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          if (!s.finished && s.current.section == 'math')
            const MathToolButtons(),
          if (s.secondsLeft case final left? when !s.finished)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.m),
              child: Center(
                child: Text(
                  formatClock(left),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: s.finished ? _Results(state: s) : _Question(state: s, notifier: n),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.state, required this.notifier});
  final DrillState state;
  final DrillNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final item = state.current;
    final answered = state.answers[item.id] != null;
    final last = state.index + 1 == state.items.length;
    final revealed = state.revealed && state.instantFeedback;
    return Column(
      children: [
        LinearProgressIndicator(value: (state.index + 1) / state.items.length),
        Expanded(
          child: ItemQuestionView(
            key: ValueKey('${item.id}-${state.revealed}'),
            item: item,
            selected: state.answers[item.id],
            onSelect: revealed ? null : notifier.select,
            revealed: revealed,
            header: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: Text(
                'Question ${state.index + 1} of ${state.items.length}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.m,
              vertical: AppSpace.s,
            ),
            child: Row(
              children: [
                if (!state.instantFeedback)
                  OutlinedButton(
                    onPressed: state.index == 0 ? null : notifier.previous,
                    child: const Text('Back'),
                  ),
                const Spacer(),
                if (state.instantFeedback && !state.revealed)
                  FilledButton(
                    onPressed: answered ? notifier.check : null,
                    child: const Text('Check'),
                  )
                else
                  FilledButton(
                    onPressed: () => unawaited(notifier.next()),
                    child: Text(last ? 'Finish' : 'Next'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state});
  final DrillState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).requireValue;
    final responses = [
      for (final i in state.items)
        ItemResponse(
          itemId: i.id,
          answer: state.answers[i.id],
          seconds: state.seconds[i.id] ?? 0,
        ),
    ];
    final b = breakdown(responses, bank.items);
    final wrong = [
      for (final i in state.items)
        if (!i.isCorrect(state.answers[i.id])) i,
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              children: [
                Text(
                  '${state.correct} / ${state.items.length}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(_verdict(state.correct / state.items.length)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.m),
        if (b.byType.length > 1)
          SectionCard(
            title: 'By question type',
            child: Column(
              children: [
                for (final t in bank.blueprint.typeOrder)
                  if (b.byType[t] case final tally?)
                    RatioBar(
                      label: bank.blueprint.types[t]!.name,
                      tally: tally,
                    ),
              ],
            ),
          ),
        if (b.byType.length > 1) const SizedBox(height: AppSpace.m),
        TrapProfileCard(counts: b.trapCounts, blueprint: bank.blueprint),
        const SizedBox(height: AppSpace.m),
        if (wrong.isNotEmpty && !state.instantFeedback)
          SectionCard(
            title: 'Questions to review',
            child: Column(
              children: [
                for (final i in wrong)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bank.blueprint.types[i.type]!.name),
                    subtitle: Text(
                      'You chose ${state.answers[i.id] ?? '—'} · answer ${i.keyLabel}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(
                      _showItem(context, i.id, state.answers[i.id], bank),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.l),
        const Text(
          'Wrong answers go into your mistake notebook and come back in 1, 3 and 7 days.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.m),
        FilledButton(
          onPressed: () => unawaited(_done(context, ref)),
          child: const Text('Done'),
        ),
      ],
    );
  }

  static String _verdict(double r) => r >= 0.9
      ? 'Excellent: try the next level.'
      : r >= 0.7
      ? 'Good work. One more set at this level will lock it in.'
      : 'Read the strategy card again, then try another set.';

  Future<void> _done(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    ref.read(drillProvider.notifier).close();
    await ref.read(adsServiceProvider).maybeShowInterstitial();
    router.go('/practice');
  }

  static Future<void> _showItem(
    BuildContext context,
    String id,
    String? chosen,
    ContentBank bank,
  ) {
    final item = bank.items[id]!;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(bank.bpForItem(item).types[item.type]!.name),
          ),
          body: ItemQuestionView(
            item: item,
            selected: chosen,
            revealed: true,
            showSource: false,
          ),
        ),
      ),
    );
  }
}
