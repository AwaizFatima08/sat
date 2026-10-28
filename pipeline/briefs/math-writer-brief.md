# Math writer brief — Module Up: Digital SAT Prep (production batches)

You are writing original SAT Math questions for the HomiLabs app "Module Up: Digital SAT Prep" in /mnt/storage/projects/sat.

## Read first
- content/math/guides/writing-guide.md (in full) and content/math/blueprint.json. Follow the guide exactly: JSON format, LaTeX in \( \) with doubled backslashes in JSON, figures as data, typed answers, the required SymPy `verify` script, traps, levels.
- The 8 checked try-it items of each of your skills (content/math/items/<type>/m-<abbr>-000[1-8].json). They are the approved style models.
- Every item already written for your skills (any pool). Do not repeat their scenarios, number sets or question shapes.

## Your batches
For each batch run `python3 pipeline/batch_math.py show <batch>` to get the exact ids, levels and which ids are typed-answer (spr). Write each item to content/math/items/<type>/<id>.json with the given pool ("drill" or "paper"); skip ids that already exist. provenance: written_by "claude-fable-5-1", written "<today's date>", checks [], reviewed_by null, status "draft"; b = the level default.

## Content rules
- Cover the skill notes in guide §7 across each batch; vary question shapes (solve, interpret a coefficient, pick an equivalent form, read a graph or table, build a model, count solutions, and so on).
- About half the items in context (word problems), half pure. About 20 % of the in-context items set in South Asia (Pakistani, Indian, Bangladeshi, Sri Lankan, Nepali settings, names, prices in rupees/taka when natural), the rest varied and global.
- Figures (xy graph, table, scatter, histogram, geometry drawing, …) wherever the skill naturally uses them; at least 1 in 4 items for data and geometry skills.
- Multiple-choice keys spread evenly over A–D within each batch. Distractors come from real, specific student errors with correct trap tags.
- Level 4 (Challenge) items are hard through reasoning (parameters, structure, no/infinite solutions, combining ideas), not heavy arithmetic. Level 1 items are one clear step.
- "paper" items read like the real test: concise stems, no hints, no teaching in the stem. "drill" items may be slightly more guided at levels 1–2.

## Lessons from the pilot (apply them)
- Numbers of 1,000 or more take a comma: `1,296` in prose, `\\(1{,}296\\)` in LaTeX. `value()` in verify scripts reads both.
- Display math `\\[ … \\]` is fine for a block on its own line (e.g. each equation of a system). Everything else inline.
- Figure labels are plain text, not LaTeX ("x + 5", "y = f(x)", "45°"). Geometry figures cannot draw arcs or semicircles.
- If a typed-answer item has more than one correct value ("one possible value"), list every correct value in spr_answers.
- Distractors must be false. A true but irrelevant statement as a wrong choice is a second defensible answer.
- Never state a real-world fact you are not sure of (real distances, populations, record values). Use clearly invented or generic numbers instead.
- Never credit a real study to an invented researcher, and never invent a named study.
- Give a formula in the stem when it is not on the SAT reference sheet.
- Do not label on a graph the exact point the student must find.

## Quality gate (every item)
1. Solve it yourself independently. Exactly one choice is correct, or the spr_answers list is complete and exact.
2. The `verify` script recomputes the answer from the problem's own numbers and asserts the key, and that the other choices are wrong where checkable.
3. Mutation test: in a throwaway copy, change each key to a wrong letter (and each typed answer to a wrong value) and confirm every verify script then fails.
4. Run `python3 pipeline/validate_math.py --items <your files>` until 0 errors.

## Boundaries
Original work only: never copy or adapt College Board, Khan Academy or prep-book problems. American English. Use only your own scratch folder (given in your task) for helper scripts. Do not edit any other repo file or other skills' items. Do not run git.

## Final reply (max 8 lines)
Ids written, the validator result line, anything you are unsure about.

## Paper set 2 (papers 11-20)
If your batches are named m-paper2-…, you are writing the second set of 10 papers. Before writing, read the digest of every existing item of your skill(s) at /tmp/claude-1000/-mnt-storage-projects-sat/37b81d9f-0d37-48df-a26f-184b5789b1d5/scratchpad/digest/<type>.txt (id, level, pool, start of stem). Do not repeat their scenarios, number sets or question shapes; open any item file you need to compare in detail. provenance "written" = today's date.
