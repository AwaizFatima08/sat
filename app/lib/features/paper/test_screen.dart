import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/widgets/question_view.dart';

String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The full-length test screen. Reads the paper session; no logic here.
class TestScreen extends ConsumerWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(paperSessionProvider);
    ref.listen(paperSessionProvider.select((s) => s?.phase), (_, phase) {
      if (phase == PaperPhase.finished) context.go('/paper/result');
    });
    if (s == null) {
      return const Scaffold(body: Center(child: Text('No paper in progress.')));
    }
    final notifier = ref.read(paperSessionProvider.notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit(context) && context.mounted) {
          notifier.pauseAndSave();
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Module ${s.module} of 2'),
          actions: [
            _TimerChip(state: s, onToggle: notifier.toggleTimer),
            const SizedBox(width: AppSpace.s),
          ],
        ),
        body: switch (s.phase) {
          PaperPhase.answering => _Answering(state: s, notifier: notifier),
          PaperPhase.checkWork => _CheckWork(state: s, notifier: notifier),
          PaperPhase.betweenModules => _BetweenModules(
            onStart: notifier.beginModule2,
          ),
          PaperPhase.finished => const Center(
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }

  static Future<bool> _confirmExit(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Leave this paper?'),
          content: const Text(
            'Your answers are saved and you can resume later, but the clock '
            'stops, so this paper will be scored as untimed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      ) ??
      false;
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.state, required this.onToggle});
  final PaperSessionState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final warn = state.secondsLeft <= 300;
    return ActionChip(
      avatar: Icon(
        Icons.timer_outlined,
        size: 18,
        color: warn ? AppColors.wrong : null,
      ),
      label: Text(
        state.timerHidden ? 'Show' : formatClock(state.secondsLeft),
        style: TextStyle(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: warn ? AppColors.wrong : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltip: state.timerHidden ? 'Show timer' : 'Hide timer',
      onPressed: onToggle,
    );
  }
}

class _Answering extends StatelessWidget {
  const _Answering({required this.state, required this.notifier});
  final PaperSessionState state;
  final PaperSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final q = state.currentState;
    return Column(
      children: [
        Expanded(
          child: QuestionView(
            key: ValueKey(state.current.id),
            content: contentOfItem(state.current),
            selected: q.answer,
            eliminated: q.eliminated,
            highlights: q.highlights,
            onSelect: notifier.select,
            onEliminate: notifier.toggleEliminate,
            onHighlight: notifier.toggleHighlight,
            header: _QuestionHeader(
              number: state.index + 1,
              marked: q.marked,
              onMark: notifier.toggleMark,
            ),
          ),
        ),
        _BottomBar(state: state, notifier: notifier),
      ],
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({
    required this.number,
    required this.marked,
    required this.onMark,
  });
  final int number;
  final bool marked;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onMark,
          icon: Icon(
            marked ? Icons.bookmark : Icons.bookmark_border,
            color: AppColors.mark,
          ),
          label: Text(marked ? 'Marked for review' : 'Mark for review'),
        ),
      ],
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.notifier});
  final PaperSessionState state;
  final PaperSessionNotifier notifier;

  @override
  Widget build(BuildContext context) => SafeArea(
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
          OutlinedButton(
            onPressed: state.index == 0 ? null : notifier.previous,
            child: const Text('Back'),
          ),
          Expanded(
            child: Center(
              child: TextButton.icon(
                onPressed: () => unawaited(_openNavigator(context)),
                icon: const Icon(Icons.grid_view),
                label: Text('${state.index + 1} of ${state.items.length}'),
              ),
            ),
          ),
          FilledButton(onPressed: notifier.next, child: const Text('Next')),
        ],
      ),
    ),
  );

  Future<void> _openNavigator(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.m,
            0,
            AppSpace.m,
            AppSpace.l,
          ),
          child: QuestionGrid(
            state: state,
            onTap: (i) {
              Navigator.pop(c);
              notifier.goTo(i);
            },
          ),
        ),
      );
}

/// Numbered grid: answered, unanswered, marked, current.
class QuestionGrid extends StatelessWidget {
  const QuestionGrid({required this.state, required this.onTap, super.key});
  final PaperSessionState state;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Wrap(
          spacing: AppSpace.m,
          children: [
            _Legend(color: AppColors.accent, label: 'Answered'),
            _Legend(color: AppColors.line, label: 'Unanswered'),
            _Legend(color: AppColors.mark, label: 'Marked'),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < state.items.length; i++)
              _GridCell(
                number: i + 1,
                answered: state.questions[state.items[i].id]?.answer != null,
                marked: state.questions[state.items[i].id]?.marked ?? false,
                current:
                    i == state.index && state.phase == PaperPhase.answering,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.number,
    required this.answered,
    required this.marked,
    required this.current,
    required this.onTap,
  });
  final int number;
  final bool answered;
  final bool marked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Question $number, ${answered ? 'answered' : 'unanswered'}${marked ? ', marked' : ''}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: marked
                ? AppColors.mark
                : (current ? AppColors.ink : AppColors.line),
            width: marked || current ? 2.5 : 1,
          ),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: answered ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    ),
  );
}

class _CheckWork extends StatelessWidget {
  const _CheckWork({required this.state, required this.notifier});
  final PaperSessionState state;
  final PaperSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final unanswered = state.items.length - state.answeredCount;
    final last = state.module == 2;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.l),
      children: [
        Text(
          'Check your work',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpace.s),
        Text(
          unanswered == 0
              ? 'You have answered every question. Tap a number to go back to it.'
              : '$unanswered unanswered. There is no penalty for guessing, so answer every question.',
        ),
        const SizedBox(height: AppSpace.l),
        QuestionGrid(state: state, onTap: notifier.goTo),
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: () => unawaited(notifier.endModule()),
          child: Text(last ? 'Submit paper' : 'Next module'),
        ),
      ],
    );
  }
}

class _BetweenModules extends StatelessWidget {
  const _BetweenModules({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_circle, size: 56, color: AppColors.accent),
          const SizedBox(height: AppSpace.m),
          Text(
            'Module 1 complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Module 2 has 27 questions and 32 minutes. Its difficulty depends on '
            'how you did in module 1. The clock starts when you tap Start.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.l),
          FilledButton(onPressed: onStart, child: const Text('Start module 2')),
        ],
      ),
    ),
  );
}
