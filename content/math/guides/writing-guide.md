# Writing guide — Math items

For anyone writing Math items for Module Up. Read all of it. Machine rules live in `content/math/blueprint.json`;
`python3 pipeline/validate_math.py --items <files>` must pass with 0 errors (it also RUNS every item's `verify` check).

## 1. Non-negotiables
1. **Original work only.** Never copy or adapt College Board (Bluebook, Question Bank, PSAT), Khan Academy or any
   prep-book problem. Invent your own numbers, contexts and structures.
2. **The key must be provably right.** Every item has a `verify` script (SymPy) that recomputes the answer from the
   problem's own numbers and asserts the key (§5). If you cannot verify it, do not write it.
3. **Exactly one correct choice** (multiple choice) or a well-defined set of accepted values (typed answers).
   Distractors are the results of real, specific student errors — each tagged with a trap type.
4. **Realistic, accurate contexts.** Units and magnitudes must make sense (no 3 m tall ants). Real facts must be
   true; invented data is fine. About 20 % of word problems set in South Asia (`context: "south_asia"`): rupees,
   kilometers, cricket, monsoon rainfall, Lahore–Karachi trains… never stereotyped.
5. **American conventions**: decimal point, "meters", "liters". Numbers of 1,000 or more take a comma: `1,296` in prose, `\\(1{,}296\\)` in LaTeX (`value()` reads both).
6. **Calculator allowed** on every question (built-in grapher/scientific calculator, as on the real test), so
   difficulty must come from reasoning and setup, not ugly arithmetic.

## 2. Item anatomy (JSON, one file per item: content/math/items/<type>/<id>.json)
```json
{
  "id": "m-le1-0001",            // m-<abbr>-<4 digits>
  "section": "math",
  "domain": "algebra",
  "type": "lin_eq_one",
  "level": 2,                    // 1 Foundations, 2 Medium, 3 Advanced, 4 Challenge
  "b": -0.5,                     // level default (−1.5, −0.5, 0.5, 1.5)
  "context": "global",           // global | south_asia
  "in_context": false,           // true for word problems
  "pool": "drill",               // paper | drill | tryit (the batch brief says which)
  "stem": "If \\(3x - 7 = 11\\), what is the value of \\(x\\)?",
  "figure": null,                // optional, §4
  "answer_type": "mcq",          // mcq | spr  (the batch brief says which ids are spr)
  "choices": {"A": "\\(\\frac{4}{3}\\)", "B": "\\(6\\)", "C": "\\(18\\)", "D": "\\(54\\)"},
  "answer": "B",                 // mcq only; null for spr
  "spr_answers": null,           // spr only: list of accepted exact values as strings, e.g. ["2/3"] or ["-4", "4"]
  "solution": ["Add 7 to both sides: \\(3x = 18\\).", "Divide by 3: \\(x = 6\\)."],
  "explanation": {"A": "Incorrect. …", "B": "Correct. …", "C": "Incorrect. …", "D": "Incorrect. …"},  // mcq only
  "traps": {"A": "sign_error", "C": "stopped_early", "D": "arithmetic"},                            // mcq only
  "verify": "x = symbols('x')\nsol = solve(Eq(3*x - 7, 11), x)\nassert sol == [6]\nassert value(choices[answer]) == 6",
  "source": {"kind": "original"},
  "provenance": {"written_by": "claude-opus-5-5", "written": "2026-10-22", "checks": [], "reviewed_by": null, "status": "draft"}
}
```
(Comments are for this guide only; real files are plain JSON. In JSON every backslash is doubled.)

### Math notation
- Inline math in `\\( … \\)`, displayed math in `\\[ … \\]` (rare). Use standard LaTeX: `\\frac{a}{b}`, `x^{2}`,
  `\\sqrt{x}`, `\\le`, `\\ge`, `\\pi`, `\\sin`, `\\cdot`, `\\left( \\right)`, `^{\\circ}` for degrees.
- Put **all** math in delimiters, including single variables (`\\(x\\)`) and numbers inside expressions.
  Plain numbers in prose ("12 meters") may stay plain.
- Choices that are numbers or expressions are fully in `\\( … \\)`; word choices are plain text.

- Display math `\\[ … \\]` for a block on its own line, e.g. each equation of a system: `\\[ 2x + y = 7 \\] \\[ x - y = 2 \\]`. Everything else inline.

### Stems (use these patterns)
- "What is the value of \\(x\\)?" / "Which of the following is equivalent to …?" / "Which equation represents …?"
- "What is the solution \\((x, y)\\) to the system of equations?" / "How many solutions does … have?"
- "Which of the following best describes …?" (interpretation of slope, intercept, constant, margin of error)
- Typed answers (spr): end with a question whose answer is a single number; no units in the answer.

## 3. Typed answers (answer_type "spr")
- About 25 % of items (the batch brief marks which ids). Answer must be a number a student can type in ≤ 5
  characters (6 with a minus sign): integer, fraction `a/b` or decimal.
- `spr_answers`: every exact correct value as a string — e.g. `["7/4"]` (the app also accepts `1.75`
  automatically), `["-3", "5"]` when either root is accepted ("enter one of them"), `["0.125"]`.
- Never require rounding instructions beyond "rounded to the nearest tenth" (then list the rounded value only).
- The grader follows the official rules: exact value, or a decimal that fills all available characters and is
  the value truncated or rounded.

## 4. Figures (drawn by the app from data — no images)
Keep coordinates simple and labels short. Labels are drawn as plain text (no LaTeX): write `x + 5`, `y = f(x)`, `45°`. Kinds:
```json
{"kind": "xy", "x": [-6, 6], "y": [-4, 8], "curves": [{"expr": "2*x + 1", "label": "y = f(x)"}],
 "points": [{"x": 1, "y": 3, "label": "(1, 3)"}], "segments": [], "x_label": "x", "y_label": "y"}
{"kind": "geometry", "points": {"A": [0, 0], "B": [6, 0], "C": [6, 4]}, "segments": [["A","B"],["B","C"],["C","A"]],
 "circles": [{"center": [3, 2], "radius": 2}], "labels": [{"at": [3, -0.6], "text": "6"}],
 "right_angles": ["B"], "not_to_scale": false}
{"kind": "scatter", "x_label": "Hours", "y_label": "Score", "points": [[1, 52], [2, 58]], "line": "6*x + 46"}
{"kind": "histogram", "x_label": "…", "y_label": "Frequency", "bins": [[0, 10, 4], [10, 20, 7]]}
{"kind": "dotplot", "x_label": "…", "values": [2, 3, 3, 4, 7]}
{"kind": "boxplot", "x_label": "…", "plots": [{"name": "Class A", "min": 2, "q1": 5, "median": 7, "q3": 9, "max": 14}]}
{"kind": "bar" | "line", "title": "…", "x_label": "…", "y_label": "…", "series": [{"name": "…", "points": [["2019", 14]]}]}
{"kind": "table", "title": "…", "columns": ["…"], "rows": [["…"]]}
```
- `expr` uses Python/SymPy syntax in `x` (`x**2`, `sqrt(x)`, `exp(x)`, `sin(x)`), evaluated by the app's grapher.
- Geometry: points are coordinates in a plain plane; set `not_to_scale: true` (and say so in the stem) when the
  drawing is deliberately not to scale. Angle values go in `labels`.
- Every number a student needs must be readable from the figure or stated in the stem.

## 5. The verify script (required)
Python run by the validator with SymPy imported (`from sympy import *`) and these names defined:
`choices` (dict, LaTeX strings), `answer` (letter or None), `spr_answers` (list or None), `figure`, and
`value(latex_string)` → SymPy value of a numeric/expression choice (handles `\\frac`, `\\sqrt`, `\\pi`, `^`, `\\cdot`).
- Recompute the answer **from the problem's numbers** (solve, simplify, evaluate data), then assert it matches
  the key: `assert value(choices[answer]) == 6` / `assert simplify(value(choices[answer]) - (2*x+3)) == 0` /
  `assert Rational(spr_answers[0]) == Rational(7, 4)`.
- For multiple choice also assert that **no other choice** is correct when that is checkable
  (`assert all(value(choices[k]) != 6 for k in choices if k != answer)`).
- For word-only choices (interpretations), verify the underlying computation (e.g. the slope equals 3.5) and
  assert the key text contains the right number.
- Keep it short (≤ 15 lines), deterministic, no imports beyond SymPy, no file or network access.

## 6. Levels
| Level | What makes it this hard |
|---|---|
| 1 Foundations | one step, small integers, direct question, familiar form |
| 2 Medium | two steps or a short context; must choose the right operation or form |
| 3 Advanced | multi-step setup, a parameter, an interpretation, or a figure/data display to decode |
| 4 Challenge | abstract parameters (no/infinite solutions, discriminant conditions), structure insight, nested percent changes, transformations, combining two skills — hard for a 700+ scorer by reasoning, never by arithmetic grind |

## 7. Skill notes (what to cover across a batch)
- **lin_eq_one**: solve; build from context; interpret a constant; conditions for no / infinitely many solutions.
- **lin_functions**: table ↔ equation ↔ graph; rule from two points or point + rate; interpret slope/intercept.
- **lin_eq_two**: Ax + By = C in context; lines through two points; parallel/perpendicular lines.
- **systems**: solve; set up from words; parameter for no / infinitely many solutions; intersection on a graph.
- **inequalities**: model a constraint; test a point; match a graph or table; two-variable constraints.
- **equiv_expr**: factor; expand; rational exponents and radicals; rational expressions; polynomial operations.
- **nonlin_eq**: quadratics (all forms), discriminant, absolute value, radical and rational equations,
  linear–quadratic systems, solving a formula for a variable.
- **nonlin_func**: quadratic and exponential models; vertex, intercepts, growth factor; equivalent forms that reveal a
  feature; transformations; f(x) notation and composition at higher levels.
- **ratios_rates**: unit rates, derived units, multi-step conversions, scale factors, proportions.
- **percentages**: percent of, percent change, growth factor 1.05, successive changes, reverse percent.
- **one_var_data**: mean/median/mode/range/SD from lists, dot plots, histograms, box plots; outlier effects.
- **two_var_data**: scatterplots, line of best fit, predictions, linear vs exponential models.
- **probability**: simple and conditional probability, two-way tables, reverse problems.
- **inference**: estimate a population value from a sample; margin of error; sample size effects.
- **stat_claims**: random sampling vs random assignment; what a study's design allows you to conclude.
- **area_volume**: area/perimeter/volume/surface area; scale factor k → k², k³; composite figures.
- **lines_angles**: parallel lines and transversals, triangle angle sums, similar and congruent triangles.
- **right_trig**: Pythagorean theorem, special right triangles, sin/cos/tan, sin x = cos(90° − x).
- **circles**: arc length, sector area, central/inscribed angles, radians, circle equations (complete the square).

## 8. Explanations
- `solution`: 2–5 short steps a student can follow; show the key move, not every keystroke.
- Each wrong choice (mcq): "Incorrect. This is the result of …" naming the exact error (matches its trap tag).
- Mention a quick calculator or graphing approach where it genuinely helps.

## 9. Before handing in
Validator 0 errors (verify passes for every item); keys spread evenly over A–D; SPR ids exactly as the brief says;
varied contexts and names; no two items with the same numbers/structure.
