/// Grading of student-produced responses (typed Math answers), following the
/// published Digital SAT entry rules:
/// - up to 5 characters for a positive answer, 6 for a negative one;
/// - a fraction or a decimal; no mixed numbers, %, \$ or commas;
/// - a decimal that does not fit must be truncated or rounded so that it
///   fills all available characters (2/3 → .6666, .6667, 0.666, 0.667).
library;

/// Characters allowed in the answer box.
final sprAllowed = RegExp(r'^[0-9./-]*$');

/// Maximum characters for an entry (the minus sign has its own extra slot).
int sprMaxLength(String entry) => entry.startsWith('-') ? 6 : 5;

/// An exact rational number, enough for SAT answers.
class Rational {
  Rational(BigInt n, BigInt d)
    : num = (d.isNegative ? -n : n) ~/ n.gcd(d).abs().max1,
      den = d.abs() ~/ n.gcd(d).abs().max1;

  final BigInt num;
  final BigInt den;

  /// Parses an integer, a decimal (".5", "-0.25") or a fraction ("7/4").
  static Rational? parse(String s) {
    final t = s.trim();
    final frac = RegExp(r'^(-?\d+)/(-?\d+)$').firstMatch(t);
    if (frac != null) {
      final d = BigInt.parse(frac.group(2)!);
      return d == BigInt.zero
          ? null
          : Rational(BigInt.parse(frac.group(1)!), d);
    }
    final dec = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$').firstMatch(t);
    if (dec == null ||
        (dec.group(2)!.isEmpty && (dec.group(3) ?? '').isEmpty)) {
      return null;
    }
    final whole = dec.group(2)!.isEmpty ? '0' : dec.group(2)!;
    final frac2 = dec.group(3) ?? '';
    final n =
        BigInt.parse('$whole$frac2') *
        (dec.group(1) == '-' ? -BigInt.one : BigInt.one);
    return Rational(n, BigInt.from(10).pow(frac2.length));
  }

  @override
  bool operator ==(Object other) =>
      other is Rational && other.num == num && other.den == den;

  @override
  int get hashCode => Object.hash(num, den);

  /// Value cut to [places] decimal places, toward zero (truncation) or to
  /// the nearest (rounding, half away from zero).
  Rational toPlaces(int places, {required bool round}) {
    final scale = BigInt.from(10).pow(places);
    final scaled = num * scale;
    var q = scaled ~/ den; // truncates toward zero
    if (round) {
      final r = (scaled - q * den).abs() * BigInt.two;
      if (r >= den) q += num.isNegative ? -BigInt.one : BigInt.one;
    }
    return Rational(q, scale);
  }
}

extension on BigInt {
  BigInt get max1 => this == BigInt.zero ? BigInt.one : this;
}

/// Whether [entry] is a valid answer-box entry (format only).
bool sprWellFormed(String entry) {
  final e = entry.trim();
  if (e.isEmpty || !sprAllowed.hasMatch(e) || e.length > sprMaxLength(e)) {
    return false;
  }
  return Rational.parse(e) != null;
}

/// True when [entry] earns credit for a question whose exact accepted values
/// are [accepted] (strings like "2/3", "-4", "0.125").
bool gradeSpr(String? entry, List<String> accepted) {
  if (entry == null || !sprWellFormed(entry)) return false;
  final e = entry.trim();
  final given = Rational.parse(e)!;
  for (final a in accepted) {
    final v = Rational.parse(a);
    if (v == null) continue;
    if (given == v) return true;
    // A decimal that fills every available character may be truncated or rounded.
    final dot = e.indexOf('.');
    if (dot < 0 || e.contains('/') || e.length < sprMaxLength(e)) continue;
    final places = e.length - dot - 1;
    if (given == v.toPlaces(places, round: false) ||
        given == v.toPlaces(places, round: true)) {
      return true;
    }
  }
  return false;
}
