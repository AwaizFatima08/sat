import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/features/auth/auth_screens.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/widgets/common.dart';

/// The 10 papers as tiles.
class PapersScreen extends ConsumerWidget {
  const PapersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final p = ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    return Scaffold(
      appBar: AppBar(title: const Text('Full-length papers')),
      body: bank == null
          ? const Center(child: CircularProgressIndicator())
          : bank.forms.isEmpty
          ? const StateMessage(
              icon: Icons.hourglass_empty,
              text: 'Papers are being prepared.',
            )
          : GridView.extent(
              padding: const EdgeInsets.all(AppSpace.m),
              maxCrossAxisExtent: 220,
              mainAxisSpacing: AppSpace.s,
              crossAxisSpacing: AppSpace.s,
              childAspectRatio: 1.3,
              children: [
                for (final f in bank.forms)
                  _PaperTile(
                    title: f.title,
                    status: p.session?.formId == f.id
                        ? 'In progress'
                        : p.latestByForm[f.id] == null
                        ? 'Not started'
                        : 'Score ${p.latestByForm[f.id]!.estimate.score}',
                    done: p.latestByForm.containsKey(f.id),
                    onTap: () => context.push('/paper/${f.id}'),
                  ),
              ],
            ),
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({
    required this.title,
    required this.status,
    required this.done,
    required this.onTap,
  });
  final String title;
  final String status;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: done ? AppColors.correctSoft : null,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.assignment_outlined,
              color: done ? AppColors.correct : AppColors.accent,
            ),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(status, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

/// Directions, then start / resume / review.
class PaperIntroScreen extends ConsumerWidget {
  const PaperIntroScreen({required this.formId, super.key});
  final String formId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    final p = ref.watch(progressProvider).value ?? ProgressSnapshot.empty;
    final form = bank?.form(formId);
    if (bank == null || form == null) {
      return const Scaffold(
        body: StateMessage(icon: Icons.error_outline, text: 'Paper not found.'),
      );
    }
    final resume = p.session?.formId == formId ? p.session : null;
    final done = p.latestByForm[formId];
    void go({SavedPaperSession? from}) {
      if (!requireAccount(context, ref, forPaper: true)) return;
      ref.read(paperSessionProvider.notifier).start(form, resume: from);
      context.go('/test');
    }

    return Scaffold(
      appBar: AppBar(title: Text(form.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.l),
        children: [
          Text(
            'Reading and Writing',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.m),
          const _Direction(
            icon: Icons.view_agenda_outlined,
            text: '2 modules, 27 questions each, 32 minutes each.',
          ),
          const _Direction(
            icon: Icons.alt_route,
            text:
                'Your module 1 result decides whether module 2 is easier or harder. Only the harder module can lead to the top scores.',
          ),
          const _Direction(
            icon: Icons.touch_app_outlined,
            text:
                'Tap a choice to answer. Use the strike button to eliminate choices, long-press a sentence to highlight it, and mark questions to review.',
          ),
          const _Direction(
            icon: Icons.timer_outlined,
            text:
                'The clock keeps running. Leaving pauses it, and the paper is then scored as untimed.',
          ),
          const _Direction(
            icon: Icons.insights_outlined,
            text:
                'You get an estimated score and full explanations as soon as you finish.',
          ),
          const SizedBox(height: AppSpace.l),
          if (resume != null) ...[
            FilledButton(
              onPressed: () => go(from: resume),
              child: Text('Resume module ${resume.module}'),
            ),
            const SizedBox(height: AppSpace.s),
            OutlinedButton(onPressed: go, child: const Text('Start over')),
          ] else
            FilledButton(
              onPressed: go,
              child: Text(done == null ? 'Start paper' : 'Retake paper'),
            ),
          if (done != null) ...[
            const SizedBox(height: AppSpace.s),
            OutlinedButton(
              onPressed: () => context.push('/attempt/$formId'),
              child: Text('Last result: ${done.estimate.score}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Direction extends StatelessWidget {
  const _Direction({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.m),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent),
        const SizedBox(width: AppSpace.m),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
