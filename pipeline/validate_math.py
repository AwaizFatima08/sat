#!/usr/bin/env python3
"""Check every Math item, form and lesson; run each item's SymPy `verify` script.

  python3 pipeline/validate_math.py                 # everything (runs all verify scripts)
  python3 pipeline/validate_math.py --items PATH... # only these items (plus pool-wide checks)
  python3 pipeline/validate_math.py --quiet
Exit 1 on any ERROR.
"""
import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
M = ROOT / "content" / "math"
BP = json.loads((M / "blueprint.json").read_text())
ABBR = {v["abbr"]: k for k, v in BP["types"].items()}
ID_RE = re.compile(r"^m-([a-z0-9]{3,4})-(\d{4})$")
LETTERS = ["A", "B", "C", "D"]
STATUSES = {"draft", "checked", "approved", "retired"}
SPR_RE = re.compile(r"^-?(\d+(\.\d+)?|\.\d+|\d+/\d+)$")
errors, warns = [], []


def err(w, m):
    errors.append(f"ERROR {w}: {m}")


def warn(w, m):
    warns.append(f"WARN  {w}: {m}")


def balanced(s):
    return s.count("\\(") == s.count("\\)") and s.count("\\[") == s.count("\\]") and s.count("{") == s.count("}")


def check_figure(w, f):
    if not isinstance(f, dict) or f.get("kind") not in BP["figure_kinds"]:
        return err(w, f"figure.kind must be one of {BP['figure_kinds']}")
    k = f["kind"]
    need = {"xy": ["x", "y"], "geometry": ["points"], "scatter": ["points", "x_label", "y_label"],
            "histogram": ["bins", "x_label"], "dotplot": ["values", "x_label"], "boxplot": ["plots", "x_label"],
            "bar": ["series", "x_label", "y_label"], "line": ["series", "x_label", "y_label"],
            "table": ["columns", "rows"]}[k]
    for n in need:
        if n not in f:
            err(w, f"figure ({k}) needs '{n}'")
    if k == "xy":
        for c in f.get("curves", []):
            if not c.get("expr"):
                err(w, "xy curve needs expr")
    if k == "geometry":
        names = set(f.get("points", {}))
        for seg in f.get("segments", []):
            if not set(seg) <= names:
                err(w, f"segment {seg} uses unknown points")
    if k == "table":
        for r in f.get("rows", []):
            if len(r) != len(f.get("columns", [])):
                err(w, "table row length differs from columns")


