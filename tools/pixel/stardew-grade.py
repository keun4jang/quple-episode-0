#!/usr/bin/env python3
"""바닥 팔레트를 스타듀밸리 쪽으로 당긴다 — 채도와 명암 분리.

    python3 tools/pixel/stardew-grade.py            # 적용
    python3 tools/pixel/stardew-grade.py --check    # 재기만

## 왜

만든 사람이 스타듀밸리 화면을 가져와 "이 디자인이 너무 좋다" 고 했다.
나란히 놓고 재 보면 차이는 그림 실력이 아니라 **숫자**다.

- 스타듀 잔디: 채도 S 0.5~0.7. 우리 풀: 0.18
- 스타듀는 이웃한 바닥끼리 명도가 확 갈린다 (짙은 풀 vs 금빛 흙).
  우리는 여섯 바닥이 명도 한 줌 안에 몰려 있다

전체를 스타듀만큼 올리면 힐링 톤이 죽는다. **절반쯤** 당긴다 —
채도를 1.35배, 그리고 바닥끼리 명도를 서로 밀어낸다.

## 명도 목표 (상대휘도 0~255 기준)

어두운 쪽    tilled-soil 70 · basalt 88 · slate-path 118
가운데       dirt 128 · cobble 138 · grass 132 · dry-grass 142
밝은 쪽      clay-earth 168 · deck 158 · stone-slab 152 · sand 208

물은 채도만 올리고 명도는 두 그룹 사이(150)에 둔다 — 모래와 만나는
경계가 살아야 한다.
"""

import sys
import glob
import colorsys
import numpy as np
from PIL import Image

TILES = "assets/tiles"

## 바닥 → (명도, 채도, 색상각 미는 정도).
##
## 곱셈이 아니라 **절대 목표**다. 두 번 돌려도 같은 결과가 나온다.
## 첫판에는 풀 132 · 돌길 138 로 잡았다가 화면이 그대로였다 —
## 이웃한 둘의 명도가 5 차이면 경계가 안 갈린다. 스타듀는 풀이 짙고
## 흙이 금빛이라 갈리는 것이다. 풀을 확 내리고 흙과 모래를 올린다.
GRADE = {
    #                명도   채도    색상각(도)
    "tilled-soil":  ( 70,  0.50,   0),
    "basalt":       ( 86,  0.24,   0),
    "grass":        (108,  0.42, +18),   # 올리브 → 초록 쪽으로
    "slate-path":   (118,  0.22,   0),
    "cobble":       (140,  0.28,   0),
    "dirt":         (136,  0.60,   0),
    "dry-grass":    (150,  0.48,  +8),
    "granite-step": (150,  0.10,   0),
    "water":        (150,  0.50,   0),
    "office-carpet":(150,  0.10,   0),
    "stone-slab":   (156,  0.28,   0),
    "deck":         (160,  0.55,   0),
    "wood-floor":   (160,  0.55,   0),
    "clay-earth":   (172,  0.50,   0),
    "lobby-marble": (176,  0.14,   0),
    "sand":         (210,  0.32,   0),
}


def luma(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def grade(path: str, base: str, apply: bool) -> None:
    if base not in GRADE:
        return
    want_y, want_s, hue_deg = GRADE[base]
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(float)
    rgb = a[..., :3] / 255.0

    # HSV 로 넘어가 채도·색상각을 **절대값으로** 맞춘다
    mx = rgb.max(2); mn = rgb.min(2); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(m & (mx == r), ((g - b) / np.maximum(d, 1e-6)) % 6, h)
    h = np.where(m & (mx == g), (b - r) / np.maximum(d, 1e-6) + 2, h)
    h = np.where(m & (mx == b), (r - g) / np.maximum(d, 1e-6) + 4, h)
    h = (h * 60.0 + hue_deg) % 360.0

    s_cur = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    s_avg = float(s_cur.mean())
    # 평균을 목표로 옮기되 픽셀 사이 차이는 살린다
    s_new = np.clip(s_cur + (want_s - s_avg), 0, 0.9)

    c = mx * s_new
    hh = h / 60.0
    x = c * (1 - np.abs(hh % 2 - 1))
    z = np.zeros_like(c)
    conds = [(hh < 1), (hh < 2), (hh < 3), (hh < 4), (hh < 5), (hh >= 5)]
    rs = np.select(conds, [c, x, z, z, x, c])
    gs = np.select(conds, [x, c, c, x, z, z])
    bs = np.select(conds, [z, z, x, c, c, x])
    mval = mx - c
    rgb = np.stack([rs + mval, gs + mval, bs + mval], axis=-1)
    a[..., :3] = np.clip(rgb * 255.0, 0, 255)

    # 명도: 평균을 목표로 평행이동 (무늬는 그대로 남는다)
    cur = float(luma(a[..., :3]).mean())
    a[..., :3] = np.clip(a[..., :3] + (want_y - cur), 0, 255)

    out = np.clip(a, 0, 255).astype("uint8")
    y = float(luma(out[..., :3].astype(float)).mean())
    m = out[..., :3].reshape(-1, 3).astype(float).mean(0) / 255.0
    hs = colorsys.rgb_to_hsv(*m)
    print("  %-18s 명도 %5.0f  S %.2f" % (path.split("/")[-1][:-4], y, hs[1]))
    if apply:
        Image.fromarray(out, "RGBA").save(path)


def main() -> None:
    apply = "--check" not in sys.argv
    for path in sorted(glob.glob(TILES + "/*.png")):
        name = path.split("/")[-1][:-4]
        # 형제 타일(-2, -3, -4)은 원본과 같은 목표를 쓴다
        base = name
        if base[-2] == "-" and base[-1].isdigit():
            base = base[:-2]
        grade(path, base, apply)
    print("\n%s" % ("적용했다." if apply else "재기만 했다."))


if __name__ == "__main__":
    main()
