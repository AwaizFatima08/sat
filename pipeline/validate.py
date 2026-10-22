#!/usr/bin/env python3
"""Check every Reading and Writing item, form, lesson and reference file.

Usage:
  python3 pipeline/validate.py                 # everything
  python3 pipeline/validate.py --items PATH... # only these item files (plus pool-wide duplicate checks)
  python3 pipeline/validate.py --quiet         # summary only

Exit code 1 if any ERROR. WARN lines are for a human to look at.
"""
import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RW = ROOT / "content" / "rw"
BP = json.loads((RW / "blueprint.json").read_text())

BLANK = "______"
LETTERS = ["A", "B", "C", "D"]
STATUSES = {"draft", "checked", "approved", "retired"}
POOLS = {"paper", "drill", "tryit"}
CONTEXTS = {"global", "south_asia"}
ID_RE = re.compile(r"^rw-([a-z]{3})-(\d{4})$")
ABBR_TO_TYPE = {v["abbr"]: k for k, v in BP["types"].items()}

# British spellings that must not appear in test content (US conventions). Word-boundary matched.
UK_WORDS = """colour colours coloured favour favourite behaviour behaviours honour honoured labour neighbour
neighbours harbour humour rumour vapour vigour centre centres metre metres litre litres theatre fibre
organise organised organising organisation realise realised recognise recognised analyse analysed
criticise apologise emphasise summarise characterise specialise minimise maximise utilise mobilise
programme programmes travelled travelling traveller cancelled modelled labelled fuelled levelled signalled
defence offence licence grey catalogue judgement ageing aluminium jewellery
manoeuvre oestrogen paediatric anaesthetic encyclopaedia mould smoulder plough sceptical whilst amongst
""".split()
UK_RE = re.compile(r"\b(" + "|".join(UK_WORDS) + r")(?:s|ed|ing|ful|less|ly|ist|ists)?\b", re.I)

errors, warns = [], []


def err(where, msg):
    errors.append(f"ERROR {where}: {msg}")


def warn(where, msg):
    warns.append(f"WARN  {where}: {msg}")


def words(text):
    return len(re.findall(r"[A-Za-z0-9’'\-]+", (text or "").replace(BLANK, " ")))


def stem_ok(stem, patterns):
    for p in patterns:
        rx = "^" + re.escape(p) + "$"
        rx = re.sub(r"\\\{[^}]*\\\}", ".+", rx)
        if re.match(rx, stem.strip()):
            return True
    return False


def check_data(where, data):
    if not isinstance(data, dict) or data.get("kind") not in {"table", "bar", "line"}:
        return err(where, "data.kind must be table, bar or line")
    if not data.get("title"):
        err(where, "data.title missing")
    if data["kind"] == "table":
        cols, rows = data.get("columns"), data.get("rows")
        if not cols or not rows:
            return err(where, "table needs columns and rows")
        for r in rows:
            if len(r) != len(cols):
                err(where, f"table row has {len(r)} cells, expected {len(cols)}")
    else:
        if not data.get("x_label") or not data.get("y_label"):
            err(where, "graph needs x_label and y_label")
        series = data.get("series") or []
        if not series:
            return err(where, "graph needs series")
        for s in series:
            if not s.get("name") or not s.get("points"):
                err(where, "each series needs name and points")
            for pt in s.get("points", []):
                if not (isinstance(pt, list) and len(pt) == 2 and isinstance(pt[1], (int, float))):
                    err(where, f"bad point {pt}: use [x_label, number]")


