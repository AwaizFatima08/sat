/// Content models for the question bank, parsed from the data packs that
/// `pipeline/build_packs.py` writes into `assets/data/`.
library;

import 'package:moduleup/engine/spr.dart';

/// The four answer letters, in display order.
const answerLetters = ['A', 'B', 'C', 'D'];

/// One question type from the blueprint (e.g. Words in Context).
class QuestionType {
  const QuestionType({
    required this.key,
    required this.name,
    required this.domain,
  });

  factory QuestionType.fromJson(String key, Map<String, Object?> json) =>
      QuestionType(
        key: key,
        name: json['name']! as String,
        domain: json['domain']! as String,
      );

  final String key;
  final String name;
  final String domain;
}

/// Section-wide constants: domains, types, levels, traps and module shape.
class Blueprint {
  const Blueprint({
    required this.section,
    required this.title,
    required this.moduleMinutes,
    required this.moduleItems,
    required this.domains,
    required this.types,
    required this.typeOrder,
    required this.levelNames,
    required this.levelDifficulty,
    required this.traps,
    required this.grammar,
  });

  factory Blueprint.fromJson(Map<String, Object?> json) {
    final types = (json['types']! as Map<String, Object?>).map(
      (k, v) =>
          MapEntry(k, QuestionType.fromJson(k, v! as Map<String, Object?>)),
    );
    final levels = json['levels']! as Map<String, Object?>;
    return Blueprint(
      section: json['section']! as String,
      title: json['title']! as String,
      moduleMinutes: json['module_minutes']! as int,
      moduleItems: json['module_items']! as int,
      domains: Map<String, String>.from(json['domains']! as Map),
      types: types,
      typeOrder: List<String>.from(json['type_order']! as List),
      levelNames: {
        for (final e in levels.entries)
          int.parse(e.key): (e.value! as Map)['name'] as String,
      },
      levelDifficulty: {
        for (final e in levels.entries)
          int.parse(e.key): ((e.value! as Map)['b'] as num).toDouble(),
      },
      traps: Map<String, String>.from(json['traps']! as Map),
      grammar: Map<String, String>.from(json['grammar'] as Map? ?? const {}),
    );
  }

  final String section;
  final String title;
  final int moduleMinutes;
  final int moduleItems;
  final Map<String, String> domains;
  final Map<String, QuestionType> types;
  final List<String> typeOrder;
  final Map<int, String> levelNames;
  final Map<int, double> levelDifficulty;
  final Map<String, String> traps;
  final Map<String, String> grammar;

  /// Short trap label: the part before the colon ("Too broad").
  String trapLabel(String key) => (traps[key] ?? key).split(':').first;
}

/// A table or a simple bar/line graph shown with a quantitative item.
sealed class ItemData {
  const ItemData({required this.title});

  factory ItemData.fromJson(Map<String, Object?> json) {
    final title = json['title']! as String;
    if (json['kind'] == 'table') {
      return TableData(
        title: title,
        columns: [for (final c in json['columns']! as List) '$c'],
        rows: [
          for (final r in json['rows']! as List)
            [for (final c in r as List) '$c'],
        ],
        note: json['note'] as String?,
      );
    }
    return GraphData(
      title: title,
      isLine: json['kind'] == 'line',
      xLabel: json['x_label']! as String,
      yLabel: json['y_label']! as String,
      series: [
        for (final s in json['series']! as List)
          GraphSeries(
            name: (s as Map)['name'] as String,
            points: [
              for (final p in s['points'] as List)
                (label: '${(p as List)[0]}', value: (p[1] as num).toDouble()),
            ],
          ),
      ],
    );
  }

  final String title;
}

class TableData extends ItemData {
  const TableData({
    required super.title,
    required this.columns,
    required this.rows,
    this.note,
  });
  final List<String> columns;
  final List<List<String>> rows;
  final String? note;
}

class GraphSeries {
  const GraphSeries({required this.name, required this.points});
  final String name;
  final List<({String label, double value})> points;
}

class GraphData extends ItemData {
  const GraphData({
    required super.title,
    required this.isLine,
    required this.xLabel,
    required this.yLabel,
    required this.series,
  });
  final bool isLine;
  final String xLabel;
  final String yLabel;
  final List<GraphSeries> series;
}

/// One question: four-option multiple choice, or (Math) a typed answer.
class Item {
  const Item({
    required this.id,
    required this.type,
    required this.domain,
    required this.level,
    required this.difficulty,
    required this.subject,
    required this.pool,
    required this.stem,
    required this.choices,
    required this.answer,
    required this.why,
    required this.choiceExplanations,
    required this.traps,
    this.passage,
    this.passageB,
    this.notes,
    this.data,
    this.grammar,
    this.source,
    this.section = 'rw',
    this.isTyped = false,
    this.typedAnswers = const [],
    this.solution = const [],
    this.figure,
  });

