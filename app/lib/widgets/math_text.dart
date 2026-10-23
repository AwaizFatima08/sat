import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:moduleup/widgets/rich_passage.dart';

final _mathSegment = RegExp(r'\\\((.+?)\\\)|\\\[(.+?)\\\]', dotAll: true);

/// Inline TeX longer than this (in characters) is split at break points.
const _breakAbove = 40;

/// Outside math, items escape the dollar sign as `\$` (TeX habit).
String _plain(String s) => s.replaceAll(r'\$', r'$');

/// Text with inline `\( … \)` and display `\[ … \]` LaTeX, rendered with
/// flutter_math_fork. Plain parts keep **bold** and the blank styling.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    final spans = <InlineSpan>[];
    var index = 0;
    for (final m in _mathSegment.allMatches(text)) {
      if (m.start > index) {
        spans.addAll(styledSpans(_plain(text.substring(index, m.start)), base));
      }
      final display = m.group(2) != null;
      final tex = (m.group(1) ?? m.group(2))!.trim();
      final widget = Math.tex(
        tex,
        textStyle: base,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        onErrorFallback: (e) =>
            Text(tex, style: base.copyWith(color: Colors.red)),
      );
      if (display) {
        // A display line scrolls sideways on a narrow phone.
        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: widget,
                ),
              ),
            ),
          ),
        );
      } else if (tex.length <= _breakAbove) {
        // Short inline math stays whole (TeX spacing intact) and shrinks
        // only if the line is too narrow for it.
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: FittedBox(fit: BoxFit.scaleDown, child: widget),
          ),
        );
      } else {
        // Long inline math breaks after relations and operators like TeX
        // does; a thin gap restores the spacing lost at each break.
        final parts = widget.texBreak().parts;
        final gap = (base.fontSize ?? 16) * 0.2;
        for (final (i, part) in parts.indexed) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: i == parts.length - 1 ? 0 : gap,
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: part),
              ),
            ),
          );
        }
      }
      index = m.end;
    }
    if (index < text.length) {
      spans.addAll(styledSpans(_plain(text.substring(index)), base));
    }
    return Text.rich(TextSpan(children: spans), textAlign: textAlign);
  }
}
