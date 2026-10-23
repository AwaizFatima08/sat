import 'package:flutter/material.dart';
import 'package:moduleup/features/math/calculator.dart';
import 'package:moduleup/features/math/reference_sheet.dart';

/// Calculator and reference-sheet buttons for a Math question's app bar.
class MathToolButtons extends StatelessWidget {
  const MathToolButtons({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Calculator',
        icon: const Icon(Icons.calculate_outlined),
        onPressed: () => openCalculator(context),
      ),
      IconButton(
        tooltip: 'Reference sheet',
        icon: const Icon(Icons.functions),
        onPressed: () => openReferenceSheet(context),
      ),
    ],
  );
}
