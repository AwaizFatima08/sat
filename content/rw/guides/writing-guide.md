# Writing guide — Reading and Writing items

For anyone (human or Claude) writing items for Module Up. Read all of it before writing. The machine-readable
rules (types, stems, traps, grammar sub-skills, levels, word ranges) live in `content/rw/blueprint.json`;
`python3 pipeline/validate.py --items <files>` must pass with no errors before an item is handed in.

## 1. Non-negotiables
1. **Original work only.** Never copy, paraphrase or "base on" a College Board (Bluebook, Question Bank, PSAT),
   Khan Academy, Princeton Review, Kaplan, Barron's, Erica Meltzer or any other prep item. Do not reuse a
   published prep passage's topic + angle + structure. Write passages from general knowledge in your own words.
2. **Facts must be true.** Science, history and statistics in passages must be accurate. Invented studies are
   fine if clearly hypothetical in style ("A team led by ecologist Maria Okafor tracked…") but must be plausible and
   must not misstate real, well-known facts. Do not invent quotations from real, named living people. Fictional
   researchers get fictional but realistic names from many cultures.
3. **Exactly one defensible answer.** A strong student must be able to prove the key from the text alone and
   prove every other option wrong. If you can argue for two options, rewrite.
4. **American English** spelling and punctuation (color, center, analyze, traveled; double quotation marks;
   period and comma inside closing quotation marks). The validator rejects common British spellings.
5. **Public-domain literature**: only for `subject: literature`, only from works first published before 1930
   (e.g. Austen, Dickens, the Brontës, George Eliot, Hardy, Wharton, Chopin, Tagore's English works, Sarojini Naidu,
   Mark Twain, Willa Cather, Zitkala-Ša, Edith Wharton, Rabindranath Tagore, Premchand in public-domain English
   translation before 1930 only if the translation itself is pre-1930). Quote a short excerpt (≤ 120 words)
   verbatim and fill `source` (author, work, year, url to Project Gutenberg or similar). If you are not certain of
   the exact wording, **write an original literary passage instead** ("The following text is adapted from…" is NOT
   allowed — no misattributed text). Original literary passages are the default.
6. **No sensitive or distressing content**: no graphic violence, no politics of current governments, no religion
   debates, no medical advice. Neutral, academic, curious tone. Students are 15–18.
7. **Context mix**: about 20 % of items set in South Asia (`context: "south_asia"`): Pakistani, Indian,
   Bangladeshi, Sri Lankan, Nepali people, places, science, arts, history. The rest `global`: all continents,
   all eras. Never stereotype. A South Asian setting must not change the difficulty or require local knowledge.

## 2. Item anatomy (JSON)
```json
{
  "id": "rw-wic-0001",                 // rw-<abbr>-<4 digits>; abbr from blueprint; file name = id + .json
  "section": "rw",
  "domain": "craft_structure",         // from blueprint for the type
  "type": "words_in_context",
  "level": 2,                          // 1 Foundations, 2 Medium, 3 Advanced, 4 Challenge
  "b": -0.5,                           // blueprint default for the level (−1.5, −0.5, 0.5, 1.5); adjust ±0.4 max
  "subject": "science",                // literature | history_social | humanities | science
  "context": "global",                 // global | south_asia
  "pool": "drill",                     // paper | drill | tryit  (the batch brief says which)
  "passage": "… ______ …",             // exactly six underscores for a blank; <u>…</u> for an underlined sentence
  "passage_b": null,                   // Text 2, cross_text only (passage = Text 1)
  "notes": null,                       // rhetorical_synthesis only: 3–6 bullet strings (no leading dash)
  "data": null,                        // coe_quantitative only (see §5)
  "stem": "Which choice completes the text with the most logical and precise word or phrase?",
  "choices": {"A": "…", "B": "…", "C": "…", "D": "…"},
  "answer": "A",
  "explanation": {
    "why": "2–4 sentences: the reasoning a student should follow to reach the key, quoting the text.",
    "A": "Correct. …",
    "B": "Incorrect. … (name the trap in plain words)",
    "C": "Incorrect. …",
    "D": "Incorrect. …"
  },
  "traps": {"B": "reversed", "C": "not_in_text", "D": "wrong_tone"},   // one per wrong letter, from blueprint
  "grammar": null,                     // boundaries / form_structure_sense only: blueprint grammar key
  "source": {"kind": "original"},      // or {"kind":"public_domain","author","work","year","url"}
  "provenance": {"written_by": "claude-opus-5-5", "written": "2026-10-22", "checks": [], "reviewed_by": null,
                 "status": "draft"}
}
```
(Comments above are for this guide only — real files are plain JSON with no comments.)

