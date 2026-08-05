#!/usr/bin/env python3
"""쿼플 앱 아이콘 생성기.

외부 에셋을 쓰지 않는다는 규칙 때문에 아이콘도 전부 도형으로 그린다.
쿼카 얼굴을 정면에서 단순화하고, 파스텔 우주 배경 + 산호색 스카프를 얹는다.

사용법:
    python3 tools/icon/gen_icon.py
    python3 tools/icon/gen_icon.py --out assets/icon
"""

import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFilter

# 게임 강조색(산호색)과 쿼카 톤. 배경은 밤하늘 파스텔 보라~남색.
CORAL = (255, 111, 97)
CORAL_DARK = (214, 78, 66)
FUR = (214, 168, 122)
FUR_DARK = (183, 136, 94)
FUR_LIGHT = (240, 208, 168)
NOSE = (94, 62, 52)
EYE = (58, 42, 40)
CHEEK = (245, 150, 150)
BG_IN = (150, 138, 214)
BG_OUT = (74, 62, 122)

# 렌더는 항상 큰 캔버스에서 하고 축소한다(안티에일리어싱 대용).
SS = 4


def _radial_bg(size: int) -> Image.Image:
    """원형 파스텔 그러데이션 배경. 픽셀 루프 대신 동심원으로 그려 빠르게 처리."""
    img = Image.new("RGB", (size, size), BG_OUT)
    d = ImageDraw.Draw(img)
    c = size / 2
    steps = 96
    for i in range(steps, 0, -1):
        t = i / steps
        r = c * 1.45 * t
        col = tuple(int(BG_OUT[k] + (BG_IN[k] - BG_OUT[k]) * (1.0 - t) ** 0.85) for k in range(3))
        d.ellipse([c - r, c - r, c + r, c + r], fill=col)
    return img


def _stars(d: ImageDraw.ImageDraw, size: int) -> None:
    """작은 별 몇 개. 64px 에서 뭉개지지 않게 개수를 적게, 가장자리에만 배치."""
    pts = [(0.16, 0.20, 0.020), (0.84, 0.17, 0.016), (0.90, 0.52, 0.013),
           (0.11, 0.58, 0.014), (0.26, 0.09, 0.011), (0.72, 0.08, 0.012)]
    for x, y, r in pts:
        cx, cy, rr = x * size, y * size, r * size
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, 250, 235))
        # 십자 반짝임
        d.line([cx - rr * 2.6, cy, cx + rr * 2.6, cy], fill=(255, 250, 235, 255), width=max(1, int(rr * 0.5)))
        d.line([cx, cy - rr * 2.6, cx, cy + rr * 2.6], fill=(255, 250, 235, 255), width=max(1, int(rr * 0.5)))


def _ellipse(d, cx, cy, rx, ry, **kw):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], **kw)


def draw_icon(size: int) -> Image.Image:
    S = size * SS
    img = _radial_bg(S).convert("RGBA")
    d = ImageDraw.Draw(img)
    _stars(d, S)

    # 안전영역: 얼굴은 캔버스의 가운데 ~62% 안에만 그린다.
    fx, fy = S * 0.5, S * 0.47
    fr = S * 0.29

    # 귀 (얼굴보다 먼저 그려 뒤로 보내기)
    for sx in (-1, 1):
        ex = fx + sx * fr * 0.78
        ey = fy - fr * 0.72
        _ellipse(d, ex, ey, fr * 0.32, fr * 0.40, fill=FUR_DARK)
        _ellipse(d, ex, ey + fr * 0.02, fr * 0.19, fill=CORAL_DARK, ry=fr * 0.25)

    # 스카프 (얼굴 아래, 목 부분) — 강조색이라 실루엣에서 바로 읽히게 두껍게
    sy = fy + fr * 0.92
    _ellipse(d, fx, sy, fr * 0.86, fr * 0.30, fill=CORAL)
    _ellipse(d, fx, sy - fr * 0.10, fr * 0.86, fr * 0.20, fill=(255, 138, 125))
    # 매듭 + 늘어진 끝
    d.polygon([(fx + fr * 0.30, sy), (fx + fr * 0.86, sy + fr * 0.10),
               (fx + fr * 0.70, sy + fr * 0.58), (fx + fr * 0.34, sy + fr * 0.30)], fill=CORAL_DARK)

    # 얼굴
    _ellipse(d, fx, fy, fr, fr * 0.94, fill=FUR)
    # 주둥이 밝은 영역
    _ellipse(d, fx, fy + fr * 0.30, fr * 0.52, fr * 0.38, fill=FUR_LIGHT)

    # 눈 — 작은 크기에서 살아남게 크고 검게
    ey = fy - fr * 0.10
    for sx in (-1, 1):
        exx = fx + sx * fr * 0.40
        _ellipse(d, exx, ey, fr * 0.155, fr * 0.175, fill=EYE)
        _ellipse(d, exx - fr * 0.05, ey - fr * 0.06, fr * 0.055, fr * 0.055, fill=(255, 255, 255))

    # 코 + 입 (쿼카 특유의 웃는 입)
    ny = fy + fr * 0.20
    d.polygon([(fx - fr * 0.12, ny - fr * 0.05), (fx + fr * 0.12, ny - fr * 0.05), (fx, ny + fr * 0.10)], fill=NOSE)
    w = max(2, int(fr * 0.055))
    d.arc([fx - fr * 0.34, ny - fr * 0.02, fx + fr * 0.34, ny + fr * 0.52], 20, 160, fill=NOSE, width=w)

    # 볼터치
    for sx in (-1, 1):
        _ellipse(d, fx + sx * fr * 0.66, fy + fr * 0.22, fr * 0.16, fr * 0.11, fill=CHEEK)

    img = img.resize((size, size), Image.LANCZOS)
    return img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "assets", "icon"))
    args = ap.parse_args()
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    for s in (512, 256, 128, 64):
        p = os.path.join(out, f"icon-{s}.png")
        draw_icon(s).save(p)
        print(f"{p}  {s}x{s}  {os.path.getsize(p)} bytes")


if __name__ == "__main__":
    main()
