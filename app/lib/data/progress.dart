import 'package:moduleup/core/clock.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';

/// What the student told us at first run.
class StudentProfile {
  const StudentProfile({
    required this.name,
    required this.targetScore,
    this.testDate,
    this.weeklyGoal = 100,
  });

  factory StudentProfile.fromJson(Map<String, Object?> j) => StudentProfile(
    name: j['name'] as String? ?? '',
    targetScore: j['target'] as int? ?? 650,
    testDate: j['testDate'] == null
        ? null
        : DateTime.parse(j['testDate']! as String),
    weeklyGoal: j['weeklyGoal'] as int? ?? 100,
  );

  final String name;

  /// Target Reading and Writing section score (200–800).
  final int targetScore;
  final DateTime? testDate;

  /// Questions per week the student aims to practise.
  final int weeklyGoal;

  Map<String, Object?> toJson() => {
    'name': name,
    'target': targetScore,
    'testDate': testDate?.toIso8601String().substring(0, 10),
    'weeklyGoal': weeklyGoal,
  };

  StudentProfile copyWith({
    String? name,
    int? targetScore,
    DateTime? testDate,
    int? weeklyGoal,
  }) => StudentProfile(
    name: name ?? this.name,
    targetScore: targetScore ?? this.targetScore,
    testDate: testDate ?? this.testDate,
    weeklyGoal: weeklyGoal ?? this.weeklyGoal,
  );
}

/// A paper in progress, saved after every answer so it can be resumed on any
/// device.
class SavedPaperSession {
  const SavedPaperSession({
    required this.formId,
    required this.module,
    required this.module1,
    required this.module2,
    required this.secondsLeft,
    required this.untimed,
    this.route,
  });

  factory SavedPaperSession.fromJson(Map<String, Object?> j) =>
      SavedPaperSession(
        formId: j['form']! as String,
        module: j['module']! as int,
        route: j['route'] == null
            ? null
            : ModuleRoute.values.byName(j['route']! as String),
        module1: [
          for (final r in j['m1']! as List)
            ItemResponse.fromJson(r as Map<String, Object?>),
        ],
        module2: [
          for (final r in j['m2']! as List)
            ItemResponse.fromJson(r as Map<String, Object?>),
        ],
        secondsLeft: j['left']! as int,
        untimed: j['untimed'] as bool? ?? false,
      );

  final String formId;

  /// 1 or 2.
  final int module;
  final ModuleRoute? route;
  final List<ItemResponse> module1;
  final List<ItemResponse> module2;
  final int secondsLeft;
  final bool untimed;

  Map<String, Object?> toJson() => {
    'form': formId,
    'module': module,
    'route': route?.name,
    'm1': [for (final r in module1) r.toJson()],
    'm2': [for (final r in module2) r.toJson()],
    'left': secondsLeft,
    'untimed': untimed,
  };
}

/// Everything about one student's progress, as last synced.
class ProgressSnapshot {
  const ProgressSnapshot({
    this.profile,
    this.papers = const [],
    this.drills = const [],
    this.notebook = const {},
    this.lastSeen = const {},
    this.session,
  });

  static const empty = ProgressSnapshot();

  final StudentProfile? profile;
  final List<PaperResult> papers;
  final List<DrillResult> drills;
  final Map<String, MistakeEntry> notebook;
  final Map<String, DateTime> lastSeen;
  final SavedPaperSession? session;

  /// Latest attempt of each paper, by form id.
  Map<String, PaperResult> get latestByForm {
    final out = <String, PaperResult>{};
    for (final p in papers) {
      final cur = out[p.formId];
      if (cur == null || p.finishedAt.isAfter(cur.finishedAt)) {
        out[p.formId] = p;
      }
    }
    return out;
  }

  /// Days with any finished paper or drill (local calendar days).
  Set<String> get activeDays => {
    for (final p in papers) dayKey(p.finishedAt.toLocal()),
    for (final d in drills) dayKey(d.finishedAt.toLocal()),
  };

  /// Consecutive active days ending today (or yesterday, if today is empty).
  int streak(DateTime now) {
    final days = activeDays;
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (days.contains(dayKey(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Questions answered since the start of this week (Monday).
  int questionsThisWeek(DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    var n = 0;
    for (final p in papers) {
      if (!p.finishedAt.toLocal().isBefore(start)) n += p.all.length;
    }
    for (final d in drills) {
      if (!d.finishedAt.toLocal().isBefore(start)) n += d.responses.length;
    }
    return n;
  }

  List<MistakeEntry> dueMistakes(DateTime now) => [
    for (final m in notebook.values)
      if (m.isDue(now)) m,
  ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  /// All responses ever given (papers and drills), for breakdowns.
  Iterable<ItemResponse> get allResponses => [
    for (final p in papers) ...p.all,
    for (final d in drills) ...d.responses,
  ];
}
