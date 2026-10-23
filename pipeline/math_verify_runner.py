#!/usr/bin/env python3
"""Runs the `verify` scripts of Math items (called by validate_math.py in a separate process).

Reads a JSON list of items on stdin, prints a JSON object {id: "ok" | "<error>"}.
Each script runs with `from sympy import *` and: choices, answer, spr_answers, figure, value().
"""
import json
import re as _regex
import signal
import sys

from sympy import *  # noqa: F401,F403  (scripts rely on SymPy names)
from sympy.parsing.sympy_parser import (convert_xor, implicit_multiplication_application, parse_expr,
                                        standard_transformations)

TRANSFORMS = standard_transformations + (implicit_multiplication_application, convert_xor)


def _braced(s, i):
    """Return (content, index after closing brace) for a {...} group starting at s[i] == '{'."""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j + 1
    raise ValueError("unbalanced braces")


def latex_to_sympy_text(s):
    s = s.strip()
    s = _regex.sub(r"^\\\(|\\\)$|^\\\[|\\\]$", "", s).strip()
    s = s.replace("\\left", "").replace("\\right", "").replace("\\!", "").replace("\\,", "")
    s = s.replace("^{\\circ}", "").replace("^\\circ", "").replace("\\%", "/100").replace("$", "")
    s = s.replace("\\cdot", "*").replace("\\times", "*").replace("\\div", "/").replace("\\pi", "pi")
    out, i = "", 0
    while i < len(s):
        if s.startswith("\\frac", i) or s.startswith("\\dfrac", i):
            i += 5 if s.startswith("\\frac", i) else 6
            a, i = _braced(s, i)
            b, i = _braced(s, i)
            out += f"(({latex_to_sympy_text(a)})/({latex_to_sympy_text(b)}))"
        elif s.startswith("\\sqrt", i):
            i += 5
            n = None
            if i < len(s) and s[i] == "[":
                k = s.index("]", i)
                n, i = s[i + 1:k], k + 1
            a, i = _braced(s, i)
            out += f"(({latex_to_sympy_text(a)})**(1/({n})))" if n else f"sqrt({latex_to_sympy_text(a)})"
        elif s[i] == "^" and i + 1 < len(s) and s[i + 1] == "{":
            a, i = _braced(s, i + 1)
            out += f"**({latex_to_sympy_text(a)})"
        elif s[i] == "{":
            a, i = _braced(s, i)
            out += f"({latex_to_sympy_text(a)})"
        elif s.startswith("\\sin", i) or s.startswith("\\cos", i) or s.startswith("\\tan", i):
            out += s[i + 1:i + 4]
            i += 4
        else:
            out += s[i]
            i += 1
    return out


def value(latex):
    # Thousands separators: 1{,}296 or 1,296 between digit groups.
    latex = _regex.sub(r"(?<=\d)\{,\}(?=\d{3})", "", latex)
    latex = _regex.sub(r"(?<=\d),(?=\d{3}(?!\d))", "", latex)
    text = _regex.sub(r"(?<![\w.])(\d*\.\d+)", r"Rational('\1')", latex_to_sympy_text(latex))
    return parse_expr(text, transformations=TRANSFORMS,
                      local_dict={"e": E, "pi": pi})


def _timeout(*_):
    raise TimeoutError("verify timed out (10 s)")


def main():
    items = json.load(sys.stdin)
    results = {}
    signal.signal(signal.SIGALRM, _timeout)
    for it in items:
        env = {k: v for k, v in globals().items() if not k.startswith("_")}
        env.update(choices=it.get("choices") or {}, answer=it.get("answer"), spr_answers=it.get("spr_answers"),
                   figure=it.get("figure"), value=value)
        signal.alarm(10)
        try:
            exec(compile(it.get("verify") or "raise AssertionError('no verify script')", it["id"], "exec"), env)
            results[it["id"]] = "ok"
        except AssertionError as e:
            results[it["id"]] = f"assertion failed {e}".strip()
        except Exception as e:  # report any other failure as an error message
            results[it["id"]] = f"{type(e).__name__}: {e}"
        finally:
            signal.alarm(0)
    print(json.dumps(results))


if __name__ == "__main__":
    main()
