/// Expression evaluation for figures and the built-in calculator, on top of
/// math_expressions. Accepts Python-style `**`, `exp(…)`, `pi`, implicit
/// multiplication (`2x`, `3(x+1)`, `)(`), and a degree mode for trig.
library;

import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

String normalizeExpr(String src, {bool degrees = false}) {
  var s = src
      .replaceAll('**', '^')
      .replaceAll('π', 'pi')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(RegExp(r'\bexp\('), 'e^(')
      .replaceAll(' ', '');
  // Implicit multiplication: 2x, 2(, )(, )x, x(  (not for function names).
  s = s.replaceAllMapped(RegExp(r'(\d|\))(?=[a-zA-Z(])'), (m) => '${m[1]}*');
  s = s.replaceAllMapped(RegExp(r'\b(x|y|pi|e)(?=\()'), (m) => '${m[1]}*');
  if (degrees) {
    s = s.replaceAllMapped(
      RegExp(r'\b(sin|cos|tan)\('),
      (m) => '${m[1]}(pi/180*',
    );
  }
  return s;
}

/// Compiles [src] once; the result evaluates it at a given x (null when the
/// value is undefined, e.g. sqrt of a negative or division by zero).
double? Function(double x)? compileExpr(String src, {bool degrees = false}) {
  final f = compileExpr2(src, degrees: degrees);
  return f == null ? null : (x) => f(x, 0);
}

/// Like [compileExpr] for an expression in x and y.
double? Function(double x, double y)? compileExpr2(
  String src, {
  bool degrees = false,
}) {
  final Expression e;
  try {
    e = ShuntingYardParser().parse(
      normalizeExpr(_expandStats(src), degrees: degrees),
    );
  } on Object {
    return null;
  }
  return (x, y) {
    final cm = ContextModel()
      ..bindVariableName('x', Number(x))
      ..bindVariableName('y', Number(y))
      ..bindVariableName('pi', Number(math.pi));
    try {
      final v = e.evaluate(EvaluationType.REAL, cm) as num;
      return v.isFinite ? v.toDouble() : null;
    } on Object {
      return null;
    }
  };
}

/// Evaluates a constant expression (calculator). Null when invalid.
double? evalExpr(String src, {bool degrees = false}) =>
    compileExpr(src, degrees: degrees)?.call(0);

final _stat = RegExp(r'\b(mean|median|stdev|sum)\(([^()]*)\)');

/// Replaces mean(…), median(…), stdev(…) (population) and sum(…) over a
/// comma list by their values, innermost first. Brackets around the list are
/// allowed: mean([2, 3, 4]).
String _expandStats(String src) {
  var s = src;
  for (var guard = 0; guard < 20; guard++) {
    final m = _stat.firstMatch(s);
    if (m == null) return s;
    final parts = m[2]!.replaceAll(RegExp(r'[\[\]]'), '').split(',');
    final xs = [for (final p in parts) evalExpr(p)];
    if (xs.isEmpty || xs.any((v) => v == null)) return s; // leave it: invalid
    final v = statOf(m[1]!, [for (final x in xs) x!]);
    s = s.replaceRange(m.start, m.end, '($v)');
  }
  return s;
}

/// mean, median, stdev (population) or sum of [xs].
double statOf(String name, List<double> xs) {
  final n = xs.length;
  final mean = xs.reduce((a, b) => a + b) / n;
  switch (name) {
    case 'sum':
      return mean * n;
    case 'median':
      final s = [...xs]..sort();
      return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
    case 'stdev':
      final v = xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b);
      return math.sqrt(v / n);
    default:
      return mean;
  }
}

/// One line typed into the Graph tab.
sealed class GraphEntry {
  const GraphEntry();
}

/// y as a function of x (from `y = …`, `f(x) = …`, a bare expression, or an
/// equation that is linear in y such as `3x - 4y = 8`).
class CurveEntry extends GraphEntry {
  const CurveEntry(this.f);
  final double? Function(double x) f;
}

/// `x = c`.
class VerticalEntry extends GraphEntry {
  const VerticalEntry(this.x);
  final double x;
}

/// `(a, b)`.
class PointEntry extends GraphEntry {
  const PointEntry(this.x, this.y);
  final double x;
  final double y;
}

/// Why an entry could not be graphed.
class BadEntry extends GraphEntry {
  const BadEntry(this.message);
  final String message;
}

final _point = RegExp(r'^\(([^,()]+(?:\([^()]*\))?[^,()]*),(.+)\)$');

