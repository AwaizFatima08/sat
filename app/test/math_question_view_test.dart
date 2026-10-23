import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/widgets/math_figure.dart';
import 'package:moduleup/widgets/math_question_view.dart';
import 'package:moduleup/widgets/question_view.dart';

Item _item(String path) => Item.fromJson(
  jsonDecode(File('../content/math/items/$path').readAsStringSync())
      as Map<String, Object?>,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('typed answer: entering, clearing and the reveal', (t) async {
    final item = _item('systems/m-sys-0004.json'); // accepts 11/2
    final answers = <String>[];
    await t.pumpWidget(
      _host(ItemQuestionView(item: item, onSelect: answers.add)),
    );
    await t.enterText(find.byType(TextField), '11/2');
    await t.enterText(find.byType(TextField), '');
    expect(answers, ['11/2', '']);
    expect(item.isCorrect('5.5'), isTrue);

    await t.pumpWidget(
      _host(ItemQuestionView(item: item, selected: '5.5', revealed: true)),
    );
    expect(find.textContaining('Correct.'), findsOneWidget);
    expect(find.text('Solution'), findsOneWidget);
  });

  testWidgets('multiple choice with a figure shows four choices', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final item = _item('area_volume/m-arv-0001.json');
    String? picked;
    await t.pumpWidget(
      _host(ItemQuestionView(item: item, onSelect: (l) => picked = l)),
    );
    expect(find.byType(ChoiceTile), findsNWidgets(4));
    expect(find.byType(MathFigure), findsOneWidget);
    await t.tap(find.text('A'));
    expect(picked, 'A');
  });
}
