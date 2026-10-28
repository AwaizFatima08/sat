# Reading and Writing writer brief — paper set 2 (papers 11-20)

You are writing original SAT Reading and Writing questions for the HomiLabs app "Module Up: Digital SAT Prep" in /mnt/storage/projects/sat. Quality matters more than speed. These items go into the second set of 10 full-length simulated papers (papers 11-20), so they must feel exactly like real Digital SAT questions.

## Your batch
Run `python3 pipeline/batch.py show <your batch>` to see the type, pool, exact ids and the level of each id. Write exactly those ids (skip any that already exist), each to content/rw/items/<type>/<id>.json (plain JSON, 2-space indent, UTF-8, no comments). provenance: written_by "claude-fable-5-1", written "<today's date>", checks [], reviewed_by null, status "draft". "b" = the level default from the blueprint. "pool": "paper".

## Read first
- content/rw/guides/writing-guide.md in full (the level table and the section for your type) and content/rw/blueprint.json.
- The four try-it items of your type at the levels you are writing (rw-<abbr>-0001..0008) as style models, and two or three of the set-1 paper items of your type (rw-<abbr>-01xx) at your levels.
- Run `python3 pipeline/topics.py` to see which topics already exist.

## Topics
Before writing each item, claim its topic with `python3 pipeline/claim_topic.py <your batch> "<3-6 word specific topic>"`. If it prints TAKEN, pick a different topic and claim again. Never write a passage on a topic you have not CLAIMED. Set 1 already used many topics, so go for fresh, specific ones. Claim one topic at a time, never a scratch note.

## Mix
- Spread subjects (science, social science, history, humanities, literature), as the guide describes for your type.
- About 20 % of passages with context "south_asia" (Pakistan, India, Bangladesh, Sri Lanka, Nepal), the rest global.
- Answer keys spread evenly over A-D within the batch (count them).
- Keep passages inside the guide's word range for each level.
- Literary excerpts only from public-domain works (published before 1930) with author, work, year and source in `source`, exactly as the guide says.

## Quality gate (every item)
1. Solve it cold as a 780-scoring student would. Exactly one option is defensible; every wrong option fails for a real, specific reason that matches its trap tag.
2. Facts accurate. Never attach invented findings to real named people, never credit a real study to an invented researcher, and never invent a named study; use clearly hypothetical or generic researchers and data when inventing.
3. American English. Original work only: never copy or reword College Board, Khan Academy or prep-book material.
4. Run `python3 pipeline/validate.py --items <your files>` and fix until 0 errors.

## Boundaries
Use only your own scratch folder (given in your task) for helper scripts. Do not edit any other repo file except via claim_topic.py. Do not run git.

## Final reply (max 8 lines)
Ids written count, the validator result line, and any item you are unsure about with the reason.
