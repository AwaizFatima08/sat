import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/expr.dart';
import 'package:moduleup/features/math/graph_tab.dart';

/// Opens the built-in calculator as a tall bottom sheet over a Math question.
Future<void> showCalculator(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      const FractionallySizedBox(heightFactor: 0.92, child: CalculatorPanel()),
);

class CalculatorPanel extends StatelessWidget {
  const CalculatorPanel({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 2,
    child: Column(
      children: [
        TabBar(
          tabs: [
            Tab(text: 'Scientific'),
            Tab(text: 'Graph'),
          ],
        ),
        Expanded(child: TabBarView(children: [_Scientific(), GraphTab()])),
      ],
    ),
  );
}

String _num(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  final s = v.toStringAsPrecision(10);
  return s.contains('e')
      ? s
      : s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

class _Scientific extends StatefulWidget {
  const _Scientific();
  @override
  State<_Scientific> createState() => _ScientificState();
}

class _ScientificState extends State<_Scientific> {
  final _ctl = TextEditingController();
  final _history = <(String, String)>[];
  bool _degrees = true;
  String? _ans;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _preview {
    if (_ctl.text.trim().isEmpty) return '';
    final v = evalExpr(_expand(_ctl.text), degrees: _degrees);
    return v == null ? '' : '= ${_num(v)}';
  }

  String _expand(String s) => s
      .replaceAll('Ans', _ans ?? '0')
      .replaceAll('√', 'sqrt')
      .replaceAll('²', '^2');

  void _insert(String s) {
    final sel = _ctl.selection;
    final text = _ctl.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _ctl.value = TextEditingValue(
      text: text.replaceRange(at, end, s),
      selection: TextSelection.collapsed(offset: at + s.length),
    );
    setState(() {});
  }

  void _equals() {
    final v = evalExpr(_expand(_ctl.text), degrees: _degrees);
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That expression could not be evaluated.'),
        ),
      );
      return;
    }
    setState(() {
      _history.insert(0, (_ctl.text, _num(v)));
      _ans = _num(v);
      _ctl.text = _num(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['mean(', 'median(', 'stdev(', 'sum(', ','],
      ['sin(', 'cos(', 'tan(', 'π', '^'],
      ['√(', '²', '(', ')', '/'],
      ['7', '8', '9', 'ln(', '*'],
      ['4', '5', '6', 'Ans', '-'],
      ['1', '2', '3', 'e', '+'],
      ['0', '.', '⌫', 'C', '='],
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type or tap an expression',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _equals(),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Deg')),
                  ButtonSegment(value: false, label: Text('Rad')),
                ],
                selected: {_degrees},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _degrees = v.first),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _preview,
              style: const TextStyle(fontSize: 18, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          for (final row in keys)
            Expanded(
              child: Row(
                children: [
                  for (final k in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                          ),
                          onPressed: () => switch (k) {
                            '=' => _equals(),
                            'C' => setState(_ctl.clear),
                            '⌫' => setState(() {
                              if (_ctl.text.isNotEmpty) {
                                _ctl.text = _ctl.text.substring(
                                  0,
                                  _ctl.text.length - 1,
                                );
                              }
                            }),
                            _ => _insert(k),
                          },
                          child: FittedBox(
                            child: Text(
                              k,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_history.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                children: [
                  for (final (e, v) in _history.take(5))
                    Text(
                      '$e = $v',
                      style: const TextStyle(color: AppColors.muted),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small helper so other screens can open the calculator without awaiting.
void openCalculator(BuildContext context) => unawaited(showCalculator(context));
