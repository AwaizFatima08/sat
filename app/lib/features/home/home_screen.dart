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
import 'package:moduleup/widgets/common.dart';

/// Weakest question types with enough answers to judge (at least 5).
List<(String, Tally)> weakestTypes(Breakdown b, {int count = 3}) {
  final list = [
    for (final e in b.byType.entries)
      if (e.value.total >= 5) (e.key, e.value),
  ]..sort((a, b) => a.$2.ratio.compareTo(b.$2.ratio));
  return list.take(count).toList();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final p = ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    if (bank == null) return const Center(child: CircularProgressIndicator());
    final now = ref.watch(clockProvider).now();
    final latest = p.latestByForm;
    final nextPaper = bank.forms
        .where((f) => !latest.containsKey(f.id))
        .firstOrNull;
    final last = ([
      ...p.papers,
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt))).firstOrNull;
    final weak = weakestTypes(breakdown(p.allResponses, bank.items));
    final due = p.dueMistakes(now).length;
    final name = p.profile?.name ?? '';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.m),
            children: [
              Text(
                name.isEmpty ? 'Welcome' : 'Hi, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.m),
              if (p.session case final s?)
                _ActionCard(
                  icon: Icons.play_circle_outline,
                  title: 'Resume ${bank.form(s.formId)?.title ?? 'paper'}',
                  subtitle: 'Module ${s.module} · saved progress',
                  onTap: () => context.push('/paper/${s.formId}'),
                  highlight: true,
                )
              else if (nextPaper != null)
                _ActionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Start ${nextPaper.title}',
                  subtitle: 'Full adaptive section · 54 questions · 64 min',
                  onTap: () => context.push('/paper/${nextPaper.id}'),
                  highlight: true,
                ),
              const SizedBox(height: AppSpace.s),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Last estimate',
                      value: last == null ? '—' : '${last.estimate.score}',
                      onTap: last == null
                          ? null
                          : () => context.push('/attempt/${last.formId}'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: _MiniStat(
                      label: 'Target',
                      value: '${p.profile?.targetScore ?? '—'}',
                      onTap: () => context.push('/settings'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: _MiniStat(
                      label: 'Mistakes due',
                      value: '$due',
                      onTap: () => context.go('/practice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              SectionCard(
                title: 'Focus on',
                child: weak.isEmpty
                    ? const Text(
                        'Do a few practice sets and your weakest skills will show here.',
                      )
                    : Column(
                        children: [
                          for (final (t, tally) in weak)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(bank.blueprint.types[t]!.name),
                              subtitle: Text(
                                '${(tally.ratio * 100).round()}% correct',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/practice/$t'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpace.m),
              _ActionCard(
                icon: Icons.library_books_outlined,
                title: 'All 10 papers',
                subtitle: '${latest.length} of ${bank.forms.length} done',
                onTap: () => context.push('/papers'),
              ),
            ],
          ),
        ),
        const BannerSlot(),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Card(
    color: highlight ? AppColors.accent : null,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      leading: Icon(
        icon,
        color: highlight ? Colors.white : AppColors.accent,
        size: 32,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: highlight ? Colors.white : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: highlight ? Colors.white70 : null),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: highlight ? Colors.white : null,
      ),
      onTap: onTap,
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          children: [
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
    ),
  );
}
