#!/usr/bin/env python3
"""물 타일의 흔들림 프레임을 만든다.

water*.png 마다 두 장을 더 만든다 (-wf2, -wf3). 밝은 픽셀(윤슬)의
일부만 좌우로 1px 씩 옮긴다 — 도넛처럼 감아서(torus) 가장자리가
이웃 칸과 어긋나지 않는다. 어두운 물 바탕은 그대로 두므로 멀리서
보면 반짝임만 살랑인다.

새 물 타일을 그리면 이 스크립트를 다시 돌리면 된다. 게임 쪽은
place.gd 의 _tick_water 가 -wf2/-wf3 유무만 보고 알아서 돌린다.
"""
import os
from PIL import Image

TILES = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tiles")


def luma(px):
    return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]


def make_frames(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    src = img.load()
    lums = sorted(luma(src[x, y]) for y in range(h) for x in range(w))
    # 상위 35% 밝기만 "윤슬"로 친다.
    cut = lums[int(len(lums) * 0.65)]

    def shifted(dx_for):
        out = Image.new("RGBA", (w, h))
        dst = out.load()
        for y in range(h):
            for x in range(w):
                dst[x, y] = src[x, y]
        for y in range(h):
            for x in range(w):
                px = src[x, y]
                if luma(px) < cut:
                    continue
                dx = dx_for(x, y)
                if dx == 0:
                    continue
                nx = (x + dx) % w  # torus — 이웃 칸과 이어진다
                # 옮긴 자리엔 윤슬을, 떠난 자리엔 이웃의 어두운 물을.
                dst[nx, y] = px
                back = src[(x - dx) % w, y]
                if luma(back) < cut:
                    dst[x, y] = back
        return out

    # 프레임 2: 짝수 줄 윤슬만 오른쪽으로. 프레임 3: 홀수 줄만 왼쪽으로.
    # 전부 같이 움직이면 타일이 통째로 미끄러져 보인다.
    f2 = shifted(lambda x, y: 1 if y % 2 == 0 else 0)
    f3 = shifted(lambda x, y: -1 if y % 2 == 1 else 0)
    base = path[:-4]
    f2.save(base + "-wf2.png")
    f3.save(base + "-wf3.png")
    print("만듦:", base + "-wf2.png", base + "-wf3.png")


for name in sorted(os.listdir(TILES)):
    if not name.endswith(".png") or "-wf" in name or "-fr-" in name:
        continue
    if name != "water.png" and not name.startswith("water-"):
        continue
    if not (name == "water.png" or name[6:-4].isdigit()):
        continue
    make_frames(os.path.join(TILES, name))
