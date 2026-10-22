import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/engine/scoring.dart';

Item _item(
  String id, {
  int level = 2,
  String type = 'transitions',
  String pool = 'drill',
}) => Item(
  id: id,
  type: type,
  domain: 'expression',
  level: level,
  difficulty: const {1: -1.5, 2: -0.5, 3: 0.5, 4: 1.5}[level]!,
  subject: 'science',
  pool: pool,
  stem: 'stem',
  choices: const {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd'},
  answer: 'A',
  why: 'why',
  choiceExplanations: const {'A': '', 'B': '', 'C': '', 'D': ''},
  traps: const {'B': 'too_broad', 'C': 'reversed', 'D': 'not_in_text'},
);

/// A 54-item paper: module 1 mixed, module 2 by route.
List<Response> _paper({required int correctOf54, required Route route}) {
  final levels = [
    ...List.filled(6, 1),
    ...List.filled(9, 2),
    ...List.filled(9, 3),
    ...List.filled(3, 4),
    if (route == Route.harder) ...[
      ...List.filled(5, 2),
      ...List.filled(12, 3),
      ...List.filled(10, 4),
    ] else ...[
      ...List.filled(10, 1),
      ...List.filled(12, 2),
      ...List.filled(5, 3),
    ],
  ];
  // Students get the easiest items right first.
  final order = List.generate(54, (i) => i)
    ..sort((a, b) => levels[a].compareTo(levels[b]));
  final right = order.take(correctOf54).toSet();
  return [
    for (var i = 0; i < 54; i++)
      (
        difficulty: const {1: -1.5, 2: -0.5, 3: 0.5, 4: 1.5}[levels[i]]!,
        correct: right.contains(i),
      ),
  ];
}

void main() {
  group('scoring', () {
    test('more correct answers never lower the score', () {
      var last = 0;
      for (var c = 0; c <= 54; c++) {
        final s = estimateScore(
          _paper(correctOf54: c, route: Route.harder),
          Route.harder,
        ).score;
        expect(s, greaterThanOrEqualTo(last), reason: '$c correct');
        last = s;
      }
    });

    test('extremes land near the ends of the scale', () {
      expect(
        estimateScore(
          _paper(correctOf54: 54, route: Route.harder),
          Route.harder,
        ).score,
        greaterThanOrEqualTo(750),
      );
      expect(
        estimateScore(
          _paper(correctOf54: 0, route: Route.easier),
          Route.easier,
        ).score,
        lessThanOrEqualTo(260),
      );
    });

    test('the easier route is capped', () {
      final s = estimateScore(
        _paper(correctOf54: 54, route: Route.easier),
        Route.easier,
      );
      expect(s.score, lessThanOrEqualTo(easierRouteCap));
      expect(s.high, lessThanOrEqualTo(easierRouteCap));
    });

    test('band brackets the score and scores are multiples of 10', () {
      final s = estimateScore(
        _paper(correctOf54: 30, route: Route.harder),
        Route.harder,
      );
      expect(s.low, lessThanOrEqualTo(s.score));
      expect(s.high, greaterThanOrEqualTo(s.score));
      expect(s.score % 10, 0);
    });

    test('golden vectors stay stable', () {
      // Changing the scale table or prior must be a deliberate decision.
      final got = [
        for (final c in [10, 27, 40, 50])
          estimateScore(
            _paper(correctOf54: c, route: Route.harder),
            Route.harder,
          ).score,
      ];
      expect(got, [400, 540, 640, 740]);
    });

    test('routing uses the threshold', () {
      expect(routeAfterModule1(15, 15), Route.harder);
      expect(routeAfterModule1(14, 15), Route.easier);
    });
  });

  group('notebook', () {
    final t0 = DateTime.utc(2026, 10, 22, 9);
    test(
      'wrong answer enters at stage 0 due in 1 day, then 3, then 7, then leaves',
      () {
        var nb = updateNotebook({}, itemId: 'x', correct: false, now: t0);
        expect(nb['x']!.dueAt, t0.add(const Duration(days: 1)));
        var now = t0.add(const Duration(days: 1));
        nb = updateNotebook(nb, itemId: 'x', correct: true, now: now);
        expect(nb['x']!.stage, 1);
        expect(nb['x']!.dueAt, now.add(const Duration(days: 3)));
        now = now.add(const Duration(days: 3));
        nb = updateNotebook(nb, itemId: 'x', correct: true, now: now);
        expect(nb['x']!.stage, 2);
        now = now.add(const Duration(days: 7));
        nb = updateNotebook(nb, itemId: 'x', correct: true, now: now);
        expect(nb.containsKey('x'), isFalse);
      },
    );

    test('correct before due does not advance; wrong resets', () {
      var nb = updateNotebook({}, itemId: 'x', correct: false, now: t0);
      nb = updateNotebook(nb, itemId: 'x', correct: true, now: t0);
      expect(nb['x']!.stage, 0);
      nb = updateNotebook(
        nb,
        itemId: 'x',
        correct: false,
        now: t0.add(const Duration(days: 2)),
      );
      expect(nb['x']!.stage, 0);
    });
  });

  group('drill picker', () {
    final items = [for (var i = 0; i < 30; i++) _item('i$i', level: i % 2 + 1)];
    test('deterministic for a seed and filtered by level', () {
      final a = pickDrill(
        items: items,
        type: 'transitions',
        level: 1,
        lastSeen: {},
        seed: 7,
      );
      final b = pickDrill(
        items: items,
        type: 'transitions',
        level: 1,
        lastSeen: {},
        seed: 7,
      );
      expect(a.map((i) => i.id), b.map((i) => i.id));
      expect(a.every((i) => i.level == 1), isTrue);
      expect(a, hasLength(10));
    });
    test('unseen items come before seen ones', () {
      final seen = {for (var i = 0; i < 20; i += 2) 'i$i': DateTime.utc(2026)};
      final a = pickDrill(
        items: items,
        type: 'transitions',
        level: 1,
        lastSeen: seen,
        seed: 1,
      );
      expect(a.take(5).every((i) => !seen.containsKey(i.id)), isTrue);
    });
  });

  group('results', () {
    final items = {for (var i = 0; i < 10; i++) 'i$i': _item('i$i')};
    final t = DateTime.utc(2026, 10, 22);
    DrillResult drill(int right) => DrillResult(
      type: 'transitions',
      level: 2,
      finishedAt: t,
      responses: [
        for (var i = 0; i < 10; i++)
          ItemResponse(
            itemId: 'i$i',
            seconds: 60,
            answer: i < right ? 'A' : 'B',
          ),
      ],
    );

    test('breakdown counts traps and pace', () {
      final b = breakdown(drill(7).responses, items);
      expect(b.overall.correct, 7);
      expect(b.trapCounts, {'too_broad': 3});
      expect(b.secondsByType['transitions'], 60);
    });

    test('mastery ladder', () {
      Mastery m(List<DrillResult> d) => masteryFor(
        type: 'transitions',
        level: 2,
        drills: d,
        papers: const [],
        items: items,
      );
      expect(m([]), Mastery.notStarted);
      expect(m([drill(6)]), Mastery.notStarted);
      expect(m([drill(7)]), Mastery.familiar);
      expect(m([drill(7), drill(10)]), Mastery.proficient);
    });

    test('paper result survives a JSON round trip', () {
      final form = PaperForm(
        id: 'paper-01',
        number: 1,
        title: 'Paper 1',
        module1: const ['i0'],
        module2Easier: const ['i1'],
        module2Harder: const ['i2'],
        routeThreshold: 1,
      );
      final r = scorePaper(
        form: form,
        route: Route.harder,
        items: items,
        finishedAt: t,
        module1: const [ItemResponse(itemId: 'i0', seconds: 50, answer: 'A')],
        module2: const [
          ItemResponse(itemId: 'i2', seconds: 40, answer: 'C', marked: true),
        ],
      );
      final back = PaperResult.fromJson(r.toJson());
      expect(back.estimate.score, r.estimate.score);
      expect(back.module2.single.marked, isTrue);
      expect(back.route, Route.harder);
    });
  });
}
