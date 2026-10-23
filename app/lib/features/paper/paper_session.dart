import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';
import 'package:moduleup/engine/scoring.dart';

enum PaperPhase { answering, checkWork, betweenModules, finished }

/// Per-question working state (not shown to anyone but the student).
class QuestionState {
  const QuestionState({
    this.answer,
    this.seconds = 0,
    this.marked = false,
    this.eliminated = const {},
    this.highlights = const {},
  });

  final String? answer;
  final int seconds;
  final bool marked;
  final Set<String> eliminated;
  final Set<int> highlights;

  QuestionState copyWith({
    String? answer,
    bool clearAnswer = false,
    int? seconds,
    bool? marked,
    Set<String>? eliminated,
    Set<int>? highlights,
  }) => QuestionState(
    answer: clearAnswer ? null : answer ?? this.answer,
    seconds: seconds ?? this.seconds,
    marked: marked ?? this.marked,
    eliminated: eliminated ?? this.eliminated,
    highlights: highlights ?? this.highlights,
  );
}

/// Immutable snapshot of a full-length paper in progress.
class PaperSessionState {
  const PaperSessionState({
    required this.form,
    required this.module,
    required this.items,
    required this.questions,
    required this.index,
    required this.secondsLeft,
    required this.phase,
    required this.untimed,
    this.route,
    this.module1 = const [],
    this.result,
    this.timerHidden = false,
  });

  final PaperForm form;
  final int module;
  final ModuleRoute? route;

  /// Items of the current module, in order.
  final List<Item> items;
  final Map<String, QuestionState> questions;
  final int index;
  final int secondsLeft;
  final PaperPhase phase;
  final bool untimed;
  final bool timerHidden;

  /// Finished module 1 responses, kept once module 2 starts.
  final List<ItemResponse> module1;
  final PaperResult? result;

  Item get current => items[index];
  QuestionState get currentState =>
      questions[current.id] ?? const QuestionState();
  int get answeredCount =>
      items.where((i) => questions[i.id]?.answer != null).length;

  List<ItemResponse> responses() => [
    for (final i in items)
      ItemResponse(
        itemId: i.id,
        answer: questions[i.id]?.answer,
        seconds: questions[i.id]?.seconds ?? 0,
        marked: questions[i.id]?.marked ?? false,
      ),
  ];

  PaperSessionState copyWith({
    int? module,
    ModuleRoute? route,
    List<Item>? items,
    Map<String, QuestionState>? questions,
    int? index,
    int? secondsLeft,
    PaperPhase? phase,
    bool? untimed,
    bool? timerHidden,
    List<ItemResponse>? module1,
    PaperResult? result,
  }) => PaperSessionState(
    form: form,
    module: module ?? this.module,
    route: route ?? this.route,
    items: items ?? this.items,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    phase: phase ?? this.phase,
    untimed: untimed ?? this.untimed,
    timerHidden: timerHidden ?? this.timerHidden,
    module1: module1 ?? this.module1,
    result: result ?? this.result,
  );
}

/// Runs one paper: timing, answers, routing, scoring, saving.
class PaperSessionNotifier extends Notifier<PaperSessionState?> {
  Timer? _timer;
  int _ticksSinceSave = 0;

  @override
  PaperSessionState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  ContentBank get _bank => ref.read(contentBankProvider).requireValue;
  int _moduleSeconds(PaperForm f) => _bank.bpOf(f.section).moduleMinutes * 60;

  /// Starts a paper, or resumes the saved one for the same form.
  void start(PaperForm form, {SavedPaperSession? resume}) {
    if (resume != null && resume.formId == form.id) {
      final ids = resume.module == 1
          ? form.module1
          : form.module2(resume.route!);
      final saved = resume.module == 1 ? resume.module1 : resume.module2;
      state = PaperSessionState(
        form: form,
        module: resume.module,
        route: resume.route,
        items: _bank.itemsOf(ids),
        questions: {
          for (final r in saved)
            r.itemId: QuestionState(
              answer: r.answer,
              seconds: r.seconds,
              marked: r.marked,
            ),
        },
        index: 0,
        secondsLeft: resume.secondsLeft,
        phase: PaperPhase.answering,
        untimed: resume.untimed,
        module1: resume.module == 2 ? resume.module1 : const [],
      );
    } else {
      state = PaperSessionState(
        form: form,
        module: 1,
        items: _bank.itemsOf(form.module1),
        questions: const {},
        index: 0,
        secondsLeft: _moduleSeconds(form),
        phase: PaperPhase.answering,
        untimed: false,
      );
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null ||
        s.phase == PaperPhase.betweenModules ||
        s.phase == PaperPhase.finished) {
      return;
    }
    final q = s.currentState;
    state = s.copyWith(
      secondsLeft: s.secondsLeft - 1,
      questions: s.phase == PaperPhase.answering
          ? {...s.questions, s.current.id: q.copyWith(seconds: q.seconds + 1)}
          : null,
    );
    if (state!.secondsLeft <= 0) {
      unawaited(endModule());
    } else if (++_ticksSinceSave >= 15) {
      _save();
    }
  }

