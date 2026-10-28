#!/usr/bin/env python3
"""Writing batches for the Math bank (pipeline/batches_math.json).

  python3 pipeline/batch_math.py plan
  python3 pipeline/batch_math.py show NAME
  python3 pipeline/batch_math.py status
Every 4th id in each pool block is a typed-answer (spr) item, so about 25 % are spr.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
M = ROOT / "content" / "math"
BP = json.loads((M / "blueprint.json").read_text())
PLAN = ROOT / "pipeline" / "batches_math.json"


def chunks(seq, n):
    k = max(1, -(-len(seq) // -(-len(seq) // n)))  # even-sized chunks of at most n
    return [seq[i:i + k] for i in range(0, len(seq), k)]


def entries(abbr, start, levels):
    out = []
    for k, lvl in enumerate(levels):
        out.append({"id": f"m-{abbr}-{start + k:04d}", "level": lvl, "spr": k % 4 == 3})
    return out


def plan():
    batches = []
    share = BP["level_share"]
    tot = sum(share.values())
    for t in BP["type_order"]:
        abbr = BP["types"][t]["abbr"]
        tryit = entries(abbr, 1, [1, 1, 2, 2, 3, 3, 4, 4])
        drill = entries(abbr, 501, [l for l in (1, 2, 3, 4) for _ in range(BP["drill_items_per_type_level"])])
        q = BP["paper_quotas"][t]
        raw = {l: q * share[l] / tot for l in share}
        cnt = {l: int(v) for l, v in raw.items()}
        for l in sorted(raw, key=lambda l: raw[l] - cnt[l], reverse=True)[: q - sum(cnt.values())]:
            cnt[l] += 1
        paper = entries(abbr, 101, [int(l) for l in "1234" for _ in range(cnt[l])])
        batches.append({"name": f"m-tryit-{abbr}", "type": t, "pool": "tryit", "items": tryit})
        for i, part in enumerate(chunks(drill, 20), 1):
            batches.append({"name": f"m-drill-{abbr}-{i}", "type": t, "pool": "drill", "items": part})
        for i, part in enumerate(chunks(paper, 30), 1):
            batches.append({"name": f"m-paper-{abbr}-{i}", "type": t, "pool": "paper", "items": part})
        # Paper set 2 (papers 11-20): same quotas and levels, ids from 0601.
        paper2 = entries(abbr, 601, [int(l) for l in "1234" for _ in range(cnt[l])])
        for i, part in enumerate(chunks(paper2, 30), 1):
            batches.append({"name": f"m-paper2-{abbr}-{i}", "type": t, "pool": "paper", "items": part})
    PLAN.write_text(json.dumps(batches, indent=1))
    print(f"{len(batches)} batches, {sum(len(b['items']) for b in batches)} items, "
          f"{sum(e['spr'] for b in batches for e in b['items'])} typed-answer")


def exists(e, t):
    return (M / "items" / t / f"{e['id']}.json").exists()


def main():
    cmd = sys.argv[1]
    if cmd == "plan":
        return plan()
    batches = json.loads(PLAN.read_text())
    if cmd == "show":
        b = next(x for x in batches if x["name"] == sys.argv[2])
        print(f"batch {b['name']}: type {b['type']} ({BP['types'][b['type']]['name']}), pool \"{b['pool']}\", "
              f"{len(b['items'])} items")
        for lvl in (1, 2, 3, 4):
            ids = [e for e in b["items"] if e["level"] == lvl]
            if ids:
                print(f"  level {lvl} ({BP['levels'][str(lvl)]['name']}): {ids[0]['id']} .. {ids[-1]['id']} ({len(ids)})")
        print("  typed-answer (answer_type \"spr\"): " + (", ".join(e["id"] for e in b["items"] if e["spr"]) or "none"))
        print("  all others: answer_type \"mcq\"")
        missing = [e["id"] for e in b["items"] if not exists(e, b["type"])]
        print(f"  already written: {len(b['items']) - len(missing)}; missing: {len(missing)}")
    elif cmd == "status":
        for b in batches:
            done = sum(exists(e, b["type"]) for e in b["items"])
            print(f"{b['name']:18s} {done:3d}/{len(b['items'])}")


if __name__ == "__main__":
    main()
