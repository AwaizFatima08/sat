#!/usr/bin/env python3
"""Shuffle answer-choice order so keys are not predictable (writers balanced keys by rotating A-D).

  python3 pipeline/shuffle_choices.py [--dry-run] [--math] [ID_GLOB ...]

Deterministic per item (seeded by id). Moves choices, the key, per-letter explanations, traps and blind-check
answers together, and rewrites "Choice X" references in explanation text. Skips the rw-xxx-000N try-it items
(the pilot that Homi reviewed). Run validate.py afterwards.
With --math: works on content/math (typed-answer items are skipped). Each verify script is left as written and
gets a one-line prelude that maps the shuffled choices and key back to the original letters, so scripts that name
letters (choices['B'], or geometry points 'A', 'B') keep working while a wrong key still fails. Run
validate_math.py afterwards; it re-runs every verify script.
"""
import fnmatch
import json
import random
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L = ["A", "B", "C", "D"]
REF = re.compile(r"\b([Cc]hoice|[Oo]ption) ([A-D])\b")


def shuffle(it):
    rng = random.Random("moduleup-" + it["id"])
    order = L[:]
    rng.shuffle(order)                      # order[new_index] = old letter
    new_of = {old: L[i] for i, old in enumerate(order)}
    it["choices"] = {new_of[o]: it["choices"][o] for o in L}
    it["choices"] = {k: it["choices"][k] for k in L}
    it["answer"] = new_of[it["answer"]]
    ex = it.get("explanation") or {}
    fix = lambda s: REF.sub(lambda m: f"{m.group(1)} {new_of[m.group(2)]}", s)
    moved = {new_of[o]: fix(ex[o]) for o in L if o in ex}
    it["explanation"] = ({"why": fix(ex["why"])} if "why" in ex else {}) | {k: moved[k] for k in L if k in moved}
    if it.get("verify"):
        old_of = {n: o for o, n in new_of.items()}
        it["verify"] = (f"choices = {{o: choices[n] for o, n in {new_of!r}.items()}}; answer = {old_of!r}[answer]"
                        "  # shuffled: original letters\n" + it["verify"])
    it["traps"] = {new_of[o]: t for o, t in it["traps"].items()}
    it["traps"] = {k: it["traps"][k] for k in L if k in it["traps"]}
    for c in it["provenance"].get("checks", []):
        for k in ("answer", "second"):
            if c.get(k) in new_of:
                c[k] = new_of[c[k]]
    it["provenance"]["shuffled"] = True
    return it


def main():
    dry = "--dry-run" in sys.argv
    section = "math" if "--math" in sys.argv else "rw"
    globs = [a for a in sys.argv[1:] if not a.startswith("--")] or ["*"]
    before, after, n = Counter(), Counter(), 0
    for p in sorted((ROOT / "content" / section / "items").glob("*/*.json")):
        it = json.loads(p.read_text())
        if re.search(r"-000\d$", it["id"]) or it["provenance"].get("shuffled"):
            continue
        if it.get("answer_type") == "spr":
            continue
        if not any(fnmatch.fnmatch(it["id"], g) for g in globs):
            continue
        before[it["answer"]] += 1
        it = shuffle(it)
        after[it["answer"]] += 1
        n += 1
        if not dry:
            p.write_text(json.dumps(it, indent=2, ensure_ascii=False) + "\n")
    print(f"{'would shuffle' if dry else 'shuffled'} {n} items; keys before {dict(before)} after {dict(after)}")


if __name__ == "__main__":
    main()
