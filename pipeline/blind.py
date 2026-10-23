#!/usr/bin/env python3
"""Blind-solve check.

  Add --math to work on content/math (typed answers are compared as numbers).
  python3 pipeline/blind.py export NAME ID_GLOB...   -> pipeline/out/blind-NAME.json (no keys, no explanations)
  python3 pipeline/blind.py record NAME SOLVER ANSWERS.json
        ANSWERS.json = {"rw-wic-0001": {"answer": "A", "second_defensible": null | "C", "note": "..."}, ...}
        Adds a check to each item's provenance. An item becomes "checked" once every recorded check agrees
        with the key and no solver found a second defensible answer; otherwise it stays "draft" (flagged).
"""
import fnmatch
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SECTION = "math" if "--math" in sys.argv else "rw"
if "--math" in sys.argv:
    sys.argv.remove("--math")
ITEMS = ROOT / "content" / SECTION / "items"
OUT = ROOT / "pipeline" / "out"
HIDE = {"answer", "explanation", "traps", "provenance", "b", "pool", "source", "spr_answers", "solution", "verify"}


def same_number(a, b):
    from fractions import Fraction
    try:
        return Fraction(str(a).strip()) == Fraction(str(b).strip())
    except (ValueError, ZeroDivisionError):
        return str(a).strip() == str(b).strip()


def is_correct(it, given):
    if it.get("answer_type") == "spr":
        return any(same_number(given, v) for v in it.get("spr_answers") or [])
    return given == it["answer"]


def load(globs):
    res = []
    for p in sorted(ITEMS.glob("*/*.json")):
        it = json.loads(p.read_text())
        if any(fnmatch.fnmatch(it["id"], g) for g in globs):
            res.append((p, it))
    return res


def main():
    cmd = sys.argv[1]
    if cmd == "export":
        name, globs = sys.argv[2], sys.argv[3:]
        OUT.mkdir(parents=True, exist_ok=True)
        blind = [{k: v for k, v in it.items() if k not in HIDE and v is not None} for _, it in load(globs)]
        f = OUT / f"blind-{name}.json"
        f.write_text(json.dumps(blind, indent=1, ensure_ascii=False))
        print(f"{f} ({len(blind)} items)")
    elif cmd == "record":
        name, solver, ans_file = sys.argv[2], sys.argv[3], sys.argv[4]
        answers = json.loads(Path(ans_file).read_text())
        agree = disagree = 0
        for p, it in load(list(answers)):
            a = answers[it["id"]]
            ok = is_correct(it, a.get("answer")) and not a.get("second_defensible")
            agree += ok
            disagree += not ok
            checks = [c for c in it["provenance"].get("checks", []) if c.get("by") != solver]
            checks.append({"by": solver, "date": date.today().isoformat(), "answer": a.get("answer"),
                           "second": a.get("second_defensible"), "note": a.get("note", ""),
                           "result": "agree" if ok else "disagree"})
            it["provenance"]["checks"] = checks
            if it["provenance"]["status"] in ("draft", "checked"):
                it["provenance"]["status"] = "checked" if all(c["result"] == "agree" for c in checks) else "draft"
            p.write_text(json.dumps(it, indent=2, ensure_ascii=False) + "\n")
        print(f"{name}/{solver}: {agree} agree, {disagree} disagree")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
