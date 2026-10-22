// Renders key screens to PNGs for a visual check (not a pass/fail golden).
// Run: flutter test test/screens_preview_test.dart --update-goldens
// Output: test/preview/*.png (gitignored).
@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/features/paper/test_screen.dart';
import 'package:moduleup/features/practice/skill_screen.dart';
import 'package:moduleup/widgets/question_view.dart';

import 'paper_session_test.dart' show FakeProgressRepository;

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  const fonts = '/mnt/storage/projects/flutter/bin/cache/artifacts/material_fonts';
  late ContentBank bank;

  setUpAll(() async {
    await _font('Roboto', ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Bold.ttf', '$fonts/Roboto-Medium.ttf']);
    await _font('serif', ['/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf']);
    await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    bank = ContentBank.fromJson(
      jsonDecode(File('assets/data/rw_bank.json').readAsStringSync()) as Map<String, Object?>,
    );
  });

  Future<void> shot(WidgetTester t, Widget child, String name, Size size) async {
    t.view.physicalSize = size * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          contentBankProvider.overrideWith((ref) async => bank),
          progressProvider.overrideWith((ref) => Stream.value(ProgressSnapshot.empty)),
        ],
        child: MaterialApp(theme: buildTheme(), debugShowCheckedModeBanner: false, home: child),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('preview/$name.png'));
  }

  Item pick(String type) => bank.items.values.firstWhere((i) => i.type == type && i.level >= 2);

  testWidgets('question views', (t) async {
    for (final type in ['coe_quantitative', 'cross_text', 'rhetorical_synthesis']) {
      final item = pick(type);
      await shot(
        t,
        Scaffold(
          appBar: AppBar(title: Text(bank.blueprint.types[type]!.name)),
          body: QuestionView(
            content: contentOfItem(item),
            selected: 'B',
            eliminated: const {'D'},
            onSelect: (_) {},
            onEliminate: (_) {},
          ),
        ),
        'phone-$type',
        const Size(392, 860),
      );
    }
    final item = pick('words_in_context');
    await shot(
      t,
      Scaffold(
        body: QuestionView(
          content: contentOfItem(item),
          selected: 'A',
          reveal: Reveal(answer: item.answer, why: item.why, explanations: item.choiceExplanations),
        ),
      ),
      'tablet-review',
      const Size(1180, 820),
    );
  });

  testWidgets('test screen', (t) async {
    final ids = bank.items.keys.toList();
    final form = PaperForm(
      id: 'p', number: 1, title: 'Paper 1',
      module1: ids.take(27).toList(), module2Easier: ids.take(27).toList(),
      module2Harder: ids.take(27).toList(), routeThreshold: 15,
    );
    final container = ProviderContainer(overrides: [
      contentBankProvider.overrideWith((ref) async => bank),
      progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
      progressProvider.overrideWith((ref) => Stream.value(ProgressSnapshot.empty)),
    ]);
    addTearDown(container.dispose);
    await container.read(contentBankProvider.future);
    container.read(paperSessionProvider.notifier)
      ..start(form)
      ..goTo(3)
      ..select('C')
      ..toggleMark();
    t.view.physicalSize = const Size(392, 860) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(), debugShowCheckedModeBanner: false, home: const TestScreen()),
    ));
    await t.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('preview/phone-test-screen.png'));
    container.read(paperSessionProvider.notifier).close();
  });

  testWidgets('skill screen', (t) async {
    await shot(t, const SkillScreen(type: 'boundaries'), 'phone-skill-lesson', const Size(392, 860));
  });
}
