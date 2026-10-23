import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/expr.dart';
import 'package:moduleup/widgets/data_view.dart';

typedef Json = Map<String, Object?>;

double _d(Object? v) => (v! as num).toDouble();
List<Json> _list(Object? v) => [
  for (final e in (v as List?) ?? const []) e as Json,
];

/// Draws a Math figure from its data spec (see the Math writing guide §4).
class MathFigure extends StatelessWidget {
  const MathFigure({required this.spec, super.key});
  final Json spec;

  @override
  Widget build(BuildContext context) {
    final kind = spec['kind'];
    if (kind == 'table' || kind == 'bar' || kind == 'line') {
      return DataView(
        data: ItemData.fromJson({'title': spec['title'] ?? '', ...spec}),
      );
    }
    final painter = switch (kind) {
      'xy' => _XyPainter(spec),
      'geometry' => _GeometryPainter(spec),
      'scatter' => _ScatterPainter(spec),
      'histogram' => _HistogramPainter(spec),
      'dotplot' => _DotPlotPainter(spec),
      'boxplot' => _BoxPlotPainter(spec),
      _ => null,
    };
    if (painter == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Column(
        children: [
          if (spec['title'] case final String t)
            Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          Semantics(
            label: 'Figure: ${spec['kind']}',
            child: AspectRatio(
              aspectRatio: kind == 'geometry' ? 1.25 : 1.35,
              child: CustomPaint(painter: painter, size: Size.infinite),
            ),
          ),
          if (spec['not_to_scale'] == true)
            const Text(
              'Note: Figure not drawn to scale.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

const Color _ink = AppColors.ink;
final _gridPaint = Paint()..color = const Color(0xFFE8EBF1);
final _axisPaint = Paint()
  ..color = const Color(0xFF6B7385)
  ..strokeWidth = 1.2;
const List<Color> _curveColors = [
  AppColors.accent,
  Color(0xFFE08A1E),
  Color(0xFF2A9D74),
];

void _label(
  Canvas c,
  String s,
  Offset at, {
  double size = 11,
  Color color = AppColors.muted,
  bool center = true,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: color, fontSize: size, fontFamily: 'Roboto'),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 140);
  tp.paint(c, at - Offset(center ? tp.width / 2 : 0, tp.height / 2));
}

/// Maps data coordinates to canvas pixels inside a padded plot rect.
class _Frame {
  _Frame(this.plot, this.x0, this.x1, this.y0, this.y1);
  final Rect plot;
  final double x0;
  final double x1;
  final double y0;
  final double y1;
  double sx(double x) => plot.left + (x - x0) / (x1 - x0) * plot.width;
  double sy(double y) => plot.bottom - (y - y0) / (y1 - y0) * plot.height;
  Offset p(double x, double y) => Offset(sx(x), sy(y));
}

double _niceStep(double span) {
  final raw = span / 8;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 5, 10]) {
    if (m * mag >= raw) return m * mag;
  }
  return 10 * mag;
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

void _gridAndAxes(
  Canvas c,
  _Frame f, {
  String? xLabel,
  String? yLabel,
  bool cross = true,
}) {
  final xs = _niceStep(f.x1 - f.x0);
  final ys = _niceStep(f.y1 - f.y0);
  for (var x = (f.x0 / xs).ceil() * xs; x <= f.x1 + 1e-9; x += xs) {
    c.drawLine(
      Offset(f.sx(x), f.plot.top),
      Offset(f.sx(x), f.plot.bottom),
      _gridPaint,
    );
    final ay = cross && f.y0 <= 0 && f.y1 >= 0 ? f.sy(0) : f.plot.bottom;
    if (x.abs() > 1e-9 || !cross) {
      _label(c, _fmt(x), Offset(f.sx(x), ay + 9), size: 9);
    }
  }
  for (var y = (f.y0 / ys).ceil() * ys; y <= f.y1 + 1e-9; y += ys) {
    c.drawLine(
      Offset(f.plot.left, f.sy(y)),
      Offset(f.plot.right, f.sy(y)),
      _gridPaint,
    );
    final ax = cross && f.x0 <= 0 && f.x1 >= 0 ? f.sx(0) : f.plot.left;
    if (y.abs() > 1e-9 || !cross) {
      _label(c, _fmt(y), Offset(ax - 12, f.sy(y)), size: 9);
    }
  }
  if (cross && f.y0 <= 0 && f.y1 >= 0) {
    c.drawLine(
      Offset(f.plot.left, f.sy(0)),
      Offset(f.plot.right, f.sy(0)),
      _axisPaint,
    );
  } else {
    c.drawLine(f.plot.bottomLeft, f.plot.bottomRight, _axisPaint);
  }
  if (cross && f.x0 <= 0 && f.x1 >= 0) {
    c.drawLine(
      Offset(f.sx(0), f.plot.top),
      Offset(f.sx(0), f.plot.bottom),
      _axisPaint,
    );
  } else {
    c.drawLine(f.plot.bottomLeft, f.plot.topLeft, _axisPaint);
  }
  if (xLabel != null) {
    _label(c, xLabel, Offset(f.plot.center.dx, f.plot.bottom + 24));
  }
  if (yLabel != null) {
    c
      ..save()
      ..translate(f.plot.left - 26, f.plot.center.dy)
      ..rotate(-math.pi / 2);
    _label(c, yLabel, Offset.zero);
    c.restore();
  }
}

void _curve(Canvas c, _Frame f, String expr, Color color) {
  final fn = compileExpr(expr);
  if (fn == null) return;
  final paint = Paint()
    ..color = color
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;
  var path = Path();
  var open = false;
  for (var i = 0; i <= 400; i++) {
    final x = f.x0 + (f.x1 - f.x0) * i / 400;
    final y = fn(x);
    if (y == null || y < f.y0 - (f.y1 - f.y0) || y > f.y1 + (f.y1 - f.y0)) {
      open = false;
      continue;
    }
    final pt = f.p(x, y.clamp(f.y0 - 1, f.y1 + 1));
    open ? path.lineTo(pt.dx, pt.dy) : path.moveTo(pt.dx, pt.dy);
    open = true;
  }
  c
    ..save()
    ..clipRect(f.plot);
  c.drawPath(path, paint);
  c.restore();
  path = Path();
}

class _XyPainter extends CustomPainter {
  _XyPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final xr = s['x']! as List;
    final yr = s['y']! as List;
    final f = _Frame(
      Rect.fromLTRB(36, 10, size.width - 10, size.height - 34),
      _d(xr[0]),
      _d(xr[1]),
      _d(yr[0]),
      _d(yr[1]),
    );
    _gridAndAxes(
      c,
      f,
      xLabel: s['x_label'] as String?,
      yLabel: s['y_label'] as String?,
    );
    final curves = _list(s['curves']);
    for (var i = 0; i < curves.length; i++) {
      _curve(c, f, curves[i]['expr']! as String, _curveColors[i % 3]);
      if (curves[i]['label'] case final String lab) {
        _label(
          c,
          lab,
          Offset(f.plot.right - 40, f.plot.top + 12 + 14.0 * i),
          color: _curveColors[i % 3],
        );
      }
    }
    for (final seg in _list(s['segments'])) {
      final a = seg['from']! as List;
      final b = seg['to']! as List;
      c.drawLine(
        f.p(_d(a[0]), _d(a[1])),
        f.p(_d(b[0]), _d(b[1])),
        Paint()
          ..color = _ink
          ..strokeWidth = 2,
      );
    }
    for (final p in _list(s['points'])) {
      final o = f.p(_d(p['x']), _d(p['y']));
      c.drawCircle(o, 4, Paint()..color = _ink);
      if (p['label'] case final String lab) {
        _label(c, lab, o + const Offset(6, -10), color: _ink, center: false);
      }
    }
  }

  @override
  bool shouldRepaint(_XyPainter old) => old.s != s;
}

class _GeometryPainter extends CustomPainter {
  _GeometryPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final pts = <String, Offset>{
      for (final e in ((s['points'] as Map?) ?? const {}).entries)
        e.key as String: Offset(
          _d((e.value as List)[0]),
          _d((e.value as List)[1]),
        ),
    };
    final circles = _list(s['circles']);
    Offset centerOf(Json ci) => ci['center'] is String
        ? pts[ci['center']]!
        : Offset(
            _d((ci['center']! as List)[0]),
            _d((ci['center']! as List)[1]),
          );
    final xs = [
      for (final p in pts.values) p.dx,
      for (final ci in circles) ...[
        centerOf(ci).dx - _d(ci['radius']),
        centerOf(ci).dx + _d(ci['radius']),
      ],
    ];
    final ys = [
      for (final p in pts.values) p.dy,
      for (final ci in circles) ...[
        centerOf(ci).dy - _d(ci['radius']),
        centerOf(ci).dy + _d(ci['radius']),
      ],
    ];
    if (xs.isEmpty) return;
    final x0 = xs.reduce(math.min);
    final x1 = xs.reduce(math.max);
    final y0 = ys.reduce(math.min);
    final y1 = ys.reduce(math.max);
    final k = math.min(
      (size.width - 48) / math.max(1e-6, x1 - x0),
      (size.height - 48) / math.max(1e-6, y1 - y0),
    );
    final ox = (size.width - (x1 - x0) * k) / 2;
    final oy = (size.height - (y1 - y0) * k) / 2;
    Offset m(Offset p) =>
        Offset(ox + (p.dx - x0) * k, size.height - oy - (p.dy - y0) * k);
    final line = Paint()
      ..color = _ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final seg in (s['segments'] as List?) ?? const []) {
      final ab = seg as List;
      if (pts[ab[0]] != null && pts[ab[1]] != null) {
        c.drawLine(m(pts[ab[0]]!), m(pts[ab[1]]!), line);
      }
    }
    for (final ci in circles) {
      c.drawCircle(m(centerOf(ci)), _d(ci['radius']) * k, line);
    }
    for (final name in (s['right_angles'] as List?) ?? const []) {
      final v = pts[name];
      if (v == null) continue;
      final nbrs = [
        for (final seg in (s['segments'] as List?) ?? const [])
          if ((seg as List)[0] == name)
            pts[seg[1]]
          else if (seg[1] == name)
            pts[seg[0]],
      ].whereType<Offset>().take(2).toList();
      if (nbrs.length < 2) continue;
      final a = m(v);
      Offset unit(Offset p) => (m(p) - a) / (m(p) - a).distance * 12;
      final u1 = unit(nbrs[0]);
      final u2 = unit(nbrs[1]);
      c.drawPath(
        Path()
          ..moveTo(a.dx + u1.dx, a.dy + u1.dy)
          ..lineTo(a.dx + u1.dx + u2.dx, a.dy + u1.dy + u2.dy)
          ..lineTo(a.dx + u2.dx, a.dy + u2.dy),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    final centroid = pts.isEmpty
        ? Offset.zero
        : pts.values.reduce((a, b) => a + b) / pts.length.toDouble();
    for (final e in pts.entries) {
      final o = m(e.value);
      c.drawCircle(o, 3, Paint()..color = _ink);
      final dir = e.value - centroid;
      final off = dir.distance < 1e-9
          ? const Offset(0, -12)
          : Offset(dir.dx, -dir.dy) / dir.distance * 14;
      _label(c, e.key, o + off, size: 13, color: _ink);
    }
    for (final lab in _list(s['labels'])) {
      final at = lab['at']! as List;
      _label(
        c,
        lab['text']! as String,
        m(Offset(_d(at[0]), _d(at[1]))),
        size: 12,
        color: const Color(0xFFA35D00),
      );
    }
  }

  @override
  bool shouldRepaint(_GeometryPainter old) => old.s != s;
}

_Frame _dataFrame(Size size, double x0, double x1, double y0, double y1) {
  final px = (x1 - x0) * 0.06;
  final py = (y1 - y0) * 0.08;
  return _Frame(
    Rect.fromLTRB(44, 10, size.width - 10, size.height - 34),
    x0 - px,
    x1 + px,
    math.min(0, y0 - py),
    y1 + py,
  );
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final pts = [
      for (final p in (s['points']! as List))
        Offset(_d((p as List)[0]), _d(p[1])),
    ];
    if (pts.isEmpty) return;
    final f = _dataFrame(
      size,
      math.min(0, pts.map((p) => p.dx).reduce(math.min)),
      pts.map((p) => p.dx).reduce(math.max),
      pts.map((p) => p.dy).reduce(math.min),
      pts.map((p) => p.dy).reduce(math.max),
    );
    _gridAndAxes(
      c,
      f,
      xLabel: s['x_label'] as String?,
      yLabel: s['y_label'] as String?,
      cross: false,
    );
    if (s['line'] case final String expr) {
      _curve(c, f, expr, const Color(0xFFE08A1E));
    }
    for (final p in pts) {
      c.drawCircle(f.p(p.dx, p.dy), 3.5, Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => old.s != s;
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final bins = [
      for (final b in (s['bins']! as List))
        (lo: _d((b as List)[0]), hi: _d(b[1]), n: _d(b[2])),
    ];
    if (bins.isEmpty) return;
    final f = _Frame(
      Rect.fromLTRB(40, 10, size.width - 10, size.height - 34),
      bins.first.lo,
      bins.last.hi,
      0,
      bins.map((b) => b.n).reduce(math.max) * 1.15,
    );
    _gridAndAxes(
      c,
      f,
      xLabel: s['x_label'] as String?,
      yLabel: (s['y_label'] as String?) ?? 'Frequency',
      cross: false,
    );
    for (final b in bins) {
      final r = Rect.fromPoints(f.p(b.lo, 0), f.p(b.hi, b.n));
      c
        ..drawRect(r, Paint()..color = AppColors.accentSoft)
        ..drawRect(
          r,
          Paint()
            ..color = AppColors.accent
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.s != s;
}

class _DotPlotPainter extends CustomPainter {
  _DotPlotPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final vals = [for (final v in (s['values']! as List)) _d(v)]..sort();
    if (vals.isEmpty) return;
    final counts = <double, int>{};
    for (final v in vals) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final maxCount = counts.values.reduce(math.max);
    final lo = vals.first.floorToDouble() - 1;
    final hi = vals.last.ceilToDouble() + 1;
    final plot = Rect.fromLTRB(20, 10, size.width - 20, size.height - 34);
    double sx(double x) => plot.left + (x - lo) / (hi - lo) * plot.width;
    c.drawLine(plot.bottomLeft, plot.bottomRight, _axisPaint);
    final step = _niceStep(hi - lo).clamp(1, double.infinity);
    for (var x = lo; x <= hi + 1e-9; x += step) {
      _label(c, _fmt(x), Offset(sx(x), plot.bottom + 10), size: 10);
    }
    final r = math.min(7, (plot.height / (maxCount + 1)) / 2.2).toDouble();
    for (final e in counts.entries) {
      for (var i = 0; i < e.value; i++) {
        c.drawCircle(
          Offset(sx(e.key), plot.bottom - r * 1.2 - i * r * 2.3),
          r,
          Paint()..color = AppColors.accent,
        );
      }
    }
    if (s['x_label'] case final String xl) {
      _label(c, xl, Offset(plot.center.dx, plot.bottom + 26));
    }
  }

  @override
  bool shouldRepaint(_DotPlotPainter old) => old.s != s;
}

class _BoxPlotPainter extends CustomPainter {
  _BoxPlotPainter(this.s);
  final Json s;

  @override
  void paint(Canvas c, Size size) {
    final plots = _list(s['plots']);
    if (plots.isEmpty) return;
    final lo = plots.map((p) => _d(p['min'])).reduce(math.min);
    final hi = plots.map((p) => _d(p['max'])).reduce(math.max);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    final plot = Rect.fromLTRB(70, 10, size.width - 16, size.height - 34);
    double sx(double x) =>
        plot.left + (x - (lo - span * 0.05)) / (span * 1.1) * plot.width;
    c.drawLine(plot.bottomLeft, plot.bottomRight, _axisPaint);
    final step = _niceStep(span * 1.1);
    for (var x = (lo / step).ceil() * step; x <= hi + 1e-9; x += step) {
      _label(c, _fmt(x), Offset(sx(x), plot.bottom + 10), size: 10);
    }
    final rowH = plot.height / plots.length;
    final stroke = Paint()
      ..color = _ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < plots.length; i++) {
      final p = plots[i];
      final cy = plot.top + rowH * (i + 0.5);
      final h = math.min(28, rowH * 0.5).toDouble();
      c
        ..drawLine(
          Offset(sx(_d(p['min'])), cy),
          Offset(sx(_d(p['q1'])), cy),
          stroke,
        )
        ..drawLine(
          Offset(sx(_d(p['q3'])), cy),
          Offset(sx(_d(p['max'])), cy),
          stroke,
        )
        ..drawRect(
          Rect.fromLTRB(
            sx(_d(p['q1'])),
            cy - h / 2,
            sx(_d(p['q3'])),
            cy + h / 2,
          ),
          Paint()..color = AppColors.accentSoft,
        )
        ..drawRect(
          Rect.fromLTRB(
            sx(_d(p['q1'])),
            cy - h / 2,
            sx(_d(p['q3'])),
            cy + h / 2,
          ),
          stroke,
        )
        ..drawLine(
          Offset(sx(_d(p['median'])), cy - h / 2),
          Offset(sx(_d(p['median'])), cy + h / 2),
          stroke..strokeWidth = 2.4,
        );
      stroke.strokeWidth = 1.6;
      for (final k in ['min', 'max']) {
        c.drawLine(
          Offset(sx(_d(p[k])), cy - h / 4),
          Offset(sx(_d(p[k])), cy + h / 4),
          stroke,
        );
      }
      if (p['name'] case final String n) {
        _label(c, n, Offset(8, cy), color: _ink, center: false);
      }
    }
    if (s['x_label'] case final String xl) {
      _label(c, xl, Offset(plot.center.dx, plot.bottom + 26));
    }
  }

  @override
  bool shouldRepaint(_BoxPlotPainter old) => old.s != s;
}