  void _update(QuestionState Function(QuestionState) f) {
    final s = state!;
    state = s.copyWith(
      questions: {...s.questions, s.current.id: f(s.currentState)},
    );
  }

  /// A choice letter, or a typed Math answer ('' clears it).
  void select(String letter) {
    _update(
      (q) => q.copyWith(
        answer: letter,
        clearAnswer: letter.isEmpty,
        eliminated: {...q.eliminated}..remove(letter),
      ),
    );
    _save();
  }

  void toggleEliminate(String letter) => _update((q) {
    final e = {...q.eliminated};
    if (!e.remove(letter)) e.add(letter);
    return q.copyWith(eliminated: e);
  });

  void toggleMark() => _update((q) => q.copyWith(marked: !q.marked));

  void toggleHighlight(int sentence) => _update((q) {
    final h = {...q.highlights};
    if (!h.remove(sentence)) h.add(sentence);
    return q.copyWith(highlights: h);
  });

  void toggleTimer() =>
      state = state!.copyWith(timerHidden: !state!.timerHidden);

  void goTo(int i) =>
      state = state!.copyWith(index: i, phase: PaperPhase.answering);
  void next() {
    final s = state!;
    state = s.index + 1 < s.items.length
        ? s.copyWith(index: s.index + 1)
        : s.copyWith(phase: PaperPhase.checkWork);
  }

  void previous() {
    final s = state!;
    if (s.index > 0) state = s.copyWith(index: s.index - 1);
  }

  void openCheckWork() => state = state!.copyWith(phase: PaperPhase.checkWork);

  /// Leaving mid-module stops the clock; the paper is then marked untimed.
  void pauseAndSave() {
    _timer?.cancel();
    state = state!.copyWith(untimed: true);
    _save();
  }

  void resumeTimer() => _startTimer();

  void _save() {
    _ticksSinceSave = 0;
    final s = state;
    final repo = ref.read(progressRepositoryProvider);
    if (s == null || repo == null || s.phase == PaperPhase.finished) return;
    unawaited(
      repo.saveSession(
        SavedPaperSession(
          formId: s.form.id,
          module: s.module,
          route: s.route,
          module1: s.module == 1 ? s.responses() : s.module1,
          module2: s.module == 2 ? s.responses() : const [],
          secondsLeft: s.secondsLeft,
          untimed: s.untimed,
        ),
      ),
    );
  }

  /// Ends the current module (time up or "Next module").
  Future<void> endModule() async {
    final s = state!;
    if (s.module == 1) {
      final m1 = s.responses();
      final correct = m1
          .where((r) => _bank.items[r.itemId]?.isCorrect(r.answer) ?? false)
          .length;
      final route = routeAfterModule1(correct, s.form.routeThreshold);
      state = s.copyWith(
        module: 2,
        route: route,
        module1: m1,
        items: _bank.itemsOf(s.form.module2(route)),
        questions: const {},
        index: 0,
        secondsLeft: _moduleSeconds(s.form),
        phase: PaperPhase.betweenModules,
      );
      _save();
      return;
    }
    _timer?.cancel();
    await _finish(s);
  }

  void beginModule2() {
    state = state!.copyWith(phase: PaperPhase.answering);
    _startTimer();
  }

  Future<void> _finish(PaperSessionState s) async {
    final now = ref.read(clockProvider).now();
    final m2 = s.responses();
    final result = scorePaper(
      form: s.form,
      route: s.route!,
      module1: s.module1,
      module2: m2,
      items: _bank.items,
      finishedAt: now,
      untimed: s.untimed,
    );
    final progress = ref.read(progressProvider).value ?? ProgressSnapshot.empty;
    var notebook = progress.notebook;
    final seen = {...progress.lastSeen};
    for (final r in result.all) {
      final item = _bank.items[r.itemId];
      if (item == null) continue;
      notebook = updateNotebook(
        notebook,
        itemId: r.itemId,
        correct: item.isCorrect(r.answer),
        now: now,
      );
      seen[r.itemId] = now;
    }
    state = s.copyWith(phase: PaperPhase.finished, result: result);
    await ref
        .read(progressRepositoryProvider)
        ?.recordPaper(result, notebook: notebook, seen: seen);
  }

  void close() {
    _timer?.cancel();
    state = null;
  }
}

final paperSessionProvider =
    NotifierProvider<PaperSessionNotifier, PaperSessionState?>(
      PaperSessionNotifier.new,
    );
