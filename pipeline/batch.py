#!/usr/bin/env python3
"""Writing batches for the full bank (pipeline/batches.json).

  python3 pipeline/batch.py plan          # (re)build batches.json from the blueprint and quotas
  python3 pipeline/batch.py show NAME     # what a writer must produce
  python3 pipeline/batch.py status        # done / missing per batch
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RW = ROOT / "content" / "rw"
BP = json.loads((RW / "blueprint.json").read_text())
PLAN = ROOT / "pipeline" / "batches.json"


def chunks(seq, n):
    return [seq[i:i + n] for i in range(0, len(seq), n)]


def plan():
    quotas = json.loads((ROOT / "pipeline" / "paper_level_quotas.json").read_text())
    batches = []
    for t in BP["type_order"]:
        abbr = BP["types"][t]["abbr"]
        drill = []
        for lvl in range(1, 5):
            for k in range(15):
                drill.append((f"rw-{abbr}-{500 + (lvl - 1) * 15 + k + 1:04d}", lvl))
        for i, part in enumerate(chunks(drill, 30), 1):
            batches.append({"name": f"drill-{abbr}-{i}", "type": t, "pool": "drill", "items": part})
        paper, n = [], 101
        for lvl in "1234":
            for _ in range(quotas[t][lvl]):
                paper.append((f"rw-{abbr}-{n:04d}", int(lvl)))
                n += 1
        size = 30 if len(paper) % 30 == 0 or len(paper) < 40 else 30
        for i, part in enumerate(chunks(paper, size), 1):
            batches.append({"name": f"paper-{abbr}-{i}", "type": t, "pool": "paper", "items": part})
    PLAN.write_text(json.dumps(batches, indent=1))
    print(f"{len(batches)} batches, {sum(len(b['items']) for b in batches)} items")


def exists(iid, t):
    return (RW / "items" / t / f"{iid}.json").exists()


def main():
    cmd = sys.argv[1]
    if cmd == "plan":
        return plan()
    batches = json.loads(PLAN.read_text())
    if cmd == "show":
        b = next(x for x in batches if x["name"] == sys.argv[2])
        print(f"batch {b['name']}: type {b['type']}, pool \"{b['pool']}\", {len(b['items'])} items")
        by_level = {}
        for iid, lvl in b["items"]:
            by_level.setdefault(lvl, []).append(iid)
        for lvl, ids in sorted(by_level.items()):
            print(f"  level {lvl} ({BP['levels'][str(lvl)]['name']}): {ids[0]} .. {ids[-1]} ({len(ids)})")
        missing = [i for i, _ in b["items"] if not exists(i, b["type"])]
        print(f"  already written: {len(b['items']) - len(missing)}; missing: {len(missing)}")
    elif cmd == "status":
        for b in batches:
            done = sum(exists(i, b["type"]) for i, _ in b["items"])
            print(f"{b['name']:16s} {done:3d}/{len(b['items'])}")


if __name__ == "__main__":
    main()
