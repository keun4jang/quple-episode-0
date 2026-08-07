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

# 화면이 실제로 보는 세로 범위. side_episode.gd 의 카메라 설정에서 나온 값이다.
#   보이는 위쪽 = CAM_Y_MIN - 화면절반 = 300 - 540 = -240
#   보이는 아래쪽 = CAM_Y_MAX + 화면절반 = 560 + 540 = 1100
VIEW_TOP = -240
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
    ap.add_argument("--floor", type=float, default=0.82,
                    help="그림에서 바닥선이 위에서 몇 지점인가 (0~1, 기본 0.82)")
    ap.add_argument("--dim", type=float, default=1.0,
                    help="어둡게/밝게 (1.0 = 그대로)")
    a = ap.parse_args()

    src = Image.open(os.path.expanduser(a.file)).convert("RGBA")
    print(f"  받은 그림  {src.width}x{src.height}")

    # 세로 맞추기 — 그림의 바닥선이 화면의 바닥선과 겹치도록 키운다.
    view_h = VIEW_BOTTOM - VIEW_TOP
    floor_from_top = FLOOR_Y - VIEW_TOP          # 화면에서 바닥선까지
    # 그림에서 바닥선 위쪽이 차지하는 비율이 a.floor 이므로,
    # 그 부분이 floor_from_top 픽셀이 되도록 전체를 키운다.
    scale = floor_from_top / (src.height * a.floor)
    new_h = max(1, int(round(src.height * scale)))
    new_w = max(1, int(round(src.width * scale)))
    im = src.resize((new_w, new_h), Image.LANCZOS)

    # 화면이 보는 만큼만 남기고, 모자라면 위아래를 늘려 채운다.
    canvas = Image.new("RGBA", (new_w, view_h), (0, 0, 0, 255))
    canvas.paste(im, (0, 0), im)
    if new_h < view_h:
        # 아래가 비면 마지막 줄을 늘려 깐다. 바닥 아래는 어차피 안 보인다.
        tail = im.crop((0, new_h - 4, new_w, new_h)).resize((new_w, view_h - new_h))
        canvas.paste(tail, (0, new_h))
        print(f"  아래 {view_h - new_h}px 를 바닥색으로 채웠다")

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
