#!/usr/bin/env python3
"""그림 모델이 그린 원본(assets/source/lane)을 게임 그림(assets/sprites/lane-*.png)으로 바꾼다.

    python tools/art/import_lane_art.py bg 1 assets/source/lane/bg1_3.png     # 배경 1

픽셀 격자 맞추기: 원본을 폭 ART_W 칸으로 줄이고(평균) 색을 COLORS 개로 정리한다(디더 없음).
게임은 이 그림을 화면에 정수배(폭 720 이면 2배)로 이웃 보간해 깐다 - 픽셀 한 칸이 화면 2점.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(HERE, "..", "..", "assets", "sprites")
ART_W = 360
COLORS = 64


def pixelize(src: str, w: int) -> Image.Image:
    im = Image.open(src).convert("RGB")
    h = round(im.height * w / im.width)
    small = im.resize((w, h), Image.LANCZOS)
    q = small.quantize(colors=COLORS, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGB")


def cut_sprite(src: str, w: int, crop=None) -> Image.Image:
    """바탕을 빼고 물건만 잘라 폭 w 칸 픽셀 그림으로.

    바탕색은 모델이 마젠타를 정확히 안 지켜서(탁한 보라가 나온다) 가장자리에서 재고, 바깥에서부터
    그 색과 비슷한 칸을 이어서 지운다(flood fill) - 물건 안의 비슷한 색은 안 지워진다.
    crop = (x0, y0, x1, y1): 한 장에 여러 개가 그려졌을 때 쓸 것만 먼저 잘라낸다.
    """
    import numpy as np
    from PIL import ImageDraw, ImageFilter
    im = Image.open(src).convert("RGB")
    if crop:
        im = im.crop(crop)
    a = np.asarray(im).astype(np.int16)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    near = (np.abs(a - bg).sum(axis=2) < 70)
    # 바깥에서 이어진 '바탕 비슷한 칸' 만 - 마스크 그림에 테두리부터 칠해 본다
    m = Image.fromarray(np.where(near, 128, 0).astype("uint8"))
    m = m.crop((0, 0, m.width, m.height))
    pad = Image.new("L", (m.width + 2, m.height + 2), 128)
    pad.paste(m, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 255, thresh=0)
    outside = np.asarray(pad)[1:-1, 1:-1] == 255
    alpha = Image.fromarray(np.where(outside, 0, 255).astype("uint8")).filter(ImageFilter.MinFilter(3))
    rgba = im.convert("RGBA")
    rgba.putalpha(alpha)
    rgba = rgba.crop(alpha.getbbox())
    h = round(rgba.height * w / rgba.width)
    rgb = rgba.convert("RGB").resize((w, h), Image.LANCZOS)
    al = rgba.getchannel("A").resize((w, h), Image.BOX).point(lambda v: 255 if v > 140 else 0)
    q = rgb.quantize(colors=COLORS, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(al)
    return q


def main() -> None:
    kind, n, src = sys.argv[1], sys.argv[2], sys.argv[3]
    if kind == "bg":
        out = os.path.join(SPR, "lane-bg-%s.png" % n)
        pixelize(src, ART_W).save(out)
    elif kind == "sprite":
        # 예: sprite fort <원본> 120 [x0,y0,x1,y1]  → lane-fort.png (폭 120칸)
        out = os.path.join(SPR, "lane-%s.png" % n)
        crop = tuple(int(v) for v in sys.argv[5].split(",")) if len(sys.argv) > 5 else None
        cut_sprite(src, int(sys.argv[4]), crop).save(out)
    else:
        raise SystemExit("모르는 종류: " + kind)
    print("ok", out)


if __name__ == "__main__":
    main()
