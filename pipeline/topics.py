#!/usr/bin/env python3
"""List every item's topic in one line (id, type, first words) so writers can avoid repeats.

  python3 pipeline/topics.py            # all items
  python3 pipeline/topics.py TYPE       # one type
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
want = sys.argv[1] if len(sys.argv) > 1 else None
for p in sorted((ROOT / "content" / "rw" / "items").glob("*/*.json")):
    it = json.loads(p.read_text())
    if want and it["type"] != want:
        continue
    text = it.get("passage") or " ".join(it.get("notes") or [])
    print(f"{it['id']}  {' '.join(text.split()[:14])}")
