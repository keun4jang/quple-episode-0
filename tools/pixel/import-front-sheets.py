#!/usr/bin/env python3
"""제미나이 정면 시트를 잘라 소품으로 넣는다 (T장).

    python3 tools/pixel/import-front-sheets.py

## 왜 따로 만드나

`import-journey-art.py` 는 마젠타를 밝기로 따고 팔레트를 다시 입힌다.
그건 **회화풍 그림**을 픽셀로 바꾸려고 만든 것이다. 이번 시트는 이미
픽셀 아트라 다시 칠할 필요가 없다 — 마젠타만 따고 크기만 줄이면 된다.
팔레트를 덧씌우면 오히려 공들여 찍은 점들이 뭉개진다.

## 잘라내는 법

마젠타가 화면 전체를 채우고 있으니 **연결 덩어리**로 나눈다.
행·열 거터를 찾는 방식은 이 시트에 안 맞는다 — 물건이 격자로
정렬돼 있지 않고 크기도 제각각이다.
"""

import os
import numpy as np
from PIL import Image

SPRITES = "assets/sprites"
TILES = "assets/tiles"
SRC = "/tmp"


def magenta_mask(a: np.ndarray) -> np.ndarray:
    """마젠타인 칸. JPEG 라 가장자리가 번지므로 넉넉히 잡는다."""
    r = a[..., 0].astype(int)
    g = a[..., 1].astype(int)
    b = a[..., 2].astype(int)
    return (r > 120) & (b > 110) & (g < r - 50) & (g < b - 40)


def grow(mask: np.ndarray, n: int = 1) -> np.ndarray:
    """마스크를 n칸 부풀린다. 번진 테두리를 같이 먹는다."""
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
    """연결 덩어리들의 상자. 4방향으로만 잇는다."""
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
    # 읽는 순서: 위에서 아래로, 그 안에서 왼쪽부터.
    # 줄 나누기는 세로 중심이 서로 얼마나 겹치는지로 본다.
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


def cut(path: str, min_area: int = 4000) -> list:
    im = Image.open(path).convert("RGB")
    a = np.asarray(im)
    bg = grow(magenta_mask(a), 2)
    boxes = blobs(~bg, min_area)
    rgba = np.dstack([a, np.where(bg, 0, 255).astype("uint8")])
    return im, rgba, boxes


def put(rgba, box, name, height: int, out_dir=SPRITES) -> None:
    """상자를 잘라 세로 height 픽셀로 줄여 저장한다."""
    x0, y0, x1, y1, _ = box
    crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1], "RGBA")
    # 알파 기준으로 한 번 더 바짝
    bb = crop.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bb:
        crop = crop.crop(bb)
    w = max(1, round(crop.width * height / crop.height))
    small = crop.resize((w, height), Image.LANCZOS)
    # 반투명 가장자리를 정리한다. 픽셀 그림에 부드러운 테두리는 안 어울린다.
    arr = np.asarray(small).copy()
    arr[..., 3] = np.where(arr[..., 3] > 128, 255, 0)
    Image.fromarray(arr, "RGBA").save(os.path.join(out_dir, name + ".png"))
    print("  %-16s %dx%d" % (name, w, height))


# 시트 → [(이름, 세로 픽셀)] . 순서는 위에서 아래, 왼쪽에서 오른쪽.
# 사람이 24px 이다. 총점검이 "건물이 나무와 키가 같다" 고 했으므로 넉넉히.
SHEETS = [
    ("/tmp/g_dcp6mldcp6mldcp6.jpg", "사무 7종", [
        ("office-window", 40), ("desk", 26), ("office-chair", 24),
        ("cabinet", 34), ("reception", 22), ("return-box", 26),
        ("icebox", 18),
    ]),
    ("/tmp/g_q51o87q51o87q51o.jpg", "건물", [
        ("guesthouse", 96), (None, 0), ("stall", 44), (None, 0),
        ("shop", 62), (None, 0), ("home-house", 78), (None, 0),
    ]),
    ("/tmp/g_vgc1qzvgc1qzvgc1.jpg", "마을 6종", [
        ("bench", 18), ("dock", 22), ("pump", 26),
        ("firewood", 22), ("home-garden", 30), ("home-deck", 30),
    ]),
]


def main() -> None:
    for path, label, names in SHEETS:
        if not os.path.exists(path):
            print("없음, 건너뜀: %s" % path)
            continue
        im, rgba, boxes = cut(path)
        print("\n[%s] %s — 덩어리 %d개 (이름 %d개)"
              % (label, os.path.basename(path), len(boxes), len(names)))
        for i, box in enumerate(boxes):
            if i >= len(names):
                print("    남은 덩어리 무시 %s" % (box[:4],))
                continue
            name, h = names[i]
            if name is None:
                continue
            put(rgba, box, name, h)

    # 아스팔트 타일 — 오른쪽 정사각형 하나만 쓴다.
    p = "/tmp/g_j5mjabj5mjabj5mj.jpg"
    if os.path.exists(p):
        im, rgba, boxes = cut(p, min_area=40000)
        print("\n[타일] 덩어리 %d개" % len(boxes))
        if len(boxes) >= 2:
            x0, y0, x1, y1, _ = boxes[-1]        # 오른쪽 = 아스팔트
            crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1], "RGBA")
            side = min(crop.size)
            crop = crop.crop((0, 0, side, side)).resize((16, 16), Image.BOX)
            arr = np.asarray(crop.convert("RGBA")).copy()
            arr[..., 3] = 255
            Image.fromarray(arr, "RGBA").save(os.path.join(TILES, "asphalt.png"))
            y = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
            print("  asphalt          16x16  sd %.2f" % y.std())


if __name__ == "__main__":
    main()
