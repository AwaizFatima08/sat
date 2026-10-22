import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/data/auth_service.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/engine/practice.dart';
import 'package:moduleup/engine/results.dart';

/// The single write path for a student's progress. Writes land in the local
/// Firestore cache first (so they work offline) and sync when online; the
/// watched snapshot re-emits on every local write.
abstract interface class ProgressRepository {
  Stream<ProgressSnapshot> watch();
  Future<void> saveProfile(StudentProfile profile);
  Future<void> saveSession(SavedPaperSession session);
  Future<void> recordPaper(
    PaperResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  });
  Future<void> recordDrill(
    DrillResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  });

  /// Removes every document of this student (account deletion).
  Future<void> deleteAll();
}

class FirestoreProgressRepository implements ProgressRepository {
  FirestoreProgressRepository(this._db, this._uid);
  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _attempts =>
      _user.collection('attempts');
  CollectionReference<Map<String, dynamic>> get _drills =>
      _user.collection('drills');

  /// Offline, a commit only completes once the server acknowledges it, which
  /// may be much later; the local write is already visible to listeners.
  void _commit(WriteBatch batch) {
    unawaited(
      batch.commit().catchError((Object e) {
        debugPrint('progress sync failed: $e');
      }),
    );
  }

  @override
  Stream<ProgressSnapshot> watch() {
    late StreamController<ProgressSnapshot> out;
    Map<String, dynamic>? user;
    var papers = <PaperResult>[];
    var drills = <DrillResult>[];
    final subs = <StreamSubscription<Object>>[];
    void emit() => out.add(_snapshot(user, papers, drills));
    out = StreamController<ProgressSnapshot>(
      onListen: () {
        subs
          ..add(
            _user.snapshots().listen((d) {
              user = d.data();
              emit();
            }),
          )
          ..add(
            _attempts.snapshots().listen((q) {
              papers = [for (final d in q.docs) PaperResult.fromJson(d.data())];
              emit();
            }),
          )
          ..add(
            _drills.snapshots().listen((q) {
              drills = [for (final d in q.docs) DrillResult.fromJson(d.data())];
              emit();
            }),
          );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  static ProgressSnapshot _snapshot(
    Map<String, dynamic>? user,
    List<PaperResult> papers,
    List<DrillResult> drills,
  ) {
    final u = user ?? const <String, dynamic>{};
    final notebook = (u['notebook'] as Map<String, dynamic>?) ?? const {};
    final seen = (u['seen'] as Map<String, dynamic>?) ?? const {};
    final session = u['session'] as Map<String, dynamic>?;
    return ProgressSnapshot(
      profile: u['profile'] == null
          ? null
          : StudentProfile.fromJson(u['profile'] as Map<String, dynamic>),
      papers: papers,
      drills: drills,
      notebook: {
        for (final e in notebook.entries)
          e.key: MistakeEntry.fromJson(e.value as Map<String, dynamic>),
      },
      lastSeen: {
        for (final e in seen.entries) e.key: DateTime.parse(e.value as String),
      },
      session: session == null ? null : SavedPaperSession.fromJson(session),
    );
  }

  static Map<String, Object?> _notebookJson(Map<String, MistakeEntry> nb) => {
    for (final e in nb.entries) e.key: e.value.toJson(),
  };

  static Map<String, Object?> _seenJson(Map<String, DateTime> seen) => {
    for (final e in seen.entries) e.key: e.value.toUtc().toIso8601String(),
  };

  @override
  Future<void> saveProfile(StudentProfile profile) async {
    _commit(
      _db.batch()
        ..set(_user, {'profile': profile.toJson()}, SetOptions(merge: true)),
    );
  }

  @override
  Future<void> saveSession(SavedPaperSession session) async {
    _commit(
      _db.batch()
        ..set(_user, {'session': session.toJson()}, SetOptions(merge: true)),
    );
  }

  @override
  Future<void> recordPaper(
    PaperResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  }) async {
    _commit(
      _db.batch()
        ..set(_attempts.doc(), result.toJson())
        ..set(_user, {
          'notebook': _notebookJson(notebook),
          'seen': _seenJson(seen),
          'session': FieldValue.delete(),
        }, SetOptions(merge: true)),
    );
  }

  @override
  Future<void> recordDrill(
    DrillResult result, {
    required Map<String, MistakeEntry> notebook,
    required Map<String, DateTime> seen,
  }) async {
    _commit(
      _db.batch()
        ..set(_drills.doc(), result.toJson())
        ..set(_user, {
          'notebook': _notebookJson(notebook),
          'seen': _seenJson(seen),
        }, SetOptions(merge: true)),
    );
  }

  @override
  Future<void> deleteAll() async {
    final batch = _db.batch();
    for (final d in (await _attempts.get()).docs) {
      batch.delete(d.reference);
    }
    for (final d in (await _drills.get()).docs) {
      batch.delete(d.reference);
    }
    batch.delete(_user);
    await batch.commit();
  }
}

/// Null until someone (guest or account) is signed in.
final progressRepositoryProvider = Provider<ProgressRepository?>((ref) {
  final uid = ref.watch(authStateProvider.select((u) => u.value?.uid));
  return uid == null
      ? null
      : FirestoreProgressRepository(FirebaseFirestore.instance, uid);
});

final progressProvider = StreamProvider<ProgressSnapshot>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo == null ? Stream.value(ProgressSnapshot.empty) : repo.watch();
});
