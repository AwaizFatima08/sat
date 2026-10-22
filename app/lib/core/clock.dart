import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now". Domain code never calls `DateTime.now()` directly.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Calendar-day key (local time) used for daily allowances and streaks.
String dayKey(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
