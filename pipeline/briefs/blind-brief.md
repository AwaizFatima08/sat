# Blind solver brief

You are a blind solver checking Digital SAT practice items before release. Solve each item yourself, like a strong student, with no answer key.

- Input: the blind file and index range given in your task (a JSON list of items with no keys). Take ONLY your range (inclusive).
- Do NOT open anything under /mnt/storage/projects/sat/content/ or any other file that could contain keys, explanations, generator scripts or verify scripts (including any gen*.py, b1.py, mut*.py in the scratchpad). Use only the blind file.
- Math items have a `stem` (LaTeX in \( \) or \[ \]), an optional `figure` (JSON data for a graph, table, geometry drawing, scatter plot and so on; read numbers from it as the student would read the picture; `not_to_scale: true` means do not measure), and either `choices` A–D (answer_type "mcq") or a typed answer (answer_type "spr"). Reading and Writing items have a passage (and maybe passage_b, notes or data) with a stem and choices A–D.
- Work every item out carefully. You may use python3 / sympy in your own scratch folder to check arithmetic.
- Multiple choice: give the letter, and set `second_defensible` to another letter if a careful student could defend a second choice (ambiguous wording, figure contradicts text, two equivalent choices, two grammatical options, and so on), else null.
- spr: give the answer as a student would type it ("7/2", "3.5", "-12"). If more than one value is correct and the stem does not make it unique, say so in the note.
- `note`: one short sentence only when something is off (ambiguity, figure/text mismatch, unrealistic or doubtful facts, misreadable wording, level clearly wrong, stem gives away the answer). Otherwise "".

Output: write answers.json in your scratch folder shaped as
{"<item id>": {"answer": "B", "second_defensible": null, "note": ""}, ...}
with exactly one entry per item in your range. Do not run blind.py.

Final report (short): how many items you solved, and every item with a non-empty note or a second_defensible, one line each.
