import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/scoring.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final bank = ContentBank.fromJson(
    _json('assets/data/rw_bank.json'),
  ).withMath(_json('assets/data/math_bank.json'));
  final forms = bank.formsOf('math');

  test('20 Math papers, 3 modules of 22', () {
    expect(forms.length, 20);
    for (final f in forms) {
      expect(f.section, 'math');
      for (final ids in [f.module1, ...ModuleRoute.values.map(f.module2)]) {
        expect(bank.itemsOf(ids).length, 22, reason: f.id);
      }
    }
  });

  test('simulated students score alike on every paper', () {
    final rng = math.Random(11);
    const abilities = [-2.0, -1.0, 0.0, 1.0, 2.0];
    final means = <double, List<double>>{};
    for (final theta in abilities) {
      for (final f in forms) {
        var total = 0.0;
        const students = 300;
        for (var s = 0; s < students; s++) {
          List<Response> answer(List<String> ids) => [
            for (final i in bank.itemsOf(ids))
              (
                difficulty: i.difficulty,
                correct: rng.nextDouble() < rasch(theta, i.difficulty),
              ),
          ];
          final m1 = answer(f.module1);
          final route = routeAfterModule1(
            m1.where((r) => r.correct).length,
            f.routeThreshold,
          );
          final all = [...m1, ...answer(f.module2(route))];
          total += estimateScore(all, route).score;
        }
        (means[theta] ??= []).add(total / students);
      }
    }
    for (final MapEntry(key: theta, value: m) in means.entries) {
      final spread = m.reduce(math.max) - m.reduce(math.min);
      // ignore: avoid_print
      print('ability $theta: mean ${m.map((v) => v.round()).join(' ')}');
      expect(spread, lessThan(25), reason: 'ability $theta spread $spread');
    }
    final overall = [
      for (final t in abilities) means[t]!.reduce((a, b) => a + b) / 10,
    ];
    for (var i = 1; i < overall.length; i++) {
      expect(overall[i], greaterThan(overall[i - 1] + 40));
    }
  });
}
