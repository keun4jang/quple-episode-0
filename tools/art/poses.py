#!/usr/bin/env python3
"""캐릭터 동작 자세 6개를 OpenPose 막대 인형 그림으로 만든다 (ControlNet 이 이 자세대로 그린다).

    python tools/art/poses.py      # assets/source/lane/poses/<자세>.png  (1024x1024, 검은 바탕)

자세: stand · walk1(오른발 들기) · walk2(왼발 들기) · atk1(팔 들어 올림) · atk2(내려침, 앞으로 숙임) · atk3(마무리)
모든 캐릭터가 같은 틀을 쓴다 - 그래서 50종의 걷기·공격이 같은 박자로 맞는다.
관절 순서·색은 OpenPose(COCO 18) 표준 그대로.
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "source", "lane", "poses")

COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
          (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255),
          (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]
LIMBS = [(2, 3), (2, 6), (3, 4), (4, 5), (6, 7), (7, 8), (2, 9), (9, 10), (10, 11), (2, 12), (12, 13), (13, 14),
         (2, 1), (1, 15), (15, 17), (1, 16), (16, 18)]

# 0 코 1 목 2 오른어깨 3 오른팔꿈치 4 오른손목 5 왼어깨 6 왼팔꿈치 7 왼손목 8 오른엉덩이 9 오른무릎 10 오른발목
# 11 왼엉덩이 12 왼무릎 13 왼발목 14 오른눈 15 왼눈 16 오른귀 17 왼귀  (그림의 왼쪽이 캐릭터의 오른쪽 - 앞을 본다)
STAND = {0: (512, 330), 1: (512, 440), 2: (448, 460), 3: (418, 550), 4: (418, 630), 5: (576, 460), 6: (606, 550),
         7: (606, 630), 8: (474, 630), 9: (468, 740), 10: (468, 850), 11: (550, 630), 12: (556, 740),
         13: (556, 850), 14: (480, 305), 15: (544, 305), 16: (436, 300), 17: (588, 300)}


def pose(name: str) -> dict:
    p = dict(STAND)
    if name == "walk1":      # 오른발 들고 왼팔 앞으로
        p.update({9: (462, 700), 10: (470, 790), 7: (590, 600), 6: (600, 530), 4: (430, 650)})
    elif name == "walk2":    # 왼발 들고 오른팔 앞으로
        p.update({12: (562, 700), 13: (554, 790), 4: (434, 600), 3: (424, 530), 7: (594, 650)})
    elif name == "atk1":     # 오른팔을 머리 위로 - 몸은 살짝 뒤로
        p = {k: (x, y - 10) for k, (x, y) in p.items()}
        p.update({3: (400, 380), 4: (430, 270), 10: (468, 850), 13: (556, 850)})
    elif name == "atk2":     # 내려침 - 앞으로 숙이며 팔이 몸 앞을 가로지른다
        p = {k: (x, y + (24 if k in (0, 1, 2, 5, 14, 15, 16, 17) else 0)) for k, (x, y) in p.items()}
        p.update({3: (470, 560), 4: (560, 650), 9: (460, 730), 10: (450, 850), 12: (566, 720), 13: (580, 850)})
    elif name == "atk3":     # 마무리 - 팔이 아래에 남는다
        p = {k: (x, y + (10 if k in (0, 1, 2, 5, 14, 15, 16, 17) else 0)) for k, (x, y) in p.items()}
        p.update({3: (450, 580), 4: (500, 690)})
    return p


def draw(points: dict) -> Image.Image:
    im = Image.new("RGB", (1024, 1024), (0, 0, 0))
    over = Image.new("RGB", (1024, 1024), (0, 0, 0))
    d = ImageDraw.Draw(over)
    for i, (a, b) in enumerate(LIMBS):
        (x1, y1), (x2, y2) = points[a - 1], points[b - 1]
        length = math.hypot(x2 - x1, y2 - y1)
        ang = math.atan2(y2 - y1, x2 - x1)
        w = 10
        pts = []
        for t in range(24):
            th = 2 * math.pi * t / 24
            ex, ey = length / 2 * math.cos(th), w * math.sin(th)
            pts.append(((x1 + x2) / 2 + ex * math.cos(ang) - ey * math.sin(ang),
                        (y1 + y2) / 2 + ex * math.sin(ang) + ey * math.cos(ang)))
        d.polygon(pts, fill=COLORS[i])
    im = Image.blend(im, over, 0.6)
    d = ImageDraw.Draw(im)
    for k, (x, y) in points.items():
        d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=COLORS[k])
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n in ("stand", "walk1", "walk2", "atk1", "atk2", "atk3"):
        draw(pose(n)).save(os.path.join(OUT, n + ".png"))
        print("ok", n)
