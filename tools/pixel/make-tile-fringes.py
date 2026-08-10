#!/usr/bin/env python3
"""바닥이 만나는 자리에 **넘침 가장자리**를 만든다.

    PYTHONHASHSEED=0 python3 tools/pixel/make-tile-fringes.py

## 왜

바닥 두 종이 만나는 경계가 칸 모양 그대로 뚝 끊긴다. 마을이 아니라
모눈종이로 보인다. 스타듀밸리를 나란히 놓고 보면 차이가 여기서 갈린다 —
풀이 흙 위로 한두 픽셀 삐져나오고, 모래가 물속으로 점점이 스민다.

## 어떻게

바닥마다 네 방향 가장자리 그림을 만든다. `grass-fr-s.png` 는
"풀이 **아래(남쪽)** 칸으로 넘친 것" — 위 3줄만 풀이고 나머지는 투명이다.
넘치는 3줄도 점점 성기게 (첫 줄은 다, 둘째 줄은 반, 셋째 줄은 드문드문)
찍어서 딱 떨어지는 직선이 안 생기게 한다.

까는 쪽은 `place.gd` 가 한다 — 이웃 칸과 바닥이 다르고 내 쪽 우선순위가
높으면, 이웃 칸 위에 내 가장자리를 얹는다.
"""

import glob
import os
import numpy as np
from PIL import Image

TILES = "assets/tiles"
TILE = 16
DEPTH = 3          # 몇 픽셀 넘치나

## 이 바닥들만 넘친다. 돌바닥이 풀 위로 넘치면 이상하다 —
## **자연이 인공물 위로** 넘치는 것만 자연스럽다.
FRINGED = ["grass", "dry-grass", "sand", "clay-earth", "dirt", "basalt"]

## 줄마다 얼마나 성기게 찍나 (1 = 다, 2 = 반, 4 = 드문드문)
STEP = [1, 2, 4]


def dither_keep(x: int, y: int, row: int, seed: int) -> bool:
    h = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    h = (h ^ (h >> 13)) & 0x7FFFFFFF
    return h % (STEP[row] * 2) < 2 if STEP[row] > 1 else True


def make(base: np.ndarray, name: str) -> None:
    seed = sum(ord(c) for c in name)
    for d, tag in [((0, -1), "n"), ((0, 1), "s"), ((-1, 0), "w"), ((1, 0), "e")]:
        out = np.zeros((TILE, TILE, 4), dtype=np.uint8)
        for row in range(DEPTH):
            for k in range(TILE):
                if tag == "s":            # 아래 칸의 **위쪽** 줄
                    x, y = k, row
                    sx, sy = k, TILE - DEPTH + row
                elif tag == "n":          # 위 칸의 **아래쪽** 줄
                    x, y = k, TILE - 1 - row
                    sx, sy = k, DEPTH - 1 - row
                elif tag == "e":          # 오른 칸의 **왼쪽** 줄
                    x, y = row, k
                    sx, sy = TILE - DEPTH + row, k
                else:                     # 왼 칸의 **오른쪽** 줄
                    x, y = TILE - 1 - row, k
                    sx, sy = DEPTH - 1 - row, k
                if not dither_keep(x, y, row, seed):
                    continue
                out[y, x, :3] = base[sy, sx, :3]
                out[y, x, 3] = 255
        Image.fromarray(out, "RGBA").save(
            os.path.join(TILES, "%s-fr-%s.png" % (name, tag)))


def main() -> None:
    n = 0
    for name in FRINGED:
        src = os.path.join(TILES, name + ".png")
        if not os.path.exists(src):
            continue
        base = np.asarray(Image.open(src).convert("RGBA"))
        make(base, name)
        n += 4
    print("가장자리 %d장 만들었다." % n)


if __name__ == "__main__":
    main()
