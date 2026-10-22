#!/usr/bin/env python3
"""Build an HTML review sheet for a batch of items.

Usage:
  python3 pipeline/review_sheet.py NAME ID_OR_GLOB...   e.g.  pilot 'rw-*-00[0-9][0-9]'
  python3 pipeline/review_sheet.py NAME --status draft  (every item with that status)
Writes pipeline/out/review-NAME.html.
"""
import argparse
import fnmatch
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RW = ROOT / "content" / "rw"
BP = json.loads((RW / "blueprint.json").read_text())
LEVEL = {k: v["name"] for k, v in BP["levels"].items()}


def esc(s):
    s = html.escape(s or "")
    s = s.replace("&lt;u&gt;", "<u>").replace("&lt;/u&gt;", "</u>")
    return s.replace("______", "<span class=blank>______</span>")


def data_html(d):
    if not d:
        return ""
    if d["kind"] == "table":
        head = "".join(f"<th>{esc(str(c))}</th>" for c in d["columns"])
        rows = "".join("<tr>" + "".join(f"<td>{esc(str(c))}</td>" for c in r) + "</tr>" for r in d["rows"])
        return f"<p class=dt>{esc(d['title'])}</p><table class=data><tr>{head}</tr>{rows}</table>"
    rows = "".join(
        f"<tr><td>{esc(s['name'])}</td>" + "".join(f"<td>{esc(str(x))}: {y}</td>" for x, y in s["points"]) + "</tr>"
        for s in d["series"])
    return (f"<p class=dt>{esc(d['title'])} ({d['kind']} graph; x: {esc(d['x_label'])}, y: {esc(d['y_label'])})</p>"
            f"<table class=data>{rows}</table>")


def card(it):
    t = BP["types"][it["type"]]
    checks = it["provenance"].get("checks") or []
    chk = "; ".join(f"{c.get('by')}: {c.get('answer')} ({c.get('result')})" for c in checks) or "not checked"
    flag = any(c.get("result") != "agree" for c in checks)
    parts = [f"<div class='item{' flag' if flag else ''}' id='{it['id']}'>",
             f"<h3>{it['id']} · {t['name']} · {LEVEL[str(it['level'])]} · {it['subject']} · {it['context']} · "
             f"pool {it['pool']} · {it['provenance']['status']}</h3>"]
    if it.get("passage_b"):
        parts.append(f"<p><b>Text 1</b><br>{esc(it['passage'])}</p><p><b>Text 2</b><br>{esc(it['passage_b'])}</p>")
    elif it.get("passage"):
        parts.append(f"<p class=passage>{esc(it['passage'])}</p>")
    if it.get("notes"):
        parts.append("<p><i>While researching a topic, a student has taken the following notes:</i></p><ul>" +
                     "".join(f"<li>{esc(n)}</li>" for n in it["notes"]) + "</ul>")
    parts.append(data_html(it.get("data")))
    parts.append(f"<p class=stem>{esc(it['stem'])}</p><ol type=A>")
    for L in "ABCD":
        key = L == it["answer"]
        trap = "" if key else f" <span class=trap>[{it['traps'].get(L, '?')}]</span>"
        parts.append(f"<li class='{'key' if key else ''}'>{esc(it['choices'][L])}{trap}"
                     f"<div class=ex>{esc(it['explanation'][L])}</div></li>")
    parts.append(f"</ol><p class=why><b>Why:</b> {esc(it['explanation']['why'])}</p>")
    extra = []
    if it.get("grammar"):
        extra.append("grammar: " + it["grammar"])
    if it["source"]["kind"] != "original":
        s = it["source"]
        extra.append(f"source: {s['author']}, <i>{esc(s['work'])}</i> ({s['year']})")
    extra.append("checks: " + esc(chk))
    parts.append(f"<p class=meta>{' · '.join(extra)}</p></div>")
    return "\n".join(parts)


CSS = """body{font:15px/1.5 system-ui,sans-serif;max-width:860px;margin:24px auto;padding:0 16px;color:#1d2433}
h1{font-size:22px}.item{border:1px solid #d6dae3;border-radius:10px;padding:14px 18px;margin:18px 0}
.item.flag{border-color:#d9534f;background:#fff6f5}h3{font-size:13px;color:#5a6478;margin:0 0 8px}
.passage{font-family:Georgia,serif}.blank{letter-spacing:1px}.stem{font-weight:600}
li{margin:6px 0}li.key{background:#e8f5e9;border-radius:6px}.ex{font-size:13px;color:#5a6478}
.trap{font-size:12px;color:#a35d00}.why{background:#f4f6fa;padding:8px;border-radius:6px}.meta{font-size:12px;color:#5a6478}
table.data{border-collapse:collapse;font-size:13px}table.data td,table.data th{border:1px solid #ccd;padding:3px 8px}
.dt{font-weight:600;font-size:13px;margin-bottom:2px}"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("patterns", nargs="*")
    ap.add_argument("--status")
    a = ap.parse_args()
    items = [json.loads(p.read_text()) for p in sorted((RW / "items").glob("*/*.json"))]
    pick = []
    for it in items:
        if a.status and it["provenance"]["status"] != a.status:
            continue
        if a.patterns and not any(fnmatch.fnmatch(it["id"], p) for p in a.patterns):
            continue
        pick.append(it)
    order = {t: i for i, t in enumerate(BP["type_order"])}
    pick.sort(key=lambda i: (order[i["type"]], i["level"], i["id"]))
    flagged = sum(1 for i in pick if any(c.get("result") != "agree" for c in i["provenance"].get("checks") or []))
    out = ROOT / "pipeline" / "out"
    out.mkdir(parents=True, exist_ok=True)
    f = out / f"review-{re.sub(r'[^a-z0-9_-]', '', a.name.lower())}.html"
    f.write_text(f"<!doctype html><meta charset=utf-8><title>Review {html.escape(a.name)}</title><style>{CSS}</style>"
                 f"<h1>Review sheet: {html.escape(a.name)}</h1><p>{len(pick)} items, {flagged} flagged by the "
                 f"blind-solve check (red). Key in green; trap type in brackets.</p>" +
                 "\n".join(card(i) for i in pick))
    print(f)


if __name__ == "__main__":
    main()
