#!/usr/bin/env python3
"""바닥 타일에 **결이 다른 형제 타일**을 만든다.

    python3 tools/pixel/make-tile-variants.py

## 왜 필요한가

16px 타일 한 장을 지도 전체에 깔면, 아무리 이음매를 지워도 **같은 그림이
수백 번 반복되는 것**은 못 감춘다. 마을이 바닥재 견본처럼 보인다.

스타듀밸리를 비롯한 탑다운 게임이 다 쓰는 방법은 간단하다 —
**같은 바닥의 형제를 여러 장 만들어 섞어 깐다.** 대부분은 밋밋한 기본
타일이고, 열에 한둘만 꽃이 피었거나 금이 가 있다. 그 한둘이 나머지를
살린다.

## 지키는 선

- **팔레트 밖으로 안 나간다.** 기본 타일에 이미 있는 색이나 그 언저리만 쓴다
- **아주 적게.** 16x16 = 256칸에 점 두세 개. 무늬가 되면 다시 격자로 읽힌다
- **무작위를 안 쓴다.** 씨앗을 박아 두어 몇 번을 돌려도 같은 그림이 나온다
- **가장자리를 안 건드린다.** 이음매에 점이 걸리면 깔았을 때 줄이 보인다
"""

import os
import numpy as np
from PIL import Image

TILES = "assets/tiles"
TILE = 16
EDGE = 2          # 가장자리 이 칸은 안 건드린다 (이음매 보호)


def rng(seed: int) -> np.random.Generator:
    """씨앗을 박은 난수. 돌릴 때마다 같은 그림이 나와야 한다."""
    return np.random.default_rng(seed)


def spots(g, n: int, avoid_edge: bool = True) -> list:
    """점을 찍을 자리 n 개. 서로 붙지 않게 고른다."""
    lo, hi = (EDGE, TILE - EDGE) if avoid_edge else (0, TILE)
    out = []
    for _ in range(n * 8):
        if len(out) >= n:
            break
        p = (int(g.integers(lo, hi)), int(g.integers(lo, hi)))
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) > 3 for q in out):
            out.append(p)
    return out


def shift(base: np.ndarray, d) -> np.ndarray:
    """기본색에서 조금 밀어낸 색. 팔레트 밖으로 안 나가게 잡아 둔다."""
    return np.clip(base.astype(float) + np.array(d, dtype=float), 0, 255)


def put(a: np.ndarray, xy, col) -> None:
    x, y = xy
    if 0 <= x < TILE and 0 <= y < TILE:
        a[y, x, :3] = col


def dot2(a, g, xy, col, base) -> None:
    """점 하나 + 그 옆에 옅은 점 하나. 한 픽셀만 찍으면 먼지처럼 보인다."""
    put(a, xy, col)
    side = (xy[0] + int(g.integers(-1, 2)), xy[1] + int(g.integers(0, 2)))
    put(a, side, (np.array(col) * 0.5 + base * 0.5))


# ── 결의 종류 ─────────────────────────────────────────────────────────
#
# 마을의 성격에 맞춘다. 바닥이 그 마을이 어떤 곳인지 말해 주어야 한다.
#
#   이름: [(형제 이름, 그리는 법, 씨앗), ...]

def flowers(a, g, base):
    """풀에 핀 작은 꽃. 산호빛 · 크림빛 두 가지."""
    for i, p in enumerate(spots(g, 3)):
        col = shift(base, (70, 30, 40) if i % 2 else (60, 60, 20))
        dot2(a, g, p, col, base)


def tufts(a, g, base):
    """짙은 풀포기."""
    for p in spots(g, 4):
        put(a, p, shift(base, (-22, -14, -18)))
        put(a, (p[0], p[1] - 1), shift(base, (-14, -8, -12)))


def pebbles(a, g, base):
    """굴러다니는 잔돌."""
    for p in spots(g, 3):
        c = shift(base, (26, 22, 18))
        put(a, p, c)
        put(a, (p[0] + 1, p[1]), c)
        put(a, (p[0], p[1] + 1), shift(base, (-16, -14, -12)))


def shells(a, g, base):
    """모래에 박힌 조개 조각."""
    for p in spots(g, 3):
        put(a, p, shift(base, (18, 14, 8)))
        put(a, (p[0] + 1, p[1]), shift(base, (10, 6, 2)))
    for p in spots(g, 2):
        put(a, p, shift(base, (-14, -12, -10)))


def ripple(a, g, base):
    """물결 자국. 가로로 길게, 아주 옅게."""
    for y in [int(g.integers(EDGE, TILE - EDGE)) for _ in range(2)]:
        x0 = int(g.integers(EDGE, TILE - 8))
        for x in range(x0, min(x0 + 6, TILE - EDGE)):
            put(a, (x, y), shift(base, (9, 9, 7)))


