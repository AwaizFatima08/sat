import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/widgets/common.dart';
import 'package:moduleup/widgets/rich_passage.dart';

typedef Json = Map<String, Object?>;

List<Json> _list(Object? v) => [
  for (final e in (v as List?) ?? const []) e as Json,
];

/// The Guides tab: reference material.
class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    if (bank == null) return const Center(child: CircularProgressIndicator());
    const guides = [
      (
        'grammar',
        Icons.spellcheck,
        'Grammar handbook',
        'US Standard English rules tested on the SAT',
      ),
      (
        'wordbank',
        Icons.style_outlined,
        'Word bank',
        'Academic words with flashcards',
      ),
      (
        'traps',
        Icons.warning_amber_outlined,
        'Trap guide',
        'The wrong-answer patterns and how to beat them',
      ),
      (
        'testday',
        Icons.event_available_outlined,
        'Test-day guide',
        'Timing, routing, tools and the big day',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        for (final (key, icon, title, sub) in guides)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: Card(
              child: ListTile(
                leading: Icon(icon, color: AppColors.accent),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right),
                enabled: bank.reference.containsKey(key),
                onTap: () => context.push('/guides/$key'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders one reference guide by key.
class GuideScreen extends ConsumerWidget {
  const GuideScreen({required this.guide, super.key});
  final String guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final data = bank?.reference[guide] as Json?;
    if (data == null) {
      return const Scaffold(
        body: StateMessage(
          icon: Icons.menu_book_outlined,
          text: 'Guide not available.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(data['title']! as String)),
      body: switch (guide) {
        'grammar' => _Grammar(data: data),
        'wordbank' => _WordBank(data: data),
        'traps' => _Traps(data: data),
        _ => _TestDay(data: data),
      },
    );
  }
}

class _Grammar extends StatelessWidget {
  const _Grammar({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.m),
    children: [
      if (data['intro'] case final String intro) RichLine(intro),
      for (final s in _list(data['sections']))
        Card(
          margin: const EdgeInsets.only(top: AppSpace.m),
          child: ExpansionTile(
            title: Text(
              s['title']! as String,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpace.m,
              0,
              AppSpace.m,
              AppSpace.m,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichLine(s['rule']! as String),
              const SizedBox(height: AppSpace.s),
              for (final pt in (s['points'] as List? ?? const []))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichLine('•  $pt'),
                ),
              for (final ex in _list(s['examples'])) _Example(ex: ex),
              if (s['us_uk'] case final String note)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s),
                  child: RichLine('**US vs UK:** $note'),
                ),
            ],
          ),
        ),
    ],
  );
}

class _Example extends StatelessWidget {
  const _Example({required this.ex});
  final Json ex;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: AppSpace.s),
    padding: const EdgeInsets.all(AppSpace.s),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichLine(
          '✗ ${ex['wrong']}',
          style: const TextStyle(color: AppColors.wrong),
        ),
        RichLine(
          '✓ ${ex['right']}',
          style: const TextStyle(color: AppColors.correct),
        ),
        RichLine(
          '${ex['why']}',
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _Traps extends StatelessWidget {
  const _Traps({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.m),
    children: [
      if (data['intro'] case final String intro) RichLine(intro),
      for (final t in _list(data['traps']))
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.m),
          child: SectionCard(
            title: t['title']! as String,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichLine(t['description']! as String),
                const SizedBox(height: AppSpace.s),
                RichLine('**Example:** ${t['example']}'),
                const SizedBox(height: AppSpace.s),
                RichLine('**How to avoid it:** ${t['how_to_avoid']}'),
              ],
            ),
          ),
        ),
    ],
  );
}

class _TestDay extends StatelessWidget {
  const _TestDay({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.m),
    children: [
      for (final s in _list(data['sections']))
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.m),
          child: SectionCard(
            title: s['title']! as String,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final para in (s['body'] as List? ?? const []))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: RichLine('$para'),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _WordBank extends StatefulWidget {
  const _WordBank({required this.data});
  final Json data;

  @override
  State<_WordBank> createState() => _WordBankState();
}

class _WordBankState extends State<_WordBank> {
  String _query = '';
  int? _level;

  @override
  Widget build(BuildContext context) {
    final words = _list(widget.data['words'])
        .where(
          (w) =>
              (_level == null || w['level'] == _level) &&
              (_query.isEmpty ||
                  (w['word']! as String).toLowerCase().contains(_query)),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.m,
            AppSpace.m,
            AppSpace.m,
            0,
          ),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search words',
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
          child: Row(
            children: [
              for (final l in [null, 1, 2, 3, 4])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s),
                  child: ChoiceChip(
                    label: Text(l == null ? 'All' : 'Level $l'),
                    selected: _level == l,
                    onSelected: (_) => setState(() => _level = l),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.style_outlined, size: 18),
                label: const Text('Flashcards'),
                onPressed: words.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _Flashcards(words: words),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
            itemCount: words.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final w = words[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${w['word']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${w['pos']}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                subtitle: Text('${w['definition']}\n“${w['example']}”'),
                isThreeLine: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Flashcards extends StatefulWidget {
  const _Flashcards({required this.words});
  final List<Json> words;

  @override
  State<_Flashcards> createState() => _FlashcardsState();
}

class _FlashcardsState extends State<_Flashcards> {
  late final List<Json> _deck = [...widget.words]..shuffle(math.Random());
  int _i = 0;
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final w = _deck[_i];
    return Scaffold(
      appBar: AppBar(title: Text('Card ${_i + 1} of ${_deck.length}')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: Card(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.l),
                      child: _flipped
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${w['definition']}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpace.m),
                                Text(
                                  '“${w['example']}”',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '${w['word']}',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.m),
            const Text(
              'Tap the card to flip it.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _i == 0
                        ? null
                        : () => setState(() {
                            _i--;
                            _flipped = false;
                          }),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: FilledButton(
                    onPressed: _i + 1 >= _deck.length
                        ? null
                        : () => setState(() {
                            _i++;
                            _flipped = false;
                          }),
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
