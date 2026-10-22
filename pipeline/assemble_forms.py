#!/usr/bin/env python3
"""Assemble the 10 adaptive papers from the paper pool.

  python3 pipeline/assemble_forms.py          # writes content/rw/forms/paper-01.json .. paper-10.json
  python3 pipeline/assemble_forms.py --check  # report only

For each question type, paper items are sorted by difficulty and dealt round-robin to the 10 papers, so every
paper gets the same spread. Within a paper, each type's items are taken in triples (low, middle, high): the low
one goes to the easier module 2, the high one to the harder module 2 and the middle one to module 1. Items in a
module follow the blueprint type order, easier to harder within each type. The routing threshold is the expected
module 1 score of a student at ability 0 (Rasch), rounded.
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RW = ROOT / "content" / "rw"
BP = json.loads((RW / "blueprint.json").read_text())
PAPERS = BP["papers"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    items = [json.loads(p.read_text()) for p in sorted((RW / "items").glob("*/*.json"))]
    pool = [i for i in items if i["pool"] == "paper" and i["provenance"]["status"] != "retired"]
    per_module = BP["module_blueprint"]["types"]
    papers = [{"m1": [], "m2_easy": [], "m2_hard": []} for _ in range(PAPERS)]
    short = []
    for t in BP["type_order"]:
        c = per_module[t]
        mine = sorted((i for i in pool if i["type"] == t), key=lambda i: (i["b"], i["id"]))
        need = 3 * c * PAPERS
        if len(mine) < need:
            short.append(f"{t}: {len(mine)}/{need}")
            continue
        dealt = [[] for _ in range(PAPERS)]
        for k, it in enumerate(mine[:need]):
            dealt[k % PAPERS].append(it)
        for p, group in enumerate(dealt):
            group.sort(key=lambda i: (i["b"], i["id"]))
            for j in range(c):
                low, mid, high = group[3 * j], group[3 * j + 1], group[3 * j + 2]
                papers[p]["m2_easy"].append(low)
                papers[p]["m1"].append(mid)
                papers[p]["m2_hard"].append(high)
    if short:
        print("Not enough paper items yet:\n  " + "\n  ".join(short))
        return
    order = {t: n for n, t in enumerate(BP["type_order"])}
    for n, mods in enumerate(papers, 1):
        out = {"id": f"paper-{n:02d}", "number": n, "title": f"Paper {n}", "modules": {}}
        for m, lst in mods.items():
            lst.sort(key=lambda i: (order[i["type"]], i["b"], i["id"]))
            out["modules"][m] = [i["id"] for i in lst]
        expected = sum(1 / (1 + math.exp(i["b"])) for i in mods["m1"])
        out["route_threshold"] = round(expected)
        levels = {m: [sum(1 for i in lst if i["level"] == L) for L in range(1, 5)] for m, lst in mods.items()}
        print(f"{out['id']}: threshold {out['route_threshold']}/27, levels {levels}")
        if not a.check:
            (RW / "forms").mkdir(exist_ok=True)
            (RW / "forms" / f"{out['id']}.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
