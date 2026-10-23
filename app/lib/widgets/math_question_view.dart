import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/engine/spr.dart';
import 'package:moduleup/widgets/math_figure.dart';
import 'package:moduleup/widgets/math_text.dart';
import 'package:moduleup/widgets/question_view.dart';

/// A Math question: stem, optional figure, then four choices or a typed
/// answer box. With [revealed], shows the key, choice explanations and the
/// worked solution.
class MathQuestionView extends StatelessWidget {
  const MathQuestionView({
    required this.item,
    super.key,
    this.response,
    this.eliminated = const {},
    this.onRespond,
    this.onEliminate,
    this.revealed = false,
    this.header,
  });

  final Item item;

  /// Selected letter (multiple choice) or typed entry.
  final String? response;
  final Set<String> eliminated;
  final ValueChanged<String>? onRespond;
  final ValueChanged<String>? onEliminate;
  final bool revealed;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final stemStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.5);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        ?header,
        MathText(item.stem, style: stemStyle),
        if (item.figure case final f?) MathFigure(spec: f),
        const SizedBox(height: AppSpace.m),
        if (item.isTyped)
          _TypedAnswer(
            key: ValueKey('typed-${item.id}'),
            initial: response,
            onChanged: revealed ? null : onRespond,
            revealed: revealed,
            correct: item.isCorrect(response),
            accepted: item.typedAnswers,
          )
        else
          for (final l in answerLetters)
            ChoiceTile(
              letter: l,
              text: item.choices[l] ?? '',
              selected: response == l,
              eliminated: eliminated.contains(l),
              onTap: revealed || onRespond == null ? null : () => onRespond!(l),
              onEliminate: revealed || onEliminate == null
                  ? null
                  : () => onEliminate!(l),
              isKey: revealed ? item.answer == l : null,
              explanation: revealed ? item.choiceExplanations[l] : null,
            ),
        if (revealed && item.solution.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          Card(
            color: AppColors.accentSoft,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solution',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  for (final (i, step) in item.solution.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 22, child: Text('${i + 1}.')),
                          Expanded(child: MathText(step)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypedAnswer extends StatefulWidget {
  const _TypedAnswer({
    required this.initial,
    required this.onChanged,
    required this.revealed,
    required this.correct,
    required this.accepted,
    super.key,
  });

  final String? initial;
  final ValueChanged<String>? onChanged;
  final bool revealed;
  final bool correct;
  final List<String> accepted;

  @override
  State<_TypedAnswer> createState() => _TypedAnswerState();
}

class _TypedAnswerState extends State<_TypedAnswer> {
  late final _ctl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctl.text;
    final valid = text.isEmpty || sprWellFormed(text);
    final border = widget.revealed
        ? (widget.correct ? AppColors.correct : AppColors.wrong)
        : AppColors.line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Your answer',
          textField: true,
          child: TextField(
            controller: _ctl,
            enabled: widget.onChanged != null,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9./-]')),
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              fontSize: 24,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: 'Your answer',
              errorText: valid
                  ? null
                  : 'Up to 5 characters (6 with a minus sign): a number, decimal or fraction like 7/2',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: border, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: border, width: 2),
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() {});
              widget.onChanged?.call(v.trim());
            },
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        if (widget.revealed)
          Text(
            '${widget.correct ? 'Correct.' : 'Not correct.'} Accepted answer: ${widget.accepted.join(' or ')}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: widget.correct ? AppColors.correct : AppColors.wrong,
            ),
          )
        else
          const Text(
            'Enter one answer. A fraction that does not fit, enter as a decimal (rounded or cut at 4 digits). '
            r'No mixed numbers, %, $ or commas.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
      ],
    );
  }
}

/// Shows [item] with the right view for its section: the passage layout for
/// Reading & Writing, [MathQuestionView] for Math.
class ItemQuestionView extends StatelessWidget {
  const ItemQuestionView({
    required this.item,
    super.key,
    this.selected,
    this.eliminated = const {},
    this.highlights = const {},
    this.onSelect,
    this.onEliminate,
    this.onHighlight,
    this.revealed = false,
    this.showSource = true,
    this.header,
  });

  final Item item;
  final String? selected;
  final Set<String> eliminated;
  final Set<int> highlights;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<int>? onHighlight;
  final bool revealed;
  final bool showSource;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (item.section == 'math') {
      return MathQuestionView(
        item: item,
        response: selected,
        eliminated: eliminated,
        onRespond: onSelect,
        onEliminate: onEliminate,
        revealed: revealed,
        header: header,
      );
    }
    return QuestionView(
      content: contentOfItem(item),
      selected: selected,
      eliminated: eliminated,
      highlights: highlights,
      onSelect: onSelect,
      onEliminate: onEliminate,
      onHighlight: onHighlight,
      reveal: revealed
          ? Reveal(
              answer: item.answer,
              why: item.why,
              explanations: item.choiceExplanations,
              source: showSource ? item.source : null,
            )
          : null,
      header: header,
    );
  }
}
