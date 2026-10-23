import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/widgets/math_text.dart';

const _blank = '______';

/// Splits text into styled spans: `<u>…</u>` underline, `**…**` bold, and the
/// six-underscore blank drawn as a wide line.
List<InlineSpan> styledSpans(String text, TextStyle base, {Color? highlight}) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'<u>(.*?)</u>|\*\*(.*?)\*\*|______', dotAll: true);
  var index = 0;
  final bg = highlight == null ? null : (Paint()..color = highlight);
  TextStyle style([TextStyle? extra]) =>
      base.merge(extra).copyWith(background: bg);
  for (final m in pattern.allMatches(text)) {
    if (m.start > index) {
      spans.add(TextSpan(text: text.substring(index, m.start), style: style()));
    }
    if (m.group(0) == _blank) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            label: 'blank',
            child: Container(
              width: 72,
              height: (base.fontSize ?? 16) * 1.1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1),
          style: style(const TextStyle(decoration: TextDecoration.underline)),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: m.group(2),
          style: style(const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }
    index = m.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: style()));
  }
  return spans;
}

/// Plain rich text (no highlighting), for explanations and lessons.
class RichLine extends StatelessWidget {
  const RichLine(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (text.contains(r'\(') || text.contains(r'\[')) {
      return MathText(text, style: style);
    }
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    return Text.rich(TextSpan(children: styledSpans(text, base)));
  }
}

/// A passage the student can highlight sentence by sentence (long-press a
/// sentence to toggle it), like the highlighter on the real test.
class HighlightablePassage extends StatefulWidget {
  const HighlightablePassage({
    required this.text,
    required this.highlighted,
    required this.onToggle,
    super.key,
  });

  final String text;
  final Set<int> highlighted;
  final ValueChanged<int>? onToggle;

  static List<String> sentences(String text) => RegExp(
    r'[^.!?]+(?:[.!?]+["”’)]*\s*|$)',
  ).allMatches(text).map((m) => m.group(0)!).toList();

  @override
  State<HighlightablePassage> createState() => _HighlightablePassageState();
}

class _HighlightablePassageState extends State<HighlightablePassage> {
  final _recognizers = <LongPressGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontFamily: passageFont,
      fontSize: 17,
      height: 1.55,
      color: AppColors.ink,
    );
    final parts = HighlightablePassage.sentences(widget.text);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      final toggle = widget.onToggle;
      final recognizer = toggle == null
          ? null
          : (LongPressGestureRecognizer()..onLongPress = () => toggle(i));
      if (recognizer != null) _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          recognizer: recognizer,
          children: styledSpans(
            parts[i],
            base,
            highlight: widget.highlighted.contains(i)
                ? AppColors.highlight
                : null,
          ),
        ),
      );
    }
    return Semantics(
      hint: widget.onToggle == null
          ? null
          : 'Long-press a sentence to highlight it',
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}