/// Parses one Graph-tab entry.
GraphEntry parseGraphEntry(String raw) {
  final src = raw.replaceAll(' ', '').replaceAll('−', '-');
  if (src.isEmpty) return const BadEntry('Empty');
  if (_point.firstMatch(src) case final m?) {
    final x = evalExpr(m[1]!);
    final y = evalExpr(m[2]!);
    if (x != null && y != null) return PointEntry(x, y);
  }
  final sides = src.split('=');
  if (sides.length > 2) return const BadEntry('Use one = sign');
  if (sides.length == 1 || RegExp(r'^(y|[a-z]\(x\))$').hasMatch(sides[0])) {
    final f = compileExpr(sides.last);
    return f == null ? const BadEntry('Not a valid expression') : CurveEntry(f);
  }
  if (sides[0] == 'x' && !RegExp('[xy]').hasMatch(sides[1])) {
    final c = evalExpr(sides[1]);
    return c == null ? const BadEntry('Not a valid number') : VerticalEntry(c);
  }
  final g = compileExpr2('(${sides[0]})-(${sides[1]})');
  if (g == null) return const BadEntry('Not a valid equation');
  // Linear in y: g(x, y) = a(x) * y + b(x). Check at a few x values.
  for (final x in const [-3.1, 0.7, 2.3]) {
    final g0 = g(x, 0);
    final g1 = g(x, 1);
    final g2 = g(x, 2);
    if (g0 == null || g1 == null || g2 == null) continue;
    if ((g2 - 2 * g1 + g0).abs() > 1e-9 * (1 + g0.abs() + g1.abs())) {
      return const BadEntry('Only equations that can be solved for y');
    }
  }
  return CurveEntry((x) {
    final g0 = g(x, 0);
    final g1 = g(x, 1);
    if (g0 == null || g1 == null || (g1 - g0).abs() < 1e-12) return null;
    return -g0 / (g1 - g0);
  });
}

/// Turning points (local maxima and minima) of [f] on [lo, hi].
List<({double x, double y, bool max})> turningPoints(
  double? Function(double) f,
  double lo,
  double hi, {
  int steps = 800,
}) {
  final out = <({double x, double y, bool max})>[];
  final h = (hi - lo) / steps;
  double? prev;
  double? prevSlope;
  for (var i = 0; i <= steps; i++) {
    final x = lo + h * i;
    final y = f(x);
    if (y == null || prev == null) {
      prev = y;
      prevSlope = null;
      continue;
    }
    final slope = y - prev;
    if (prevSlope != null &&
        slope.abs() > 1e-15 &&
        prevSlope.abs() > 1e-15 &&
        (slope > 0) != (prevSlope > 0)) {
      final isMax = prevSlope > 0;
      // Golden-section refine on [x - 2h, x].
      var a = x - 2 * h;
      var b = x;
      for (var k = 0; k < 60; k++) {
        final m1 = a + (b - a) * 0.382;
        final m2 = a + (b - a) * 0.618;
        final f1 = f(m1);
        final f2 = f(m2);
        if (f1 == null || f2 == null) break;
        if ((f1 > f2) == isMax) {
          b = m2;
        } else {
          a = m1;
        }
      }
      final xm = (a + b) / 2;
      if (f(xm) case final ym?) out.add((x: xm, y: ym, max: isMax));
    }
    prev = y;
    prevSlope = slope;
  }
  return out;
}

/// Real zeros of [f] on [lo, hi] found by sign changes + bisection.
List<double> zerosOf(
  double? Function(double) f,
  double lo,
  double hi, {
  int steps = 800,
}) {
  final out = <double>[];
  double? prevX;
  double? prevY;
  for (var i = 0; i <= steps; i++) {
    final x = lo + (hi - lo) * i / steps;
    final y = f(x);
    if (y != null && y.abs() < 1e-12) {
      out.add(x);
    } else if (y != null &&
        prevY != null &&
        prevX != null &&
        (y > 0) != (prevY > 0)) {
      var a = prevX;
      var b = x;
      var fa = prevY;
      for (var k = 0; k < 60; k++) {
        final m = (a + b) / 2;
        final fm = f(m);
        if (fm == null) break;
        if ((fm > 0) == (fa > 0)) {
          a = m;
          fa = fm;
        } else {
          b = m;
        }
      }
      final root = (a + b) / 2;
      if ((f(root) ?? double.infinity).abs() < 1e-6) out.add(root);
    }
    prevX = x;
    prevY = y;
  }
  final dedup = <double>[];
  for (final r in out) {
    if (dedup.isEmpty || (r - dedup.last).abs() > (hi - lo) / steps * 2) {
      dedup.add(r);
    }
  }
  return dedup;
}
