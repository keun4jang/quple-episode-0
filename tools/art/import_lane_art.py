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
    # 바탕이 그러데이션일 때가 있다 - 줄마다 왼쪽·오른쪽 끝 색을 이어 붙여 바탕을 짐작한다
    hgt, wid = a.shape[:2]
    left = a[:, :12].mean(axis=1)
    right = a[:, -12:].mean(axis=1)
    t = np.linspace(0.0, 1.0, wid)[None, :, None]
    bg = left[:, None, :] * (1.0 - t) + right[:, None, :] * t
    near = (np.abs(a - bg).sum(axis=2) < 70)
    # 바깥에서 이어진 '바탕 비슷한 칸' 만 - 마스크 그림에 테두리부터 칠해 본다
    m = Image.fromarray(np.where(near, 128, 0).astype("uint8"))
    m = m.crop((0, 0, m.width, m.height))
    pad = Image.new("L", (m.width + 2, m.height + 2), 128)
    pad.paste(m, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 255, thresh=0)
    outside = np.asarray(pad)[1:-1, 1:-1] == 255
    # 팔·무기 사이에 갇힌 바탕 덩어리도 지운다 (바깥에서 칠해서는 안 닿는다) - 바탕색에 아주 가깝고 큰 것만
    from scipy import ndimage
    close = np.abs(a - bg).sum(axis=2) < 45
    lab, n = ndimage.label(close & ~outside)
    if n:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        big = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > a.shape[0] * a.shape[1] * 0.0015])
        outside |= big
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


def unit_sheet(src: str, w: int) -> Image.Image:
    """서 있는 앞모습 한 장 → 게임 캐릭터 시트 (4칸 x 3줄, 정사각 칸 - IdleActor 가 읽는 모양).

    0줄 앞모습: 서 있음 · 환호(위로 2칸) · 서 있음 · 아파함(아래로 1칸, 납작)
    1줄 공격:   서 있음 · 덤벼듦(아래로 3칸 = 앞) · 덤벼듦 · 돌아옴
    2줄 걷기:   들썩들썩 (0 · 위 1 · 0 · 위 1)
    움직임 대부분(늘림·눌림·덤벼들기)은 게임 코드가 한다 - 여기선 칸마다 살짝만 다르게.
    """
    sp = cut_sprite(src, w)
    side = max(sp.width, sp.height) + 6
    sheet = Image.new("RGBA", (side * 4, side * 3), (0, 0, 0, 0))
    base_x = (side - sp.width) // 2
    base_y = side - sp.height - 1
    offs = [[0, -2, 0, 1], [0, 3, 3, 1], [0, -1, 0, -1]]
    for r in range(3):
        for c in range(4):
            img = sp
            if r == 0 and c == 3:
                img = sp.resize((sp.width, max(1, sp.height - 2)), Image.NEAREST)
            sheet.alpha_composite(img, (c * side + base_x, r * side + base_y + offs[r][c] + (sp.height - img.height)))
    return sheet


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
    elif kind == "unit":
        # 예: unit tiny <원본> 30  → lane-unit-tiny.png (몸 폭 30칸). 진화는 이름을 tiny-2 로.
        out = os.path.join(SPR, "lane-unit-%s.png" % n)
        unit_sheet(src, int(sys.argv[4])).save(out)
    elif kind == "bug":
        out = os.path.join(SPR, "lane-bug-%s.png" % n)
        unit_sheet(src, int(sys.argv[4])).save(out)
    else:
        raise SystemExit("모르는 종류: " + kind)
    if kind in ("unit", "bug"):
        # 한 장을 비틀어 걷기·공격·맞음 칸을 만든다 (animate_sheets.py) - 안 하면 걸어도 서 있는 것처럼 보인다
        sys.path.insert(0, HERE)
        import animate_sheets
        animate_sheets.animate(out).save(out)
    print("ok", out)


if __name__ == "__main__":
    main()
