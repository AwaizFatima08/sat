// Renders the Play Store phone screenshots (1080x1920) to ../store/phone/*.png.
// Run: flutter test test/store_screens_test.dart --update-goldens --tags preview
@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/features/math/calculator.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/features/paper/test_screen.dart';
import 'package:moduleup/features/practice/practice_screen.dart';
import 'package:moduleup/features/practice/skill_screen.dart';
import 'package:moduleup/features/section/section.dart';
import 'package:moduleup/widgets/math_question_view.dart';

import 'paper_session_test.dart' show FakeProgressRepository;

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
    );
  }
  await loader.load();
}

class _MathSection extends SectionNotifier {
  @override
  String build() => 'math';
}

const _size = Size(432, 768); // x2.5 = 1080x1920
const _dpr = 2.5;

void main() {
  const fonts =
      '/mnt/storage/projects/flutter/bin/cache/artifacts/material_fonts';
  final katex =
      '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
      'flutter_math_fork-0.7.4/lib/katex_fonts/fonts';
  late ContentBank bank;

  setUpAll(() async {
    await _font('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Bold.ttf',
      '$fonts/Roboto-Medium.ttf',
    ]);
    await _font('serif', ['/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf']);
    await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    for (final f in Directory(katex).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last.split('-').first;
      await _font('packages/flutter_math_fork/$name', [f.path]);
    }
    Map<String, Object?> json(String p) =>
        jsonDecode(File(p).readAsStringSync()) as Map<String, Object?>;
    bank = ContentBank.fromJson(
      json('assets/data/rw_bank.json'),
    ).withMath(json('assets/data/math_bank.json'));
  });

  List<Override> overrides({bool math = false}) => [
    contentBankProvider.overrideWith((ref) async => bank),
    progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
    progressProvider.overrideWith(
      (ref) => Stream.value(ProgressSnapshot.empty),
    ),
    if (math) sectionProvider.overrideWith(_MathSection.new),
  ];

  Future<void> snap(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../store/phone/$name.png'),
  );

  Future<void> shot(
    WidgetTester t,
    Widget child,
    String name, {
    bool math = false,
  }) async {
    t.view.physicalSize = _size * _dpr;
    t.view.devicePixelRatio = _dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(math: math),
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
    await t.pumpAndSettle();
    await snap(t, name);
  }

  Future<void> testScreen(
    WidgetTester t,
    PaperForm form,
    int index,
    String answer,
    String name,
  ) async {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await container.read(contentBankProvider.future);
    container.read(paperSessionProvider.notifier)
      ..start(form)
      ..goTo(index)
      ..select(answer);
    t.view.physicalSize = _size * _dpr;
    t.view.devicePixelRatio = _dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          home: const TestScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await snap(t, name);
    container.read(paperSessionProvider.notifier).close();
  }

  testWidgets('1 math test with a figure', (t) async {
    final form = bank.formsOf('math')[2];
    final i = form.module1.indexWhere((id) {
      final it = bank.items[id]!;
      return it.figure != null && !it.isTyped && it.figure!['kind'] == 'xy';
    });
    await testScreen(t, form, i < 0 ? 0 : i, 'B', '1-math-test');
  });

  testWidgets('2 reading and writing test', (t) async {
    final form = bank.formsOf('rw')[0];
    await testScreen(t, form, 3, 'C', '2-rw-test');
  });

  testWidgets('3 math solution', (t) async {
    final item = bank.items.values.firstWhere(
      (i) =>
          i.section == 'math' &&
          i.isTyped &&
          i.level == 3 &&
          i.solution.length >= 3 &&
          i.figure == null,
    );
    await shot(
      t,
      Scaffold(
        appBar: AppBar(title: Text(bank.bpForItem(item).types[item.type]!.name)),
        body: MathQuestionView(
          item: item,
          response: item.typedAnswers.first,
          revealed: true,
        ),
      ),
      '3-math-solution',
    );
  });

  testWidgets('4 graphing calculator', (t) async {
    t.view.physicalSize = _size * _dpr;
    t.view.devicePixelRatio = _dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Calculator')),
          body: const CalculatorPanel(),
        ),
      ),
    );
    await t.tap(find.text('Graph'));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'y = x^2 - 4x + 1');
    await t.enterText(fields.at(1), '2x - y = 3');
    await t.pumpAndSettle();
    await snap(t, '4-calculator');
  });

  testWidgets('5 math practice', (t) async {
    await shot(
      t,
      const Scaffold(body: SafeArea(child: PracticeScreen())),
      '5-math-practice',
      math: true,
    );
  });

  testWidgets('6 math lesson', (t) async {
    await shot(
      t,
      const SkillScreen(type: 'nonlin_func'),
      '6-math-lesson',
      math: true,
    );
  });
}
