#!/usr/bin/env python3
"""바닥 데칼을 만든다 — 넓은 단색 면을 깨는 잔무늬 24장.

16x16 반투명 PNG. 바닥 위에 얹는 그림이라 배경은 완전 투명이고,
무늬 픽셀도 알파를 낮게 둔다 (바닥 결이 비쳐야 얼룩이 아니라 흔적이
된다). 종류별로 두세 장씩 — 같은 데칼이 반복되면 그것도 무늬가 된다.

게임 쪽은 `Place._build_decals()` 가 바닥 종류에 맞는 것만 골라
좌표 해시로 뿌린다. 여기 이름을 더하면 그쪽 표에도 더한다.
"""
import os
from PIL import Image

TILES = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tiles")
S = 16


def h2(hx, a):
    return (int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16), a)


def rng(seed):
    # 데칼은 만들 때마다 같아야 한다 — 손수 만든 결정적 난수.
    s = seed * 2654435761 % (2 ** 31)
    while True:
        s = (s * 1103515245 + 12345) % (2 ** 31)
        yield s


def blank():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def dots(name, colors, n, seed, size=1):
    """점 무리 — 낙엽·잔돌·꽃잎·솔잎이 다 이 골격이다."""
    img = blank()
    px = img.load()
    r = rng(seed)
    for i in range(n):
        x = 2 + next(r) % (S - 4)
        y = 2 + next(r) % (S - 4)
        c = colors[next(r) % len(colors)]
        for dx in range(size):
            for dy in range(size):
                if x + dx < S and y + dy < S:
                    px[x + dx, y + dy] = c
    img.save(os.path.join(TILES, name + ".png"))
    print("만듦:", name)


def blades(name, color, n, seed, tall=3):
    """풀포기 — 세로 획 두세 개가 한 포기."""
    img = blank()
    px = img.load()
    r = rng(seed)
    for i in range(n):
        x = 2 + next(r) % (S - 4)
        y = 4 + next(r) % (S - 8)
        h = 2 + next(r) % tall
        for k in range(h):
            px[x, y + k] = color
        if next(r) % 2 == 0 and x + 1 < S:
            px[x + 1, y + 1] = color
    img.save(os.path.join(TILES, name + ".png"))
    print("만듦:", name)


def streaks(name, color, seed, horiz=True):
    """바큇자국·모래결 — 끊어진 줄 두 가닥."""
    img = blank()
    px = img.load()
    r = rng(seed)
    for lane in (5, 10):
        skip = next(r) % 3
        for t in range(1, S - 1):
            if (t + skip) % 4 == 3:
                continue
            if horiz:
                px[t, lane + (next(r) % 2)] = color
            else:
                px[lane + (next(r) % 2), t] = color
    img.save(os.path.join(TILES, name + ".png"))
    print("만듦:", name)


def blob(name, color, seed, r0=4):
    """물얼룩·이끼 — 가장자리가 우둘투둘한 둥근 판."""
    img = blank()
    px = img.load()
    r = rng(seed)
    cx, cy = 8, 8
    for y in range(S):
        for x in range(S):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            edge = r0 + (next(r) % 3) - 1
            if d <= edge:
                px[x, y] = color
    img.save(os.path.join(TILES, name + ".png"))
    print("만듦:", name)


A = 120     # 무늬 알파 기준 — 바닥이 비쳐야 한다
A2 = 90

# ── 풀밭 (grass · dry-grass) ── 8장
dots("dc-leaf-1", [h2("#8a6d3b", A), h2("#a3853f", A)], 6, 11)
dots("dc-leaf-2", [h2("#8a6d3b", A), h2("#6e5a30", A)], 5, 12)
dots("dc-flower-w", [h2("#f2ead8", A), h2("#e8d7b0", A)], 5, 13)
dots("dc-flower-y", [h2("#e8c463", A), h2("#d9a93f", A)], 4, 14)
blades("dc-tuft-1", h2("#4f7a3a", A), 4, 15)
blades("dc-tuft-2", h2("#5d8a43", A), 5, 16)
blades("dc-tuft-dry", h2("#9a8a52", A), 4, 17)
blob("dc-moss", h2("#577240", A2), 18, 3)

# ── 흙길 (dirt · clay-earth) ── 6장
streaks("dc-track-h", h2("#5f4a35", A2), 21, True)
streaks("dc-track-v", h2("#5f4a35", A2), 22, False)
dots("dc-grit-1", [h2("#7d6a52", A), h2("#93805f", A)], 7, 23)
dots("dc-grit-2", [h2("#6b593f", A), h2("#89755a", A)], 6, 24)
blob("dc-puddle", h2("#4a5668", 70), 25, 3)
dots("dc-straw", [h2("#b3985c", A2)], 5, 26, 1)

# ── 모래 (sand) ── 4장
streaks("dc-ripple-1", h2("#c9b083", A2), 31, True)
streaks("dc-ripple-2", h2("#c9b083", A2), 32, True)
dots("dc-shellbit", [h2("#efe6d2", A), h2("#d9c9a8", A)], 4, 33)
dots("dc-wrack", [h2("#7a7350", A2), h2("#8d8560", A2)], 5, 34)

# ── 돌바닥 (cobble · stone-slab · slate-path) ── 4장
dots("dc-crack", [h2("#4c4c55", A2)], 5, 41)
blob("dc-stain", h2("#54504a", 60), 42, 4)
dots("dc-pebblebit", [h2("#8f8f96", A2), h2("#75757d", A2)], 5, 43)
blades("dc-grasscrack", h2("#577240", A2), 3, 44, 2)

# ── 밭 (tilled-soil) · 솔숲 전용 ── 2장
dots("dc-sprout", [h2("#6f9a4b", A)], 4, 51)
dots("dc-needle", [h2("#5a6e46", A2), h2("#48583a", A2)], 7, 52)
