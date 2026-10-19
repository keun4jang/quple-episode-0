#!/usr/bin/env python3
"""벌레 악당 도트 시트를 만든다 (외부 그림 없이 코드로).

`pixel-art`/`pixel-art-sprites` 스킬 규칙:
- 픽셀 크기 하나 (한 칸 = 1px, 화면에서 정수배로만 키운다)
- 빛은 왼쪽 위 한 곳 → 오른쪽 아래가 그늘 (가장자리만 어둡게 하는 '베개 음영' 금지)
- 겉테두리(진한 색)로 실루엣이 어떤 배경에서도 읽히게
- 한 벌레 4~6색, 큰 눈 + 하이라이트 + 볼터치 = 귀여움, 화난 눈썹 = 악당

시트: 4칸 x 3줄 (0줄 걷기 · 1줄 공격 · 2줄 아파함). 앞을 본다(화면 아래 = 쿼카 쪽으로 걸어온다).
    python3 tools/pixel/make-bug-sprites.py          # assets/sprites/bug-<kind>.png
"""
import math
import os
import sys
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")

def hx(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

INK = hx("#2B1B2E")        # 테두리
EYE_W = hx("#FFFFFF")
EYE_P = hx("#231626")
BLUSH = hx("#FF8FA3")

# 종류: 모양(shape) · 색(base, dark, light) · 장식
KINDS = {
    "ant":         dict(shape="ant", c=("#C2452F", "#7E2A1E", "#E8806A")),
    "caterpillar": dict(shape="caterpillar", c=("#7CC15A", "#4E8A35", "#B4E58E"), dots="#F6D44C"),
    "mosquito":    dict(shape="mosquito", c=("#8E8EA8", "#5D5D78", "#C2C2D8"), wing=True),
    "fly":         dict(shape="fly", c=("#3E4A5A", "#232B36", "#6E7E92"), wing=True, eye_red=True),
    "bee":         dict(shape="bee", c=("#F6C33B", "#C98F1A", "#FFE58A"), wing=True, stripe="#3A2A20"),
    "ladybug":     dict(shape="beetle", c=("#E2352F", "#9C1F1C", "#FF7A6E"), spots="#2A1A1A", head="#2A1A2A"),
    "termite":     dict(shape="ant", c=("#E9D6B0", "#B89E72", "#FFF3D8")),
    "cricket":     dict(shape="cricket", c=("#6E8A3A", "#465A22", "#A2BE66")),
    "moth":        dict(shape="moth", c=("#B9A27E", "#7E6A4C", "#E2D2B2"), wing=True),
    "spider":      dict(shape="spider", c=("#4A3A5E", "#2C2238", "#7C68A0")),
    "centipede":   dict(shape="centipede", c=("#C9572E", "#86361A", "#F08B5E")),
    "stag":        dict(shape="stag", c=("#6A3E26", "#40241A", "#9E6A48")),
    "wasp":        dict(shape="bee", c=("#F59A1E", "#B8650E", "#FFC766"), wing=True, stripe="#22181C", angry=2),
    "pillbug":     dict(shape="pillbug", c=("#8A8FA0", "#585C6C", "#BFC4D2")),
    "molecricket": dict(shape="mole", c=("#9A6B45", "#62402A", "#C99A72")),
    "roach":       dict(shape="roach", c=("#8E4E26", "#5A2E14", "#C98450")),
    # 우두머리 - 크고 왕관
    "queen_ant":     dict(shape="ant", c=("#B23A2A", "#701F16", "#E07A5F"), boss=True),
    "mosquito_king": dict(shape="mosquito", c=("#7A6A9E", "#4A3E6A", "#AE9ED2"), wing=True, boss=True),
    "hornet":        dict(shape="bee", c=("#F08A12", "#A8580A", "#FFC060"), wing=True, stripe="#1E1418", boss=True, angry=2),
    "rhino":         dict(shape="rhino", c=("#3E5A3A", "#24361F", "#6E8E64"), boss=True),
    "tarantula":     dict(shape="spider", c=("#5A3A2A", "#341F16", "#8E6A50"), boss=True, fuzzy=True),
    "fly_king":      dict(shape="fly", c=("#2F5A4A", "#173328", "#5E9A82"), wing=True, eye_red=True, boss=True),
    "moth_queen":    dict(shape="moth", c=("#C9A4D8", "#8A6A9E", "#EED8F8"), wing=True, boss=True),
    "cricket_king":  dict(shape="mole", c=("#8A5A36", "#523320", "#BC8A62"), boss=True),
    "centipede_king":dict(shape="centipede", c=("#A8321E", "#661C10", "#E06A48"), boss=True),
    "roach_king":    dict(shape="roach", c=("#6E3A1C", "#40200C", "#B0703E"), boss=True, cape=True),
}

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}
    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c
    def get(self, x, y):
        return self.px.get((x, y))
    def ellipse(self, cx, cy, rx, ry, base, dark, light, shade=True):
        """왼쪽 위에서 빛 - 오른쪽 아래 1/3 이 그늘, 왼쪽 위 작은 하이라이트."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx, dy = (x + 0.5 - cx) / max(rx, 0.5), (y + 0.5 - cy) / max(ry, 0.5)
                d = dx * dx + dy * dy
                if d <= 1.0:
                    c = base
                    if shade and (dx * 0.6 + dy * 0.8) > 0.45:
                        c = dark
                    if shade and (dx + 0.45) ** 2 + (dy + 0.5) ** 2 < 0.09:
                        c = light
                    self.set(x, y, c)
    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)
    def outline(self):
        """겉테두리: 빈 칸 중 그림과 맞닿은 칸을 진하게 (selout 대신 한 색 - 작게 보일 때 가장 또렷하다)."""
        add = {}
        for (x, y) in list(self.px.keys()):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.px and 0 <= p[0] < self.w and 0 <= p[1] < self.h:
                    add[p] = INK
        self.px.update(add)
    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def face(cv, cx, cy, s, spec, mode, frame):
    """큰 눈 둘 + 하이라이트 + 볼터치 + 눈썹(악당). mode: walk / attack / hurt"""
    ex = max(2, int(round(2.6 * s)))
    er = max(1.6, 1.7 * s)
    red = spec.get("eye_red")
    for side in (-1, 1):
        x = cx + side * ex
        if mode == "hurt":
            # 질끈 감은 눈 ><
            cv.line(x - er, cy - er * 0.6, x + er * 0.2, cy, EYE_P)
            cv.line(x - er, cy + er * 0.6, x + er * 0.2, cy, EYE_P)
            continue
        cv.ellipse(x, cy, er, er * 1.1, hx("#D8343C") if red else EYE_W, EYE_W, EYE_W, shade=False)
        pr = er * 0.62
        cv.ellipse(x + side * 0.3, cy + 0.4, pr, pr * 1.1, EYE_P, EYE_P, EYE_P, shade=False)
        cv.set(x - pr * 0.5, cy - pr * 0.4, EYE_W)            # 반짝
        # 화난 눈썹 (안쪽이 아래로)
        a = spec.get("angry", 1)
        by = cy - er - 1.2
        cv.line(x - side * er * 1.1, by + a * 0.8, x + side * er * 0.9, by - 0.4, INK)
    # 볼터치
    cv.set(cx - ex - er * 0.9, cy + er + 0.6, BLUSH)
    cv.set(cx + ex + er * 0.9, cy + er + 0.6, BLUSH)
    # 입
    my = cy + er + 1.2 * s
    if mode == "attack":
        cv.ellipse(cx, my + 0.4, 1.3 * s, 1.0 * s, hx("#7A1E2C"), hx("#7A1E2C"), hx("#7A1E2C"), shade=False)
        cv.set(cx - 0.6 * s, my - 0.3, EYE_W)
        cv.set(cx + 0.6 * s, my - 0.3, EYE_W)
    elif mode == "hurt":
        cv.line(cx - 1, my, cx + 1, my + 0.5, INK)
    else:
        cv.set(cx - 0.8, my, INK)
        cv.set(cx + 0.8, my, INK)
        cv.set(cx, my + 0.6, INK)


def legs(cv, cx, top, bottom, spread, n, frame, col):
    for i in range(n):
        y = top + (bottom - top) * (i / max(1, n - 1))
        lift = ((i + frame) % 2) * 1.0
        for side in (-1, 1):
            x0 = cx + side * spread * 0.5
            cv.line(x0, y, x0 + side * spread * 0.55, y + 1.8 - lift, col)
            cv.set(x0 + side * spread * 0.62, y + 2.4 - lift, col)


def antenna(cv, x0, y0, side, ln, curl, col):
    x, y = x0, y0
    for i in range(ln):
        x += side * 0.6
        y -= 0.9
        cv.set(x, y, col)
    if curl:
        cv.set(x + side, y, col)
        cv.set(x + side, y + 1, col)


def wings(cv, cx, cy, s, frame, col, big=False):
    flap = (0, 1, 2, 1)[frame % 4]
    for side in (-1, 1):
        w = (4.2 if not big else 6.5) * s - flap * 0.6
        h = (3.2 if not big else 5.5) * s + flap * 0.4
        cv.ellipse(cx + side * (3.5 * s + w * 0.5), cy - 1.5 * s - flap * 0.5, w, h, col,
                   mix(col, (255, 255, 255, 255), 0.25), mix(col, (255, 255, 255, 255), 0.6))


def draw(kind, spec, frame, mode):
    boss = spec.get("boss", False)
    W = 40 if boss else 24
    cv = Canvas(W, W)
    base, dark, light = (hx(c) for c in spec["c"])
    s = 1.55 if boss else 1.0
    cx = W / 2 - 0.5
    bob = (0, -1, 0, 1)[frame % 4] if mode == "walk" else 0
    lean = 1.5 * s if mode == "attack" else 0
    foot = W - 3
    cy = foot - 9 * s + bob + lean          # 머리 중심
    shape = spec["shape"]
    wingcol = hx("#DDEFFF") if shape != "moth" else mix(base, (255, 255, 255, 255), 0.35)
    if spec.get("wing") and shape != "moth":
        wings(cv, cx, cy - 1, s, frame, wingcol)
    if shape == "moth":
        wings(cv, cx, cy, s, frame, mix(base, hx("#FFFFFF"), 0.15), big=True)
    if spec.get("cape"):
        for y in range(int(cy - 2), int(foot)):
            for x in range(int(cx - 9 * s + (y - cy) * 0.2), int(cx + 9 * s - (y - cy) * 0.2) + 1):
                cv.set(x, y, hx("#5B1E3A") if (x + y) % 7 else hx("#7A2A4E"))
    # 몸통 / 다리
    if shape in ("ant", "mosquito", "fly", "bee", "cricket"):
        cv.ellipse(cx, cy + 5 * s, 3.6 * s, 3.0 * s, base, dark, light)
        if spec.get("stripe"):
            for k in (0, 2):
                for x in range(int(cx - 3.4 * s), int(cx + 3.6 * s) + 1):
                    cv.set(x, cy + (4 + k) * s, hx(spec["stripe"]))
        legs(cv, cx, cy + 3 * s, cy + 7 * s, 6.5 * s, 3, frame if mode == "walk" else 0, INK)
        if shape == "cricket":
            for side in (-1, 1):
                cv.line(cx + side * 3 * s, cy + 6 * s, cx + side * 7 * s, cy + 1 * s, dark)
                cv.line(cx + side * 7 * s, cy + 1 * s, cx + side * 8 * s, foot, dark)
        if shape == "mosquito":
            cv.line(cx, cy + 3.2 * s, cx, cy + 3.2 * s + 4 * s + lean, INK)      # 침
    elif shape in ("caterpillar", "centipede"):
        n = 4 if shape == "caterpillar" else 5
        for i in range(n, 0, -1):
            side = -1 if i % 2 else 1
            sx = cx + side * (i * 2.2 * s) * (0.55 if shape == "caterpillar" else 0.75) + (frame % 2) * side * 0.5
            sy = cy + 4 * s + i * 0.6 * s
            cv.ellipse(sx, sy, 2.8 * s, 2.6 * s, base, dark, light)
            if spec.get("dots"):
                cv.set(sx, sy - 1, hx(spec["dots"]))
            if shape == "centipede":
                cv.line(sx - 2 * s, sy + 2 * s, sx - 3 * s, sy + 3.6 * s - (i + frame) % 2, INK)
                cv.line(sx + 2 * s, sy + 2 * s, sx + 3 * s, sy + 3.6 * s - (i + frame + 1) % 2, INK)
    elif shape in ("beetle", "stag", "rhino", "roach", "pillbug", "mole"):
        rx = 5.4 * s if shape != "roach" else 4.8 * s
        cv.ellipse(cx, cy + 4.5 * s, rx, 4.2 * s, base, dark, light)
        if shape in ("beetle", "stag", "rhino", "roach"):
            for y in range(int(cy + 1 * s), int(cy + 8.6 * s)):
                cv.set(cx, y, dark)
        if spec.get("spots"):
            for (ox, oy) in ((-2.6, 3.2), (2.6, 3.2), (-2.2, 6.2), (2.2, 6.2)):
                cv.ellipse(cx + ox * s, cy + oy * s, 1.0 * s, 1.0 * s, hx(spec["spots"]), hx(spec["spots"]), hx(spec["spots"]), shade=False)
        if shape == "pillbug":
            for k in range(4):
                yy = cy + (1.5 + k * 1.8) * s
                for x in range(int(cx - rx + 1), int(cx + rx)):
                    if cv.get(x, yy):
                        cv.set(x, yy, dark)
        if shape == "mole":
            for side in (-1, 1):       # 큰 삽 앞발
                cv.ellipse(cx + side * 5.5 * s, cy + 6.5 * s, 2.2 * s, 1.6 * s, light, dark, light)
        legs(cv, cx, cy + 5 * s, cy + 8 * s, 9 * s, 3 if shape != "pillbug" else 4, frame if mode == "walk" else 0, INK)
    elif shape == "spider":
        cv.ellipse(cx, cy + 5 * s, 5.2 * s, 4.0 * s, base, dark, light)
        for i in range(4):
            for side in (-1, 1):
                lift = ((i + frame) % 2) if mode == "walk" else 0
                x0 = cx + side * 3.5 * s
                y0 = cy + (2.5 + i * 1.6) * s
                cv.line(x0, y0, x0 + side * 4.5 * s, y0 - 2 * s - lift, INK)
                cv.line(x0 + side * 4.5 * s, y0 - 2 * s - lift, x0 + side * 6 * s, y0 + 3 * s - lift, INK)
        if spec.get("fuzzy"):
            for k in range(0, 360, 30):
                a = math.radians(k)
                cv.set(cx + math.cos(a) * 5.6 * s, cy + 5 * s + math.sin(a) * 4.4 * s, light)
    elif shape == "moth":
        cv.ellipse(cx, cy + 5 * s, 2.8 * s, 3.6 * s, base, dark, light)
        legs(cv, cx, cy + 4 * s, cy + 7 * s, 5 * s, 2, frame if mode == "walk" else 0, INK)
    # 머리 (크게 = 귀엽게)
    hr = 4.6 * s if shape not in ("caterpillar", "centipede") else 4.2 * s
    head_c = hx(spec["head"]) if spec.get("head") else base
    head_d = mix(head_c, (0, 0, 0, 255), 0.35)
    head_l = mix(head_c, (255, 255, 255, 255), 0.35)
    cv.ellipse(cx, cy, hr, hr * 0.92, head_c, head_d, head_l)
    # 더듬이·뿔·집게
    if shape in ("ant", "bee", "fly", "beetle", "roach", "cricket", "mosquito", "caterpillar", "pillbug", "mole"):
        ln = 4 if shape != "roach" else 8
        for side in (-1, 1):
            antenna(cv, cx + side * 1.6 * s, cy - hr + 0.5, side, int(ln * s), shape in ("ant", "bee", "caterpillar"), INK)
    if shape == "moth":
        for side in (-1, 1):
            for i in range(5):
                cv.set(cx + side * (1.5 + i * 0.8) * s, cy - hr - i * 0.7 * s, light)
                cv.set(cx + side * (2.0 + i * 0.8) * s, cy - hr - i * 0.7 * s + 1, light)
    if shape == "stag":
        for side in (-1, 1):
            cv.line(cx + side * 2.5 * s, cy - hr + 1, cx + side * 5 * s, cy - hr - 3 * s, dark)
            cv.line(cx + side * 5 * s, cy - hr - 3 * s, cx + side * 3 * s, cy - hr - 4.5 * s, dark)
    if shape == "rhino":
        cv.line(cx, cy - hr + 1, cx, cy - hr - 5 * s, dark)
        cv.line(cx, cy - hr - 5 * s, cx - 2 * s, cy - hr - 6.5 * s, dark)
        cv.line(cx + 1, cy - hr + 1, cx + 1, cy - hr - 4 * s, light)
    if shape == "spider":
        for side in (-1, 1):
            cv.set(cx + side * 1.2 * s, cy - hr * 0.55, hx("#FF4A5A"))
    face(cv, cx, cy + 0.6 * s, s, spec, mode, frame)
    if boss:
        # 왕관
        top = cy - hr - (6.5 * s if shape in ("rhino", "stag") else 1.5 * s)
        gold, gold_d = hx("#FFD15A"), hx("#C9921E")
        for x in range(int(cx - 4 * s), int(cx + 4 * s) + 1):
            cv.set(x, top, gold_d)
            cv.set(x, top - 1, gold)
        for k in (-4, 0, 4):
            cv.line(cx + k * s * 0.9, top - 1, cx + k * s * 0.9, top - 3.5 * s * (1.0 if k == 0 else 0.7), gold)
        cv.set(cx, top - 2, hx("#E8405A"))
    cv.outline()
    im = cv.image()
    if mode == "hurt":
        # 살짝 하얗게 질린다
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (min(255, r + 40), min(255, g + 40), min(255, b + 40), a)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    for kind, spec in KINDS.items():
        if only and kind not in only:
            continue
        W = 40 if spec.get("boss") else 24
        sheet = Image.new("RGBA", (W * 4, W * 3), (0, 0, 0, 0))
        for f in range(4):
            sheet.paste(draw(kind, spec, f, "walk"), (f * W, 0))
            sheet.paste(draw(kind, spec, f if f < 2 else 1, "attack" if f % 2 == 0 or f == 1 else "walk"), (f * W, W))
            sheet.paste(draw(kind, spec, 0, "hurt"), (f * W, W * 2))
        path = os.path.join(OUT, "bug-%s.png" % kind)
        sheet.save(path)
    print("bug sheets:", len(KINDS) if not only else len(only))


if __name__ == "__main__":
    main()
