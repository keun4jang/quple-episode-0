#!/usr/bin/env python3
"""제미나이에서 받은 실내 배경 그림을 게임에 넣는다.

    python3 tools/side/import-indoor-bg.py --map office --file ~/사무실.png
    python3 tools/side/import-indoor-bg.py --map office --file ~/사무실.png --floor 0.78

하는 일:
  1. 바닥선이 화면의 제자리에 오도록 세로를 맞춘다
  2. 맵 길이만큼 좌우로 넓힌다 (거울처럼 이어 붙여 이음매를 감춘다)
  3. assets/side/<맵>-room.png 으로 저장한다

넣고 나면 게임이 알아서 코드로 그린 배경 대신 이 그림을 건다.
되돌리려면 파일만 지우면 된다.

**--floor 가 이 도구의 전부다.** 그림에서 바닥선(벽과 바닥이 만나는 줄)이
위에서 몇 % 지점에 있는지를 알려 주는 값이다. 이게 틀리면 캐릭터가
공중에 뜨거나 바닥에 묻힌다. 넣어 보고 어긋나면 이 값만 고쳐 다시 넣는다.
"""
import argparse
import os
from PIL import Image, ImageEnhance

OUT = "assets/side"

# 화면이 보는 세로 범위. side_episode.gd 의 카메라 설정에서 나온 값이다.
#   카메라가 제일 높이 올라갔을 때 = CAM_Y_MIN - 화면절반 = 300 - 540 = -240
#   카메라가 평소에 있을 때       = CAM_Y_MAX - 화면절반 = 560 - 540 =   20
#   아래쪽                        = CAM_Y_MAX + 화면절반 = 560 + 540 = 1100
VIEW_TOP = -240
NORMAL_TOP = 20
VIEW_BOTTOM = 1100
FLOOR_Y = 860

# 맵마다 필요한 그림 폭. 맵 길이 × 배경이 따라 흐르는 정도 + 화면 하나.
MAPS = {
    "front": 3600,
    "lobby": 3400,
    "office": 4200,
    "hallway": 3400,
}
PARALLAX = 0.40
SCREEN_W = 2600


def _rows(im, step=6):
    """줄마다 (평균색, 가로로 얼마나 들쭉날쭉한가) 를 잰다."""
    px = im.convert("RGB").load()
    w, h = im.size
    out = []
    for y in range(h):
        vals = [px[x, y] for x in range(0, w, step)]
        n = len(vals)
        m = tuple(sum(v[i] for v in vals) / n for i in range(3))
        var = sum((sum(v) - sum(m)) ** 2 for v in vals) / n
        out.append((m, var ** 0.5))
    return out


def trim_bands(im):
    """위아래에 덧대어진 단색 띠를 잘라낸다.

    이미지 모델은 요청한 비율을 맞추려고 위아래를 단색으로 채워 내보내는
    일이 잦다. 복도 그림이 그랬다 — 실제 복도는 가운데 60% 뿐이고 나머지는
    분홍빛 여백이었다. 그대로 넣으면 그 여백이 천장과 바닥 행세를 한다.

    잘라내는 기준은 두 가지를 **함께** 본다. 첫 줄과 색이 거의 같고,
    가로로도 거의 변화가 없는 줄. 하나만 보면 진짜 천장이나 카펫처럼
    고르게 칠해진 부분까지 잘려 나간다.
    """
    rows = _rows(im)
    h = len(rows)

    def flat_like(i, ref):
        m, var = rows[i]
        near = sum(abs(m[k] - ref[k]) for k in range(3)) < 9
        return near and var < 4.0

    top = 0
    while top < h - 2 and flat_like(top, rows[0][0]):
        top += 1
    bot = h - 1
    while bot > top + 2 and flat_like(bot, rows[h - 1][0]):
        bot -= 1
    if top == 0 and bot == h - 1:
        return im, 0, 0
    return im.crop((0, top, im.width, bot + 1)), top, h - 1 - bot


def find_floor(im):
    """벽과 바닥이 만나는 줄을 찾는다.

    화면 폭 전체를 가로지르는 가장 뚜렷한 가로 경계가 그것이다. 아래쪽
    절반에서만 찾는다 — 위쪽에는 천장선과 창틀이 있어서 더 셀 수 있다.
    """
    rows = _rows(im)
    h = len(rows)
    best, best_y = -1.0, None
    for y in range(int(h * 0.45), int(h * 0.97)):
        d = sum(abs(rows[y][0][k] - rows[y - 1][0][k]) for k in range(3))
        if d > best:
            best, best_y = d, y
    return (best_y / h) if best_y else None


