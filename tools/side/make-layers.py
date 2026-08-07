#!/usr/bin/env python3
"""옆에서 본 맵의 배경 겹을 미리 만들어 둔다.

한 장을 게임 안에서 잡아 늘이면 뭉개진다. 겹마다 필요한 폭이 다르고
(멀수록 천천히 지나가니 덜 필요하다), 중간 겹은 윗변을 흐려야 하늘과
섞인다. 그건 실행 중에 할 일이 아니라 미리 해 둘 일이다.

    python3 tools/side/make-layers.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import os

OUT = "assets/side"
SRC = {"korea": "assets/travel/chapter-korea.png",
       "world": "assets/travel/chapter-world.png",
       "space": "assets/travel/chapter-space.png",
       "beyond": "assets/travel/chapter-beyond.png"}


def widen(im, target_w):
    """좌우로 거울처럼 이어 붙여 넓힌다. 그냥 반복하면 이음매가 딱 보인다."""
    out = Image.new("RGB", (target_w, im.height))
    x, flip = 0, False
    while x < target_w:
        tile = im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im
        out.paste(tile, (x, 0))
        x += im.width
        flip = not flip
    return out


def band(im, top, bot, w, h, blur=0, dark=1.0, sat=1.0):
    c = im.crop((0, int(im.height * top), im.width, int(im.height * bot)))
    c = c.resize((int(c.width * h / c.height), h), Image.LANCZOS)
    c = widen(c, w)
    if sat != 1.0: c = ImageEnhance.Color(c).enhance(sat)
    if dark != 1.0: c = ImageEnhance.Brightness(c).enhance(dark)
    if blur: c = c.filter(ImageFilter.GaussianBlur(blur))
    return c.convert("RGBA")


def fade_top(im, px):
    """윗변을 서서히 사라지게. 직선으로 끊기면 붙여 놓은 티가 난다."""
    a = Image.new("L", im.size, 255)
    d = ImageDraw.Draw(a)
    for i in range(px):
        d.line((0, i, im.width, i), fill=int(255 * (i / px) ** 1.4))
    im = im.copy(); im.putalpha(a)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, path in SRC.items():
        if not os.path.exists(path):
            print("  건너뜀", path); continue
        im = Image.open(path).convert("RGB")
        # 먼 겹 — 하늘과 산. 넓게 안 만들어도 된다, 천천히 지나가니까.
        sky = band(im, 0.00, 0.58, 3000, 1080, blur=4, dark=1.05, sat=0.58)
        sky.convert("RGB").save(f"{OUT}/{name}-sky.png")
        # 중간 겹 — 마을과 숲. 빨리 지나가니 훨씬 넓어야 한다.
        mid = band(im, 0.28, 0.82, 5600, 620, blur=1.0, dark=0.98, sat=0.95)
        fade_top(mid, 210).save(f"{OUT}/{name}-mid.png")
        print(f"  {name}: sky 3000x1080, mid 5600x620")


if __name__ == "__main__":
    main()
