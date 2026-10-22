import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/content.dart';

const _seriesColors = [Color(0xFF2F5BEA), Color(0xFFE08A1E), Color(0xFF2A9D74)];

/// A table or a bar/line graph for quantitative evidence questions.
class DataView extends StatelessWidget {
  const DataView({required this.data, super.key});
  final ItemData data;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      data.title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Column(
        children: [
          title,
          const SizedBox(height: AppSpace.s),
          switch (data) {
            final TableData t => _TableView(table: t),
            final GraphData g => _GraphView(graph: g),
          },
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});
  final TableData table;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    Widget cell(String s, {bool head = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        s,
        style: head ? style?.copyWith(fontWeight: FontWeight.w700) : style,
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: AppColors.line),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppColors.accentSoft),
                children: [for (final c in table.columns) cell(c, head: true)],
              ),
              for (final r in table.rows)
                TableRow(children: [for (final c in r) cell(c)]),
            ],
          ),
          if (table.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                table.note!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _GraphView extends StatelessWidget {
  const _GraphView({required this.graph});
  final GraphData graph;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final s in graph.series)
        for (final p in s.points) '${s.name}, ${p.label}: ${p.value}',
    ];
    return Semantics(
      label:
          '${graph.isLine ? 'Line' : 'Bar'} graph. ${graph.yLabel} by '
          '${graph.xLabel}. ${values.join('; ')}',
      child: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(painter: _GraphPainter(graph)),
          ),
          Wrap(
            spacing: AppSpace.m,
            children: [
              for (var i = 0; i < graph.series.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: _seriesColors[i % _seriesColors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(graph.series[i].name),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.g);
  final GraphData g;

  static double _niceMax(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final f in [1, 2, 2.5, 5, 10]) {
      if (f * mag >= v) return f * mag;
    }
    return 10 * mag;
  }

  void _text(
    Canvas c,
    String s,
    Offset at, {
    double size = 11,
    bool center = false,
    bool rotate = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: AppColors.muted, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    c.save();
    c.translate(at.dx, at.dy);
    if (rotate) c.rotate(-math.pi / 2);
    tp.paint(c, Offset(center ? -tp.width / 2 : -tp.width, -tp.height / 2));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 52.0;
    const bottom = 36.0;
    final plot = Rect.fromLTRB(left, 8, size.width - 8, size.height - bottom);
    final labels = g.series.first.points.map((p) => p.label).toList();
    final maxV = _niceMax(
      g.series.expand((s) => s.points).map((p) => p.value).reduce(math.max),
    );
    final axis = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), axis);
      final v = maxV * i / 4;
      _text(
        canvas,
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1),
        Offset(plot.left - 4, y),
      );
    }
    _text(
      canvas,
      g.yLabel,
      Offset(10, plot.center.dy),
      rotate: true,
      center: true,
    );
    final slot = plot.width / labels.length;
    for (var i = 0; i < labels.length; i++) {
      _text(
        canvas,
        labels[i],
        Offset(plot.left + slot * (i + 0.5), plot.bottom + 10),
        center: true,
      );
    }
    _text(
      canvas,
      g.xLabel,
      Offset(plot.center.dx, size.height - 8),
      center: true,
    );
    final n = g.series.length;
    for (var s = 0; s < n; s++) {
      final paint = Paint()..color = _seriesColors[s % _seriesColors.length];
      final pts = <Offset>[];
      for (var i = 0; i < g.series[s].points.length && i < labels.length; i++) {
        final v = g.series[s].points[i].value;
        final y = plot.bottom - plot.height * v / maxV;
        if (g.isLine) {
          pts.add(Offset(plot.left + slot * (i + 0.5), y));
        } else {
          final w = slot * 0.7 / n;
          final x = plot.left + slot * i + slot * 0.15 + w * s;
          canvas.drawRect(Rect.fromLTRB(x, y, x + w, plot.bottom), paint);
        }
      }
      if (g.isLine) {
        paint
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(Path()..addPolygon(pts, false), paint);
        for (final p in pts) {
          canvas.drawCircle(p, 4, Paint()..color = paint.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.g != g;
}