def check_item(p, it):
    w = p.relative_to(ROOT).as_posix()
    req = ["id", "section", "domain", "type", "level", "b", "context", "in_context", "pool", "stem", "answer_type",
           "solution", "verify", "source", "provenance"]
    missing = [k for k in req if k not in it]
    if missing:
        return err(w, f"missing {missing}")
    m = ID_RE.match(it["id"])
    if not m or ABBR.get(m.group(1)) != it["type"]:
        err(w, "id must be m-<abbr>-NNNN matching the type")
    if p.stem != it["id"] or p.parent.name != it["type"]:
        err(w, "file must be items/<type>/<id>.json")
    t = BP["types"].get(it["type"])
    if not t:
        return err(w, f"unknown type {it['type']}")
    if it["section"] != "math" or it["domain"] != t["domain"]:
        err(w, f"section must be math and domain {t['domain']}")
    if str(it["level"]) not in BP["levels"]:
        err(w, "level 1-4")
    elif abs(float(it["b"]) - BP["levels"][str(it["level"])]["b"]) > 0.75:
        warn(w, "b far from level default")
    if it["context"] not in ("global", "south_asia") or it["pool"] not in ("paper", "drill", "tryit"):
        err(w, "bad context or pool")
    texts = [it["stem"]] + list((it.get("choices") or {}).values()) + it["solution"]
    for s in texts:
        if not balanced(s):
            err(w, f"unbalanced math delimiters or braces in: {s[:60]}")
    if "$" in it["stem"] and "\\$" not in it["stem"]:
        warn(w, "stem uses $; write dollars as \\$ or words, math in \\( \\)")
    if it["answer_type"] == "mcq":
        ch = it.get("choices") or {}
        if sorted(ch) != LETTERS or len({str(v).strip() for v in ch.values()}) != 4:
            err(w, "mcq needs 4 distinct choices A-D")
        if it.get("answer") not in LETTERS:
            err(w, "mcq answer must be A-D")
        ex = it.get("explanation") or {}
        if sorted(ex) != LETTERS or not all(str(v).strip() for v in ex.values()):
            err(w, "mcq needs an explanation for each of A-D")
        tr = it.get("traps") or {}
        if set(tr) != set(LETTERS) - {it.get("answer")} or not all(v in BP["traps"] for v in tr.values()):
            err(w, "traps must cover exactly the wrong letters with blueprint trap keys")
        if it.get("spr_answers"):
            err(w, "mcq must not have spr_answers")
    elif it["answer_type"] == "spr":
        sa = it.get("spr_answers") or []
        if not sa:
            err(w, "spr needs spr_answers")
        for a in sa:
            if not SPR_RE.match(str(a)):
                err(w, f"spr answer '{a}' must be an integer, decimal or a/b")
            elif len(str(a).lstrip("-")) > 5 and "/" in str(a):
                warn(w, f"spr answer {a} longer than 5 characters (students must enter a decimal)")
        if it.get("choices") or it.get("answer"):
            err(w, "spr must not have choices/answer")
    else:
        err(w, "answer_type must be mcq or spr")
    if not (2 <= len(it["solution"]) <= 8):
        warn(w, "solution should have 2-8 steps")
    if it.get("figure") is not None:
        check_figure(w, it["figure"])
    if it["provenance"].get("status") not in STATUSES:
        err(w, "bad provenance.status")
    if re.search(r"College Board|Khan Academy|Bluebook", json.dumps(it), re.I):
        err(w, "mentions a protected name")


def run_verify(items):
    proc = subprocess.run([sys.executable, "-I", str(ROOT / "pipeline" / "math_verify_runner.py")],
                          input=json.dumps(items), capture_output=True, text=True, timeout=1800, cwd="/tmp")
    if proc.returncode != 0:
        err("verify", f"runner crashed: {proc.stderr[-400:]}")
        return
    for iid, r in json.loads(proc.stdout).items():
        if r != "ok":
            err(iid, f"verify: {r}")


def check_forms(by_id):
    seen = {}
    for fp in sorted((M / "forms").glob("*.json")):
        w = fp.relative_to(ROOT).as_posix()
        f = json.loads(fp.read_text())
        mods = f.get("modules", {})
        if set(mods) != {"m1", "m2_easy", "m2_hard"} or not isinstance(f.get("route_threshold"), int):
            err(w, "needs m1, m2_easy, m2_hard and route_threshold")
            continue
        mean = {}
        for mk, ids in mods.items():
            if len(ids) != BP["module_items"]:
                err(w, f"{mk} has {len(ids)} items")
            items = [by_id[i] for i in ids if i in by_id]
            if len(items) != len(ids):
                err(w, f"{mk} has unknown items")
            for i in ids:
                if i in seen:
                    err(w, f"{i} used twice")
                seen[i] = mk
            doms = Counter(i["domain"] for i in items)
            if dict(doms) != BP["module_blueprint"]["domains"]:
                err(w, f"{mk} domain counts {dict(doms)}")
            spr = sum(i["answer_type"] == "spr" for i in items)
            lo, hi = BP["module_blueprint"]["spr_per_module"]
            if not lo <= spr <= hi:
                warn(w, f"{mk} has {spr} typed-answer items (want {lo}-{hi})")
            bs = [i["b"] for i in items]
            if bs != sorted(bs):
                err(w, f"{mk} not ordered easiest to hardest")
            mean[mk] = sum(bs) / max(1, len(bs))
        if len(mean) == 3 and not mean["m2_easy"] < mean["m1"] < mean["m2_hard"]:
            err(w, f"module difficulty order wrong {mean}")
    return seen


LESSON_KEYS = ["type", "title", "what_is_tested", "how_to_spot", "method", "pitfalls", "cards"]


