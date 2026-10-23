import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/features/paper/paper_session.dart';
import 'package:moduleup/features/practice/drill_session.dart';

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 10, 22, 9);
}

class FakeProgressRepository implements ProgressRepository {
  final papers = <PaperResult>[];
  final drills = <DrillResult>[];
  final sessions = <SavedPaperSession>[];
  Map<String, MistakeEntry> notebook = {};

  @override
  Stream<ProgressSnapshot> watch() => Stream.value(ProgressSnapshot.empty);
  @override
  Future<void> saveProfile(StudentProfile profile) async {}
  @override
  Future<void> saveSession(SavedPaperSession session) async =>
      sessions.add(session);
  @override
  Future<void> recordPaper(
    PaperResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  }) async {
    papers.add(result);
    this.notebook = notebook;
  }

  @override
  Future<void> recordDrill(
    DrillResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  }) async {
    drills.add(result);
    this.notebook = notebook;
  }

  @override
  Future<void> deleteAll() async {}
}

/// The real content pack, with a synthetic paper built from whatever items it has.
ContentBank _bank() {
  final raw =
      jsonDecode(File('assets/data/rw_bank.json').readAsStringSync())
          as Map<String, Object?>;
  final bank = ContentBank.fromJson(raw);
  final ids = bank.items.keys.toList();
  final form = PaperForm(
    id: 'paper-test',
    number: 1,
    title: 'Test paper',
    module1: ids.take(27).toList(),
    module2Easier: ids.skip(27).take(27).toList(),
    module2Harder: ids.skip(54).take(27).toList(),
    routeThreshold: 15,
  );
  return ContentBank(
    version: bank.version,
    blueprint: bank.blueprint,
    items: bank.items,
    forms: [form],
    lessons: bank.lessons,
    reference: bank.reference,
    moduleTypeCounts: bank.moduleTypeCounts,
  );
}

void main() {
  late ProviderContainer c;
  late FakeProgressRepository repo;
  late ContentBank bank;

  setUp(() async {
    bank = _bank();
    repo = FakeProgressRepository();
    c = ProviderContainer.test(
      overrides: [
        contentBankProvider.overrideWith((ref) async => bank),
        progressRepositoryProvider.overrideWithValue(repo),
        progressProvider.overrideWith(
          (ref) => Stream.value(ProgressSnapshot.empty),
        ),
        clockProvider.overrideWithValue(_FixedClock()),
      ],
    );
    await c.read(contentBankProvider.future);
    c.listen(progressProvider, (_, _) {});
    await c.read(progressProvider.future);
  });

  test(
    'a perfect module 1 routes to the harder module and scores high',
    () async {
      final n = c.read(paperSessionProvider.notifier)..start(bank.forms.single);
      for (var i = 0; i < 27; i++) {
        n.select(c.read(paperSessionProvider)!.current.answer);
        n.next();
      }
      expect(c.read(paperSessionProvider)!.phase, PaperPhase.checkWork);
      await n.endModule();
      final s = c.read(paperSessionProvider)!;
      expect(s.route, ModuleRoute.harder);
      expect(s.phase, PaperPhase.betweenModules);
      expect(s.items.map((i) => i.id), bank.forms.single.module2Harder);
      n.beginModule2();
      for (var i = 0; i < 27; i++) {
        n.select(c.read(paperSessionProvider)!.current.answer);
        n.next();
      }
      await n.endModule();
      final done = c.read(paperSessionProvider)!;
      expect(done.phase, PaperPhase.finished);
      expect(repo.papers.single.estimate.score, greaterThanOrEqualTo(700));
      expect(repo.papers.single.all, hasLength(54));
      expect(repo.notebook, isEmpty);
      n.close();
    },
  );

  test(
    'a blank module 1 routes to the easier module; wrong answers enter the notebook',
    () async {
      final n = c.read(paperSessionProvider.notifier)..start(bank.forms.single);
      await n.endModule();
      expect(c.read(paperSessionProvider)!.route, ModuleRoute.easier);
      n.beginModule2();
      final first = c.read(paperSessionProvider)!.current;
      n.select(answerLetters.firstWhere((l) => l != first.answer));
      await n.endModule();
      expect(repo.papers.single.route, ModuleRoute.easier);
      expect(repo.papers.single.estimate.score, lessThanOrEqualTo(610));
      expect(repo.notebook, hasLength(54));
      n.close();
    },
  );

  test('leaving mid-paper saves a resumable, untimed session', () {
    final n = c.read(paperSessionProvider.notifier)..start(bank.forms.single);
    n
      ..select('B')
      ..pauseAndSave();
    final saved = repo.sessions.last;
    expect(saved.untimed, isTrue);
    expect(saved.module1.first.answer, 'B');
    n
      ..close()
      ..start(bank.forms.single, resume: saved);
    expect(c.read(paperSessionProvider)!.currentState.answer, 'B');
    expect(c.read(paperSessionProvider)!.untimed, isTrue);
    n.close();
  });

  test('a skill drill gives instant feedback and records the result', () async {
    final d = c.read(drillProvider.notifier);
    final type = bank.items.values.firstWhere((i) => i.pool == 'drill').type;
    expect(d.startSkill(type, 1), isTrue);
    final s = c.read(drillProvider)!;
    expect(s.instantFeedback, isTrue);
    for (var i = 0; i < s.items.length; i++) {
      d
        ..select(c.read(drillProvider)!.current.answer)
        ..check();
      expect(c.read(drillProvider)!.revealed, isTrue);
      await d.next();
    }
    expect(c.read(drillProvider)!.finished, isTrue);
    expect(repo.drills.single.responses.every((r) => r.answer != null), isTrue);
    d.close();
    unawaited(Future<void>.value());
  });
}
