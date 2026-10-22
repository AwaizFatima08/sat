/// Score estimate for a Reading and Writing section: a Rasch (1PL) ability
/// estimate over every answered item, mapped onto the 200–800 scale.
///
/// College Board's real scoring uses secret item parameters, so this is an
/// estimate by design; the app always shows it with a ± band.
library;

import 'dart:math' as math;

import 'package:moduleup/engine/content.dart';

/// One scored response: the item's difficulty and whether it was correct.
typedef Response = ({double difficulty, bool correct});

/// The estimate shown on the score report.
class ScoreEstimate {
  const ScoreEstimate({
    required this.score,
    required this.low,
    required this.high,
    required this.ability,
    required this.standardError,
  });

  /// Section score, rounded to a multiple of 10 like the real test.
  final int score;
  final int low;
  final int high;
  final double ability;
  final double standardError;

  int get band => ((high - low) / 2).round();
}

/// Ability → scaled score anchors (piecewise linear between them).
const List<(double, double)> _scaleTable = [
  (-4, 200),
  (-3, 240),
  (-2, 330),
  (-1, 430),
  (0, 520),
  (1, 610),
  (2, 700),
  (3, 770),
  (3.8, 800),
];

/// Highest score reachable on the easier second module, as on the real test.
const int easierRouteCap = 610;

/// Probability of a correct answer under the Rasch model.
double rasch(double ability, double difficulty) =>
    1 / (1 + math.exp(difficulty - ability));

/// Expected a posteriori ability with a standard normal prior, evaluated on a
/// fine grid. Total: works for all-correct and all-wrong response sets.
({double ability, double standardError}) estimateAbility(
  List<Response> responses,
) {
  const lo = -5.0;
  const hi = 5.0;
  const steps = 401;
  var sumW = 0.0;
  var sumWT = 0.0;
  var sumWT2 = 0.0;
  for (var i = 0; i < steps; i++) {
    final t = lo + (hi - lo) * i / (steps - 1);
    var logL = -t * t / 2;
    for (final r in responses) {
      final p = rasch(t, r.difficulty);
      logL += math.log(r.correct ? p : 1 - p);
    }
    final w = math.exp(logL);
    sumW += w;
    sumWT += w * t;
    sumWT2 += w * t * t;
  }
  final mean = sumWT / sumW;
  final variance = math.max(0, sumWT2 / sumW - mean * mean);
  return (ability: mean, standardError: math.sqrt(variance));
}

/// Maps an ability value onto the 200–800 scale.
double scaleScore(double ability) {
  if (ability <= _scaleTable.first.$1) return _scaleTable.first.$2;
  for (var i = 1; i < _scaleTable.length; i++) {
    final (t1, s1) = _scaleTable[i];
    if (ability <= t1) {
      final (t0, s0) = _scaleTable[i - 1];
      return s0 + (s1 - s0) * (ability - t0) / (t1 - t0);
    }
  }
  return _scaleTable.last.$2;
}

int _round10(double v) => ((v / 10).round() * 10).clamp(200, 800);

/// Section score estimate for a finished paper.
ScoreEstimate estimateScore(List<Response> responses, ModuleRoute route) {
  final est = estimateAbility(responses);
  final cap = route == ModuleRoute.easier ? easierRouteCap.toDouble() : 800.0;
  double scaled(double t) => math.min(scaleScore(t), cap);
  return ScoreEstimate(
    score: _round10(scaled(est.ability)),
    low: _round10(scaled(est.ability - est.standardError)),
    high: _round10(scaled(est.ability + est.standardError)),
    ability: est.ability,
    standardError: est.standardError,
  );
}

/// Which second module a student gets after module 1.
ModuleRoute routeAfterModule1(int module1Correct, int threshold) =>
    module1Correct >= threshold ? ModuleRoute.harder : ModuleRoute.easier;
