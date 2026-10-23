import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/widgets/math_text.dart';

/// The standard formulas available on the Math section (our own layout).
const _formulas = [
  ('Circle', r'\(A = \pi r^{2}\), \(C = 2\pi r\)'),
  ('Rectangle', r'\(A = \ell w\)'),
  ('Triangle', r'\(A = \frac{1}{2}bh\)'),
  ('Pythagorean theorem', r'\(c^{2} = a^{2} + b^{2}\)'),
  (
    'Special right triangles',
    r'30°-60°-90°: sides \(x,\ x\sqrt{3},\ 2x\); 45°-45°-90°: sides \(s,\ s,\ s\sqrt{2}\)',
  ),
  ('Rectangular prism', r'\(V = \ell w h\)'),
  ('Cylinder', r'\(V = \pi r^{2} h\)'),
  ('Sphere', r'\(V = \frac{4}{3}\pi r^{3}\)'),
  ('Cone', r'\(V = \frac{1}{3}\pi r^{2} h\)'),
  ('Pyramid', r'\(V = \frac{1}{3}\ell w h\)'),
  (
    'Facts',
    r'A circle has \(360^{\circ}\) of arc, which equals \(2\pi\) radians. The angles of a triangle sum to \(180^{\circ}\).',
  ),
];

Future<void> showReferenceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ReferenceSheet(),
    );

void openReferenceSheet(BuildContext context) =>
    unawaited(showReferenceSheet(context));

class ReferenceSheet extends StatelessWidget {
  const ReferenceSheet({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(AppSpace.m, 0, AppSpace.m, AppSpace.l),
    shrinkWrap: true,
    children: [
      Text(
        'Reference',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpace.s),
      for (final (name, tex) in _formulas)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: MathText(tex),
        ),
    ],
  );
}
