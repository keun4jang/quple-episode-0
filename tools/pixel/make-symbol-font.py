#!/usr/bin/env python3
"""기본 폰트(Jua·PoorStory)에 없는 기호만 담은 작은 폰트를 직접 그린다.

    .sdenv/Scripts/python.exe tools/pixel/make-symbol-font.py   (fonttools 필요)

→ assets/fonts/QuokkaSymbols.ttf. 테마(`quple_bold.tres`)의 대체 폰트 맨 뒤에
붙어 있어서, 글 사이에 섞인 ★ ✦ ▶ ✓ ● 가 폰에서도 네모 상자 없이 뜬다.
모양은 전부 이 파일의 도형이다 - 다른 폰트에서 베껴 온 것이 없다.
"""

import math
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

UPM = 1000
ASC, DESC = 900, -250
MID = 330  # 한글 글자 몸통의 가운데 높이쯤


def poly(pts):
    """점 목록 → 닫힌 윤곽. TrueType 은 바깥 윤곽이 시계 방향이어야 한다."""
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts)))
    if area > 0:  # 반시계 → 뒤집기
        pts = pts[::-1]
    return [(round(x), round(y)) for x, y in pts]


def star(n, r_out, r_in, cx=500, cy=MID, rot=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return [poly(pts)]


def circle(r, cx=500, cy=MID, seg=32):
    return [poly([(cx + math.cos(i * math.tau / seg) * r, cy + math.sin(i * math.tau / seg) * r)
                  for i in range(seg)])]


def triangle():
    return [poly([(170, MID - 330), (850, MID), (170, MID + 330)])]


def check():
    # 굵은 체크 한 획 (왼쪽 짧은 획 + 오른쪽 긴 획을 한 윤곽으로)
    return [poly([(120, MID + 10), (230, MID + 120), (400, MID - 50), (790, MID + 380),
                  (900, MID + 270), (400, MID - 270)])]


GLYPHS = {
    0x2605: ("star", star(5, 400, 165)),       # ★
    0x2726: ("sparkle", star(4, 420, 120)),    # ✦
    0x25B6: ("play", triangle()),              # ▶
    0x2713: ("check", check()),                # ✓
    0x25CF: ("dot", circle(300)),              # ●
}


def main():
    order = [".notdef", "space"] + [g[0] for g in GLYPHS.values()]
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    cmap = {0x20: "space"}
    cmap.update({cp: g[0] for cp, g in GLYPHS.items()})
    fb.setupCharacterMap(cmap)
    glyf, metrics = {}, {}
    for name in order:
        pen = TTGlyphPen(None)
        contours = []
        if name == ".notdef":
            contours = [poly([(100, 0), (100, 700), (600, 700), (600, 0)])]
        for cp, (gn, cs) in GLYPHS.items():
            if gn == name:
                contours = cs
        for c in contours:
            pen.moveTo(c[0])
            for p in c[1:]:
                pen.lineTo(p)
            pen.closePath()
        glyf[name] = pen.glyph()
        metrics[name] = (UPM if name not in (".notdef", "space") else 700 if name == ".notdef" else 300, 0)
    fb.setupGlyf(glyf)
    for name in order:  # 왼쪽 여백 = 윤곽의 가장 왼쪽 x
        g = glyf[name]
        g.recalcBounds(fb.font["glyf"])
        metrics[name] = (metrics[name][0], getattr(g, "xMin", 0))
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
    fb.setupNameTable({"familyName": "QuokkaSymbols", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, usWinAscent=ASC, usWinDescent=-DESC)
    fb.setupPost()
    out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "QuokkaSymbols.ttf")
    fb.save(os.path.normpath(out))
    print("saved", os.path.normpath(out))


if __name__ == "__main__":
    main()
