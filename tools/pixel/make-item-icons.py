#!/usr/bin/env python3
"""배낭에 들어갈 물건 그림을 찍는다.

16x16 안쪽에서 **실루엣으로 구분되게** 그린다. 잔무늬를 넣으면 배낭
격자에서 서로 구별이 안 된다 — 색 네댓과 1px 외곽선이면 충분하다.
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
S = 16


def hx(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def save(name, px):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.putdata([px.get((x, y), (0, 0, 0, 0))
                 for y in range(S) for x in range(S)])
    img.save(os.path.join(OUT, name + ".png"))
    print("만듦:", name)


def disc(px, cx, cy, r, col, line):
    """외곽선 있는 동그라미."""
    for y in range(S):
        for x in range(S):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r - 1.0:
                px[(x, y)] = col
            elif d <= r:
                px[(x, y)] = line


# ── 유리구슬 — 윤슬의 저녁 바다를 닮은 구슬 ──────────────────────────
px = {}
# 작은 원은 계산식으로 그리면 각져 보인다. 11px 원을 줄별로 적어 둔다.
ROWS = [(5, 10), (3, 12), (2, 13), (2, 13), (1, 14),
        (1, 14), (1, 14), (2, 13), (2, 13), (3, 12), (5, 10)]
for i, (a, b) in enumerate(ROWS):
    y = 3 + i
    for x in range(a, b):
        px[(x, y)] = hx("#6FA8B8")
    px[(a - 1, y)] = hx("#33555F")
    px[(b, y)] = hx("#33555F")
for x in range(5, 10):
    px[(x, 2)] = hx("#33555F")
    px[(x, 14)] = hx("#33555F")
# 아래쪽을 조금 짙게 — 유리가 두께를 갖는다
for y in range(9, 13):
    for x in range(2, 14):
        if px.get((x, y)) == hx("#6FA8B8"):
            px[(x, y)] = hx("#4E8492")
# 윗면 빛 한 점
px[(5, 5)] = hx("#EAF6F7")
px[(6, 5)] = hx("#C7E6EA")
px[(5, 6)] = hx("#C7E6EA")
save("i-marble", px)

# ── 찻잔 — 가게에서 마시는 따뜻한 차 ─────────────────────────────────
px = {}
body = hx("#F2E7D2")
line = hx("#7A6552")
tea = hx("#9C6B3E")
# 잔
for y in range(7, 13):
    w = 5 if y < 12 else 4
    for x in range(8 - w, 8 + w):
        px[(x, y)] = body
for y in range(7, 13):
    w = 5 if y < 12 else 4
    px[(8 - w, y)] = line
    px[(8 + w - 1, y)] = line
for x in range(4, 12):
    px[(x, 13)] = line
# 찻물
for x in range(4, 12):
    px[(x, 7)] = tea
px[(3, 7)] = line
px[(12, 7)] = line
# 손잡이
for y in (9, 10):
    px[(13, y)] = line
px[(12, 8)] = line
px[(12, 11)] = line
# 김 두 줄
px[(6, 4)] = hx("#D9CBB6")
px[(6, 3)] = hx("#D9CBB6")
px[(9, 4)] = hx("#D9CBB6")
px[(9, 2)] = hx("#D9CBB6")
save("i-tea", px)
