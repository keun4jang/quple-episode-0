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
    "bg2": dict(sky="#CFE6EE", far="#86B9A6", ground="#6FAE7E", road="#C9A878", blobs=["#7FC4D8", "#5FA7C4"],
                blob_trunk="#4E7A5A", fence="#8C7656"),
    "bg3": dict(sky="#F5DDEB", far="#C8A9D8", ground="#86BE62", road="#E0BC88", blobs=["#F7A8C4", "#C59AE6", "#FFE08A"],
                blob_trunk="#5E8A3E", fence="#B08A5E"),
    "bg4": dict(sky="#D7EAC8", far="#5E8F52", ground="#5C9A48", road="#B58C5E", blobs=["#3F7A3A", "#5A9A44"],
                blob_trunk="#5A3A24", fence="#7A5A3A"),
    "bg5": dict(sky="#3A3150", far="#4E4468", ground="#6B6380", road="#9A8C7A", blobs=["#B48AE6", "#8A6CC8"],
                blob_trunk="#3E3650", fence="#5E5470"),
    "bg6": dict(sky="#F5D2A8", far="#C9A37A", ground="#9AAE6A", road="#C2A07A", blobs=["#B8865A", "#8E9AA6", "#C9B27A"],
                blob_trunk="#6E5236", fence="#8A6A4A"),
    "bg7": dict(sky="#1E2450", far="#2E3A6A", ground="#2E5A4A", road="#6E6A8A", blobs=["#3E6A5A", "#FFE58A"],
                blob_trunk="#2A2A3A", fence="#4A4A6A"),
    "bg8": dict(sky="#5A4030", far="#7A5A40", ground="#8A6A4A", road="#C2A07A", blobs=["#E89A5A", "#9AD08A"],
                blob_trunk="#5A3A24", fence="#6E4A30"),
    "bg9": dict(sky="#F2E6D2", far="#D8C4A8", ground="#EDE3D3", road="#C9B8A0", blobs=["#FFFFFF", "#D8D0C4", "#E8C890"],
                blob_trunk="#B8A890", fence="#A89880"),
    "bg10": dict(sky="#2A3A30", far="#3A4A3E", ground="#4A5A4E", road="#6A6A62", blobs=["#6AE08A", "#4A8A6A"],
                 blob_trunk="#3A3A3A", fence="#5A5A5A"),
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
