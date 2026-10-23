import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/engine/spr.dart';
import 'package:moduleup/widgets/math_question_view.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final bank = ContentBank.fromJson(
    _json('assets/data/rw_bank.json'),
  ).withMath(_json('assets/data/math_bank.json'));
  final math = bank.items.values.where((i) => i.section == 'math').toList();

  test('the Math pack parses: items, blueprint, lessons', () {
    expect(math.length, greaterThan(1000));
    expect(bank.math!.blueprint.moduleItems, 22);
    expect(bank.lessonsOf('math').length, 19);
    for (final i in math) {
      expect(bank.bpForItem(i).types, contains(i.type), reason: i.id);
    }
  });

  test('every typed answer key is accepted by the SPR grader', () {
    for (final i in math.where((i) => i.isTyped)) {
      expect(i.typedAnswers, isNotEmpty, reason: i.id);
      for (final a in i.typedAnswers) {
        expect(gradeSpr(a, i.typedAnswers), isTrue, reason: '${i.id} $a');
      }
      expect(i.isCorrect(i.typedAnswers.first), isTrue, reason: i.id);
    }
  });

  test('every worked example becomes a Math item', () {
    for (final MapEntry(key: type, value: lesson)
        in bank.lessonsOf('math').entries) {
      for (final card in lesson.cards) {
        final item = card.example.asMathItem(
          type: type,
          domain: bank.bpOfType(type).types[type]!.domain,
          level: card.level,
        );
        expect(item.isCorrect(card.example.answer), isTrue, reason: item.id);
        expect(item.solution, isNotEmpty);
      }
    }
  });

  testWidgets('every Math item renders without errors', (t) async {
    t.view.physicalSize = const Size(390, 3000); // a phone's width
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final i in math) {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemQuestionView(
              key: ValueKey(i.id),
              item: i,
              revealed: true,
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: i.id);
    }
  });
}
