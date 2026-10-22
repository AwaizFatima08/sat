# Lesson and reference formats

Shipped in the app (pipeline/build_packs.py copies them into the content pack). Original HomiLabs writing only,
American English, student-friendly, addressed to the student ("you"). Plain text; `**bold**` allowed inside strings.

## content/rw/lessons/<type>.json — one per question type (11 files)
```json
{
  "type": "words_in_context",
  "title": "Words in Context",
  "what_is_tested": "2-3 sentences: what this question type tests and why the SAT asks it.",
  "how_to_spot": "1-2 sentences: how to recognize the type (stem wording, layout).",
  "method": ["4-6 short steps, the general method for every level"],
  "pitfalls": ["3-5 common mistakes, each one sentence, linked to the trap types where natural"],
  "us_uk": "optional: one note where British habits mislead (conventions types mainly), or null",
  "cards": [
    {
      "level": 1,
      "title": "Foundations: <short focus>",
      "steps": ["exactly 4 steps tuned to this level"],
      "worked_example": {
        "passage": "an ORIGINAL short passage (not one of the items)",
        "passage_b": null,
        "notes": null,
        "stem": "the standard stem",
        "choices": {"A": "...", "B": "...", "C": "...", "D": "..."},
        "answer": "C",
        "walkthrough": ["3-5 sentences applying the 4 steps to this example, ending with why the key is right and the strongest trap is wrong"]
      },
      "tryit": ["rw-wic-0001", "rw-wic-0002"]
    }
  ]
}
```
- `cards`: exactly 4, levels 1-4. `tryit`: the two try-it items of that level for the type
  (ids rw-<abbr>-0001/0002 level 1, 0003/0004 level 2, 0005/0006 level 3, 0007/0008 level 4).
- Worked examples follow the item rules (one defensible answer, accurate facts, original).
- For coe_quantitative the worked example may include `"data"` in the item data format.

## content/rw/reference/grammar.json
```json
{"title": "Grammar handbook",
 "intro": "2 sentences",
 "sections": [{"key": "subject_verb", "title": "Subject-verb agreement",
               "rule": "1-3 sentences", "points": ["3-6 bullet rules"],
               "examples": [{"wrong": "...", "right": "...", "why": "..."}],
               "us_uk": "note or null"}]}
```
One section per blueprint grammar key (8), 3-5 examples each.

## content/rw/reference/wordbank.json
```json
{"title": "Word bank", "intro": "...",
 "words": [{"word": "corroborate", "pos": "verb", "definition": "to support with evidence",
            "example": "an original sentence in an academic register", "level": 3}]}
```
About 400 high-use academic words that appear in SAT-style passages and Words in Context choices; levels 1-4;
definitions in our own words (not copied from a dictionary); alphabetical.

## content/rw/reference/traps.json
```json
{"title": "Trap guide", "intro": "...",
 "traps": [{"key": "too_broad", "title": "Too broad", "description": "...",
            "example": "short original illustration", "how_to_avoid": "..."}]}
```
One entry per blueprint trap key (9).

## content/rw/reference/testday.json
```json
{"title": "Test-day guide", "sections": [{"title": "...", "body": ["paragraph", "..."]}]}
```
Sections: how the Reading and Writing section works (2 modules, 27 questions, 32 minutes, routing);
pacing (about 71 seconds per question, when to move on, marking for review); order of question types and
where to spend time; tools in the digital test (highlighter, eliminator, mark for review, navigator — described
generically, no College Board branding); the night before and the morning of; after the test.
Factual statements about the test must be accurate as of 2026; no claims about specific test dates or fees.
