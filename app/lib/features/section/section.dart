import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';

/// The two SAT sections. Keys match `Item.section` and `PaperForm.section`.
const sectionNames = {'rw': 'Reading & Writing', 'math': 'Math'};

/// Which section the Home, Papers, Practice and Progress tabs show.
class SectionNotifier extends Notifier<String> {
  @override
  String build() => 'rw';

  void select(String section) => state = section;
}

final sectionProvider = NotifierProvider<SectionNotifier, String>(
  SectionNotifier.new,
);

/// The section to show, falling back to R&W when no Math pack is shipped.
String effectiveSection(WidgetRef ref) {
  final bank = ref.watch(contentBankProvider).value;
  final s = ref.watch(sectionProvider);
  return s == 'math' && !(bank?.hasMath ?? false) ? 'rw' : s;
}

/// R&W | Math toggle; renders nothing until a Math pack is available.
class SectionSwitcher extends ConsumerWidget {
  const SectionSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(contentBankProvider).value;
    if (!(bank?.hasMath ?? false)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.m,
        AppSpace.s,
        AppSpace.m,
        AppSpace.s,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: [
            for (final e in sectionNames.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {effectiveSection(ref)},
          showSelectedIcon: false,
          onSelectionChanged: (v) =>
              ref.read(sectionProvider.notifier).select(v.first),
        ),
      ),
    );
  }
}

/// [SectionSwitcher] sized for `AppBar.bottom`.
class SectionSwitcherBar extends ConsumerWidget implements PreferredSizeWidget {
  const SectionSwitcherBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SectionSwitcher();
}
