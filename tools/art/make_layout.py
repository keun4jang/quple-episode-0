#!/usr/bin/env python3
"""배경 밑그림 - 그림 모델이 길·성 자리를 게임과 똑같이 그리도록 깔아 주는 색 덩어리 (img2img 의 시작 그림).

    python tools/art/make_layout.py bg1          # assets/source/lane/bg1_layout.png

구도는 게임(`LaneField`)과 같다 - 배경 높이의 비율:
  ROAD_TOP 0.18 (우리 성 앞, 좁다)  ~  ROAD_BOT 0.82 (둥지 앞, 넓다), 그 아래는 버튼 판에 덮인다.
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "source", "lane")
W, H = 768, 1344
ROAD_TOP, ROAD_BOT = 0.18, 0.82
TOP_W, BOT_W = 0.16, 0.62

## 구역별 밑색: 하늘 · 먼 풍경 · 땅 · 길 · 양옆 덩어리(나무 등)
THEMES = {
    "bg1": dict(sky="#BFE3F5", far="#9CC98A", ground="#7DBB55", road="#D9B07A", blobs=["#F2A9C8", "#E890B5"],
                blob_trunk="#7A5236", fence="#B08A5E"),
}


def road_half(y: float) -> float:
    t = min(1.0, max(0.0, (y / H - ROAD_TOP) / (ROAD_BOT - ROAD_TOP)))
    return W * (TOP_W + (BOT_W - TOP_W) * t) * 0.5


def make(jid: str) -> str:
    th = THEMES[jid]
    rnd = random.Random(7)
    im = Image.new("RGB", (W, H), th["ground"])
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, int(H * 0.08)], fill=th["sky"])
    d.rectangle([0, int(H * 0.08), W, int(H * 0.14)], fill=th["far"])
    # 길 (사다리꼴, 아래로 넓어진다) - 아래 끝은 화면 밖까지
    cx = W / 2
    pts_l, pts_r = [], []
    for i in range(41):
        y = H * ROAD_TOP + (H - H * ROAD_TOP) * i / 40
        hw = road_half(y)
        pts_l.append((cx - hw, y))
        pts_r.append((cx + hw, y))
    d.polygon(pts_l + pts_r[::-1], fill=th["road"])
    # 양옆 나무 덩어리 (길 위에는 안 놓는다)
    for _ in range(46):
        y = rnd.uniform(H * 0.13, H * 0.95)
        side = rnd.choice((-1, 1))
        gap = road_half(y) + rnd.uniform(30, 260)
        x = cx + side * gap
        r = rnd.uniform(28, 62) * (0.6 + 0.6 * y / H)
        if 0 - r < x < W + r:
            d.rectangle([x - r * 0.12, y, x + r * 0.12, y + r * 1.1], fill=th["blob_trunk"])
            # 잎 뭉치: 작은 원 여럿 (큰 원 하나면 모델이 꽃 한 송이로 그린다)
            for _k in range(9):
                ox, oy = rnd.uniform(-0.7, 0.7) * r, rnd.uniform(-0.8, 0.3) * r
                rr = r * rnd.uniform(0.35, 0.55)
                d.ellipse([x + ox - rr, y + oy - rr, x + ox + rr, y + oy + rr], fill=rnd.choice(th["blobs"]))
    # 낮은 울타리 (길 따라)
    for side in (-1, 1):
        pts = []
        for i in range(21):
            y = H * 0.3 + H * 0.5 * i / 20
            pts.append((cx + side * (road_half(y) + 18), y))
        d.line(pts, fill=th["fence"], width=8)
    # 잡티 - 단색 덩어리면 모델이 밋밋하게 그린다
    import numpy as np
    a = np.asarray(im).astype(np.int16)
    a += np.random.default_rng(3).integers(-22, 23, size=a.shape[:2])[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1))
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, "%s_layout.png" % jid)
    im.save(p)
    return p


if __name__ == "__main__":
    for j in sys.argv[1:] or ["bg1"]:
        print("ok", make(j))
