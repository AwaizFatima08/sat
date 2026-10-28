#!/usr/bin/env python3
"""Assemble the 10 adaptive Math papers from the paper pool.

  python3 pipeline/assemble_math_forms.py          # writes content/math/forms/math-01.json .. math-10.json
  python3 pipeline/assemble_math_forms.py --check  # report only
  python3 pipeline/assemble_math_forms.py --set 2  # math-11 .. math-20 from paper items numbered 0601+

Math modules have fixed counts per domain (blueprint module_blueprint.domains), not per type. For each domain the
paper items are sorted by difficulty, then type, and dealt in snake order to the 10 papers, so every paper gets the
same difficulty spread and a mix of types. Within a paper each domain's share is split into thirds by difficulty:
lowest third to the easier module 2, middle third to module 1, highest third to the harder module 2. A repair pass
then swaps typed-answer and multiple-choice items of the same domain and difficulty between modules until every
module has the blueprint's number of typed-answer items. Items in a module run easiest to hardest (ties mixed
across domains). The routing threshold is the expected module 1 score of a student at ability 0 (Rasch), rounded.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
M = ROOT / "content" / "math"
BP = json.loads((M / "blueprint.json").read_text())
PAPERS = BP.get("papers", 10)
MODS = ("m2_easy", "m1", "m2_hard")


def mix(i):
    return hashlib.sha1(i["id"].encode()).hexdigest()


def spr_count(lst):
    return sum(i["answer_type"] == "spr" for i in lst)


def repair_spr(papers):
    """Swap same-domain, same-b items between modules to bring typed-answer counts into range."""
    lo, hi = BP["module_blueprint"]["spr_per_module"]
    mods = [lst for p in papers for lst in p.values()]
    for _ in range(500):
        low = [m for m in mods if spr_count(m) < lo]
        high = [m for m in mods if spr_count(m) > hi]
        if not low and not high:
            return True
        moved = False
        for a in low + high:
            want_spr_in = spr_count(a) < lo        # a needs one more typed item (or one fewer)
            donors = sorted(mods, key=lambda m: -spr_count(m) if want_spr_in else spr_count(m))
            for b in donors:
                if b is a or (want_spr_in and spr_count(b) <= lo) or (not want_spr_in and spr_count(b) >= hi):
                    continue
                give = [i for i in b if (i["answer_type"] == "spr") == want_spr_in]
                take = [i for i in a if (i["answer_type"] == "spr") != want_spr_in]
                pair = next(((x, y) for x in give for y in take
                             if x["domain"] == y["domain"] and x["b"] == y["b"]), None)
                if pair:
                    x, y = pair
                    b.remove(x); a.remove(y); b.append(y); a.append(x)
                    moved = True
                    break
            if moved:
                break
        if not moved:
            return False
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--set", type=int, default=1, choices=[1, 2])
    a = ap.parse_args()
    lo, hi = (101, 499) if a.set == 1 else (601, 999)
    first = (a.set - 1) * PAPERS + 1
    items = [json.loads(p.read_text()) for p in sorted((M / "items").glob("*/*.json"))]
    pool = [i for i in items if i["pool"] == "paper" and i["provenance"]["status"] == "checked"
            and lo <= int(i["id"].rsplit("-", 1)[1]) <= hi]
    type_rank = {t: n for n, t in enumerate(BP["type_order"])}
    papers = [{m: [] for m in MODS} for _ in range(PAPERS)]
    short = []
    for d, c in BP["module_blueprint"]["domains"].items():
        mine = sorted((i for i in pool if i["domain"] == d), key=lambda i: (i["b"], type_rank[i["type"]], i["id"]))
        need = 3 * c * PAPERS
        if len(mine) < need:
            short.append(f"{d}: {len(mine)}/{need} checked paper items")
            continue
        dealt = [[] for _ in range(PAPERS)]
        for k, it in enumerate(mine[:need]):
            r, pos = divmod(k, PAPERS)
            dealt[pos if r % 2 == 0 else PAPERS - 1 - pos].append(it)
        for p, group in enumerate(dealt):
            group.sort(key=lambda i: (i["b"], mix(i)))
            papers[p]["m2_easy"] += group[:c]
            papers[p]["m1"] += group[c:2 * c]
            papers[p]["m2_hard"] += group[2 * c:]
    if short:
        print("Not enough paper items yet:\n  " + "\n  ".join(short))
        return
    if not repair_spr(papers):
        print("warning: could not bring every module's typed-answer count into range")
    for n, mods in enumerate(papers, first):
        out = {"id": f"math-{n:02d}", "number": n, "title": f"Math Paper {n}", "section": "math", "modules": {}}
        for m in ("m1", "m2_easy", "m2_hard"):
            lst = sorted(mods[m], key=lambda i: (i["b"], mix(i)))
            out["modules"][m] = [i["id"] for i in lst]
        out["route_threshold"] = round(sum(1 / (1 + math.exp(i["b"])) for i in mods["m1"]))
        levels = {m: [sum(1 for i in lst if i["level"] == L) for L in range(1, 5)] for m, lst in mods.items()}
        spr = {m: spr_count(lst) for m, lst in mods.items()}
        print(f"{out['id']}: threshold {out['route_threshold']}/{BP['module_items']}, levels {levels}, typed {spr}")
        if not a.check:
            (M / "forms").mkdir(exist_ok=True)
            (M / "forms" / f"{out['id']}.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
