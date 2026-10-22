# Module Up: Digital SAT Prep

A free Android app by [HomiLabs](https://homilabs.org) that simulates the Digital SAT®: 10 full-length adaptive
Reading and Writing papers with an estimated score at the end, section-wise practice material, a progress board,
and student accounts (Google or email and password). Math will be added later.

All questions are original. SAT® is a trademark registered by the College Board, which is not affiliated with,
and does not endorse, this app.

## Common commands
```bash
python3 pipeline/validate.py            # check every item and form
python3 pipeline/build_packs.py         # build app/assets/data from content/
python3 pipeline/review_sheet.py <ids>  # HTML review sheet for a batch
bash scripts/backup.sh                  # local + Google Drive + GitHub backup
```
See [CLAUDE.md](CLAUDE.md) and [docs/design.md](docs/design.md).
