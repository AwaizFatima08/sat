import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/engine/expr.dart';

void main() {
  testWidgets('tex renders', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Math.tex(r'\frac{3x+2}{5}=\sqrt{y^2-1}')),
      ),
    );
    expect(find.byType(Math), findsOneWidget);
  });

  test('expressions: python syntax, implicit multiplication, pi, exp', () {
    double at(String s, double x) => compileExpr(s)!(x)!;
    expect(at('2*x**2+3', 2), 11);
    expect(at('2x+1', 3), 7);
    expect(at('3(x+1)', 1), 6);
    expect(at('exp(x)', 0), 1);
    expect(at('pi*x', 1), closeTo(3.14159, 1e-4));
    expect(compileExpr('sqrt(x)')!(-1), isNull);
    expect(evalExpr('sin(30)', degrees: true), closeTo(0.5, 1e-9));
    expect(compileExpr('2x+'), isNull);
  });

  test('zeros', () {
    final f = compileExpr('x**2 - 4x + 3')!;
    final z = zerosOf(f, -5, 10);
    expect(z.length, 2);
    expect(z[0], closeTo(1, 1e-6));
    expect(z[1], closeTo(3, 1e-6));
  });

  test('statistics functions', () {
    expect(evalExpr('mean(3, 5, 8)'), closeTo(16 / 3, 1e-9));
    expect(evalExpr('median([2,3,3,4,5,5,6,7])'), 4.5);
    expect(evalExpr('stdev(2, 4, 4, 4, 5, 5, 7, 9)'), closeTo(2, 1e-9));
    expect(evalExpr('sum(1,2,3) * 2'), 12);
  });

  test('graph entries', () {
    final line = parseGraphEntry('3x - 4y = 8') as CurveEntry;
    expect(line.f(0), closeTo(-2, 1e-9));
    expect(line.f(4), closeTo(1, 1e-9));
    expect((parseGraphEntry('y = x^2') as CurveEntry).f(3), 9);
    expect((parseGraphEntry('f(x) = 2x + 1') as CurveEntry).f(1), 3);
    expect((parseGraphEntry('x = 5') as VerticalEntry).x, 5);
    final p = parseGraphEntry('(2, -3.5)') as PointEntry;
    expect((p.x, p.y), (2, -3.5));
    expect(parseGraphEntry('x^2 + y^2 = 9'), isA<BadEntry>());
    expect(parseGraphEntry('2x+'), isA<BadEntry>());
  });

  test('turning points', () {
    final f = compileExpr('-5x^2 + 30x + 35')!;
    final t = turningPoints(f, -10, 10).single;
    expect(t.max, isTrue);
    expect(t.x, closeTo(3, 1e-6));
    expect(t.y, closeTo(80, 1e-6));
  });
}
