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


def regen_sheet(prefix: str, target_h: int) -> Image.Image:
    """동작마다 새로 생성한 그림 6장(regen/<prefix>_<자세>_0.png) → 게임 시트 (4칸 x 3줄).
    0줄: 서기 · 환호(공격 준비 그림) · 서기 · 맞음  1줄 공격: 준비 · 내려침 · 마무리 · 서기  2줄 걷기: 서기 · 왼발 · 서기 · 오른발
    크기는 몸 높이로 맞춘다 (자세마다 무기 때문에 폭이 달라서)."""
    d = os.path.join(HERE, "..", "..", "assets", "source", "lane", "regen")
    fr = {p: cut_sprite(os.path.join(d, "%s_%s_0.png" % (prefix, p)), 0, target_h=target_h)
          for p in ("stand", "walk1", "walk2", "atk1", "atk2", "atk3")}
    side = max(max(f.width, f.height) for f in fr.values()) + 8
    sheet = Image.new("RGBA", (side * 4, side * 3), (0, 0, 0, 0))

    def cell(img):
        c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        c.alpha_composite(img, ((side - img.width) // 2, side - img.height - 2))
        return c
    st = cell(fr["stand"])
    rows = [[st, cell(fr["atk1"]), st, _hurt(st)],
            [cell(fr["atk1"]), cell(fr["atk2"]), cell(fr["atk3"]), st],
            [st, cell(fr["walk1"]), st, cell(fr["walk2"])]]
    for r in range(3):
        for c in range(4):
            sheet.alpha_composite(rows[r][c], (c * side, r * side))
    return sheet


BODY_H = {"unit-giant": 72, "unit-mage": 50, "unit-shield": 52, "unit-turtle": 50}


def sheet_height(path: str) -> int:
    """지금 시트의 서 있는 칸 몸 높이 - 새로 만들 때 크기를 맞춘다."""
    im = Image.open(path).convert("RGBA")
    c = im.crop((0, 0, im.width // 4, im.height // 3))
    t, b, _x0, _x1 = _rows(c)
    return b - t + 1


def cut_sprite(src: str, w: int, crop=None, target_h: int = 0) -> Image.Image:
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
    if target_h:
        h = target_h
        w = max(1, round(rgba.width * target_h / rgba.height))
    else:
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
    side = max(sp.width, sp.height) + 16
    sheet = Image.new("RGBA", (side * 4, side * 3), (0, 0, 0, 0))
    # 칸 안에 발끝을 맞춰 놓은 그림 (칸 크기 캔버스)
    base = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    base.alpha_composite(sp, ((side - sp.width) // 2, side - sp.height - 2))
    frames = [
        [base, _cheer(base), base, _hurt(base)],
        [_attack(base, 11, False), _attack(base, -15, True), _attack(base, -7, False), base],
        [base, _walk(base, "L"), base, _walk(base, "R")],
    ]
    for r in range(3):
        for c in range(4):
            sheet.alpha_composite(frames[r][c], (c * side, r * side))
    return sheet


# ── 부위별 동작 ─ 한 장을 통째로 옮기지 않는다: 발·상체를 떼어 칸마다 다른 자세로 다시 놓는다 ──────────

def _rows(img: Image.Image):
    import numpy as np
    a = np.asarray(img.getchannel("A")) > 0
    ys = np.where(a.any(axis=1))[0]
    xs = np.where(a.any(axis=0))[0]
    return int(ys[0]), int(ys[-1]), int(xs[0]), int(xs[-1])


def _band(img: Image.Image, y0: int, y1: int) -> Image.Image:
    """y0 <= y < y1 줄만 남긴 그림."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.crop((0, y0, img.width, y1)), (0, y0))
    return out


def _walk(img: Image.Image, foot: str) -> Image.Image:
    """걷기: 한쪽 발을 들어 올리고(3칸) 몸은 그쪽으로 살짝 기울며 들썩인다."""
    top, bot, x0, x1 = _rows(img)
    h = bot - top + 1
    feet_y = top + int(h * 0.88)
    cx = (x0 + x1) // 2
    upper = _band(img, 0, feet_y)
    feet = _band(img, feet_y, img.height)
    left = feet.crop((0, 0, cx, img.height))
    right = feet.crop((cx, 0, img.width, img.height))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    lift_l, lift_r = (-3, 0) if foot == "L" else (0, -3)
    out.alpha_composite(left, (-1 if foot == "L" else 0, lift_l))
    out.alpha_composite(right, (cx + (1 if foot == "R" else 0), lift_r))
    ang = 2 if foot == "L" else -2
    body = upper.rotate(ang, resample=Image.NEAREST, center=(cx, feet_y))
    out.alpha_composite(body)
    return out


def _attack(img: Image.Image, angle: float, swoosh: bool) -> Image.Image:
    """공격: 다리는 땅에 두고 허리 위 상체만 젖히거나(준비) 휘두른다(내려침). 내려칠 땐 휘두른 궤적을 긋는다."""
    import math
    from PIL import ImageDraw
    top, bot, x0, x1 = _rows(img)
    h = bot - top + 1
    waist = top + int(h * 0.64)
    cx = (x0 + x1) // 2
    lower = _band(img, waist, img.height)
    upper = _band(img, 0, waist)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(lower)
    # 허리 이음매가 비지 않게 아래 몸을 두 줄 위로 한 번 더 깐다
    out.alpha_composite(_band(img, waist - 2, waist + 2))
    body = upper.rotate(angle, resample=Image.NEAREST, center=(cx, waist))
    out.alpha_composite(body, (0, 2 if angle < 0 else -1))
    if swoosh:
        d = ImageDraw.Draw(out)
        r = h * 0.55
        for k, col in ((0, (255, 255, 255, 230)), (2, (255, 236, 160, 200))):
            pts = [(cx + (r - k) * math.cos(math.radians(a)), waist - (r - k) * math.sin(math.radians(a)))
                   for a in range(150, 20, -6)]
            d.line(pts, fill=col, width=2)
    return out


def _cheer(img: Image.Image) -> Image.Image:
    top, bot, x0, x1 = _rows(img)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(_band(img, 0, img.height), (0, -3))
    return out


def _hurt(img: Image.Image) -> Image.Image:
    """맞음: 눌리고 붉어진다."""
    top, bot, x0, x1 = _rows(img)
    sq = img.resize((img.width + 2, max(1, img.height - 4)), Image.NEAREST)
    red = Image.new("RGBA", sq.size, (255, 80, 90, 0))
    a = sq.getchannel("A").point(lambda v: 90 if v else 0)
    red.putalpha(a)
    sq.alpha_composite(red)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(sq.crop((1, 0, img.width + 1, sq.height)), (0, 4))
    return out


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
    elif kind == "regen":
        # 예: regen unit-spear q_spear  → lane-unit-spear.png 를 새로 생성한 동작 6장으로 (키는 지금 시트 그대로)
        out = os.path.join(SPR, "lane-%s.png" % n)
        base = n[:-2] if n.endswith("-2") else n
        # 몸 키 - 옛 시트에서 물려받은 키가 이름과 안 맞는 것만 정해 둔다 (거대 쿼카가 망치 쿼카보다 작았다)
        h = BODY_H.get(base) or sheet_height(os.path.join(SPR, "lane-%s.png" % base))
        if n.endswith("-2"):    # 진화한 모습 - 기본보다 15% 크게
            h = int(round(h * 1.15))
        regen_sheet(src, h).save(out)
    else:
        raise SystemExit("모르는 종류: " + kind)
    print("ok", out)


if __name__ == "__main__":
    main()
