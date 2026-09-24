#!/usr/bin/env python3
"""그늘(전투에 나오는 마음의 그림자) 그림을 찍는다.

걷기 시트 한 장(`s-<id>-walk.png`, 가로 4프레임 x 세로 3방향)과 전투
화면에 크게 띄울 한 장(`s-<id>.png`)을 같이 낸다. 시트 규격은
`QuoSprite` 가 읽는 것과 똑같다 — 그늘도 마을을 떠다니는 `Folk` 다.

**실루엣으로 구분되게** 그린다. 전투 화면에서 6배로 키워 띄우므로
잔무늬는 뭉개지고 윤곽만 남는다. 그래서 몸피(넓다/좁다·크다/작다),
자락의 물결 수, 눈의 수와 모양으로 가른다. 색은 거들 뿐이다.

떠 있는 것이라 **발이 바닥에 안 닿는다.** 그래도 원점은 발끝에 맞춘다
(`QuoSprite` 가 그렇게 그리고, Y 정렬도 발 높이로 한다).
"""
import math
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
FRAMES = 4
ROWS = 3


def hx(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


## 그늘 하나. 머리는 반원, 허리는 곧고, 자락은 물결친다.
##
## `phase` 를 프레임마다 돌려 자락이 흔들리게 한다 — 걸음이 아니라
## **떠 있는 것의 일렁임**이다. 발이 없으니 걸음을 그릴 수가 없다.
def body_mask(w, h, half, top, bumps, phase, foot):
    on = set()
    cx = (w - 1) / 2.0
    head_cy = top + half
    for y in range(top, h):
        if y < head_cy:
            dy = (head_cy - y) / float(half)
            hw = half * math.sqrt(max(0.0, 1.0 - dy * dy))
        else:
            hw = half
        if hw < 0.6:
            continue
        x0 = int(round(cx - hw))
        x1 = int(round(cx + hw))
        for x in range(x0, x1 + 1):
            wob = math.sin(x * bumps * math.pi / float(w) + phase)
            bottom = (h - 1 - foot) + int(round(wob * 2.0))
            if y <= bottom:
                on.add((x, y))
    return on


def outline(on, w, h):
    edge = set()
    for (x, y) in on:
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + d[0], y + d[1])
            if p not in on and 0 <= p[0] < w and 0 <= p[1] < h:
                edge.add(p)
    return edge


## 눈. 그늘은 눈만 밝다 — 어두운 덩어리에서 그것만 읽힌다.
def put_eyes(px, spec, cx, ey, col, row):
    if row == 2:
        return                      # 뒷모습엔 눈이 없다
    shift = 2 if row == 1 else 0    # 옆모습은 한쪽으로 몰린다
    for (dx, dy, big) in spec:
        x = int(round(cx + dx)) + shift
        y = ey + dy
        px[(x, y)] = col
        if big:
            px[(x + 1, y)] = col
            px[(x, y + 1)] = col
            px[(x + 1, y + 1)] = col


## 꿈결의 몬스터 (`docs/elements.md` 3절). **속성이 모양으로 보이게** 한다:
##   drop   물방울 - 머리가 뾰족하고 하얀 반짝임
##   flame  불꽃 - 머리 위로 혀 셋이 날름거린다 (프레임마다 흔들림)
##   sprout 새싹 - 머리에 떡잎 두 장
##   rock   돌 - 몸이 각지고 돌 무늬 점
##   swirl  바람 - 몸에 흰 소용돌이 줄
##   thorn  가시 - 몸 둘레에 가시
## (id, 셀, 몸피, 머리 꼭대기, 자락 물결, 발밑 띄움, 몸빛, 테두리, 눈빛, 눈, 꾸밈, 꾸밈빛)
SHADES = [
    ("drop",   (20, 24), 5, 7,  4, 3, "#4DABF7", "#1B4F7A", "#FFFFFF",
     [(-2, 1, False), (2, 1, False)], "drop", "#E7F5FF"),
    ("whirl",  (20, 24), 6, 6,  6, 2, "#1C7ED6", "#0B3B66", "#E7F5FF",
     [(-2, 0, True), (2, 0, True)], "swirl", "#A5D8FF"),
    ("ember",  (20, 24), 4, 8,  3, 3, "#FF7043", "#7A2A12", "#FFF3BF",
     [(-2, 0, False), (2, 0, False)], "flame", "#FFD43B"),
    ("blaze",  (20, 24), 6, 8,  4, 2, "#E8590C", "#5C1E05", "#FFF3BF",
     [(-3, 0, True), (3, 0, True)], "flame", "#FFD43B"),
    ("sprout", (20, 24), 5, 9,  3, 3, "#69DB7C", "#1E5A2A", "#FFFFFF",
     [(-2, 0, False), (2, 0, False)], "sprout", "#2B8A3E"),
    ("thorn",  (20, 24), 6, 7,  5, 2, "#2F9E44", "#123F1C", "#FFE066",
     [(-3, 0, True), (3, 0, True)], "thorn", "#D8F5A2"),
    ("pebble", (20, 24), 6, 9,  2, 2, "#A0896B", "#3F3222", "#FFF3BF",
     [(-3, 0, False), (3, 0, False)], "rock", "#6B5A48"),
    ("mole",   (20, 24), 7, 8,  2, 2, "#C9955C", "#4A3320", "#1A1418",
     [(-3, 0, True), (3, 0, True)], "rock", "#8D6E4F"),
    ("gust",   (20, 24), 4, 5,  5, 4, "#C5F6FA", "#3B8A96", "#1A1418",
     [(-2, 0, False), (2, 0, False)], "swirl", "#FFFFFF"),
    ("storm",  (20, 24), 6, 4,  6, 3, "#66D9E8", "#1D5E68", "#FFFFFF",
     [(-3, 0, True), (3, 0, True)], "swirl", "#E3FAFC"),
    # 우두머리는 한눈에 크다. 셀부터 다르다.
    ("night",  (26, 30), 9, 2,  4, 2, "#2E2836", "#121017", "#FFD166",
     [(-4, 0, True), (4, 0, True)], "none", "#B197FC"),
]


