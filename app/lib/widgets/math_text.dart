import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:moduleup/widgets/rich_passage.dart';

final _mathSegment = RegExp(r'\\\((.+?)\\\)|\\\[(.+?)\\\]', dotAll: true);

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
      } else {
        // Inline math breaks after relations and operators like TeX does;
        // a single piece that is still too wide is scaled down to fit.
        for (final part in widget.texBreak().parts) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: FittedBox(fit: BoxFit.scaleDown, child: part),
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
