import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/expr.dart';

/// The Graph tab: up to four entries (curves, equations linear in y,
/// vertical lines, points), with x-intercepts, intersections, turning points
/// and tap-to-read coordinates.
class GraphTab extends StatefulWidget {
  const GraphTab({super.key});
  @override
  State<GraphTab> createState() => _GraphTabState();
}

const _defaultView = Rect.fromLTRB(-10, -10, 10, 10);

const graphColors = [
  AppColors.accent,
  Color(0xFFE08A1E),
  Color(0xFF2A9D74),
  Color(0xFFB23A8E),
];

String fmtNum(double v) {
  final r = double.parse(v.toStringAsFixed(4));
  if (r == r.roundToDouble() && r.abs() < 1e15) return r.toInt().toString();
  return r.toString();
}

String fmtPoint(double x, double y) => '(${fmtNum(x)}, ${fmtNum(y)})';

class _GraphTabState extends State<GraphTab> {
  final _ctls = List.generate(4, (_) => TextEditingController());
  Rect _view = _defaultView;
  ({int entry, double x, double y})? _picked;

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  List<GraphEntry?> get _entries => [
    for (final c in _ctls)
      c.text.trim().isEmpty ? null : parseGraphEntry(c.text),
  ];

  void _zoom(double k) => setState(() {
    _view = Rect.fromCenter(
      center: _view.center,
      width: _view.width * k,
      height: _view.height * k,
    );
  });

