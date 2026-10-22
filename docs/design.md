# Design summary

The full design is the Claude Doc **SAT Simulator — English Design**:
https://claude.ai/artifact/SxNyPMFC6QiQiqoh49GNbz (v0.3, agreed with Homi on 22 Oct 2026).

## Decisions (22 Oct 2026)
- Name: **Module Up: Digital SAT Prep**, package `com.homilabs.moduleup`, Android only, Flutter.
- English (Reading and Writing) first; Math later as the second half of the same 10 papers.
- 10 full-length adaptive papers: module 1 (27 items, 32 min) routes to an easier or harder module 2 (27 items,
  32 min). Estimated section score 200–800 with a ± band, shown as soon as the paper ends.
- Practice material per skill (11 skills): lesson notes, strategy card per level, drills at 4 levels
  (Foundations, Medium, Advanced, Challenge), domain quizzes, timed module practice; reference guides (grammar
  handbook, word bank, trap guide, test-day guide).
- Pool for v1: 810 paper items + 660 drill items + 88 try-it items ≈ 1,560, all original.
- Progress board: score trend, 10 paper tiles, skill × level mastery, trap profile, pace, streak, study plan,
  mistake notebook (1/3/7-day spaced review).
- Accounts: Firebase Auth (Google, email + password), Firestore sync, offline-first; guest may try one drill set;
  in-app account deletion. Firebase project under homilabs.smc@gmail.com.
- Monetization: AdMob only, no purchases. Banner on Home/Progress only; interstitial after drill sets (max 1 per 3,
  4 min apart, never day 1, never around a paper); rewarded = 1 extra Challenge set (2 free per day, up to 3 earned).
  UMP consent; content rating PG; audience 13+. Ids: config/admob.json.
- About 20 % of passages set in South Asia; American English conventions.
- Scoring: Rasch ability over 54 answers, difficulty b per level (−1.5, −0.5, +0.5, +1.5), fixed scale table,
  easier route capped near 600–620.
