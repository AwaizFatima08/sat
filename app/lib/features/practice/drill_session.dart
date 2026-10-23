import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';

/// Kinds of practice set.
enum DrillKind { skill, tryIt, mistakes, domainQuiz, module }

/// One practice set: instant feedback after each question (skill drills,
/// try-it, mistakes) or at the end (quizzes and timed module practice).
class DrillState {
  const DrillState({
    required this.kind,
    required this.title,
    required this.type,
    required this.level,
    required this.items,
    required this.index,
    required this.answers,
    required this.seconds,
    required this.revealed,
    required this.finished,
    this.secondsLeft,
  });

  final DrillKind kind;
  final String title;

  /// Question type key, or `mixed`.
  final String type;
  final int level;
  final List<Item> items;
  final int index;
  final Map<String, String> answers;
  final Map<String, int> seconds;

  /// Whether the current item's key is shown (instant-feedback sets).
  final bool revealed;
  final bool finished;

  /// Countdown for timed sets; null when untimed.
  final int? secondsLeft;

  bool get instantFeedback =>
      kind == DrillKind.skill ||
      kind == DrillKind.tryIt ||
      kind == DrillKind.mistakes;
  Item get current => items[index];
  int get correct => items.where((i) => i.isCorrect(answers[i.id])).length;

  DrillState copyWith({
    int? index,
    Map<String, String>? answers,
    Map<String, int>? seconds,
    bool? revealed,
    bool? finished,
    int? secondsLeft,
  }) => DrillState(
    kind: kind,
    title: title,
    type: type,
    level: level,
    items: items,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    seconds: seconds ?? this.seconds,
    revealed: revealed ?? this.revealed,
    finished: finished ?? this.finished,
    secondsLeft: secondsLeft ?? this.secondsLeft,
  );
}

class DrillNotifier extends Notifier<DrillState?> {
  Timer? _timer;

  @override
  DrillState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  ContentBank get _bank => ref.read(contentBankProvider).requireValue;
  ProgressSnapshot get _progress =>
      ref.read(progressProvider).value ?? ProgressSnapshot.empty;
  DateTime get _now => ref.read(clockProvider).now();
  int get _seed => _now.millisecondsSinceEpoch;

  /// Returns false when no items are available for that choice.
  bool startSkill(String type, int level) {
    final items = pickDrill(
      items: _bank.items.values,
      type: type,
      level: level,
      lastSeen: _progress.lastSeen,
      seed: _seed,
    );
    final name =
        '${_bank.bpOfType(type).types[type]!.name} · ${_bank.bpOfType(type).levelNames[level]}';
    return _begin(DrillKind.skill, name, type, level, items);
  }

  bool startTryIt(String type, int level, List<String> ids) => _begin(
    DrillKind.tryIt,
    'Try it · ${_bank.bpOfType(type).types[type]!.name}',
    type,
    level,
    _bank.itemsOf(ids),
  );

  bool startMistakes() {
    final due = _progress.dueMistakes(_now).take(10).map((m) => m.itemId);
    return _begin(
      DrillKind.mistakes,
      'Mistake notebook',
      'mixed',
      0,
      _bank.itemsOf(due),
    );
  }

  /// 15 mixed questions from one domain, timed at the section's pace.
  bool startDomainQuiz(String domain) {
    final bp = _bank.bpOfDomain(domain);
    final types = [
      for (final t in bp.typeOrder)
        if (bp.types[t]!.domain == domain) t,
    ];
    final per = <String, int>{};
    for (var i = 0; i < 15; i++) {
      per[types[i % types.length]] = (per[types[i % types.length]] ?? 0) + 1;
    }
    final items = pickMixed(
      items: _bank.items.values,
      perType: per,
      typeOrder: bp.typeOrder,
      lastSeen: _progress.lastSeen,
      seed: _seed,
    );
    return _begin(
      DrillKind.domainQuiz,
      '${bp.domains[domain]} quiz',
      'mixed',
      0,
      items,
      // The section's own pace: about 18 min for R&W, 24 min for Math.
      seconds: (15 * bp.moduleMinutes * 60 / bp.moduleItems).round(),
    );
  }

  /// A full timed module of [section] (R&W 27 questions in 32 minutes,
  /// Math 22 in 35) from the drill pool.
  bool startModulePractice({String section = 'rw'}) {
    final bp = _bank.bpOf(section);
    final items = pickMixed(
      items: _bank.items.values,
      perType: _bank.moduleTypeCountsOf(section),
      typeOrder: bp.typeOrder,
      lastSeen: _progress.lastSeen,
      seed: _seed,
    );
    return _begin(
      DrillKind.module,
      section == 'math' ? 'Timed Math module' : 'Timed module practice',
      'mixed',
      0,
      items,
      seconds: bp.moduleMinutes * 60,
    );
  }

  bool _begin(
    DrillKind kind,
    String title,
    String type,
    int level,
    List<Item> items, {
    int? seconds,
  }) {
    if (items.isEmpty) return false;
    state = DrillState(
      kind: kind,
      title: title,
      type: type,
      level: level,
      items: items,
      index: 0,
      answers: const {},
      seconds: const {},
      revealed: false,
      finished: false,
      secondsLeft: seconds,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return true;
  }

  void _tick() {
    final s = state;
    if (s == null || s.finished || s.revealed) return;
    final id = s.current.id;
    final left = s.secondsLeft == null ? null : math.max(0, s.secondsLeft! - 1);
    state = s.copyWith(
      seconds: {...s.seconds, id: (s.seconds[id] ?? 0) + 1},
      secondsLeft: left,
    );
    if (left == 0) unawaited(finish());
  }

  void select(String letter) {
    final s = state!;
    if (s.revealed) return;
    final answers = {...s.answers, s.current.id: letter};
    if (letter.isEmpty) answers.remove(s.current.id);
    state = s.copyWith(answers: answers);
  }

  /// Instant-feedback sets: check the answer. Others: move on.
  void check() => state = state!.copyWith(revealed: true);

  Future<void> next() async {
    final s = state!;
    if (s.index + 1 >= s.items.length) return finish();
    state = s.copyWith(index: s.index + 1, revealed: false);
  }

  void previous() {
    final s = state!;
    if (s.index > 0) state = s.copyWith(index: s.index - 1, revealed: false);
  }

  Future<void> finish() async {
    _timer?.cancel();
    final s = state!;
    final now = _now;
    final responses = [
      for (final i in s.items)
        ItemResponse(
          itemId: i.id,
          answer: s.answers[i.id],
          seconds: s.seconds[i.id] ?? 0,
        ),
    ];
    final result = DrillResult(
      type: s.type,
      level: s.level,
      responses: responses,
      finishedAt: now,
    );
    var notebook = _progress.notebook;
    final seen = {..._progress.lastSeen};
    for (final i in s.items) {
      notebook = updateNotebook(
        notebook,
        itemId: i.id,
        correct: i.isCorrect(s.answers[i.id]),
        now: now,
      );
      seen[i.id] = now;
    }
    state = s.copyWith(finished: true, revealed: true);
    await ref
        .read(progressRepositoryProvider)
        ?.recordDrill(result, notebook: notebook, seen: seen);
  }

  void close() {
    _timer?.cancel();
    state = null;
  }
}

final drillProvider = NotifierProvider<DrillNotifier, DrillState?>(
  DrillNotifier.new,
);
