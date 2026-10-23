import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/widgets/common.dart';
import 'package:moduleup/widgets/math_question_view.dart';

enum ReviewFilter { all, wrong, marked }

/// Every question of a paper with the student's answer, the key and all four
/// explanations.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({required this.formId, super.key});
  final String formId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ReviewFilter _filter = ReviewFilter.all;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(contentBankProvider).value;
    final session = ref.watch(paperSessionProvider)?.result;
    final latest = ref
        .watch(progressProvider)
        .value
        ?.latestByForm[widget.formId];
    final result = session?.formId == widget.formId ? session : latest;
    if (bank == null || result == null) {
      return const Scaffold(
        body: StateMessage(icon: Icons.hourglass_empty, text: 'Loading…'),
      );
    }
    final responses = [
      for (final (i, r) in result.all.indexed)
        if (bank.items[r.itemId] case final item?)
          if (_keep(r, item)) (number: i + 1, response: r, item: item),
    ];
    final idx = responses.isEmpty ? 0 : _index.clamp(0, responses.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review answers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: SegmentedButton<ReviewFilter>(
              segments: const [
                ButtonSegment(value: ReviewFilter.all, label: Text('All')),
                ButtonSegment(value: ReviewFilter.wrong, label: Text('Wrong')),
                ButtonSegment(
                  value: ReviewFilter.marked,
                  label: Text('Marked'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() {
                _filter = s.first;
                _index = 0;
              }),
            ),
          ),
        ),
      ),
      body: responses.isEmpty
          ? const StateMessage(
              icon: Icons.check_circle_outline,
              text: 'Nothing to show for this filter.',
            )
          : Column(
              children: [
                Expanded(
                  child: _ReviewItem(entry: responses[idx], bank: bank),
                ),
                _Pager(
                  index: idx,
                  count: responses.length,
                  onChanged: (i) => setState(() => _index = i),
                ),
              ],
            ),
    );
  }

  bool _keep(ItemResponse r, Item item) => switch (_filter) {
    ReviewFilter.all => true,
    ReviewFilter.wrong => !item.isCorrect(r.answer),
    ReviewFilter.marked => r.marked,
  };
}

typedef _Entry = ({int number, ItemResponse response, Item item});

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.entry, required this.bank});
  final _Entry entry;
  final ContentBank bank;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final r = entry.response;
    final ok = item.isCorrect(r.answer);
    final trap = r.answer == null ? null : item.traps[r.answer];
    return ItemQuestionView(
      key: ValueKey(item.id),
      item: item,
      selected: r.answer,
      revealed: true,
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s),
        child: Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.xs,
          children: [
            Chip(label: Text('Q${entry.number}')),
            Chip(
              avatar: Icon(
                ok ? Icons.check : Icons.close,
                color: ok ? AppColors.correct : AppColors.wrong,
              ),
              label: Text(
                r.answer == null
                    ? 'Not answered'
                    : (ok ? 'Correct' : 'You chose ${r.answer}'),
              ),
            ),
            Chip(label: Text(bank.bpForItem(item).types[item.type]!.name)),
            Chip(label: Text(bank.bpForItem(item).levelNames[item.level]!)),
            Chip(label: Text('${r.seconds} s')),
            if (!ok && trap != null)
              Chip(
                label: Text('Trap: ${bank.bpForItem(item).trapLabel(trap)}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.index,
    required this.count,
    required this.onChanged,
  });
  final int index;
  final int count;
  final ValueChanged<int> onChanged;

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
            onPressed: index == 0 ? null : () => onChanged(index - 1),
            child: const Text('Previous'),
          ),
          Expanded(child: Center(child: Text('${index + 1} of $count'))),
          FilledButton(
            onPressed: index + 1 >= count ? null : () => onChanged(index + 1),
            child: const Text('Next'),
          ),
        ],
      ),
    ),
  );
}
