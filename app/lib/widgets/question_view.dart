import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/engine/content.dart';
import 'package:moduleup/widgets/data_view.dart';
import 'package:moduleup/widgets/rich_passage.dart';

/// What a question shows, shared by items and worked examples.
typedef QuestionContent = ({
  String? passage,
  String? passageB,
  List<String>? notes,
  ItemData? data,
  String stem,
  Map<String, String> choices,
});

QuestionContent contentOfItem(Item i) => (
  passage: i.passage,
  passageB: i.passageB,
  notes: i.notes,
  data: i.data,
  stem: i.stem,
  choices: i.choices,
);

QuestionContent contentOfExample(WorkedExample e) => (
  passage: e.passage,
  passageB: e.passageB,
  notes: e.notes,
  data: e.data,
  stem: e.stem,
  choices: e.choices,
);

/// After answering: the key and the explanation for each choice.
class Reveal {
  const Reveal({
    required this.answer,
    this.why,
    this.explanations,
    this.source,
  });
  final String answer;
  final String? why;
  final Map<String, String>? explanations;
  final String? source;
}

/// Passage pane + question pane: side by side on wide screens (like the real
/// test), stacked with a draggable divider on phones.
class QuestionView extends StatefulWidget {
  const QuestionView({
    required this.content,
    super.key,
    this.selected,
    this.eliminated = const {},
    this.highlights = const {},
    this.onSelect,
    this.onEliminate,
    this.onHighlight,
    this.reveal,
    this.header,
  });

  final QuestionContent content;
  final String? selected;
  final Set<String> eliminated;
  final Set<int> highlights;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<int>? onHighlight;
  final Reveal? reveal;

  /// Shown above the stem (question number, mark-for-review toggle).
  final Widget? header;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  bool get _hasStimulus =>
      widget.content.passage != null ||
      widget.content.notes != null ||
      widget.content.data != null;

  @override
  Widget build(BuildContext context) {
    final stimulus = _StimulusPane(
      content: widget.content,
      highlights: widget.highlights,
      onHighlight: widget.reveal == null ? widget.onHighlight : null,
    );
    final question = _QuestionPane(widget: widget);
    if (!_hasStimulus) return question;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stimulus),
              const VerticalDivider(width: 1, color: AppColors.line),
              Expanded(child: question),
            ],
          );
        }
        return ListView(
          children: [
            _StimulusPane(
              content: widget.content,
              highlights: widget.highlights,
              onHighlight: widget.reveal == null ? widget.onHighlight : null,
              scroll: false,
            ),
            const Divider(height: 1, color: AppColors.line),
            _QuestionPane(widget: widget, scroll: false),
          ],
        );
      },
    );
  }
}

class _StimulusPane extends StatelessWidget {
  const _StimulusPane({
    required this.content,
    required this.highlights,
    required this.onHighlight,
    this.scroll = true,
  });

  final bool scroll;
  final QuestionContent content;
  final Set<int> highlights;
  final ValueChanged<int>? onHighlight;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w700,
    );
    final notes = content.notes;
    return _Pane(
      scroll: scroll,
      children: [
        if (content.passageB != null) Text('Text 1', style: label),
        if (content.passage case final p?)
          HighlightablePassage(
            text: p,
            highlighted: highlights,
            onToggle: onHighlight,
          ),
        if (content.passageB case final p?) ...[
          const SizedBox(height: AppSpace.m),
          Text('Text 2', style: label),
          HighlightablePassage(
            text: p,
            highlighted: {
              for (final h in highlights)
                if (h >= 1000) h - 1000,
            },
            onToggle: onHighlight == null
                ? null
                : (i) => onHighlight!(i + 1000),
          ),
        ],
        if (notes != null) ...[
          const Text(
            'While researching a topic, a student has taken the following notes:',
          ),
          const SizedBox(height: AppSpace.s),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: RichLine(n)),
                ],
              ),
            ),
        ],
        if (content.data case final d?) DataView(data: d),
      ],
    );
  }
}

class _QuestionPane extends StatelessWidget {
  const _QuestionPane({required this.widget, this.scroll = true});
  final QuestionView widget;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final reveal = widget.reveal;
    return _Pane(
      scroll: scroll,
      children: [
        ?widget.header,
        RichLine(
          c.stem,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpace.m),
        for (final l in answerLetters)
          ChoiceTile(
            letter: l,
            text: c.choices[l]!,
            selected: widget.selected == l,
            eliminated: widget.eliminated.contains(l),
            onTap: widget.onSelect == null ? null : () => widget.onSelect!(l),
            onEliminate: widget.onEliminate == null
                ? null
                : () => widget.onEliminate!(l),
            isKey: reveal == null ? null : reveal.answer == l,
            explanation: reveal?.explanations?[l],
          ),
        if (reveal?.why case final why?) ...[
          const SizedBox(height: AppSpace.s),
          Card(
            color: AppColors.accentSoft,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: RichLine(why),
            ),
          ),
        ],
        if (reveal?.source case final s?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s),
            child: Text(
              'Source: $s',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// One answer choice. Tap to select; the strike button eliminates it.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.eliminated,
    super.key,
    this.onTap,
    this.onEliminate,
    this.isKey,
    this.explanation,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool eliminated;
  final VoidCallback? onTap;
  final VoidCallback? onEliminate;

  /// null while answering; true/false once the key is revealed.
  final bool? isKey;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final revealed = isKey != null;
    final border = switch ((revealed, isKey, selected)) {
      (true, true, _) => AppColors.correct,
      (true, false, true) => AppColors.wrong,
      (false, _, true) => AppColors.accent,
      _ => AppColors.line,
    };
    final fill = switch ((revealed, isKey, selected)) {
      (true, true, _) => AppColors.correctSoft,
      (true, false, true) => AppColors.wrongSoft,
      (false, _, true) => AppColors.accentSoft,
      _ => Colors.white,
    };
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      decoration: eliminated ? TextDecoration.lineThrough : null,
      color: eliminated ? AppColors.muted : AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Semantics(
        selected: selected,
        button: onTap != null,
        label:
            'Choice $letter${eliminated ? ', eliminated' : ''}'
            '${revealed && isKey! ? ', correct answer' : ''}',
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: border,
              width: selected || revealed && isKey! ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LetterBadge(letter: letter, active: selected),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text.rich(
                            TextSpan(children: styledSpans(text, textStyle!)),
                          ),
                        ),
                      ),
                      if (onEliminate != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: eliminated
                              ? 'Restore $letter'
                              : 'Eliminate $letter',
                          icon: Icon(
                            eliminated ? Icons.undo : Icons.strikethrough_s,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          onPressed: onEliminate,
                        ),
                    ],
                  ),
                  if (explanation != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 6, 8, 0),
                      child: RichLine(
                        explanation!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.letter, required this.active});
  final String letter;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? AppColors.accent : Colors.white,
      border: Border.all(color: active ? AppColors.accent : AppColors.muted),
    ),
    child: Text(
      letter,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: active ? Colors.white : AppColors.ink,
      ),
    ),
  );
}

/// A padded list: scrollable on its own, or a plain column inside a parent scroll.
class _Pane extends StatelessWidget {
  const _Pane({required this.scroll, required this.children});
  final bool scroll;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => scroll
      ? ListView(padding: const EdgeInsets.all(AppSpace.m), children: children)
      : Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
}
