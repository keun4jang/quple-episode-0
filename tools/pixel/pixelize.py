#!/usr/bin/env python3
"""이 게임의 그림을 픽셀 화풍으로 바꾼다.

    python3 tools/pixel/pixelize.py --preview

**색은 지금 게임에서 뽑아 쓴다.** 화풍을 바꾸는 것이지 게임을 바꾸는 것이
아니다 — 크림·황금·카키·캐러멜이라는 이 게임의 얼굴은 픽셀이 되어도 남아야
한다. 그래서 팔레트를 새로 고르지 않고 기존 에셋에서 모은다.

방법은 세 걸음이다.
  ① 작게 줄인다      — 픽셀 화풍의 본질은 "픽셀이 크다" 가 아니라 **적다** 는 것
  ② 색을 줄인다      — 부드러운 그러데이션이 남아 있으면 축소한 사진처럼 보인다
  ③ 크게 되돌린다    — 이웃 보간으로. 부드럽게 늘리면 다시 흐릿해진다
"""
import argparse
import os
from PIL import Image

# 화면 기준 해상도. 2400x1080 을 5로 나눈 값이라 딱 떨어진다.
BASE_W, BASE_H = 480, 216
# 캐릭터 키(기준 해상도에서). 지금 게임의 비율(화면의 약 16%)을 지킨다.
CHAR_H = 36

## 팔레트를 뽑아 올 그림들. 게임의 얼굴이 담긴 것만 고른다.
PALETTE_SOURCES = [
    "assets/mascots/sheet/leader-front.png",
    "assets/mascots/sheet/partner-front.png",
    "assets/travel/chapter-korea.png",
    "assets/travel/hub-bg.png",
]
PALETTE_SIZE = 32


def build_palette(size: int = PALETTE_SIZE) -> Image.Image:
    """기존 에셋에서 대표색을 모은다."""
    tiles = []
    for p in PALETTE_SOURCES:
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB").resize((64, 64), Image.LANCZOS)
        tiles.append(im)
    if not tiles:
        raise SystemExit("팔레트를 뽑을 그림이 없다")
    sheet = Image.new("RGB", (64 * len(tiles), 64))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * 64, 0))
    return sheet.quantize(colors=size, method=Image.MEDIANCUT)


def pixelize(im: Image.Image, target_w: int, pal: Image.Image) -> Image.Image:
    """작게 줄이고, 팔레트에 맞추고, 그대로 둔다 (확대는 부르는 쪽에서)."""
    has_alpha = im.mode == "RGBA"
    w = target_w
    h = max(1, round(im.height * target_w / im.width))
    small = im.resize((w, h), Image.BOX)      # BOX = 면적 평균. 점 하나가 또렷하다
    if has_alpha:
        alpha = small.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        rgb = small.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")
        out = rgb.convert("RGBA")
        out.putalpha(alpha)
        return out
    return small.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")


def outline(im: Image.Image, col=(38, 28, 34, 255)) -> Image.Image:
    """캐릭터에 1px 테두리를 두른다.

    픽셀 캐릭터가 배경에서 읽히는 것은 대개 색이 아니라 이 한 줄 덕이다.
    없으면 배경과 같은 명도에서 실루엣이 녹는다.
    """
    w, h = im.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    a = im.getchannel("A")
    ring = Image.new("RGBA", out.size, (0, 0, 0, 0))
    for dx, dy in [(0, 1), (2, 1), (1, 0), (1, 2), (0, 0), (2, 0), (0, 2), (2, 2)]:
        layer = Image.new("RGBA", out.size, col)
        m = Image.new("L", out.size, 0)
        m.paste(a, (dx, dy))
        ring.paste(layer, (0, 0), m)
    out.paste(ring, (0, 0))
    out.paste(im, (1, 1), im)
    return out


def upscale(im: Image.Image, factor: int) -> Image.Image:
    return im.resize((im.width * factor, im.height * factor), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true", help="미리보기 화면을 만든다")
    ap.add_argument("--out", default="/tmp/pixel")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    pal = build_palette()
    print(f"  팔레트 {PALETTE_SIZE}색 (기존 에셋에서 뽑음)")

    # 캐릭터
    for who in ["leader", "partner"]:
        for view in ["front", "side"]:
            src = f"assets/mascots/sheet/{who}-{view}.png"
            if not os.path.exists(src):
                continue
            im = Image.open(src).convert("RGBA")
            w = max(1, round(CHAR_H * im.width / im.height))
            px = outline(pixelize(im, w, pal))
            px.save(f"{a.out}/{who}-{view}.png")
            upscale(px, 8).save(f"{a.out}/{who}-{view}@8.png")
            print(f"  {who}-{view}  {px.width}x{px.height}")

    # 배경
    for name, src in [("korea", "assets/travel/chapter-korea.png"),
                      ("office", "assets/side/office-room.png"),
                      ("hub", "assets/travel/hub-bg.png")]:
        if not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGB")
        px = pixelize(im, BASE_W, pal)
        px.save(f"{a.out}/bg-{name}.png")
        print(f"  bg-{name}  {px.width}x{px.height}")

    if a.preview:
        _preview(a.out, pal)


def _preview(out: str, pal):
    """게임 화면처럼 조립해 본다. 조각만 봐서는 어울리는지 알 수 없다."""
    bg = Image.open(f"{out}/bg-korea.png").convert("RGBA")
    canvas = bg.crop((0, 0, BASE_W, BASE_H)).copy()
    ground = int(BASE_H * 0.80)
    # 땅
    for y in range(ground, BASE_H):
        t = (y - ground) / max(1, BASE_H - ground)
        col = (int(150 - 40 * t), int(196 - 70 * t), int(124 - 50 * t), 255)
        for x in range(BASE_W):
            canvas.putpixel((x, y), col)
    for x in range(BASE_W):
        canvas.putpixel((x, ground), (232, 244, 200, 255))

    for who, x in [("leader", 200), ("partner", 236)]:
        s = Image.open(f"{out}/{who}-side.png").convert("RGBA")
        canvas.alpha_composite(s, (x, ground - s.height + 1))
    upscale(canvas, 5).save(f"{out}/preview.png")
    print(f"  ✓ 미리보기 {out}/preview.png  ({BASE_W}x{BASE_H} → 5배)")


if __name__ == "__main__":
    main()
