#!/usr/bin/env python3
"""Build the app's content pack from content/rw.

  python3 pipeline/build_packs.py                 # checked + approved items
  python3 pipeline/build_packs.py --include-draft # development builds

Writes app/assets/data/rw_bank.json (items without provenance, forms, lessons, reference guides,
blueprint) and app/assets/data/manifest.json. Run validate.py first.
"""
import argparse
import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RW = ROOT / "content" / "rw"
OUT = ROOT / "app" / "assets" / "data"
DROP = {"provenance", "context", "section"}


def load_dir(d):
    return [json.loads(p.read_text()) for p in sorted(d.glob("*.json"))] if d.exists() else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--include-draft", action="store_true")
    a = ap.parse_args()
    ok = {"checked", "approved"} | ({"draft"} if a.include_draft else set())

    bp = json.loads((RW / "blueprint.json").read_text())
    items = []
    for p in sorted((RW / "items").glob("*/*.json")):
        it = json.loads(p.read_text())
        if it["provenance"]["status"] in ok:
            items.append({k: v for k, v in it.items() if k not in DROP and v is not None})
    ids = {i["id"] for i in items}

    forms = []
    for f in load_dir(RW / "forms"):
        all_ids = [i for m in f["modules"].values() for i in m]
        if all(i in ids for i in all_ids):
            forms.append(f)
        else:
            print(f"skip {f['id']}: {sum(i not in ids for i in all_ids)} items not releasable")
    lessons = load_dir(RW / "lessons")
    reference = {p.stem: json.loads(p.read_text()) for p in sorted((RW / "reference").glob("*.json"))}

    blueprint = {k: bp[k] for k in ["section", "title", "module_minutes", "module_items", "domains", "type_order",
                                     "levels", "subjects", "traps", "grammar"]}
    blueprint["types"] = {k: {"name": v["name"], "domain": v["domain"], "abbr": v["abbr"]}
                          for k, v in bp["types"].items()}
    blueprint["module_blueprint"] = bp["module_blueprint"]

    release = json.loads((ROOT / "pipeline" / "release.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    bank = {"version": release["version"], "blueprint": blueprint, "items": items, "forms": forms,
            "lessons": lessons, "reference": reference}
    (OUT / "rw_bank.json").write_text(json.dumps(bank, ensure_ascii=False, separators=(",", ":")))
    manifest = {"schema": 1, "version": release["version"], "built": date.today().isoformat(),
                "items": len(items), "forms": len(forms), "lessons": len(lessons),
                "reference": sorted(reference)}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    size = (OUT / "rw_bank.json").stat().st_size
    print(f"rw_bank.json: {len(items)} items, {len(forms)} forms, {len(lessons)} lessons, "
          f"{len(reference)} reference guides, {size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
