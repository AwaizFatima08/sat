#!/usr/bin/env python3
"""HTML review sheet for Math items (KaTeX for formulas, SVG for xy/geometry figures).

  python3 pipeline/review_sheet_math.py NAME ID_GLOB...
Writes pipeline/out/review-math-NAME.html.
"""
import fnmatch
import html
import json
import math
import re
import sys
from pathlib import Path

from sympy import lambdify, symbols
from sympy.parsing.sympy_parser import parse_expr

ROOT = Path(__file__).resolve().parent.parent
M = ROOT / "content" / "math"
BP = json.loads((M / "blueprint.json").read_text())
W, H, PAD = 360, 260, 30


def esc(s):
    return html.escape(str(s or ""), quote=False)


def svg_xy(f):
    x0, x1 = f["x"]
    y0, y1 = f["y"]
    sx = lambda x: PAD + (x - x0) / (x1 - x0) * (W - 2 * PAD)
    sy = lambda y: H - PAD - (y - y0) / (y1 - y0) * (H - 2 * PAD)
    out = [f'<svg width="{W}" height="{H}" style="background:#fff;border:1px solid #ccd">']
    for gx in range(math.ceil(x0), math.floor(x1) + 1):
        out.append(f'<line x1="{sx(gx)}" y1="{PAD}" x2="{sx(gx)}" y2="{H-PAD}" stroke="#eee"/>')
    for gy in range(math.ceil(y0), math.floor(y1) + 1):
        out.append(f'<line x1="{PAD}" y1="{sy(gy)}" x2="{W-PAD}" y2="{sy(gy)}" stroke="#eee"/>')
    if x0 <= 0 <= x1:
        out.append(f'<line x1="{sx(0)}" y1="{PAD}" x2="{sx(0)}" y2="{H-PAD}" stroke="#555"/>')
    if y0 <= 0 <= y1:
        out.append(f'<line x1="{PAD}" y1="{sy(0)}" x2="{W-PAD}" y2="{sy(0)}" stroke="#555"/>')
    x = symbols("x")
    for c in f.get("curves", []):
        try:
            fn = lambdify(x, parse_expr(c["expr"]), "math")
            pts, path = [], []
            for i in range(301):
                xv = x0 + (x1 - x0) * i / 300
                try:
                    yv = float(fn(xv))
                except Exception:
                    yv = None
                if yv is None or not (y0 - 1 <= yv <= y1 + 1):
                    if pts:
                        path.append(pts)
                    pts = []
                    continue
                pts.append(f"{sx(xv):.1f},{sy(yv):.1f}")
            if pts:
                path.append(pts)
            for p in path:
                out.append(f'<polyline points="{" ".join(p)}" fill="none" stroke="#2f5bea" stroke-width="2"/>')
        except Exception as e:
            out.append(f'<text x="40" y="40" fill="red">bad expr {esc(c["expr"])}: {esc(e)}</text>')
    for p in f.get("points", []):
        out.append(f'<circle cx="{sx(p["x"])}" cy="{sy(p["y"])}" r="4" fill="#1d2433"/>'
                   f'<text x="{sx(p["x"])+6}" y="{sy(p["y"])-6}" font-size="11">{esc(p.get("label", ""))}</text>')
    out.append("</svg>")
    return "".join(out)


def svg_geometry(f):
    pts = f.get("points", {})
    xs = [p[0] for p in pts.values()] + [c["center"][0] + s * c["radius"] for c in f.get("circles", []) for s in (-1, 1)]
    ys = [p[1] for p in pts.values()] + [c["center"][1] + s * c["radius"] for c in f.get("circles", []) for s in (-1, 1)]
    if not xs:
        return ""
    x0, x1, y0, y1 = min(xs) - 1, max(xs) + 1, min(ys) - 1, max(ys) + 1
    k = min((W - 2 * PAD) / (x1 - x0), (H - 2 * PAD) / (y1 - y0))
    sx = lambda x: PAD + (x - x0) * k
    sy = lambda y: H - PAD - (y - y0) * k
    out = [f'<svg width="{W}" height="{H}" style="background:#fff;border:1px solid #ccd">']
    for a, b in f.get("segments", []):
        out.append(f'<line x1="{sx(pts[a][0])}" y1="{sy(pts[a][1])}" x2="{sx(pts[b][0])}" y2="{sy(pts[b][1])}" '
                   f'stroke="#1d2433" stroke-width="2"/>')
    for c in f.get("circles", []):
        cx, cy = c["center"] if isinstance(c["center"], list) else pts[c["center"]]
        out.append(f'<circle cx="{sx(cx)}" cy="{sy(cy)}" r="{c["radius"]*k}" fill="none" stroke="#1d2433" stroke-width="2"/>')
    for n, (x, y) in pts.items():
        out.append(f'<circle cx="{sx(x)}" cy="{sy(y)}" r="3"/><text x="{sx(x)+5}" y="{sy(y)-5}" font-size="12">{esc(n)}</text>')
    for lab in f.get("labels", []):
        out.append(f'<text x="{sx(lab["at"][0])}" y="{sy(lab["at"][1])}" font-size="12" fill="#a35d00">{esc(lab["text"])}</text>')
    out.append("</svg>")
    if f.get("not_to_scale"):
        out.append("<div><i>Not drawn to scale</i></div>")
    return "".join(out)


