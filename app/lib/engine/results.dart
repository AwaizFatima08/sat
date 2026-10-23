/// Results of papers and drills, and everything derived from them:
/// per-domain and per-type accuracy, trap profile, pace and skill mastery.
library;

import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/scoring.dart';

/// Target pace on the real test: 64 minutes for 54 questions.
const double targetSecondsPerQuestion = 71;

/// The student's response to one item.
class ItemResponse {
  const ItemResponse({
    required this.itemId,
    required this.seconds,
    this.answer,
    this.marked = false,
  });

  factory ItemResponse.fromJson(Map<String, Object?> json) => ItemResponse(
    itemId: json['id']! as String,
    answer: json['a'] as String?,
    seconds: json['s']! as int,
    marked: json['m'] as bool? ?? false,
  );

  final String itemId;
  final String? answer;
  final int seconds;
  final bool marked;

  Map<String, Object?> toJson() => {
    'id': itemId,
    'a': answer,
    's': seconds,
    if (marked) 'm': true,
  };
}

/// Correct out of total, for one group of items.
class Tally {
  const Tally(this.correct, this.total);
  final int correct;
  final int total;
  double get ratio => total == 0 ? 0 : correct / total;
  Tally add({required bool isCorrect}) =>
      Tally(correct + (isCorrect ? 1 : 0), total + 1);
}

/// Breakdown of a set of responses (a paper, a drill, or a history).
class Breakdown {
  const Breakdown({
    required this.overall,
    required this.byDomain,
    required this.byType,
    required this.trapCounts,
    required this.secondsByType,
  });

  final Tally overall;
  final Map<String, Tally> byDomain;
  final Map<String, Tally> byType;

  /// How many wrong answers fell into each trap type.
  final Map<String, int> trapCounts;

  /// Average seconds per question for each type.
  final Map<String, double> secondsByType;
}

