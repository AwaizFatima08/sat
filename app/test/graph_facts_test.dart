import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/engine/expr.dart';
import 'package:moduleup/features/math/graph_tab.dart';

void main() {
  test('facts: intersections, vertical lines and points', () {
    final facts = graphFacts(
      [
        parseGraphEntry('y = 200 - 10x'),
        parseGraphEntry('y = 50 + 20x'),
        parseGraphEntry('x = 2'),
        parseGraphEntry('(5, 150)'),
      ],
      -10,
      10,
    );
    expect(facts, contains('Lines 1 and 2 meet at (5, 150)'));
    expect(facts, contains('Lines 1 and 3 meet at (2, 180)'));
    expect(facts, contains('Point (5, 150) is on line 1'));
    expect(facts, contains('Point (5, 150) is on line 2'));
  });
}