def check_lessons(by_id, verify=True):
    """content/math/lessons/<type>.json: one per type, 4 cards, verified worked examples."""
    examples = []
    for fp in sorted((M / "lessons").glob("*.json")):
        w = f"lesson {fp.stem}"
        try:
            les = json.loads(fp.read_text())
        except json.JSONDecodeError as e:
            err(w, f"invalid JSON: {e}")
            continue
        for k in LESSON_KEYS:
            if not les.get(k):
                err(w, f"missing {k}")
        t = les.get("type")
        if t not in BP["types"] or fp.stem != t:
            err(w, "type unknown or file name differs from type")
            continue
        abbr = BP["types"][t]["abbr"]
        for k in ("method", "pitfalls"):
            for line in les.get(k) or []:
                if not balanced(line):
                    err(w, f"unbalanced math delimiters in {k}")
        cards = les.get("cards") or []
        if sorted(c.get("level") for c in cards) != [1, 2, 3, 4]:
            err(w, "needs one card per level 1-4")
        for c in cards:
            lv = c.get("level")
            cw = f"{w} L{lv}"
            if len(c.get("steps") or []) != 4:
                err(cw, "needs exactly 4 steps")
            want = [f"m-{abbr}-{2 * lv - 1:04d}", f"m-{abbr}-{2 * lv:04d}"]
            if c.get("tryit") != want:
                err(cw, f"tryit must be {want}")
            ex = c.get("worked_example") or {}
            for k in ("stem", "walkthrough", "verify"):
                if not ex.get(k):
                    err(cw, f"worked_example missing {k}")
            if ex.get("answer_type") == "spr":
                if not ex.get("spr_answers"):
                    err(cw, "typed example needs spr_answers")
            elif sorted(ex.get("choices") or {}) != list("ABCD") or ex.get("answer") not in "ABCD":
                err(cw, "example needs choices A-D and an answer")
            if ex.get("figure"):
                check_figure(cw, ex["figure"])
            stem = re.sub(r"\s+", " ", ex.get("stem", "")).strip()
            for it in by_id.values():
                if re.sub(r"\s+", " ", it.get("stem", "")).strip() == stem:
                    err(cw, f"worked example copies item {it['id']}")
            for text in [ex.get("stem", ""), *ex.get("walkthrough", []), *(ex.get("choices") or {}).values()]:
                if not balanced(text):
                    err(cw, "unbalanced math delimiters")
            examples.append({**ex, "id": f"lesson-{t}-L{lv}"})
    if verify and examples:
        run_verify(examples)
    return len(list((M / "lessons").glob("*.json")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", nargs="*")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--no-verify", action="store_true")
    a = ap.parse_args()
    items, by_id = [], {}
    for p in sorted((M / "items").glob("*/*.json")):
        try:
            it = json.loads(p.read_text())
        except json.JSONDecodeError as e:
            err(p.name, f"invalid JSON: {e}")
            continue
        if it.get("id") in by_id:
            err(p.name, "duplicate id")
        by_id[it.get("id")] = it
        items.append((p, it))
    targets = {Path(x).resolve() for x in a.items} if a.items else None
    chosen = [(p, it) for p, it in items if targets is None or p.resolve() in targets]
    for p, it in chosen:
        check_item(p, it)
    if not a.no_verify and chosen:
        run_verify([it for _, it in chosen])
    stems = Counter(re.sub(r"\s+", " ", it["stem"]).strip() for _, it in items)
    for s, n in stems.items():
        if n > 1:
            err("pool", f"{n} items share the same stem: {s[:70]}")
    placed = check_forms(by_id)
    n_lessons = check_lessons(by_id, verify=not a.no_verify and targets is None)
    if not a.quiet:
        for line in errors + warns:
            print(line)
    live = [it for _, it in items if it["provenance"].get("status") != "retired"]
    st = Counter(it["provenance"].get("status") for it in live)
    spr = sum(it.get("answer_type") == "spr" for it in live)
    print(f"\n{len(live)} math items ({dict(st)}), {spr} typed-answer; {len(placed)} placed in forms; "
          f"{n_lessons} lessons; {len(errors)} errors, {len(warns)} warnings")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
