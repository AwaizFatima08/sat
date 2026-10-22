import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/widgets/common.dart';

/// Score report for the paper just finished (from the session) or for the
/// latest attempt of [formId].
class ScoreReportScreen extends ConsumerWidget {
  const ScoreReportScreen({super.key, this.formId});
  final String? formId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final fromSession = ref.watch(paperSessionProvider)?.result;
    final latest = formId == null
        ? null
        : ref.watch(progressProvider).value?.latestByForm[formId];
    final result = formId == null ? fromSession : latest;
    if (bank == null || result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final b = breakdown(result.all, bank.items);
    final form = bank.form(result.formId);
    return Scaffold(
      appBar: AppBar(
        title: Text(form?.title ?? 'Score report'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            ref.read(paperSessionProvider.notifier).close();
            context.go('/');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.m),
        children: [
          _ScoreCard(result: result, correct: b.overall),
          const SizedBox(height: AppSpace.m),
          SectionCard(
            title: 'By content domain',
            child: Column(
              children: [
                for (final d in bank.blueprint.domains.entries)
                  if (b.byDomain[d.key] case final t?)
                    RatioBar(label: d.value, tally: t),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.m),
          SectionCard(
            title: 'By question type',
            child: Column(
              children: [
                for (final t in bank.blueprint.typeOrder)
                  if (b.byType[t] case final tally?)
                    RatioBar(
                      label: bank.blueprint.types[t]!.name,
                      tally: tally,
                      trailing: _pace(b.secondsByType[t]),
                    ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.m),
          TrapProfileCard(counts: b.trapCounts, blueprint: bank.blueprint),
          const SizedBox(height: AppSpace.l),
          FilledButton.icon(
            onPressed: () => context.push('/review/${result.formId}'),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Review every answer'),
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'This is an estimate based on Module Up questions, not an official '
            'SAT score.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  static String? _pace(double? seconds) =>
      seconds == null ? null : '${seconds.round()} s/q';
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result, required this.correct});
  final PaperResult result;
  final Tally correct;

  @override
  Widget build(BuildContext context) {
    final e = result.estimate;
    final route = result.route == ModuleRoute.harder ? 'harder' : 'easier';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          children: [
            const Text('Estimated Reading and Writing score'),
            const SizedBox(height: AppSpace.s),
            Text(
              '${e.score}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            Text('likely range ${e.low}–${e.high}'),
            const SizedBox(height: AppSpace.m),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              alignment: WrapAlignment.center,
              children: [
                Chip(
                  label: Text('${correct.correct} of ${correct.total} correct'),
                ),
                Chip(label: Text('Module 2: $route')),
                if (result.untimed) const Chip(label: Text('Untimed')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