def widen(im, target_w):
    """좌우로 거울처럼 이어 붙여 넓힌다. 그냥 반복하면 이음매가 딱 보인다."""
    if im.width >= target_w:
        return im.crop((0, 0, target_w, im.height))
    out = Image.new("RGBA", (target_w, im.height))
    x, flip = 0, False
    while x < target_w:
        tile = im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im
        out.paste(tile, (x, 0))
        x += im.width
        flip = not flip
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", required=True, choices=sorted(MAPS))
    ap.add_argument("--file", required=True)
    ap.add_argument("--floor", type=float, default=None,
                    help="바닥선이 위에서 몇 지점인가 (0~1). 안 주면 알아서 찾는다")
    ap.add_argument("--no-trim", action="store_true",
                    help="위아래 단색 여백을 잘라내지 않는다")
    ap.add_argument("--dim", type=float, default=1.0,
                    help="어둡게/밝게 (1.0 = 그대로)")
    a = ap.parse_args()

    src = Image.open(os.path.expanduser(a.file)).convert("RGBA")
    print(f"  받은 그림  {src.width}x{src.height}")

    if not a.no_trim:
        src, cut_top, cut_bot = trim_bands(src)
        if cut_top or cut_bot:
            print(f"  위아래 단색 여백을 잘랐다 (위 {cut_top}px, 아래 {cut_bot}px)"
                  f" → {src.width}x{src.height}")

    floor_frac = a.floor
    if floor_frac is None:
        floor_frac = find_floor(src) or 0.82
        print(f"  바닥선을 찾았다: 위에서 {floor_frac * 100:.1f}%")
    else:
        print(f"  바닥선: 위에서 {floor_frac * 100:.1f}% (직접 지정)")

    # 세로 맞추기 — 그림의 바닥선이 화면의 바닥선과 겹치도록 키운다.
    #
    # 기준을 **평소 카메라 높이**로 잡는다. 카메라가 제일 높이 올라갔을 때를
    # 기준으로 잡았더니 그림이 24% 더 커져서, 대부분의 시간 동안 천장이
    # 화면 위로 잘려 나갔다. 방인데 천장이 안 보이면 방으로 안 읽힌다.
    # 카메라가 올라가는 경우(로비 2층)는 위쪽을 늘려 메운다.
    view_h = VIEW_BOTTOM - VIEW_TOP
    floor_from_top = FLOOR_Y - NORMAL_TOP        # 평소 화면에서 바닥선까지
    scale = floor_from_top / (src.height * floor_frac)
    new_h = max(1, int(round(src.height * scale)))
    new_w = max(1, int(round(src.width * scale)))
    im = src.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (new_w, view_h), (0, 0, 0, 255))
    head = NORMAL_TOP - VIEW_TOP                 # 위로 남겨 둘 여백
    canvas.paste(im, (0, head), im)
    if head > 0:
        # 위를 첫 줄로 늘려 메운다. 카메라가 올라갔을 때만 보이는 자리다.
        cap = im.crop((0, 0, new_w, 4)).resize((new_w, head))
        canvas.paste(cap, (0, 0))
        print(f"  위 {head}px 를 천장색으로 늘렸다 (카메라가 올라갔을 때만 보인다)")
    bottom = head + new_h
    if bottom < view_h:
        tail = im.crop((0, new_h - 4, new_w, new_h)).resize((new_w, view_h - bottom))
        canvas.paste(tail, (0, bottom))
        print(f"  아래 {view_h - bottom}px 를 바닥색으로 늘렸다")

    if a.dim != 1.0:
        canvas = ImageEnhance.Brightness(canvas).enhance(a.dim)

    need_w = int(MAPS[a.map] * PARALLAX + SCREEN_W)
    canvas = widen(canvas, need_w)

    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/{a.map}-room.png"
    canvas.convert("RGB").save(path)
    print(f"  ✓ {path}  {canvas.width}x{canvas.height}")
    print(f"    바닥선이 어긋나 보이면 --floor 값을 조금 바꿔 다시 넣어라.")


if __name__ == "__main__":
    main()