  factory Item.fromJson(Map<String, Object?> json) {
    final explanation =
        (json['explanation'] as Map<String, Object?>?) ?? const {};
    final source = json['source'] as Map<String, Object?>?;
    final solution = (json['solution'] as List?)?.cast<String>() ?? const [];
    final typed = json['answer_type'] == 'spr';
    return Item(
      section: json['section'] as String? ?? 'rw',
      isTyped: typed,
      typedAnswers: (json['spr_answers'] as List?)?.cast<String>() ?? const [],
      solution: solution,
      figure: json['figure'] as Map<String, Object?>?,
      id: json['id']! as String,
      type: json['type']! as String,
      domain: json['domain']! as String,
      level: json['level']! as int,
      difficulty: (json['b']! as num).toDouble(),
      subject: json['subject'] as String? ?? 'math',
      pool: json['pool']! as String,
      passage: json['passage'] as String?,
      passageB: json['passage_b'] as String?,
      notes: (json['notes'] as List?)?.cast<String>(),
      data: json['data'] == null
          ? null
          : ItemData.fromJson(json['data']! as Map<String, Object?>),
      stem: json['stem']! as String,
      choices: Map<String, String>.from(json['choices'] as Map? ?? const {}),
      answer: json['answer'] as String? ?? '',
      why: explanation['why'] as String? ?? solution.join('\n\n'),
      choiceExplanations: {
        for (final l in answerLetters)
          if (explanation[l] case final String e) l: e,
      },
      traps: Map<String, String>.from(json['traps'] as Map? ?? const {}),
      grammar: json['grammar'] as String?,
      source: source == null || source['kind'] == 'original'
          ? null
          : '${source['author']}, ${source['work']} (${source['year']})',
    );
  }

  final String id;
  final String type;
  final String domain;
  final int level;

  /// Rasch difficulty `b` on the ability scale.
  final double difficulty;
  final String subject;

  /// paper | drill | tryit
  final String pool;
  final String? passage;
  final String? passageB;
  final List<String>? notes;
  final ItemData? data;
  final String stem;
  final Map<String, String> choices;
  final String answer;
  final String why;
  final Map<String, String> choiceExplanations;

  /// Trap type for each wrong letter.
  final Map<String, String> traps;
  final String? grammar;

  /// Attribution line for public-domain excerpts; null for original text.
  final String? source;

  /// `rw` or `math`.
  final String section;

  /// Math typed (student-produced) answer instead of four choices.
  final bool isTyped;

  /// Every exact accepted value of a typed answer ("2/3", "-4").
  final List<String> typedAnswers;

  /// Worked solution steps (Math).
  final List<String> solution;

  /// Figure spec (Math), drawn by the app.
  final Map<String, Object?>? figure;

  /// The key as shown to students: a letter, or the first accepted value.
  String get keyLabel => isTyped ? typedAnswers.first : answer;

  /// Whether [response] (a letter, or a typed entry) earns credit.
  bool isCorrect(String? response) =>
      response != null &&
      (isTyped ? gradeSpr(response, typedAnswers) : response == answer);
}

/// The two possible second modules.
enum ModuleRoute { easier, harder }

/// One full-length adaptive paper.
class PaperForm {
  const PaperForm({
    required this.id,
    required this.number,
    required this.title,
    required this.module1,
    required this.module2Easier,
    required this.module2Harder,
    required this.routeThreshold,
    this.section = 'rw',
  });

  factory PaperForm.fromJson(
    Map<String, Object?> json, {
    String section = 'rw',
  }) {
    final modules = json['modules']! as Map<String, Object?>;
    List<String> ids(String k) => List<String>.from(modules[k]! as List);
    return PaperForm(
      id: json['id']! as String,
      number: json['number']! as int,
      title: json['title']! as String,
      module1: ids('m1'),
      module2Easier: ids('m2_easy'),
      module2Harder: ids('m2_hard'),
      routeThreshold: json['route_threshold']! as int,
      section: json['section'] as String? ?? section,
    );
  }

  final String id;
  final int number;
  final String title;

  /// `rw` or `math`.
  final String section;
  final List<String> module1;
  final List<String> module2Easier;
  final List<String> module2Harder;

  /// Module 1 correct answers needed to be routed to the harder module 2.
  final int routeThreshold;

  List<String> module2(ModuleRoute route) =>
      route == ModuleRoute.harder ? module2Harder : module2Easier;
}