def check_item(path, item):
    w = path.relative_to(ROOT).as_posix()
    req = ["id", "section", "domain", "type", "level", "b", "subject", "context", "pool", "stem", "choices",
           "answer", "explanation", "traps", "source", "provenance"]
    for k in req:
        if k not in item:
            err(w, f"missing field '{k}'")
    if any(k not in item for k in req):
        return
    m = ID_RE.match(item["id"])
    if not m:
        return err(w, f"bad id {item['id']}")
    if path.stem != item["id"]:
        err(w, "file name must equal id")
    t = item["type"]
    if t not in BP["types"]:
        return err(w, f"unknown type {t}")
    spec = BP["types"][t]
    if ABBR_TO_TYPE.get(m.group(1)) != t:
        err(w, f"id prefix {m.group(1)} does not match type {t}")
    if path.parent.name != t:
        err(w, f"file must live in items/{t}/")
    if item["section"] != "rw":
        err(w, "section must be rw")
    if item["domain"] != spec["domain"]:
        err(w, f"domain must be {spec['domain']}")
    if str(item["level"]) not in BP["levels"]:
        err(w, "level must be 1-4")
    elif abs(float(item["b"]) - BP["levels"][str(item["level"])]["b"]) > 0.75:
        warn(w, f"b={item['b']} far from level {item['level']} default")
    if item["subject"] not in BP["subjects"]:
        err(w, f"subject must be one of {list(BP['subjects'])}")
    if item["context"] not in CONTEXTS:
        err(w, "context must be global or south_asia")
    if item["pool"] not in POOLS:
        err(w, "pool must be paper, drill or tryit")

    needs = spec["needs"]
    passage = item.get("passage") or ""
    text_all = passage + " " + (item.get("passage_b") or "")
    if "passage" in needs:
        lo, hi = spec["words"]
        n = words(passage) + words(item.get("passage_b"))
        if not passage:
            err(w, "passage missing")
        elif n < lo or n > hi:
            (err if n < lo * 0.8 or n > hi * 1.15 else warn)(w, f"passage length {n} words, expected {lo}-{hi}")
    if "passage_b" in needs and not item.get("passage_b"):
        err(w, "cross_text needs passage_b")
    if "passage_b" not in needs and item.get("passage_b"):
        err(w, "passage_b only for cross_text")
    if "blank" in needs and passage.count(BLANK) != 1:
        err(w, f"passage must contain exactly one blank {BLANK}")
    if t == "words_in_context" and passage.count(BLANK) > 1:
        err(w, "at most one blank")
    if "notes" in needs:
        notes = item.get("notes") or []
        if not (3 <= len(notes) <= 6):
            err(w, "rhetorical_synthesis needs 3-6 notes")
        text_all += " " + " ".join(notes)
    elif item.get("notes"):
        err(w, "notes only for rhetorical_synthesis")
    if "data" in needs:
        check_data(w, item.get("data"))
    elif item.get("data"):
        err(w, "data only for coe_quantitative")
    if "<u>" in passage and passage.count("<u>") != passage.count("</u>"):
        err(w, "unbalanced <u> underline tags")
    if "underlined" in item["stem"] and "<u>" not in passage:
        err(w, "stem mentions an underlined sentence but the passage has no <u>")

    if not stem_ok(item["stem"], spec["stems"]):
        warn(w, f"stem not in the standard set: {item['stem'][:70]}")

    ch = item["choices"]
    if sorted(ch) != LETTERS:
        err(w, "choices must be exactly A-D")
    else:
        vals = [str(ch[k]).strip() for k in LETTERS]
        if any(not v for v in vals):
            err(w, "empty choice")
        if len(set(v.lower() for v in vals)) != 4:
            err(w, "choices are not distinct")
        text_all += " " + " ".join(vals)
    if item["answer"] not in LETTERS:
        err(w, "answer must be A-D")

    ex = item["explanation"]
    for k in ["why"] + LETTERS:
        if not (ex.get(k) or "").strip():
            err(w, f"explanation.{k} missing")
    if len((ex.get("why") or "").split()) < 12:
        warn(w, "explanation.why is very short")

    traps = item["traps"]
    wrong = set(LETTERS) - {item["answer"]}
    if set(traps) != wrong:
        err(w, f"traps must cover exactly the wrong letters {sorted(wrong)}")
    for k, v in traps.items():
        if v not in BP["traps"]:
            err(w, f"trap {k}={v} not in blueprint traps")

    if "grammar" in needs:
        if item.get("grammar") not in BP["grammar"]:
            err(w, f"grammar must be one of {list(BP['grammar'])}")
    elif item.get("grammar"):
        err(w, "grammar only for conventions items")

    src = item["source"]
    if src.get("kind") == "public_domain":
        for k in ["author", "work", "year", "url"]:
            if not src.get(k):
                err(w, f"public_domain source needs {k}")
        if src.get("year") and int(src["year"]) >= 1930:
            err(w, "public-domain excerpts must be published before 1930")
    elif src.get("kind") != "original":
        err(w, "source.kind must be original or public_domain")

    prov = item["provenance"]
    if prov.get("status") not in STATUSES:
        err(w, f"provenance.status must be one of {sorted(STATUSES)}")
    if not prov.get("written_by") or not prov.get("written"):
        err(w, "provenance needs written_by and written")

    uk = sorted(set(x.lower() for x in UK_RE.findall(text_all)))
    if uk and src.get("kind") != "public_domain":
        err(w, f"British spelling in test content: {', '.join(uk)}")
    for bad in ["College Board", "Khan Academy", "Bluebook"]:
        if bad.lower() in text_all.lower():
            err(w, f"mentions {bad}")


def shingles(text, n=5):
    toks = re.findall(r"[a-z0-9]+", text.lower())
    return {" ".join(toks[i:i + n]) for i in range(max(0, len(toks) - n + 1))}


def check_duplicates(items):
    sh = {i["id"]: shingles((i.get("passage") or "") + " " + " ".join(i.get("notes") or [])) for i in items}
    ids = [i for i in sh if len(sh[i]) > 3]
    for a_i, a in enumerate(ids):
        for b in ids[a_i + 1:]:
            A, B = sh[a], sh[b]
            j = len(A & B) / len(A | B)
            if j > 0.5:
                err(f"{a} / {b}", f"near-duplicate passages (overlap {j:.0%})")
            elif j > 0.3:
                warn(f"{a} / {b}", f"similar passages (overlap {j:.0%})")


