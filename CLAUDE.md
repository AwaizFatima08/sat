# Module Up: Digital SAT Prep (folder sat)

Android app (Flutter) that simulates the Digital SAT. English (Reading and Writing) first; Math added later on the
same engine. Repo: https://github.com/AwaizFatima08/sat (PUBLIC, agreed by Homi 22 Oct 2026).
Design master: Claude Doc "SAT Simulator — English Design" https://claude.ai/artifact/SxNyPMFC6QiQiqoh49GNbz
(summary in docs/design.md).

## Rules
- Every question, passage, lesson and explanation is original HomiLabs work. Never copy or reword College Board
  (Bluebook, SAT Question Bank), Khan Academy or prep-book material. Literary excerpts only from public-domain works
  (published before 1930), with author, work, year and source in the item's `source`.
- "SAT" is used descriptively only. The About screen and store listing carry the College Board trademark notice.
- Only items with `provenance.status` = `approved` (or `checked` during development) are built into the app.
  Run `python3 pipeline/validate.py` and `python3 pipeline/validate_math.py` before committing content.
- American English conventions in all test content.
- Ads: AdMob ids are in config/admob.json. No ads on test, drill or review screens. Debug builds use Google sample ids;
  `scripts/check-release-ad-ids.sh` must pass before a release build.
- No secrets in the public repo: signing keys, key.properties and .secrets/ stay local + Drive.
- Heavy jobs (Gradle, emulator) follow ~/.claude/heavy-jobs.md: check `free -h` first, one at a time, `./gradlew --stop` after.
- Backups: `bash scripts/backup.sh` (local sat_backup, Google Drive sat folder, GitHub).

## Layout
| Path | What |
|---|---|
| content/rw/items/<type>/ | question pool, one JSON per item (schema: content/rw/schema/item.schema.json) |
| content/rw/forms/ | the 10 adaptive papers (module 1, module 2 easier, module 2 harder) |
| content/rw/lessons/ | lesson notes + strategy cards per skill |
| content/rw/reference/ | grammar handbook, word bank, trap guide, test-day guide |
| content/rw/guides/ | writing guides per question type (for authors, not shipped) |
| content/math/items/<type>/ | Math pool (19 types), one JSON per item with a SymPy `verify` script |
| content/math/forms/ | the 10 adaptive Math papers (math-01..10), built by pipeline/assemble_math_forms.py |
| content/math/lessons/, guides/ | Math lessons (19) and the writing / lesson format guides |
| content/math/review_flags.md | writer and solver notes for Homi's review |
| pipeline/ | validate.py, validate_math.py, build_packs.py (content → app/assets/data), review_sheet(_math).py, blind.py (--math), shuffle_choices.py (--math), resolve_blind.py |
| app/ | Flutter app `com.homilabs.moduleup` |
| firebase/ | Firestore rules + emulator tests |
| config/admob.json | AdMob app + ad unit ids |
