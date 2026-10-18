#!/usr/bin/env python3
"""직업마다 다른 차림의 쿼카 걷기 시트를 만든다 (무료 · PIL 만).

    python3 tools/pixel/make-job-sprites.py

`assets/sprites/hero-walk.png`(4칸 x 3줄, 칸 17x25)을 읽어 직업마다
`assets/sprites/hero-<job>-walk.png` 를 쓴다. 칸 위쪽에 7px 여백을 더해(17x32)
투구 깃털·마법사 모자 꼭대기가 들어갈 자리를 만든다. 원점은 그대로 발끝이라
게임 코드는 칸 크기만 다시 읽으면 된다 (`IdleActor.set_sheet`).

  전사   - 쇠 투구 + 붉은 깃털 + 붉은 목도리
  마법사 - 보라 고깔모자(별) + 남색 긴 옷
  궁수   - 초록 두건 + 깃털 + 등에 화살통
  도적   - 검은 두건(매듭 꼬리) + 보라 목도리 + 어두운 옷

무기는 그림에 넣지 않는다 - 휘두르는 동작이 있어 코드가 따로 그린다 (`IdleActor`).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/sprites/hero-walk.png"
CW, CH = 17, 25
PAD = 7

# 원래 모자(초록 회색 여행 모자) 빛깔 - 이 빛깔이면서 머리 위쪽(여섯 줄 안)에 있으면 모자로 본다.
HAT = {(0x97, 0x9E, 0x74), (0x81, 0x89, 0x7D), (0x82, 0x77, 0x5F), (0x7A, 0x67, 0x5A),
       (0xAC, 0x98, 0x84), (0x9C, 0x7F, 0x73), (0x97, 0x7E, 0x67)}


def hexc(s: str) -> tuple:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def lum(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def tone(c, pal: list) -> tuple:
    """원래 빛깔의 밝기대로 새 팔레트(어둠·가운데·밝음) 중 하나를 고른다 - 명암이 그대로 남는다."""
    v = lum(c)
    if v < 105:
        return pal[0]
    if v < 135:
        return pal[1]
    return pal[2]


JOBS = {
    "warrior": {"hat": ["#4F5966", "#8792A0", "#C5CED8"], "neck": ["#8E2A2A", "#C43C3C", "#E46A5A"]},
    "mage": {"hat": ["#33275F", "#5241A0", "#8270D2"], "robe": ["#26336A", "#3B4F9C", "#6680CC"]},
    "archer": {"hat": ["#35592C", "#4F8640", "#82BA62"]},
    "thief": {"hat": ["#222230", "#383850", "#56567A"], "neck": ["#4A2C73", "#6A43A0", "#9270C8"],
              "body_dark": 0.78},
}


def frame_box(cell: Image.Image):
    """모자 픽셀의 상자와 맨 윗줄."""
    xs, ys = [], []
    for y in range(PAD, PAD + 7):
        for x in range(CW):
            p = cell.getpixel((x, y))
            if p[3] >= 128 and p[:3] in HAT:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), max(xs), min(ys), max(ys)


def put(cell, x, y, c):
    if 0 <= x < CW and 0 <= y < CH + PAD:
        cell.putpixel((x, y), c)


def dress(cell: Image.Image, job: str, row: int) -> None:
    cfg = JOBS[job]
    box = frame_box(cell)
    if box is None:
        return
    x0, x1, top, _ = box
    cx = (x0 + x1) // 2
    # 몸이 숨쉬며 오르내린다 - 원래 맨 윗줄(1)에서 얼마나 내려왔나
    dy = top - (PAD + 1)
    back = 1 if row == 1 else 0           # 둘째 줄(옆모습)은 왼쪽을 본다 - 등은 오른쪽

    # 1) 모자 빛깔 바꾸기
    for y in range(PAD, PAD + 7 + dy):
        for x in range(CW):
            p = cell.getpixel((x, y))
            if p[3] >= 128 and p[:3] in HAT:
                cell.putpixel((x, y), tone(p, [hexc(h) for h in cfg["hat"]]))

    # 2) 몸 빛깔 (마법사 긴 옷 · 도적 어두운 옷)
    if "robe" in cfg:
        pal = [hexc(h) for h in cfg["robe"]]
        for y in range(PAD + 12 + dy, PAD + 22 + dy):
            for x in range(CW):
                p = cell.getpixel((x, y))
                if p[3] >= 128:
                    cell.putpixel((x, y), tone(p, pal))
        # 옷깃 금빛 한 줄
        for x in range(CW):
            p = cell.getpixel((x, PAD + 12 + dy))
            if p[3] >= 128 and x % 2 == 0:
                cell.putpixel((x, PAD + 12 + dy), hexc("#E8C25A"))
    if "body_dark" in cfg:
        k = cfg["body_dark"]
        for y in range(PAD + 12 + dy, PAD + 22 + dy):
            for x in range(CW):
                p = cell.getpixel((x, y))
                if p[3] >= 128:
                    cell.putpixel((x, y), (int(p[0] * k * 0.9), int(p[1] * k * 0.85), int(p[2] * k), 255))

    # 3) 목도리
    if "neck" in cfg:
        pal = [hexc(h) for h in cfg["neck"]]
        for y in (PAD + 10 + dy, PAD + 11 + dy):
            for x in range(CW):
                p = cell.getpixel((x, y))
                if p[3] >= 128:
                    cell.putpixel((x, y), pal[1] if y == PAD + 10 + dy else pal[0])
        if row == 1:   # 옆모습 - 꼬리가 등 뒤로 날린다
            ex = max(x for x in range(CW) if cell.getpixel((x, PAD + 11 + dy))[3] >= 128)
            put(cell, ex + 1, PAD + 11 + dy, pal[1])
            put(cell, ex + 2, PAD + 12 + dy, pal[0])

    # 4) 모자 위 장식
    if job == "warrior":
        red, dark = hexc("#D64545"), hexc("#8E2A2A")
        for i, (ox, oy) in enumerate([(0, -1), (0, -2), (back, -3), (back * 2, -3), (back * 3, -2)]):
            put(cell, cx + ox, top + oy, red if i % 2 == 0 else dark)
        if back == 0:
            put(cell, cx + 1, top - 2, dark)
            put(cell, cx - 1, top - 3, red)
        # 투구 이마 쇠줄
        for x in range(x0, x1 + 1):
            if cell.getpixel((x, top + 2))[3] >= 128 and cell.getpixel((x, top + 2))[:3] != (0, 0, 0):
                pass
    elif job == "mage":
        pal = [hexc(h) for h in JOBS["mage"]["hat"]]
        w = x1 - x0 + 1
        # 모자 챙을 양옆으로 한 칸씩 넓힌다
        for x in (x0 - 1, x1 + 1):
            put(cell, x, top + 3, pal[0])
        # 고깔: 위로 갈수록 좁아지고 끝이 등 쪽으로 꺾인다
        h = 6
        for k in range(1, h + 1):
            half = max(0, (w // 2) - (k * w) // (2 * h + 2))
            lean = (k * back) // 3
            for x in range(cx - half + lean, cx + half + 1 + lean):
                put(cell, x, top - k, pal[1] if x < cx + lean else pal[2])
        put(cell, cx + back * 2, top - h - 1, pal[1])
        put(cell, cx, top - 2, hexc("#FFE27A"))          # 별
    elif job == "archer":
        red, white = hexc("#D85A4A"), hexc("#F4EEDC")
        bx = x1 if back else cx + 2
        for i, (ox, oy) in enumerate([(0, 0), (1, -1), (1, -2), (2, -3)]):
            put(cell, bx + ox * (1 if back else 0) + (0 if back else ox // 2), top + oy, red if i < 2 else white)
        # 화살통
        brown, dbrown = hexc("#8A5A33"), hexc("#5E3A20")
        if row == 1:
            xs = [x for x in range(CW) if cell.getpixel((x, PAD + 13 + dy))[3] >= 128]
            qx = (max(xs) + 1) if xs else 13
            for y in range(PAD + 10 + dy, PAD + 18 + dy):
                put(cell, qx, y, brown)
                put(cell, qx - 1, y, dbrown if y % 3 == 0 else brown)
            put(cell, qx, PAD + 8 + dy, white)
            put(cell, qx - 1, PAD + 9 + dy, red)
            put(cell, qx, PAD + 9 + dy, white)
        elif row == 2:
            for k in range(9):
                put(cell, 6 + k // 2 + 1, PAD + 10 + dy + k, brown)
                put(cell, 7 + k // 2 + 1, PAD + 10 + dy + k, dbrown if k % 3 == 0 else brown)
            put(cell, 7, PAD + 9 + dy, white)
            put(cell, 8, PAD + 8 + dy, red)
        else:
            for k in range(6):                       # 앞모습: 가슴을 가로지르는 끈
                put(cell, 5 + k, PAD + 12 + dy + k, dbrown)
    elif job == "thief":
        pal = [hexc(h) for h in JOBS["thief"]["hat"]]
        kx = x1 + 1 if back else x1
        for ox, oy in [(0, 1), (1, 2), (2, 2), (1, 1), (2, 3)]:
            put(cell, kx + ox * (1 if back else 0), top + oy + (0 if back else 1), pal[1] if oy < 3 else pal[0])


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    assert src.size == (CW * 4, CH * 3), src.size
    for job in JOBS:
        out = Image.new("RGBA", (CW * 4, (CH + PAD) * 3), (0, 0, 0, 0))
        for row in range(3):
            for col in range(4):
                cell = Image.new("RGBA", (CW, CH + PAD), (0, 0, 0, 0))
                cell.paste(src.crop((col * CW, row * CH, (col + 1) * CW, (row + 1) * CH)), (0, PAD))
                dress(cell, job, row)
                out.paste(cell, (col * CW, row * (CH + PAD)))
        path = ROOT / f"assets/sprites/hero-{job}-walk.png"
        out.save(path)
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