def check_forms(items_by_id):
    seen = {}
    mb = BP["module_blueprint"]
    for fp in sorted((RW / "forms").glob("*.json")):
        w = fp.relative_to(ROOT).as_posix()
        f = json.loads(fp.read_text())
        mods = f.get("modules", {})
        if set(mods) != {"m1", "m2_easy", "m2_hard"}:
            err(w, "modules must be m1, m2_easy, m2_hard")
            continue
        if not isinstance(f.get("route_threshold"), int):
            err(w, "route_threshold (module 1 raw correct needed for the harder module) missing")
        for mk, ids in mods.items():
            if len(ids) != BP["module_items"]:
                err(w, f"{mk} has {len(ids)} items, expected {BP['module_items']}")
            types, levels = Counter(), Counter()
            last = -1
            for iid in ids:
                it = items_by_id.get(iid)
                if not it:
                    err(w, f"{mk}: unknown item {iid}")
                    continue
                if it["pool"] != "paper":
                    err(w, f"{mk}: {iid} is pool {it['pool']}, must be paper")
                if iid in seen:
                    err(w, f"{iid} used twice ({seen[iid]} and {fp.stem}/{mk})")
                seen[iid] = f"{fp.stem}/{mk}"
                types[it["type"]] += 1
                levels[str(it["level"])] += 1
                pos = BP["type_order"].index(it["type"])
                if pos < last:
                    err(w, f"{mk}: {iid} out of type order")
                last = pos
            if dict(types) != {k: v for k, v in mb["types"].items() if v}:
                err(w, f"{mk} type counts {dict(types)} differ from blueprint")
            want = {k: v for k, v in mb["levels"][mk].items() if v}
            if dict(levels) != want:
                warn(w, f"{mk} level counts {dict(levels)} differ from blueprint {want}")
    return seen


def check_lessons():
    for fp in sorted((RW / "lessons").glob("*.json")):
        w = fp.relative_to(ROOT).as_posix()
        d = json.loads(fp.read_text())
        if d.get("type") not in BP["types"]:
            err(w, "lesson type unknown")
            continue
        for k in ["title", "what_is_tested", "how_to_spot", "method", "cards"]:
            if not d.get(k):
                err(w, f"lesson missing {k}")
        cards = d.get("cards", [])
        if sorted(str(c.get("level")) for c in cards) != ["1", "2", "3", "4"]:
            err(w, "lesson needs one strategy card per level 1-4")
        for c in cards:
            if len(c.get("steps", [])) != 4:
                err(w, f"card level {c.get('level')} needs 4 steps")
            if not c.get("worked_example"):
                err(w, f"card level {c.get('level')} needs a worked_example")
            if len(c.get("tryit", [])) != 2:
                err(w, f"card level {c.get('level')} needs 2 tryit item ids")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", nargs="*")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    all_paths = sorted((RW / "items").glob("*/*.json"))
    items, by_id = [], {}
    for p in all_paths:
        try:
            it = json.loads(p.read_text())
        except json.JSONDecodeError as e:
            err(p.relative_to(ROOT).as_posix(), f"invalid JSON: {e}")
            continue
        if it.get("id") in by_id:
            err(p.name, f"duplicate id {it.get('id')}")
        by_id[it.get("id")] = it
        items.append((p, it))

    targets = {Path(x).resolve() for x in a.items} if a.items else None
    for p, it in items:
        if targets is None or p.resolve() in targets:
            check_item(p, it)
    live = [it for _, it in items if it.get("provenance", {}).get("status") != "retired"]
    check_duplicates(live)
    in_forms = check_forms(by_id)
    check_lessons()

    # Answer-key balance per pool
    for pool in POOLS:
        keys = Counter(it["answer"] for it in live if it.get("pool") == pool and it.get("answer") in LETTERS)
        n = sum(keys.values())
        if n >= 40 and max(keys.values()) > n * 0.35:
            warn(f"pool {pool}", f"answer keys unbalanced {dict(keys)}")
    unused = [it["id"] for it in live if it.get("pool") == "paper" and it["id"] not in in_forms]
    if unused and any((RW / "forms").glob("*.json")):
        warn("forms", f"{len(unused)} paper items not yet placed in a form")

    if not a.quiet:
        for line in errors + warns:
            print(line)
    counts = Counter((it.get("type"), it.get("pool")) for it in live)
    status = Counter(it.get("provenance", {}).get("status") for it in live)
    print(f"\n{len(live)} items ({dict(status)}); {len(in_forms)} placed in forms; "
          f"{len(errors)} errors, {len(warns)} warnings")
    by_type = defaultdict(dict)
    for (t, pool), n in counts.items():
        by_type[t][pool] = n
    for t in BP["type_order"]:
        if t in by_type:
            print(f"  {t:22s} {by_type[t]}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