## 3. Levels — what makes an item harder
| Level | Passage | Question | Distractors |
|---|---|---|---|
| 1 Foundations | 40–80 words, plain everyday-academic vocabulary, one clear idea, literal | answer stated almost directly | clearly wrong on a careful read; one tempting trap at most |
| 2 Medium | 60–110 words, some academic vocabulary, one contrast or qualification | needs one inference step | two tempting traps |
| 3 Advanced | 80–130 words, dense academic prose, hedged claims, abstract nouns | needs careful tracking of qualifiers, scope, who-says-what | all three distractors plausible; at least one is "almost right" (scope or certainty) |
| 4 Challenge | 90–150 words, sophisticated syntax, nested clauses, discipline-specific framing, or a period literary style | needs combining two parts of the text or rejecting a very attractive near-miss | every distractor is attractive to a 700 scorer; key may use unexpected but precise wording |
Difficulty must come from reasoning and language, never from obscure trivia or ambiguity.
Answer choice length: keep all four similar in length and grammar; never make the key the longest "because it is
careful".

## 4. Type-by-type rules
Use the stems in `blueprint.json` word for word (fill `{…}` slots naturally).

### Words in Context (`wic`)
- One blank in the passage (or, less often, a quoted word for "most nearly mean" — then no blank).
- Context must force the meaning: a contrast ("Instead,", "although"), a restatement, or a cause/effect.
- Choices: single words or short phrases, same part of speech and form. Distractors: near-synonyms with the wrong
  shade (`wrong_tone`), words that fit the sentence but reverse the logic (`reversed`/`wrong_logic`), words
  suggested by the topic but not by the context (`not_in_text`).
- Level 3–4: choices are sophisticated academic words (e.g. "corroborate", "ameliorate", "tentative",
  "idiosyncratic"); the key may be a less familiar word.

### Text Structure and Purpose (`tsp`)
- Main purpose: the key names the author's overall aim with the right verb (argue, describe, explain, challenge,
  present a finding and its limit). Traps: purpose of one part only (`too_narrow`), stronger claim than the text
  (`too_broad`), wrong verb/attitude (`wrong_tone`).
- Function of an underlined sentence: put exactly one sentence in `<u>…</u>`. Key states its role relative to the
  rest (introduces a counterexample, qualifies the claim above, provides evidence for…).
- Literary passages welcome (what the passage mainly does: characterizes, reveals a shift, contrasts…).

### Cross-Text Connections (`ctc`)
- `passage` = Text 1, `passage_b` = Text 2. Start each with its own context; do NOT write "Text 1:" inside.
- Text 2 must respond to something specific in Text 1 (agree, qualify, offer an alternative explanation, cast
  doubt on a method). Total 80–200 words.
- Key states the specific relationship. Traps: Text 2 author rejects everything (`too_broad`), confuses which author
  said what (`reversed`), true of one text only (`true_irrelevant`).

### Central Ideas and Details (`cid`)
- Main idea: key captures the whole passage, not the first sentence. Detail: answer stated in the text in other words.
- Traps: `too_narrow`, `too_broad`, `not_in_text`, `reversed`.

