#!/usr/bin/env python3
"""새 동물 종 시트(52칸, 13종 x 4포즈)에서 정지 그림만 뽑는다.

    python3 tools/pixel/import-species-sheet.py

## 왜 정지 그림만 뽑나

`QuoSprite`가 읽는 "-walk.png"는 **가로 4프레임 x 세로 3방향**(아래/옆/위)
고정 격자다(`scripts/journey/quo_sprite.gd`). 이번 시트는 종마다 4칸이지만
방향별로 나뉜 게 아니라 정지/깜빡임/걷는 자세 둘이 섞여 있다 — 그대로
걷기 시트 자리에 넣으면 방향이 뒤죽박죽된다.

그래서 이번엔 **각 종의 첫 칸(정면 정지 자세)만** `이름.png`로 저장한다.
기존 `seal.png`/`seagull.png`/`raccoon.png`(걷기와 별개로, 지금 코드
어디서도 안 쓰는 정지 그림)를 새 그림으로 갈아 끼우고, 새 종 10개는
같은 이름의 정지 그림만 새로 만든다. **걷기 시트는 아직 없다** — 실제로
마을을 걸어 다니게 하려면 방향별 걷기 프레임을 따로 받아야 한다.
"""

import os
import numpy as np
from PIL import Image

SRC = "/tmp/g_new_species.jpg"
OUT = "assets/sprites"
HEIGHT = 24     # 캐릭터 기준 24px (CLAUDE.md)


def magenta_mask(a: np.ndarray) -> np.ndarray:
    r = a[..., 0].astype(int)
    g = a[..., 1].astype(int)
    b = a[..., 2].astype(int)
    return (r > 120) & (b > 110) & (g < r - 50) & (g < b - 40)


def grow(mask: np.ndarray, n: int = 1) -> np.ndarray:
    m = mask.copy()
    for _ in range(n):
        p = np.zeros_like(m)
        p[1:, :] |= m[:-1, :]
        p[:-1, :] |= m[1:, :]
        p[:, 1:] |= m[:, :-1]
        p[:, :-1] |= m[:, 1:]
        m |= p
    return m


def blobs(solid: np.ndarray, min_area: int) -> list:
    h, w = solid.shape
    seen = np.zeros((h, w), dtype=bool)
    out = []
    ys, xs = np.nonzero(solid)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        stack = [(sy, sx)]
        seen[sy, sx] = True
        x0 = x1 = sx
        y0 = y1 = sy
        n = 0
        while stack:
            y, x = stack.pop()
            n += 1
            if x < x0: x0 = x
            if x > x1: x1 = x
            if y < y0: y0 = y
            if y > y1: y1 = y
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if n >= min_area:
            out.append((x0, y0, x1, y1, n))
    out.sort(key=lambda b: (b[1], b[0]))
    rows = []
    for b in out:
        cy = (b[1] + b[3]) * 0.5
        for r in rows:
            if abs(cy - r[0]) < (b[3] - b[1]) * 0.6:
                r[1].append(b)
                break
        else:
            rows.append([cy, [b]])
    rows.sort(key=lambda r: r[0])
    flat = []
    for _, items in rows:
        items.sort(key=lambda b: b[0])
        flat += items
    return flat


# 13행 x 4칸. 각 행의 **첫 칸만** 쓴다 (정면 정지 자세).
ROWS = [
    "seal", "seagull", "raccoon",              # 기존 셋 (물범·갈매기·너구리) 갱신
    "otter", "magpie", "squirrel", "owl", "snail", "deer", "frog",   # 새 7종
    "capybara-a", "capybara-b", "capybara-c",  # 카피바라 세 벌 (2탄, 물범의 강가 버전)
]


def main() -> None:
    im = Image.open(SRC).convert("RGB")
    a = np.asarray(im)
    bg = grow(magenta_mask(a), 3)
    boxes = blobs(~bg, 3000)
    print("덩어리 %d개 (13행 x 4칸 = 52 기대)" % len(boxes))
    if len(boxes) != len(ROWS) * 4:
        print("!! 칸 수가 예상과 다르다 — 이름 매핑을 다시 확인해라.")

    rgba = np.dstack([a, np.where(bg, 0, 255).astype("uint8")])
    for i, name in enumerate(ROWS):
        idx = i * 4       # 그 행의 첫 칸
        if idx >= len(boxes):
            print("  없음: %s" % name)
            continue
        x0, y0, x1, y1, _ = boxes[idx]
        crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1], "RGBA")
        bb = crop.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        if bb:
            crop = crop.crop(bb)
        w = max(1, round(crop.width * HEIGHT / crop.height))
        small = crop.resize((w, HEIGHT), Image.LANCZOS)
        arr = np.asarray(small).copy()
        arr[..., 3] = np.where(arr[..., 3] > 128, 255, 0)
        Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".png"))
        print("  %-14s %dx%d" % (name, w, HEIGHT))


if __name__ == "__main__":
    main()
