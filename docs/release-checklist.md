# Release checklist — Module Up: Digital SAT Prep

Status 22 Oct 2026: build complete; release 1.0.0+1 (content 2026-10.1) waiting for the Homi steps below.

## Done
- [x] 1,558 original items (810 in 10 adaptive papers, 660 drills, 88 try-it), each validated and blind-solved
      (Sonnet for levels 1-2, Opus for everything else); disagreements fixed or confirmed by review.
- [x] 11 lessons with 44 strategy cards; grammar handbook, 411-word word bank, trap guide, test-day guide.
- [x] Answer positions shuffled (writers had rotated A-D); keys balanced.
- [x] Scoring check: simulated students score within about 10 points across all 10 papers (pipeline log
      in the commit "Complete question bank").
- [x] Firebase project `moduleup-sat-homilabs` (homilabs.smc@gmail.com): Firestore asia-south1 with owner-only rules;
      Google, email/password and anonymous sign-in; debug + upload-key SHA-1 registered.
- [x] AdMob app and 3 units (config/admob.json); release id check passes.
- [x] Upload keystore in .secrets/ (gitignored; backed up locally and on Drive).
- [x] App: test simulator, score report, review, practice by skill/level, lessons, guides, progress board,
      accounts (guest → Google/email upgrade), account deletion, ads with consent. 17 tests pass.

## Homi to do (in this order)
1. [ ] **Review content**: `pipeline/out/review-flagged.html` (59 items writers flagged; list in
       content/rw/review_flags.md) and `pipeline/out/review-paper-01.html` (one full paper). Say "approve" or give
       fixes in chat; approved items get `status: approved`.
2. [ ] **Unlock the test phone** (Oppo CPH2743) so I can run the app on it: sign in with Google and email, take a
       paper, check ads (test ads in debug).
3. [ ] **Publish on homilabs.org** (needs your OK): docs/privacy-policy.md at /moduleup/privacy, a deletion-request page
       at /moduleup/delete-account, and app-ads.txt with
       `google.com, pub-2087846699268567, DIRECT, f08c47fec0942fa0`.
4. [ ] **Google Play Console** (HomiLabs account): create the app "Module Up: Digital SAT Prep", fill the listing from
       docs/play-listing.md, Data safety, content rating, target audience 13+, "Contains ads".
       Upload `releases/v1.0.0-1/moduleup-1.0.0-1.aab` to internal testing first.
5. [ ] After Play App Signing is set up: copy the **app signing key SHA-1** from Play Console → App integrity, and I add it
       to Firebase (otherwise Google sign-in fails for Play-installed copies).
6. [ ] **Link AdMob** app to the Play listing (AdMob → App settings → Add store), so AdMob review can start.
7. [ ] **Graphics**: feature graphic 1024×500 and screenshots (I can capture them once the phone is unlocked; a feature
       graphic could be drawn in code or made on homidev with your approval).

## Before every release
- `python3 pipeline/validate.py` → 0 errors; `python3 pipeline/build_packs.py`; `bash scripts/build_release.sh`
  (checks memory, ad ids, 10 papers, tests, upload-key signature).
- Bump `version:` in app/pubspec.yaml (versionCode +1) and `pipeline/release.json`.
- About screen and store listing carry the College Board trademark notice.
- `bash scripts/backup.sh`.

## Not done yet (known gaps)
- Firestore rules are not yet covered by emulator tests (rules are owner-only and simple).
- No on-device run yet (phone locked); UI checked through rendered widget-test screenshots.
- Strings are in code (English only), not ARB files.
