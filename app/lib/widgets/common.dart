import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/results.dart';

/// A titled card section.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    super.key,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpace.s),
          child,
        ],
      ),
    ),
  );
}

/// Label, percentage bar and "x/y" count.
class RatioBar extends StatelessWidget {
  const RatioBar({
    required this.label,
    required this.tally,
    super.key,
    this.trailing,
  });
  final String label;
  final Tally tally;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final pct = (tally.ratio * 100).round();
    final color = tally.ratio >= 0.8
        ? AppColors.correct
        : tally.ratio >= 0.6
        ? AppColors.accent
        : AppColors.wrong;
    return Semantics(
      label: '$label: ${tally.correct} of ${tally.total} correct, $pct percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  '${tally.correct}/${tally.total}'
                  '${trailing == null ? '' : ' · $trailing'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: tally.ratio,
                minHeight: 8,
                color: color,
                backgroundColor: AppColors.line,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which traps the student fell for, largest first.
class TrapProfileCard extends StatelessWidget {
  const TrapProfileCard({
    required this.counts,
    required this.blueprint,
    super.key,
  });
  final Map<String, int> counts;
  final Blueprint blueprint;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      title: 'Traps you fell for',
      child: total == 0
          ? const Text('No wrong answers to analyse yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in sorted.take(5))
                  RatioBar(
                    label: blueprint.trapLabel(e.key),
                    tally: Tally(e.value, total),
                  ),
                const SizedBox(height: AppSpace.s),
                Text(
                  blueprint.traps[sorted.first.key] ?? '',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
    );
  }
}

/// Centered loading / error / empty states.
class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.icon,
    required this.text,
    super.key,
    this.action,
  });
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: AppSpace.m),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: AppSpace.m), action!],
        ],
      ),
    ),
  );
}
