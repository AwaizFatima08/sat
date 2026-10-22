#!/usr/bin/env python3
"""Draws the Module Up launcher icon in code (flat shapes, no AI): solid accent square, white upward
chevron above a short bar ("module up"). Writes Android mipmaps and a 512 px Play Store icon.

  python3 tools/make_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ACCENT = (47, 91, 234)
WHITE = (255, 255, 255)


def draw(size, rounded):
    s = 4 * size  # supersample for smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=ACCENT)
    else:
        d.rectangle([0, 0, s, s], fill=ACCENT)
    w = int(s * 0.11)
    cx, top = s / 2, s * 0.24
    d.line([(s * 0.26, s * 0.56), (cx, top), (s * 0.74, s * 0.56)], fill=WHITE, width=w, joint="curve")
    for x, y in [(s * 0.26, s * 0.56), (cx, top), (s * 0.74, s * 0.56)]:
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)
    d.rounded_rectangle([s * 0.30, s * 0.68, s * 0.70, s * 0.68 + w], radius=w // 2, fill=WHITE)
    return img.resize((size, size), Image.LANCZOS)


def main():
    res = ROOT / "app/android/app/src/main/res"
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        draw(px, rounded=True).save(res / f"mipmap-{folder}" / "ic_launcher.png")
    store = ROOT / "store"
    store.mkdir(exist_ok=True)
    draw(512, rounded=False).convert("RGB").save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()
