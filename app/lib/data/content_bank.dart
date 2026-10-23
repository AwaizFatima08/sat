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
    this.raw = const {},
  });

  factory WorkedExample.fromJson(Map<String, Object?> j) => WorkedExample(
    raw: j,
    passage: j['passage'] as String?,
    passageB: j['passage_b'] as String?,
    notes: (j['notes'] as List?)?.cast<String>(),
    data: j['data'] == null
        ? null
        : ItemData.fromJson(j['data']! as Map<String, Object?>),
    stem: j['stem']! as String,
    choices: Map<String, String>.from(j['choices'] as Map? ?? const {}),
    answer:
        j['answer'] as String? ??
        ((j['spr_answers'] as List?)?.first as String? ?? ''),
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

  /// The example as written, so a Math example (figure, typed answer) can be
  /// shown with the Math question view; see [asMathItem].
  final Map<String, Object?> raw;

  /// This example as a Math [Item] whose solution is the walkthrough.
  Item asMathItem({
    required String type,
    required String domain,
    required int level,
  }) => Item.fromJson({
    ...raw,
    'id': 'example-$type-$level',
    'section': 'math',
    'type': type,
    'domain': domain,
    'level': level,
    'b': 0,
    'pool': 'example',
    'solution': walkthrough,
  });
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
    this.calculator,
  });

  factory Lesson.fromJson(Map<String, Object?> j) => Lesson(
    type: j['type']! as String,
    title: j['title']! as String,
    whatIsTested: j['what_is_tested']! as String,
    howToSpot: j['how_to_spot']! as String,
    method: List<String>.from(j['method']! as List),
    pitfalls: List<String>.from(j['pitfalls'] as List? ?? const []),
    usUk: j['us_uk'] as String?,
    calculator: j['calculator'] as String?,
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

  /// Math only: when the built-in calculator helps for this skill.
  final String? calculator;
  final List<StrategyCard> cards;
}

/// Everything shipped in `assets/data/rw_bank.json`.
/// The Math section's own blueprint, papers and lessons.
class SectionContent {
  const SectionContent({
    required this.blueprint,
    required this.forms,
    required this.lessons,
    required this.reference,
    required this.domainCounts,
  });

  factory SectionContent.fromJson(Map<String, Object?> j) {
    final bp = j['blueprint']! as Map<String, Object?>;
    return SectionContent(
      blueprint: Blueprint.fromJson(bp),
      forms: [
        for (final f in j['forms']! as List)
          PaperForm.fromJson(f as Map<String, Object?>, section: 'math'),
      ]..sort((a, b) => a.number.compareTo(b.number)),
      lessons: {
        for (final l in j['lessons']! as List)
          (l as Map<String, Object?>)['type']! as String: Lesson.fromJson(l),
      },
      reference: Map<String, Object?>.from(j['reference'] as Map? ?? const {}),
      domainCounts: Map<String, int>.from(
        ((bp['module_blueprint']! as Map)['domains']) as Map? ?? const {},
      ),
    );
  }

  final Blueprint blueprint;
  final List<PaperForm> forms;
  final Map<String, Lesson> lessons;
  final Map<String, Object?> reference;

  /// Questions of each domain in one Math module.
  final Map<String, int> domainCounts;
}

class ContentBank {
  const ContentBank({
    required this.version,
    required this.blueprint,
    required this.items,
    required this.forms,
    required this.lessons,
    required this.reference,
    required this.moduleTypeCounts,
    this.math,
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

  /// Adds the Math section; its items join the shared [items] map.
  ContentBank withMath(Map<String, Object?> j) => ContentBank(
    version: version,
    blueprint: blueprint,
    items: {
      ...items,
      for (final raw in j['items']! as List)
        (raw as Map<String, Object?>)['id']! as String: Item.fromJson(raw),
    },
    forms: forms,
    lessons: lessons,
    reference: reference,
    moduleTypeCounts: moduleTypeCounts,
    math: SectionContent.fromJson(j),
  );

  final String version;

  /// Reading and Writing blueprint (see [bpOf] for either section).
  final Blueprint blueprint;
  final Map<String, Item> items;
  final SectionContent? math;

  bool get hasMath => math != null && math!.forms.isNotEmpty;

  Blueprint bpOf(String section) =>
      section == 'math' && math != null ? math!.blueprint : blueprint;

  Blueprint bpForItem(Item i) => bpOf(i.section);

  /// The blueprint that defines [type] (type keys are unique across sections).
  Blueprint bpOfType(String type) =>
      math?.blueprint.types.containsKey(type) ?? false
      ? math!.blueprint
      : blueprint;

  /// The blueprint that defines [domain].
  Blueprint bpOfDomain(String domain) =>
      math?.blueprint.domains.containsKey(domain) ?? false
      ? math!.blueprint
      : blueprint;

  /// Questions of each type in one module of [section]. Math blueprints fix
  /// counts per domain; those are spread evenly over the domain's types.
  Map<String, int> moduleTypeCountsOf(String section) {
    final m = math;
    if (section != 'math' || m == null) return moduleTypeCounts;
    final out = <String, int>{};
    for (final MapEntry(key: domain, value: n) in m.domainCounts.entries) {
      final types = [
        for (final t in m.blueprint.typeOrder)
          if (m.blueprint.types[t]!.domain == domain) t,
      ];
      for (var i = 0; i < n && types.isNotEmpty; i++) {
        final t = types[i % types.length];
        out[t] = (out[t] ?? 0) + 1;
      }
    }
    return out;
  }

  List<PaperForm> formsOf(String section) =>
      section == 'math' ? (math?.forms ?? const []) : forms;

  Map<String, Lesson> lessonsOf(String section) =>
      section == 'math' ? (math?.lessons ?? const {}) : lessons;
  final List<PaperForm> forms;
  final Map<String, Lesson> lessons;

  /// Raw reference guides (grammar, wordbank, traps, testday) as decoded JSON.
  final Map<String, Object?> reference;

  /// Questions of each type in one module (used for timed module practice).
  final Map<String, int> moduleTypeCounts;

  PaperForm? form(String id) {
    for (final f in [...forms, ...?math?.forms]) {
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

ContentBank _decode((String, String?) raw) {
  final bank = ContentBank.fromJson(jsonDecode(raw.$1) as Map<String, Object?>);
  final math = raw.$2;
  return math == null
      ? bank
      : bank.withMath(jsonDecode(math) as Map<String, Object?>);
}

/// Loads and parses the bank once, off the UI isolate.
final contentBankProvider = FutureProvider<ContentBank>((ref) async {
  final rw = await rootBundle.loadString('assets/data/rw_bank.json');
  String? math;
  try {
    math = await rootBundle.loadString('assets/data/math_bank.json');
  } on FlutterError {
    math = null; // no Math pack shipped
  }
  return compute(_decode, (rw, math));
});