def sparkle(a, g, base):
    """물 위에 반짝이는 것."""
    for p in spots(g, 2):
        put(a, p, shift(base, (40, 44, 40)))
        put(a, (p[0] + 1, p[1]), shift(base, (18, 20, 18)))


def cracks(a, g, base):
    """돌바닥의 실금."""
    x = int(g.integers(EDGE + 2, TILE - EDGE - 2))
    y = EDGE
    while y < TILE - EDGE:
        put(a, (x, y), shift(base, (-24, -22, -20)))
        x += int(g.integers(-1, 2))
        x = max(EDGE, min(TILE - EDGE - 1, x))
        y += 1


def moss(a, g, base):
    """돌 틈에 낀 이끼."""
    for p in spots(g, 3):
        c = shift(base, (-10, 16, -14))
        put(a, p, c)
        put(a, (p[0], p[1] + 1), shift(base, (-6, 8, -8)))


def knots(a, g, base):
    """나무 판자의 옹이."""
    for p in spots(g, 2):
        put(a, p, shift(base, (-30, -26, -22)))
        for d in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            put(a, (p[0] + d[0], p[1] + d[1]), shift(base, (-14, -12, -10)))


def rake(a, g, base):
    """비질한 자국. 고향 마당."""
    y = int(g.integers(EDGE, TILE - EDGE))
    for x in range(EDGE, TILE - EDGE):
        put(a, (x, y), shift(base, (14, 10, 6)))
        if x % 3 == 0:
            put(a, (x, y + 1), shift(base, (-10, -8, -6)))


def grit(a, g, base):
    """거친 알갱이. 현무암·자갈."""
    for p in spots(g, 5):
        put(a, p, shift(base, (22, 18, 14)))
    for p in spots(g, 3):
        put(a, p, shift(base, (-16, -14, -12)))


def weave(a, g, base):
    """카펫의 결. 실내."""
    for y in range(EDGE, TILE - EDGE, 3):
        for x in range(EDGE, TILE - EDGE):
            if (x + y) % 2 == 0:
                put(a, (x, y), shift(base, (7, 7, 9)))


def sheen(a, g, base):
    """젖은 돌의 윤기."""
    x0 = int(g.integers(EDGE, TILE - 7))
    y0 = int(g.integers(EDGE, TILE - 7))
    for k in range(5):
        put(a, (x0 + k, y0 + k), shift(base, (16, 16, 18)))


def furrow(a, g, base):
    """밭고랑."""
    for x in range(EDGE, TILE - EDGE):
        put(a, (x, EDGE + 3), shift(base, (-14, -12, -10)))
        put(a, (x, EDGE + 4), shift(base, (12, 10, 8)))


VARIANTS = {
    "grass":         [("2", flowers), ("3", tufts), ("4", pebbles)],
    "dry-grass":     [("2", tufts), ("3", pebbles)],
    "sand":          [("2", shells), ("3", ripple)],
    "water":         [("2", sparkle), ("3", ripple)],
    "dirt":          [("2", pebbles), ("3", grit)],
    "cobble":        [("2", cracks), ("3", moss)],
    "stone-slab":    [("2", cracks), ("3", sheen)],
    "deck":          [("2", knots), ("3", cracks)],
    "wood-floor":    [("2", knots)],
    "tilled-soil":   [("2", furrow), ("3", grit)],
    "basalt":        [("2", grit), ("3", moss)],
    "clay-earth":    [("2", rake), ("3", pebbles)],
    "granite-step":  [("2", sheen), ("3", cracks)],
    "slate-path":    [("2", moss), ("3", cracks)],
    "office-carpet": [("2", weave)],
    "lobby-marble":  [("2", sheen), ("3", cracks)],
}


def main() -> None:
    made = 0
    for name, kinds in VARIANTS.items():
        src = os.path.join(TILES, name + ".png")
        if not os.path.exists(src):
            print("  없음, 건너뜀: %s" % name)
            continue
        im = Image.open(src).convert("RGBA")
        base_arr = np.asarray(im).astype(float)
        base = base_arr[..., :3].reshape(-1, 3).mean(axis=0)
        for suffix, fn in kinds:
            a = base_arr.copy()
            # 씨앗은 이름에서 뽑는다. 몇 번을 돌려도 같은 그림이 나온다.
            seed = abs(hash(name + suffix)) % (2 ** 31)
            fn(a, rng(seed), base)
            out = os.path.join(TILES, "%s-%s.png" % (name, suffix))
            Image.fromarray(a.astype("uint8"), "RGBA").save(out)
            made += 1
            y = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
            print("  %-18s sd %.2f  →  %s" % (name + "-" + suffix, y.std(), out))
    print("\n형제 타일 %d장 만들었다." % made)


if __name__ == "__main__":
    main()