/// Builds a breakdown; responses whose item is unknown are skipped.
Breakdown breakdown(Iterable<ItemResponse> responses, Map<String, Item> items) {
  var overall = const Tally(0, 0);
  final byDomain = <String, Tally>{};
  final byType = <String, Tally>{};
  final traps = <String, int>{};
  final seconds = <String, List<int>>{};
  for (final r in responses) {
    final item = items[r.itemId];
    if (item == null) continue;
    final ok = item.isCorrect(r.answer);
    overall = overall.add(isCorrect: ok);
    byDomain[item.domain] = (byDomain[item.domain] ?? const Tally(0, 0)).add(
      isCorrect: ok,
    );
    byType[item.type] = (byType[item.type] ?? const Tally(0, 0)).add(
      isCorrect: ok,
    );
    final trap = r.answer == null ? null : item.traps[r.answer];
    if (!ok && trap != null) traps[trap] = (traps[trap] ?? 0) + 1;
    (seconds[item.type] ??= []).add(r.seconds);
  }
  return Breakdown(
    overall: overall,
    byDomain: byDomain,
    byType: byType,
    trapCounts: traps,
    secondsByType: {
      for (final e in seconds.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    },
  );
}

/// A finished (or abandoned) full-length paper.
class PaperResult {
  const PaperResult({
    required this.formId,
    required this.route,
    required this.module1,
    required this.module2,
    required this.estimate,
    required this.finishedAt,
    required this.untimed,
  });

  factory PaperResult.fromJson(Map<String, Object?> json) => PaperResult(
    formId: json['form']! as String,
    route: ModuleRoute.values.byName(json['route']! as String),
    module1: [
      for (final r in json['m1']! as List)
        ItemResponse.fromJson(r as Map<String, Object?>),
    ],
    module2: [
      for (final r in json['m2']! as List)
        ItemResponse.fromJson(r as Map<String, Object?>),
    ],
    estimate: ScoreEstimate(
      score: json['score']! as int,
      low: json['low']! as int,
      high: json['high']! as int,
      ability: (json['theta']! as num).toDouble(),
      standardError: (json['se']! as num).toDouble(),
    ),
    finishedAt: DateTime.parse(json['at']! as String),
    untimed: json['untimed'] as bool? ?? false,
  );

  final String formId;
  final ModuleRoute route;
  final List<ItemResponse> module1;
  final List<ItemResponse> module2;
  final ScoreEstimate estimate;
  final DateTime finishedAt;

  /// True when the clock was paused, so the score is not a timed result.
  final bool untimed;

  Iterable<ItemResponse> get all => [...module1, ...module2];

  Map<String, Object?> toJson() => {
    'form': formId,
    'route': route.name,
    'm1': [for (final r in module1) r.toJson()],
    'm2': [for (final r in module2) r.toJson()],
    'score': estimate.score,
    'low': estimate.low,
    'high': estimate.high,
    'theta': estimate.ability,
    'se': estimate.standardError,
    'at': finishedAt.toUtc().toIso8601String(),
    'untimed': untimed,
  };
}

/// Scores a finished paper.
PaperResult scorePaper({
  required PaperForm form,
  required ModuleRoute route,
  required List<ItemResponse> module1,
  required List<ItemResponse> module2,
  required Map<String, Item> items,
  required DateTime finishedAt,
  bool untimed = false,
}) {
  final responses = <Response>[
    for (final r in [...module1, ...module2])
      if (items[r.itemId] case final item?)
        (difficulty: item.difficulty, correct: item.isCorrect(r.answer)),
  ];
  return PaperResult(
    formId: form.id,
    route: route,
    module1: module1,
    module2: module2,
    estimate: estimateScore(responses, route),
    finishedAt: finishedAt,
    untimed: untimed,
  );
}

/// A finished drill set (or quiz).
class DrillResult {
  const DrillResult({
    required this.type,
    required this.level,
    required this.responses,
    required this.finishedAt,
  });

  factory DrillResult.fromJson(Map<String, Object?> json) => DrillResult(
    type: json['type']! as String,
    level: json['level']! as int,
    responses: [
      for (final r in json['r']! as List)
        ItemResponse.fromJson(r as Map<String, Object?>),
    ],
    finishedAt: DateTime.parse(json['at']! as String),
  );

  /// Question type key, or `mixed` for a domain quiz or module practice.
  final String type;
  final int level;
  final List<ItemResponse> responses;
  final DateTime finishedAt;

  Map<String, Object?> toJson() => {
    'type': type,
    'level': level,
    'r': [for (final r in responses) r.toJson()],
    'at': finishedAt.toUtc().toIso8601String(),
  };
}

/// Mastery of one skill at one level, Khan-style ladder.
enum Mastery { notStarted, familiar, proficient, mastered }

/// Mastery rules (design doc): Familiar at ≥70 % on a drill set, Proficient at
/// 100 % on a set, Mastered after Proficient plus ≥80 % on that skill across
/// the last two full papers.
Mastery masteryFor({
  required String type,
  required int level,
  required List<DrillResult> drills,
  required List<PaperResult> papers,
  required Map<String, Item> items,
}) {
  var best = 0.0;
  var attempted = false;
  for (final d in drills) {
    if (d.type != type || d.level != level || d.responses.isEmpty) continue;
    attempted = true;
    final t = breakdown(d.responses, items).overall;
    if (t.ratio > best) best = t.ratio;
  }
  if (!attempted) return Mastery.notStarted;
  if (best < 0.7) return Mastery.notStarted;
  if (best < 1) return Mastery.familiar;
  final recent = [...papers]
    ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  final lastTwo = recent.take(2).toList();
  if (lastTwo.length < 2) return Mastery.proficient;
  final onType = breakdown(lastTwo.expand((p) => p.all), items).byType[type];
  return onType != null && onType.total > 0 && onType.ratio >= 0.8
      ? Mastery.mastered
      : Mastery.proficient;
}