  void _tap(Offset p, Size size, List<GraphEntry?> entries) {
    final x = _view.left + p.dx / size.width * _view.width;
    double sy(double y) =>
        size.height - (y - _view.top) / _view.height * size.height;
    ({int entry, double x, double y})? best;
    var bestDist = 36.0;
    for (final (i, e) in entries.indexed) {
      final (double, double)? at = switch (e) {
        CurveEntry(:final f) => f(x) == null ? null : (x, f(x)!),
        PointEntry(x: final px, y: final py) => (px, py),
        _ => null,
      };
      if (at == null) continue;
      final dx = (at.$1 - x) / _view.width * size.width;
      final d = math.sqrt(dx * dx + math.pow(sy(at.$2) - p.dy, 2));
      if (d < bestDist) {
        bestDist = d;
        best = (entry: i, x: at.$1, y: at.$2);
      }
    }
    setState(() => _picked = best);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final facts = graphFacts(entries, _view.left, _view.right);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        children: [
          for (var i = 0; i < _ctls.length; i++)
            _EntryField(
              index: i,
              controller: _ctls[i],
              entry: entries[i],
              onChanged: () => setState(() => _picked = null),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                return GestureDetector(
                  onTapUp: (d) => _tap(d.localPosition, size, entries),
                  onPanUpdate: (d) => setState(() {
                    _view = _view.shift(
                      Offset(
                        -d.delta.dx / size.width * _view.width,
                        d.delta.dy / size.height * _view.height,
                      ),
                    );
                  }),
                  child: ClipRect(
                    child: CustomPaint(
                      painter: GraphPainter(_view, entries, _picked),
                      size: size,
                    ),
                  ),
                );
              },
            ),
          ),
          _GraphControls(
            view: _view,
            picked: _picked,
            onZoom: _zoom,
            onReset: () => setState(() => _view = _defaultView),
          ),
          if (facts.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView(
                children: [
                  for (final f in facts)
                    Text(f, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.index,
    required this.controller,
    required this.entry,
    required this.onChanged,
  });
  final int index;
  final TextEditingController controller;
  final GraphEntry? entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.circle, size: 12, color: graphColors[index]),
        prefixIconConstraints: const BoxConstraints(minWidth: 28),
        hintText: switch (index) {
          0 => 'y = 2x^2 - 3x + 1',
          1 => '3x - 4y = 8',
          2 => 'x = 5',
          _ => '(2, 3)',
        },
        errorText: switch (entry) {
          BadEntry(:final message) => message,
          _ => null,
        },
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}

class _GraphControls extends StatelessWidget {
  const _GraphControls({
    required this.view,
    required this.picked,
    required this.onZoom,
    required this.onReset,
  });
  final Rect view;
  final ({int entry, double x, double y})? picked;
  final ValueChanged<double> onZoom;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Zoom in',
        onPressed: () => onZoom(0.5),
        icon: const Icon(Icons.zoom_in),
      ),
      IconButton(
        tooltip: 'Zoom out',
        onPressed: () => onZoom(2),
        icon: const Icon(Icons.zoom_out),
      ),
      IconButton(
        tooltip: 'Reset view',
        onPressed: onReset,
        icon: const Icon(Icons.center_focus_strong),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          switch (picked) {
            final p? => 'Line ${p.entry + 1}: ${fmtPoint(p.x, p.y)}',
            null => 'x ${fmtNum(view.left)} to ${fmtNum(view.right)}',
          },
          textAlign: TextAlign.end,
          style: TextStyle(
            color: picked == null ? AppColors.muted : null,
            fontWeight: picked == null ? null : FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

/// What the Graph tab reports under the graph for the visible x range.
List<String> graphFacts(List<GraphEntry?> entries, double lo, double hi) {
  final out = <String>[];
  for (final (i, e) in entries.indexed) {
    if (e is! CurveEntry) continue;
    final n = 'Line ${i + 1}';
    for (final z in zerosOf(e.f, lo, hi).take(4)) {
      out.add('$n crosses the x-axis at ${fmtPoint(z, 0)}');
    }
    for (final t in turningPoints(e.f, lo, hi).take(3)) {
      out.add('$n ${t.max ? 'maximum' : 'minimum'} at ${fmtPoint(t.x, t.y)}');
    }
    for (final (j, other) in entries.indexed) {
      if (j <= i || other == null) continue;
      final m = 'Lines ${i + 1} and ${j + 1}';
      switch (other) {
        case CurveEntry(:final f):
          double? diff(double x) {
            final a = e.f(x);
            final b = f(x);
            return a == null || b == null ? null : a - b;
          }
          for (final x in zerosOf(diff, lo, hi).take(4)) {
            out.add('$m meet at ${fmtPoint(x, e.f(x)!)}');
          }
        case VerticalEntry(:final x):
          if (e.f(x) case final y?) out.add('$m meet at ${fmtPoint(x, y)}');
        case PointEntry(:final x, :final y):
          final fy = e.f(x);
          final on = fy != null && (fy - y).abs() < 1e-6 * (1 + y.abs());
          out.add(
            on
                ? 'Point ${fmtPoint(x, y)} is on line ${i + 1}'
                : 'Point ${fmtPoint(x, y)} is not on line ${i + 1}',
          );
        case BadEntry():
          break;
      }
    }
  }
  // Points listed before the curve they are checked against.
  for (final (i, e) in entries.indexed) {
    if (e is! PointEntry) continue;
    for (final (j, c) in entries.indexed) {
      if (j <= i || c is! CurveEntry) continue;
      final fy = c.f(e.x);
      final on = fy != null && (fy - e.y).abs() < 1e-6 * (1 + e.y.abs());
      out.add(
        'Point ${fmtPoint(e.x, e.y)} is '
        '${on ? '' : 'not '}on line ${j + 1}',
      );
    }
  }
  return out;
}

class GraphPainter extends CustomPainter {
  GraphPainter(this.view, this.entries, this.picked);
  final Rect view;
  final List<GraphEntry?> entries;
  final ({int entry, double x, double y})? picked;

  @override
  void paint(Canvas c, Size size) {
    double sx(double x) => (x - view.left) / view.width * size.width;
    double sy(double y) =>
        size.height - (y - view.top) / view.height * size.height;
    c.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final grid = Paint()..color = const Color(0xFFEDEFF4);
    final step = math
        .pow(10, (math.log(view.width / 8) / math.ln10).floor())
        .toDouble();
    for (var x = (view.left / step).ceil() * step; x <= view.right; x += step) {
      c.drawLine(Offset(sx(x), 0), Offset(sx(x), size.height), grid);
    }
    for (var y = (view.top / step).ceil() * step; y <= view.bottom; y += step) {
      c.drawLine(Offset(0, sy(y)), Offset(size.width, sy(y)), grid);
    }
    final axis = Paint()
      ..color = const Color(0xFF6B7385)
      ..strokeWidth = 1.3;
    c
      ..drawLine(Offset(sx(0), 0), Offset(sx(0), size.height), axis)
      ..drawLine(Offset(0, sy(0)), Offset(size.width, sy(0)), axis);
    for (final (i, e) in entries.indexed) {
      final paint = Paint()
        ..color = graphColors[i]
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      switch (e) {
        case CurveEntry(:final f):
          c.drawPath(_curve(f, size, sy), paint);
        case VerticalEntry(:final x):
          c.drawLine(Offset(sx(x), 0), Offset(sx(x), size.height), paint);
        case PointEntry(:final x, :final y):
          c.drawCircle(
            Offset(sx(x), sy(y)),
            5,
            paint..style = PaintingStyle.fill,
          );
        case BadEntry() || null:
          break;
      }
    }
    if (picked case final p?) {
      final o = Offset(sx(p.x), sy(p.y));
      c
        ..drawCircle(o, 7, Paint()..color = Colors.white)
        ..drawCircle(
          o,
          7,
          Paint()
            ..color = graphColors[p.entry]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
    }
  }

  Path _curve(
    double? Function(double) f,
    Size size,
    double Function(double) sy,
  ) {
    final path = Path();
    var open = false;
    final n = size.width.toInt();
    for (var px = 0; px <= n; px++) {
      final x = view.left + view.width * px / n;
      final y = f(x);
      if (y == null || (y - view.center.dy).abs() > view.height * 5) {
        open = false;
        continue;
      }
      open
          ? path.lineTo(px.toDouble(), sy(y))
          : path.moveTo(px.toDouble(), sy(y));
      open = true;
    }
    return path;
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}
