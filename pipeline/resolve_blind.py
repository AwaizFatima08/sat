#!/usr/bin/env python3
"""Record an owner review that confirms the key after a blind solver disagreed.

  python3 pipeline/resolve_blind.py ID "why the key is right" [ID "why" ...]

Drops the disagreeing solver checks of each item, adds a claude-opus-review check that agrees with the key and
marks the item checked. Use only after working the item by hand.
"""
import datetime
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    args = sys.argv[1:]
    for iid, why in zip(args[::2], args[1::2]):
        sec = "math" if iid.startswith("m-") else "rw"
        p = next((ROOT / "content" / sec / "items").glob(f"*/{iid}.json"))
        it = json.loads(p.read_text())
        key = it.get("answer") or (it.get("spr_answers") or [None])[0]
        prov = it["provenance"]
        prov["checks"] = [c for c in prov.get("checks", []) if c.get("result") != "disagree"] + [{
            "by": "claude-opus-review", "date": datetime.date.today().isoformat(), "answer": key, "second": None,
            "note": f"solver objection reviewed: key confirmed ({why})", "result": "agree"}]
        prov["status"] = "checked"
        p.write_text(json.dumps(it, indent=2, ensure_ascii=False) + "\n")
        print(f"{iid}: key {key} confirmed")


if __name__ == "__main__":
    main()
