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




# ── 미역 — 갯벌에서 걷어 온다. 물결치는 띠 하나가 위아래로 흔들린다.
px = {}
DK = hx("#25462F")
LT = hx("#4E8C4A")
HI = hx("#7BB86E")
COLS = [5, 5, 4, 4, 5, 6, 6, 5, 4, 4, 5, 6, 7, 7]  # 줄기가 좌우로 흔들린다
for y, cx in enumerate(COLS):
    px[(cx, y + 1)] = LT
    px[(cx + 1, y + 1)] = HI if y % 3 == 0 else LT
    px[(cx - 1, y + 1)] = DK
    px[(cx + 2, y + 1)] = DK
save("p-seaweed", px)


# ── 소라 — 조개(p-shell)와 실루엣이 갈라야 한다. 조개는 부채꼴,
# 소라는 위로 갈수록 좁아지다 끝이 옆으로 살짝 휘는 뿔 모양이다.
px = {}
line = hx("#5A4432")
body = hx("#D8B896")
shade = hx("#B8926C")
hi = hx("#F0DFC4")
# 아래(넓다)에서 위(좁다)로 - 끝은 오른쪽으로 휜다(말려 올라간 뿔)
ROWS = [(1, 10, 10), (1, 10, 9), (2, 9, 8), (2, 8, 7), (3, 8, 6),
        (4, 8, 5), (5, 8, 4), (6, 8, 3), (7, 9, 2)]
for a, b, y in ROWS:
    for x in range(a, b + 1):
        px[(x, y)] = body
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
px[(8, 1)] = line
px[(9, 1)] = line
# 밑동을 가로로 마감
for x in range(0, 12):
    px[(x, 11)] = line
# 나선 줄무늬 - 굵은 대각선 두 가닥이 뿔을 휘감는다
for x, y in [(3, 9), (4, 8), (5, 7), (6, 6), (7, 5)]:
    px[(x, y)] = shade
for x, y in [(2, 10), (3, 8), (5, 6)]:
    px[(x, y)] = hi
save("p-conch", px)


# ── 갈댓잎 — 길고 가는 잎 하나가 휘어 있다. 미역(물결)과 달리 곧고
# 뾰족해야 한다.
px = {}
line = hx("#5C6B2E")
body = hx("#8FAE4A")
hi = hx("#B8D473")
LEAF = [(7, 1), (7, 2), (6, 3), (6, 4), (5, 5), (5, 6), (4, 7), (4, 8),
        (3, 9), (3, 10), (2, 11), (2, 12), (1, 13)]
for x, y in LEAF:
    px[(x, y)] = body
    px[(x + 1, y)] = hi if y % 4 == 1 else body
for x, y in LEAF:
    px[(x - 1, y)] = line
    px[(x + 2, y)] = line
save("p-reed-leaf", px)


# ── 갈꽃 — 이삭 끝이 부풀어 오른 억새꽃. 줄기는 곧고 가늘게,
# 끝의 깃털만 부풀린다.
px = {}
stem = hx("#7A6A3E")
fluff = hx("#E8DCC0")
fluff_sh = hx("#C9B98F")
for y in range(9, 15):
    px[(7, y)] = stem
px[(6, 14)] = stem
# 깃털 - 위로 갈수록 좁아지는 타원 실루엣
ROWS = [(6, 8, 3), (5, 8, 4), (5, 9, 5), (5, 9, 6), (6, 8, 7), (6, 8, 8)]
for a, b, y in ROWS:
    for x in range(a, b + 1):
        px[(x, y)] = fluff
    px[(a, y)] = fluff_sh
    px[(b, y)] = fluff_sh
px[(7, 2)] = fluff
save("p-reed-plume", px)


# ── 귤 — 낙과만 줍는다(나무에서 안 딴다). 감(p-persimmon)과 실루엣이
# 갈라야 한다 - 감은 위아래로 길쭉하고, 귤은 동그랗다.
px = {}
line = hx("#8A4A1E")
body = hx("#E8912E")
shade = hx("#C77420")
hi = hx("#F7C878")
leaf = hx("#4E7A3A")
disc(px, 6, 8, 5, body, line)
# 아래쪽을 살짝 짙게 - 둥근 부피감
for y in range(9, 13):
    for x in range(2, 11):
        if px.get((x, y)) == body:
            px[(x, y)] = shade
px[(4, 5)] = hi
px[(5, 5)] = hi
# 꼭지 - 초록 잎 하나
px[(6, 2)] = leaf
px[(5, 3)] = leaf
px[(7, 3)] = leaf
save("p-tangerine", px)


# ── 귤잎 — 끝이 뾰족한 길쭉한 타원. 갈댓잎(p-reed-leaf, 가늘고 대각선)
# 과 달리 통통하고 짧다.
px = {}
line = hx("#3A5A2A")
body = hx("#6FA050")
hi = hx("#93C46E")
LEAF = [(6, 6, 1), (5, 7, 2), (5, 8, 3), (4, 8, 4),
        (4, 8, 5), (5, 7, 6), (5, 7, 7), (6, 7, 8),
        (6, 6, 9)]
for a, b, y in LEAF:
    for x in range(a, b + 1):
        px[(x, y)] = body
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
# 가운데 잎맥
for y in range(2, 9):
    px[(6, y)] = hi
save("p-citrus-leaf", px)