def figure_html(f):
    if not f:
        return ""
    if f["kind"] == "xy":
        return svg_xy(f)
    if f["kind"] == "geometry":
        return svg_geometry(f)
    return f'<pre class=fig>{esc(json.dumps(f, indent=1))}</pre>'


def card(it):
    checks = it["provenance"].get("checks") or []
    flag = any(c.get("result") != "agree" for c in checks)
    t = BP["types"][it["type"]]["name"]
    lvl = BP["levels"][str(it["level"])]["name"]
    h = [f"<div class='item{' flag' if flag else ''}'><h3>{it['id']} · {t} · {lvl} · {it['answer_type']} · "
         f"{'context' if it['in_context'] else 'pure'} · {it['context']} · {it['provenance']['status']}</h3>",
         f"<p>{esc(it['stem'])}</p>", figure_html(it.get("figure"))]
    if it["answer_type"] == "mcq":
        h.append("<ol type=A>")
        for L in "ABCD":
            key = L == it["answer"]
            trap = "" if key else f" <span class=trap>[{it['traps'].get(L)}]</span>"
            h.append(f"<li class='{'key' if key else ''}'>{esc(it['choices'][L])}{trap}"
                     f"<div class=ex>{esc(it['explanation'][L])}</div></li>")
        h.append("</ol>")
    else:
        h.append(f"<p class=key>Accepted: {esc(', '.join(it['spr_answers']))}</p>")
    h.append("<div class=sol><b>Solution</b><ol>" + "".join(f"<li>{esc(s)}</li>" for s in it["solution"]) + "</ol></div>")
    h.append(f"<details><summary>verify</summary><pre>{esc(it['verify'])}</pre></details>")
    chk = "; ".join(f"{c.get('by')}: {c.get('answer')} ({c.get('result')})" for c in checks) or "not checked"
    h.append(f"<p class=meta>checks: {esc(chk)}</p></div>")
    return "\n".join(h)


CSS = """body{font:15px/1.5 system-ui,sans-serif;max-width:880px;margin:24px auto;padding:0 16px;color:#1d2433}
.item{border:1px solid #d6dae3;border-radius:10px;padding:14px 18px;margin:18px 0}.item.flag{border-color:#d9534f;background:#fff6f5}
h3{font-size:13px;color:#5a6478;margin:0 0 8px}li{margin:6px 0}li.key,p.key{background:#e8f5e9;border-radius:6px;padding:2px 6px}
.ex{font-size:13px;color:#5a6478}.trap{font-size:12px;color:#a35d00}.sol{background:#f4f6fa;padding:8px;border-radius:6px}
.meta{font-size:12px;color:#5a6478}pre{font-size:12px;background:#f7f7f9;padding:6px;overflow:auto}"""
KATEX = ('<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">'
         '<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>'
         '<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js" '
         'onload="renderMathInElement(document.body,{delimiters:[{left:\'\\\\(\',right:\'\\\\)\',display:false},'
         '{left:\'\\\\[\',right:\'\\\\]\',display:true}]})"></script>')


def main():
    name, globs = sys.argv[1], sys.argv[2:] or ["*"]
    items = [json.loads(p.read_text()) for p in sorted((M / "items").glob("*/*.json"))]
    pick = [i for i in items if any(fnmatch.fnmatch(i["id"], g) for g in globs)]
    order = {t: n for n, t in enumerate(BP["type_order"])}
    pick.sort(key=lambda i: (order[i["type"]], i["level"], i["id"]))
    out = ROOT / "pipeline" / "out"
    out.mkdir(parents=True, exist_ok=True)
    f = out / f"review-math-{re.sub(r'[^a-z0-9_-]', '', name.lower())}.html"
    f.write_text(f"<!doctype html><meta charset=utf-8><title>Math review {esc(name)}</title>{KATEX}<style>{CSS}</style>"
                 f"<h1>Math review: {esc(name)}</h1><p>{len(pick)} items. Key in green, trap type in brackets, "
                 f"verify script under each item.</p>" + "\n".join(card(i) for i in pick))
    print(f)


if __name__ == "__main__":
    main()