### Command of Evidence — Textual (`cet`)
- Passage presents a claim/hypothesis (often a researcher's). Question asks which hypothetical finding would
  support or weaken it, or which quotation illustrates a claim (literature).
- Every choice is a plausible "finding"; only the key bears directly on the specific claim. Traps: supports a
  different claim (`true_irrelevant`), would weaken instead of support (`reversed`), goes beyond the claim
  (`too_broad`).
- For "which quotation" items the choices are short quotations from the (original or public-domain) work; you may
  use only real public-domain works whose exact lines you know verbatim; otherwise use the "finding" sub-types.

### Command of Evidence — Quantitative (`ceq`)
- Passage + `data` (table or simple bar/line graph). Passage ends with a blank or a claim the data must complete or
  support. Numbers must be internally consistent and plausible (invented data is fine; say "hypothetical" nowhere —
  just make it realistic).
- The key must be TRUE according to the data AND relevant to the specific claim. Traps: true of the data but
  irrelevant to the claim (`true_irrelevant`), misreads the data (`reversed`), true of the claim but not shown by
  the data (`not_in_text`).
- Level 3–4: the student must compare two series or two rows, or notice which comparison the claim needs.

### Inferences (`inf`)
- Passage ends with "______." completing a logical conclusion. The key follows necessarily from the stated
  premises; distractors overreach (`too_broad`), contradict (`reversed`), or bring in outside ideas (`not_in_text`).
- Level 1: one premise → conclusion. Level 3–4: two premises combine; the key may be hedged ("may not be…").

### Boundaries (`bnd`) — grammar: linking_clauses | supplements | punctuation
- Blank sits at a punctuation boundary; choices differ ONLY in punctuation (and conjunctions where needed).
- Test: comma splices, run-ons, semicolon vs comma, colon after an independent clause, dash pairs, comma pairs
  around nonessential elements, no comma between subject and verb, no punctuation between a verb and its object,
  punctuation with quotations, question mark vs period.
- Each wrong option breaks a real rule (`grammar_rule`). Explanations name the rule plainly.

### Form, Structure, and Sense (`fss`) — grammar: subject_verb | pronoun | plural_possessive | verb_form | modifier
- Choices differ in one form: verb agreement (with long intervening phrases at higher levels), tense/sequence,
  pronoun number/case, possessive vs plural (its/it's, researchers'/researcher's), dangling modifiers (blank begins
  the main clause after an introductory phrase), finite vs non-finite verb forms.
- Every wrong option is `grammar_rule`.

### Transitions (`trn`)
- Blank at the start of a sentence (or after a semicolon). Choices: transition words/phrases ending in a comma
  ("However," "For example," "Consequently," "Similarly," "In other words," "Still," "Granted," "Specifically,").
- Key matches the exact relationship (contrast, cause/effect, example, addition, concession, restatement,
  sequence). Distractors express other relationships (`wrong_logic`). At higher levels, two options are both
  "contrast-like" and only one fits (e.g. "Nevertheless" vs "Instead").

### Rhetorical Synthesis (`rhs`)
- `passage` is null. The app shows "While researching a topic, a student has taken the following notes:" by itself,
  so do not write it anywhere. Put only the bullet facts in `notes` (3–6 strings), and write the stem exactly as the
  blueprint pattern with a specific goal: "The student wants to {emphasize a similarity between
  the two bridges}. Which choice most effectively uses relevant information from the notes to accomplish this goal?"
- All four choices are accurate, well-formed sentences using note facts; only the key accomplishes the goal.
  Traps: `misses_goal` (accurate but wrong purpose), `too_narrow` (half the goal), `true_irrelevant`.
- Goals: emphasize a difference/similarity, introduce X to an unfamiliar audience, present a study's aim/method/
  finding, make a generalization, explain a cause.

## 5. Data format (`ceq` only)
```json
{"kind": "table", "title": "Average Monsoon Rainfall by City, 2015–2019",
 "columns": ["City", "June (mm)", "July (mm)"],
 "rows": [["Lahore", 78, 202], ["Karachi", 18, 82]],
 "note": "optional source-style note"}
```
```json
{"kind": "bar", "title": "…", "x_label": "Year", "y_label": "Nests observed",
 "series": [{"name": "Site A", "points": [["2019", 14], ["2020", 22]]},
            {"name": "Site B", "points": [["2019", 9], ["2020", 11]]}]}
```
`kind: "line"` uses the same shape. At most 3 series, at most 8 points, at most 6 rows × 5 columns.

## 6. Explanations
- `why`: 2–4 sentences teaching the reasoning ("The text says X, so the blank must express Y…").
- Each letter: starts "Correct." or "Incorrect." then one or two sentences on exactly why, in student-friendly
  language. For conventions items name the rule ("A comma alone can't join two independent clauses").
- Where a US/UK difference could mislead a Pakistani student, add one short note in `why` ("In American English the
  period goes inside the closing quotation mark.").

## 7. Before handing in
- Run the validator on your files. Zero errors.
- Answer keys across a batch: roughly even A/B/C/D.
- Vary subjects, contexts, names, sentence openings. No two passages on the same narrow topic in one batch.
- `provenance.status` = "draft". The check step sets "checked".
