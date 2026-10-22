import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/engine/content.dart';

/// A worked example on a strategy card.
class WorkedExample {
  const WorkedExample({
    required this.stem,
    required this.choices,
    required this.answer,
    required this.walkthrough,
    this.passage,
    this.passageB,
    this.notes,
    this.data,
  });

  factory WorkedExample.fromJson(Map<String, Object?> j) => WorkedExample(
    passage: j['passage'] as String?,
    passageB: j['passage_b'] as String?,
    notes: (j['notes'] as List?)?.cast<String>(),
    data: j['data'] == null
        ? null
        : ItemData.fromJson(j['data']! as Map<String, Object?>),
    stem: j['stem']! as String,
    choices: Map<String, String>.from(j['choices']! as Map),
    answer: j['answer']! as String,
    walkthrough: List<String>.from(j['walkthrough']! as List),
  );

  final String? passage;
  final String? passageB;
  final List<String>? notes;
  final ItemData? data;
  final String stem;
  final Map<String, String> choices;
  final String answer;
  final List<String> walkthrough;
}

class StrategyCard {
  const StrategyCard({
    required this.level,
    required this.title,
    required this.steps,
    required this.example,
    required this.tryIt,
  });

  factory StrategyCard.fromJson(Map<String, Object?> j) => StrategyCard(
    level: j['level']! as int,
    title: j['title']! as String,
    steps: List<String>.from(j['steps']! as List),
    example: WorkedExample.fromJson(
      j['worked_example']! as Map<String, Object?>,
    ),
    tryIt: List<String>.from(j['tryit']! as List),
  );

  final int level;
  final String title;
  final List<String> steps;
  final WorkedExample example;
  final List<String> tryIt;
}

/// Lesson notes and strategy cards for one question type.
class Lesson {
  const Lesson({
    required this.type,
    required this.title,
    required this.whatIsTested,
    required this.howToSpot,
    required this.method,
    required this.pitfalls,
    required this.cards,
    this.usUk,
  });

  factory Lesson.fromJson(Map<String, Object?> j) => Lesson(
    type: j['type']! as String,
    title: j['title']! as String,
    whatIsTested: j['what_is_tested']! as String,
    howToSpot: j['how_to_spot']! as String,
    method: List<String>.from(j['method']! as List),
    pitfalls: List<String>.from(j['pitfalls'] as List? ?? const []),
    usUk: j['us_uk'] as String?,
    cards: [
      for (final c in j['cards']! as List)
        StrategyCard.fromJson(c as Map<String, Object?>),
    ]..sort((a, b) => a.level.compareTo(b.level)),
  );

  final String type;
  final String title;
  final String whatIsTested;
  final String howToSpot;
  final List<String> method;
  final List<String> pitfalls;
  final String? usUk;
  final List<StrategyCard> cards;
}

/// Everything shipped in `assets/data/rw_bank.json`.
class ContentBank {
  const ContentBank({
    required this.version,
    required this.blueprint,
    required this.items,
    required this.forms,
    required this.lessons,
    required this.reference,
    required this.moduleTypeCounts,
  });

  factory ContentBank.fromJson(Map<String, Object?> j) {
    final bp = j['blueprint']! as Map<String, Object?>;
    final items = {
      for (final raw in j['items']! as List)
        (raw as Map<String, Object?>)['id']! as String: Item.fromJson(raw),
    };
    return ContentBank(
      version: j['version']! as String,
      blueprint: Blueprint.fromJson(bp),
      items: items,
      forms: [
        for (final f in j['forms']! as List)
          PaperForm.fromJson(f as Map<String, Object?>),
      ]..sort((a, b) => a.number.compareTo(b.number)),
      lessons: {
        for (final l in j['lessons']! as List)
          (l as Map<String, Object?>)['type']! as String: Lesson.fromJson(l),
      },
      reference: Map<String, Object?>.from(j['reference']! as Map),
      moduleTypeCounts: Map<String, int>.from(
        ((bp['module_blueprint']! as Map)['types']) as Map,
      ),
    );
  }

  final String version;
  final Blueprint blueprint;
  final Map<String, Item> items;
  final List<PaperForm> forms;
  final Map<String, Lesson> lessons;

  /// Raw reference guides (grammar, wordbank, traps, testday) as decoded JSON.
  final Map<String, Object?> reference;

  /// Questions of each type in one module (used for timed module practice).
  final Map<String, int> moduleTypeCounts;

  PaperForm? form(String id) {
    for (final f in forms) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Item> itemsOf(Iterable<String> ids) => [
    for (final id in ids) ?items[id],
  ];

  /// Drill items available for one type and level.
  int drillCount(String type, int level) => items.values
      .where((i) => i.pool == 'drill' && i.type == type && i.level == level)
      .length;
}

ContentBank _decode(String raw) =>
    ContentBank.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// Loads and parses the bank once, off the UI isolate.
final contentBankProvider = FutureProvider<ContentBank>((ref) async {
  final raw = await rootBundle.loadString('assets/data/rw_bank.json');
  return compute(_decode, raw);
});
