# Math lesson format

Shipped in the app (pipeline/build_packs.py copies them into math_bank.json). Original HomiLabs writing only,
American English, student-friendly, addressed to the student ("you"). Strings may use `**bold**` and LaTeX in
`\\( … \\)` / `\\[ … \\]` (doubled backslashes in JSON, as in items). The app renders both.

## content/math/lessons/<type>.json — one per question type (19 files)
```json
{
  "type": "lin_eq_one",
  "title": "Linear equations in one variable",
  "what_is_tested": "2-3 sentences: what this skill covers on the Digital SAT and why it matters.",
  "how_to_spot": "1-2 sentences: how to recognize it (stem wording, what is given, what is asked).",
  "method": ["4-6 short steps, the general method for every level"],
  "pitfalls": ["3-5 common mistakes, each one sentence, linked to the trap types where natural"],
  "calculator": "1-2 sentences: when the built-in calculator (scientific or graphing) helps and when it is slower, or null",
  "cards": [
    {
      "level": 1,
      "title": "Foundations: <short focus>",
      "steps": ["exactly 4 steps tuned to this level"],
      "worked_example": {
        "stem": "an ORIGINAL problem (not one of the items), LaTeX as in items",
        "figure": null,
        "answer_type": "mcq",
        "choices": {"A": "...", "B": "...", "C": "...", "D": "..."},
        "answer": "C",
        "walkthrough": ["3-6 steps applying the card's 4 steps, with the math shown, ending with why the key is right and why the strongest trap is wrong"],
        "verify": "a SymPy script exactly like an item's verify script (same helpers: value(), choices, answer, spr_answers, figure)"
      },
      "tryit": ["m-le1-0001", "m-le1-0002"]
    }
  ]
}
```
- `cards`: exactly 4, levels 1-4 (Foundations, Medium, Advanced, Challenge, as in the blueprint).
- `tryit`: the two try-it items of that level: m-<abbr>-0001/0002 level 1, 0003/0004 level 2, 0005/0006 level 3,
  0007/0008 level 4. Read them, so the card teaches what they need.
- A worked example may be typed-answer: `"answer_type": "spr", "spr_answers": ["7/2", "3.5"]`, no choices/answer.
- A worked example may carry a `figure` in the item figure format (guide §4) when the skill is visual.
- Worked examples follow every item rule: one defensible answer, verified by its script, original, no real-world
  facts you are unsure of, never a named study.
- Use at least one worked example per lesson that shows the calculator route (e.g. graph both sides and read the
  intersection) when the skill allows it, and say in the walkthrough which tab (Scientific or Graph) to use.
- The validator (`python3 pipeline/validate_math.py`) checks the shape, the tryit ids, balanced delimiters, that no
  example copies an item stem, and runs every example's `verify`.
