#!/usr/bin/env python3
"""'진짜 행복' 로고를 그린다 - 무료 글꼴(OFL) + 직접 그린 도형만. 그림 모델을 쓰지 않는다.

    .sdenv/Scripts/python.exe tools/splash/make-logo.py [A|B|C] [출력.png]

기본은 D (분홍→라벤더 채움 + 통통 튀는 글자, 얼굴 없음) → assets/splash/logo-happy.png (투명 바탕, 폭 1200).
색: 키 컬러 라벤더 #BF94E4 · 포인트 벚꽃 분홍 #F7A8C4 (노랑은 쓰지 않는다).
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = {"jua": os.path.join(ROOT, "assets/fonts/Jua.ttf"),
         "black": os.path.join(ROOT, "assets/fonts/BlackHanSans.ttf")}

LAV = (191, 148, 228)
LAV_DK = (122, 86, 176)
PLUM = (74, 46, 94)
PINK = (247, 168, 196)
PINK_DK = (217, 112, 143)
WHITE = (255, 255, 255)
BROWN = (196, 132, 82)
BROWN_DK = (120, 74, 46)
CREAM = (250, 228, 200)

W, H = 1200, 520


## 글자마다 기울기(도)와 위아래 튐(점) - 통통 튀는 느낌 (D 시안)
# 기울기는 뺐다 (2026-11 아트 검토) - 진 -5° / 짜 +4° 라 "진" 의 ㅣ 가 비스듬히 짜에 붙어 빗금처럼 읽혔다.
# 위아래 튐만 남긴다.
BOUNCE = {"진": (0, 6), "짜": (0, -8), "행": (0, -4), "복": (0, 6)}


def text_mask(txt, font, size, xy, spacing=0, bounce=False):
    m = Image.new("L", (W, H), 0)
    f = ImageFont.truetype(font, size)
    x, y = xy
    for ch in txt:
        adv = f.getlength(ch)
        if ch != " ":
            g = Image.new("L", (int(adv) + 80, size + 120), 0)
            ImageDraw.Draw(g).text((40, 40), ch, font=f, fill=255)
            ang, dy = BOUNCE.get(ch, (0, 0)) if bounce else (0, 0)
            if ang:
                g = g.rotate(ang, resample=Image.BICUBIC, center=(40 + adv / 2, 40 + size * 0.6))
            m.paste(255, (int(x) - 40, int(y) - 40 + dy), g)
        x += adv + spacing
    return m


def grow(mask, r):
    return mask.filter(ImageFilter.MaxFilter(r * 2 + 1)) if r > 0 else mask


def fill(mask, col):
    im = Image.new("RGBA", (W, H), col + (255,))
    im.putalpha(mask)
    return im


def vgrad(mask, top, bot, y0, y1):
    g = Image.new("RGBA", (W, H))
    px = g.load()
    for y in range(H):
        t = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(W):
            px[x, y] = c
    g.putalpha(mask)
    return g


def bbox_y(mask):
    b = mask.getbbox()
    return (b[1], b[3]) if b else (0, H)


def sparkle(d, cx, cy, r, col):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=col)


def heart(d, cx, cy, s, col):
    d.ellipse((cx - s, cy - s * 0.7, cx, cy + s * 0.3), fill=col)
    d.ellipse((cx, cy - s * 0.7, cx + s, cy + s * 0.3), fill=col)
    d.polygon([(cx - s * 0.98, cy - s * 0.1), (cx + s * 0.98, cy - s * 0.1), (cx, cy + s * 1.05)], fill=col)


def quokka(im, cx, cy, r):
    """웃는 쿼카 얼굴 (테두리 → 귀 → 얼굴 → 주둥이 → 눈 → 코 → 웃음 → 볼)."""
    d = ImageDraw.Draw(im)
    o = max(4, int(r * 0.09))
    for ex in (-0.62, 0.62):  # 귀
        ecx, ecy = cx + ex * r, cy - 0.72 * r
        d.ellipse((ecx - r * 0.36 - o, ecy - r * 0.36 - o, ecx + r * 0.36 + o, ecy + r * 0.36 + o), fill=PLUM)
    d.ellipse((cx - r - o, cy - r * 0.92 - o, cx + r + o, cy + r * 0.92 + o), fill=PLUM)
    for ex in (-0.62, 0.62):
        ecx, ecy = cx + ex * r, cy - 0.72 * r
        d.ellipse((ecx - r * 0.36, ecy - r * 0.36, ecx + r * 0.36, ecy + r * 0.36), fill=BROWN)
        d.ellipse((ecx - r * 0.2, ecy - r * 0.2, ecx + r * 0.2, ecy + r * 0.2), fill=PINK)
    d.ellipse((cx - r, cy - r * 0.92, cx + r, cy + r * 0.92), fill=BROWN)
    d.ellipse((cx - r * 0.62, cy - r * 0.05, cx + r * 0.62, cy + r * 0.8), fill=CREAM)  # 주둥이
    for ex in (-0.38, 0.38):  # 눈
        d.ellipse((cx + ex * r - r * 0.11, cy - r * 0.3, cx + ex * r + r * 0.11, cy - r * 0.04), fill=PLUM)
        d.ellipse((cx + ex * r - r * 0.04, cy - r * 0.26, cx + ex * r + r * 0.03, cy - r * 0.18), fill=WHITE)
    d.ellipse((cx - r * 0.13, cy + r * 0.12, cx + r * 0.13, cy + r * 0.3), fill=PLUM)  # 코
    d.arc((cx - r * 0.34, cy + r * 0.12, cx + r * 0.34, cy + r * 0.62), 20, 160, fill=PLUM, width=max(3, int(r * 0.08)))
    for ex in (-0.66, 0.66):  # 볼
        d.ellipse((cx + ex * r - r * 0.15, cy + r * 0.12, cx + ex * r + r * 0.15, cy + r * 0.3), fill=PINK)


def build(variant="A"):
    font = FONTS["black"] if variant == "B" else FONTS["jua"]
    bounce = variant == "D"
    size = 210 if variant != "B" else 196
    spacing = 18 if variant == "D" else (6 if variant != "B" else 10)  # D: 글자 사이를 띄워 ㅣ 가 옆 글자에 안 붙게
    # 가운데 맞추기: 먼저 그려 폭을 잰다
    probe = text_mask("진짜 행복", font, size, (60, 60), spacing, bounce)
    b = probe.getbbox()
    tw, th = b[2] - b[0], b[3] - b[1]
    x0 = (W - tw) // 2 - (b[0] - 60) + (30 if variant in ("A", "D") else 0)
    y0 = (H - th) // 2 - (b[1] - 60) + 20
    m = text_mask("진짜 행복", font, size, (x0, y0), spacing, bounce)
    ya, yb = bbox_y(m)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # 그림자 (자두색, 아래로) → 진한 라벤더 굵은 테두리 → 흰 안쪽 테두리 → 채움
    ow, iw = (17, 8) if variant == "D" else (22, 11)   # D 는 'ㅇ' 구멍이 막히지 않게 조금 얇게
    shadow = grow(m, ow)
    out.alpha_composite(fill(ImageChops.offset(shadow, 0, 14), PLUM))
    out.alpha_composite(fill(grow(m, ow), LAV_DK))
    out.alpha_composite(fill(grow(m, iw), WHITE))
    if variant in ("C", "D"):
        out.alpha_composite(vgrad(m, (255, 214, 230) if variant == "D" else PINK, LAV, ya, yb))
    else:
        out.alpha_composite(vgrad(m, WHITE, PINK, ya + (yb - ya) * 0.35, yb))
    # 위쪽 반짝임: 글자 윗부분에만 흰 띠
    gl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(gl).rectangle((0, ya + 8, W, ya + (yb - ya) * (0.18 if variant == "D" else 0.3)), fill=90 if variant == "D" else 150)
    gl = ImageChops.multiply(gl, m.filter(ImageFilter.MinFilter(9)))
    out.alpha_composite(fill(gl, WHITE))
    d = ImageDraw.Draw(out)
    b2 = m.getbbox()
    if variant == "A":   # D 는 얼굴 없이 (곰처럼 보였다)
        quokka(out, b2[0] - 58, ya - 4, 62)       # "진" 왼쪽 위에서 빼꼼
    sparkle(d, b2[2] + 34, ya - 6, 34, PINK)
    sparkle(d, b2[2] + 6, ya - 46, 18, LAV)
    sparkle(d, b2[0] + (tw * 0.47), ya - 40, 20, WHITE)
    heart(d, b2[2] - 20, yb + 30, 22, PINK_DK)
    if variant not in ("A", "D"):
        sparkle(d, b2[0] - 30, yb - 20, 26, LAV)
    # 바깥 가장자리 부드럽게 (투명 바탕 위 계단 줄이기)
    return out.crop(out.getbbox())


def main():
    v = sys.argv[1] if len(sys.argv) > 1 else "D"
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets/splash/logo-happy.png")
    im = build(v)
    im.save(dst)
    print("saved", dst, im.size)


if __name__ == "__main__":
    main()
