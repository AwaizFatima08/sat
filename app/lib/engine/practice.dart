/// Practice selection: the mistake notebook (spaced review) and the drill
/// picker. Pure and deterministic for a given seed.
library;

import 'dart:math' as math;

import 'package:moduleup/engine/content.dart';

/// Days until a wrong item comes back, by review stage.
const reviewIntervalsDays = [1, 3, 7];

/// One item in the mistake notebook.
class MistakeEntry {
  const MistakeEntry({
    required this.itemId,
    required this.stage,
    required this.dueAt,
  });

  factory MistakeEntry.fromJson(Map<String, Object?> json) => MistakeEntry(
    itemId: json['id']! as String,
    stage: json['stage']! as int,
    dueAt: DateTime.parse(json['due']! as String),
  );

  final String itemId;

  /// 0, 1 or 2: index into [reviewIntervalsDays] for the current wait.
  final int stage;
  final DateTime dueAt;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  Map<String, Object?> toJson() => {
    'id': itemId,
    'stage': stage,
    'due': dueAt.toUtc().toIso8601String(),
  };
}

/// The notebook after answering [itemId]. A wrong answer (re)starts the item
/// at stage 0; a correct answer to a notebook item advances it, and it leaves
/// the notebook after the last stage.
Map<String, MistakeEntry> updateNotebook(
  Map<String, MistakeEntry> notebook, {
  required String itemId,
  required bool correct,
  required DateTime now,
}) {
  final next = Map<String, MistakeEntry>.of(notebook);
  final current = notebook[itemId];
  if (!correct) {
    next[itemId] = MistakeEntry(
      itemId: itemId,
      stage: 0,
      dueAt: now.add(Duration(days: reviewIntervalsDays[0])),
    );
  } else if (current != null && current.isDue(now)) {
    final stage = current.stage + 1;
    if (stage >= reviewIntervalsDays.length) {
      next.remove(itemId);
    } else {
      next[itemId] = MistakeEntry(
        itemId: itemId,
        stage: stage,
        dueAt: now.add(Duration(days: reviewIntervalsDays[stage])),
      );
    }
  }
  return next;
}

/// Picks [count] drill items of one type and level. Unseen items first, then
/// the ones seen longest ago; ties broken by a seeded shuffle.
List<Item> pickDrill({
  required Iterable<Item> items,
  required String type,
  required int level,
  required Map<String, DateTime> lastSeen,
  required int seed,
  int count = 10,
}) {
  final pool =
      items
          .where((i) => i.pool == 'drill' && i.type == type && i.level == level)
          .toList()
        ..shuffle(math.Random(seed));
  final epoch = DateTime.utc(1970);
  pool.sort(
    (a, b) => (lastSeen[a.id] ?? epoch).compareTo(lastSeen[b.id] ?? epoch),
  );
  return pool.take(count).toList();
}

/// A mixed set across several types (domain quiz or timed module practice),
/// ordered like a real module.
List<Item> pickMixed({
  required Iterable<Item> items,
  required Map<String, int> perType,
  required List<String> typeOrder,
  required Map<String, DateTime> lastSeen,
  required int seed,
}) {
  final picked = <Item>[];
  final rng = math.Random(seed);
  for (final type in typeOrder) {
    final n = perType[type] ?? 0;
    if (n == 0) continue;
    final levels = [1, 2, 3, 4]..shuffle(rng);
    final ofType =
        items.where((i) => i.pool == 'drill' && i.type == type).toList()
          ..shuffle(rng);
    final epoch = DateTime.utc(1970);
    ofType.sort((a, b) {
      final seen = (lastSeen[a.id] ?? epoch).compareTo(lastSeen[b.id] ?? epoch);
      return seen != 0
          ? seen
          : levels.indexOf(a.level).compareTo(levels.indexOf(b.level));
    });
    final chosen = ofType.take(n).toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    picked.addAll(chosen);
  }
  return picked;
}