def decorate(px, deco, col, on, cw, ch, top, half, f, row):
    c = hx(col)
    cx = int(round((cw - 1) / 2.0))
    if deco == "drop":
        # 머리 꼭대기를 뾰족하게, 반짝임 하나
        for dy in range(1, 4):
            px[(cx, top - dy)] = hx("#1B4F7A") if dy == 3 else px.get((cx, top), c)
        px[(cx - 2, top + 2)] = c
        px[(cx - 1, top + 1)] = c
    elif deco == "flame":
        sway = [0, 1, 0, -1][f]
        for i, dx in enumerate((-2, 0, 2)):
            h = 4 + (1 if i == 1 else 0)
            for dy in range(1, h + 1):
                x = cx + dx + (sway if dy > 1 else 0)
                px[(x, top - dy + 1)] = c if dy < h else hx("#FFF3BF")
    elif deco == "sprout":
        px[(cx, top - 1)] = c
        px[(cx, top - 2)] = c
        for (x, y) in ((cx - 1, top - 3), (cx - 2, top - 3), (cx - 3, top - 4),
                       (cx + 1, top - 3), (cx + 2, top - 3), (cx + 3, top - 4)):
            px[(x, y)] = hx("#8CE99A")
    elif deco == "thorn":
        for (x, y) in list(on):
            if (x + y + f) % 5 == 0 and ((x - 1, y) not in on or (x + 1, y) not in on):
                nx = x - 1 if (x - 1, y) not in on else x + 1
                px[(nx, y)] = c
    elif deco == "rock":
        for (x, y) in on:
            if (x * 7 + y * 3) % 11 == 0:
                px[(x, y)] = c
    elif deco == "swirl":
        if row == 2:
            return
        cy = top + half + 4
        for k in range(10):
            a = k * 0.7 + f * 0.8
            r = 1.0 + k * 0.35
            x = int(round(cx + math.cos(a) * r))
            y = int(round(cy + math.sin(a) * r * 0.6))
            if (x, y) in on:
                px[(x, y)] = c


def build(spec):
    sid, (cw, ch), half, top, bumps, foot, body, edge, eyec, eyes, deco, dcol = spec
    body_c, edge_c, eye_c = hx(body), hx(edge), hx(eyec)
    sheet = Image.new("RGBA", (cw * FRAMES, ch * ROWS), (0, 0, 0, 0))
    one = None
    for row in range(ROWS):
        for f in range(FRAMES):
            px = {}
            # 프레임마다 자락을 돌리고 몸을 1px 들썩인다
            lift = [0, -1, 0, 1][f]
            on = body_mask(cw, ch, half, top + lift, bumps,
                           f * math.pi / 2.0, foot)
            for p in outline(on, cw, ch):
                px[p] = edge_c
            for p in on:
                px[p] = body_c
            decorate(px, deco, dcol, on, cw, ch, top + lift, half, f, row)
            put_eyes(px, eyes, (cw - 1) / 2.0, top + half + lift, eye_c, row)
            cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            cell.putdata([px.get((x, y), (0, 0, 0, 0))
                          for y in range(ch) for x in range(cw)])
            sheet.paste(cell, (f * cw, row * ch))
            if row == 0 and f == 0:
                one = cell
    sheet.save(os.path.join(OUT, "s-%s-walk.png" % sid))
    one.save(os.path.join(OUT, "s-%s.png" % sid))
    print("만듦: s-%s (%dx%d 칸)" % (sid, cw, ch))


for spec in SHADES:
    build(spec)
