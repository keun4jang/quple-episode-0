#!/usr/bin/env python3
"""몽이 - 꿈결의 안내 요정 (`docs/redesign-dream.md` 2절).

작고 둥근 빛덩이에 날개 둘. 걷지 않고 **팔랑이며 떠 있다** - 프레임마다
날개가 오르내리고 몸이 1px 들썩인다. 규격은 다른 걷기 시트와 같다
(가로 4프레임 x 세로 3방향: 정면·옆·뒤).
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
CW, CH = 16, 20


def hx(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


BODY = hx("#FFF3BF")
GLOW = hx("#FFD43B")
EDGE = hx("#B08900")
WING = hx("#D0EBFF", 220)
WING_E = hx("#74C0FC")
EYE = hx("#3A2C2C")
CHEEK = hx("#FF8FAB")


def cell(f, row):
    px = {}
    lift = [0, -1, -2, -1][f]
    cx, cy = 7.5, 11 + lift
    # 날개 - 프레임마다 오르내린다
    flap = [0, -1, -2, -1][f]
    for side in (-1, 1):
        wx, wy = cx + side * 5.5, cy - 3 + flap
        for y in range(CH):
            for x in range(CW):
                e = ((x - wx) / 2.4) ** 2 + ((y - wy) / 3.2) ** 2
                if e <= 1.0:
                    px[(x, y)] = WING if e < 0.55 else WING_E
    # 몸 - 둥근 빛
    for y in range(CH):
        for x in range(CW):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 4.2:
                px[(x, y)] = BODY if d < 3.2 else GLOW
            elif d <= 5.0:
                px.setdefault((x, y), EDGE)
    # 머리 위 더듬이 별
    px[(int(cx), int(cy) - 6)] = GLOW
    px[(int(cx), int(cy) - 7)] = BODY
    if row != 2:
        shift = 1 if row == 1 else 0
        px[(int(cx) - 1 - shift, int(cy))] = EYE
        px[(int(cx) + 2 - shift, int(cy))] = EYE
        px[(int(cx) - 2 - shift, int(cy) + 1)] = CHEEK
        px[(int(cx) + 3 - shift, int(cy) + 1)] = CHEEK
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    img.putdata([px.get((x, y), (0, 0, 0, 0)) for y in range(CH) for x in range(CW)])
    return img


sheet = Image.new("RGBA", (CW * 4, CH * 3), (0, 0, 0, 0))
for row in range(3):
    for f in range(4):
        sheet.paste(cell(f, row), (f * CW, row * CH))
sheet.save(os.path.join(OUT, "mongi-walk.png"))
print("만듦: mongi-walk")
