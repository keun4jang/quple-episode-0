#!/usr/bin/env python3
"""쿼카 군단 도트 시트 (외부 그림 없이 코드로). `make-bug-sprites.py` 와 같은 규칙:
한 픽셀 크기 · 왼쪽 위 빛 · 겉테두리 · 큰 머리(2등신) · 볼터치.

시트: 4칸 x 3줄
  0줄 앞모습  - 0 서 있음 · 1 만세(이겼다) · 2 눈 감음(^^) · 3 아파함(><)   ← 초상화·결과 창
  1줄 뒷모습 공격 - 0 들어 올림 · 1 내려침 · 2 따라감 · 3 돌아옴
  2줄 뒷모습 걷기 - 4칸 (꼬리가 흔들린다)
진화(레벨 10): `quokka-<id>-2.png` - 금테·망토·조금 더 크게.
    python3 tools/pixel/make-quokka-units.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")

def hx(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

INK = hx("#2B1B2E")
FUR, FUR_D, FUR_L = hx("#B8784F"), hx("#8A5536"), hx("#D99A6C")
BELLY = hx("#F3D5AD")
NOSE = hx("#3A2418")
EYE_W, EYE_P = hx("#FFFFFF"), hx("#231626")
BLUSH = hx("#FF8FA3")
GOLD, GOLD_D = hx("#FFD15A"), hx("#C9921E")

UNITS = {
    "tiny":   dict(cell=22, head=6.2, gear="leaf"),
    "shield": dict(cell=24, head=6.6, gear="shield", helm="#9AA6B8"),
    "spear":  dict(cell=24, head=6.6, gear="spear", band="#D8433C"),
    "hammer": dict(cell=24, head=6.6, gear="hammer", helm="#F2C14E"),
    "runner": dict(cell=24, head=6.4, gear="runner", band="#3FA7E0"),
    "sling":  dict(cell=24, head=6.6, gear="sling", helm="#5DAE5B"),
    "mage":   dict(cell=26, head=6.6, gear="mage", helm="#6A4FB8"),
    "giant":  dict(cell=36, head=9.5, gear="giant", helm="#8E6A4E", big=True),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.px = w, h, {}
    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c
    def get(self, x, y):
        return self.px.get((int(round(x)), int(round(y))))
    def ellipse(self, cx, cy, rx, ry, base, dark=None, light=None):
        dark = dark or base
        light = light or base
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx, dy = (x + 0.5 - cx) / max(rx, 0.5), (y + 0.5 - cy) / max(ry, 0.5)
                if dx * dx + dy * dy <= 1.0:
                    c = base
                    if (dx * 0.6 + dy * 0.8) > 0.5:
                        c = dark
                    if (dx + 0.45) ** 2 + (dy + 0.5) ** 2 < 0.08:
                        c = light
                    self.set(x, y, c)
    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.set(x, y, c)
    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            self.set(x, y, c)
            if w > 1:
                self.set(x + 1, y, c)
    def outline(self):
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


def hat(cv, spec, cx, top, hr, back, evo):
    g = spec["gear"]
    col = hx(spec.get("helm", "#9AA6B8"))
    d, l = mix(col, (0, 0, 0, 255), 0.3), mix(col, (255, 255, 255, 255), 0.35)
    if g in ("shield", "hammer", "sling", "giant"):
        cv.ellipse(cx, top + hr * 0.55, hr * 0.98, hr * 0.62, col, d, l)
        if g == "hammer":
            cv.rect(cx - hr, top + hr * 0.95, cx + hr, top + hr * 1.05, d)
        if g == "sling" and not back:
            cv.rect(cx - 1, top + hr * 1.0, cx + hr * 1.1, top + hr * 1.12, d)      # 모자 챙
        if g == "giant":
            for side in (-1, 1):
                cv.line(cx + side * hr * 0.8, top + hr * 0.4, cx + side * hr * 1.25, top - hr * 0.3, hx("#F3E7C8"))
    elif g == "mage":
        cv.ellipse(cx, top + hr * 0.75, hr * 1.25, hr * 0.32, col, d, l)
        for i in range(int(hr * 1.6)):
            w = max(0.5, hr * 0.85 * (1 - i / (hr * 1.6)))
            cv.rect(cx - w + i * 0.15, top + hr * 0.6 - i, cx + w + i * 0.15, top + hr * 0.6 - i, col if i % 4 else d)
        cv.set(cx + hr * 0.3, top + hr * 0.6 - hr * 1.6, GOLD)
    elif g in ("spear", "runner"):
        b = hx(spec["band"])
        cv.rect(cx - hr * 0.92, top + hr * 0.62, cx + hr * 0.92, top + hr * 0.82, b)
        if back:
            cv.line(cx + hr * 0.4, top + hr * 0.8, cx + hr * 1.1, top + hr * 1.6, b)
            cv.line(cx + hr * 0.2, top + hr * 0.8, cx + hr * 0.7, top + hr * 1.8, b)
    elif g == "leaf":
        cv.line(cx, top + 1, cx + 1, top - 2, hx("#4E8A35"))
        cv.ellipse(cx + 2.5, top - 2.5, 2.0, 1.2, hx("#7CC15A"), hx("#4E8A35"), hx("#B4E58E"))
    if evo:
        # 진화: 금 왕관 띠
        cv.rect(cx - hr * 0.7, top + hr * 0.1, cx + hr * 0.7, top + hr * 0.25, GOLD)
        for k in (-1, 0, 1):
            cv.set(cx + k * hr * 0.5, top - 0.5, GOLD)
        cv.set(cx, top - 1.5, hx("#E8405A"))


def weapon(cv, spec, cx, by, hr, pose, back, evo):
    """pose: -1 들어 올림 · 0 보통 · 1 내려침. 뒷모습에선 오른손에 든다."""
    g = spec["gear"]
    wood, wood_d = hx("#A9754A"), hx("#6E4628")
    metal, metal_l = hx("#BFC8D6"), hx("#F0F4FA")
    hand = (cx + hr * 0.95, by - hr * 0.2)
    if g == "shield":
        sx = cx - hr * 0.95 if back else cx - hr * 0.6
        col = hx("#5B8FD8") if not evo else hx("#E0B030")
        cv.ellipse(sx, by + hr * 0.05, hr * 0.62, hr * 0.78, col, mix(col, (0, 0, 0, 255), 0.3), mix(col, (255, 255, 255, 255), 0.4))
        cv.set(sx, by + hr * 0.05, GOLD)
    elif g == "spear":
        ang_top = {-1: (hand[0] + 1, hand[1] - hr * 2.2), 0: (hand[0] + 2, hand[1] - hr * 2.0), 1: (hand[0] + hr * 1.4, hand[1] - hr * 1.5)}[pose]
        cv.line(hand[0], hand[1] + hr * 0.6, ang_top[0], ang_top[1], wood)
        cv.ellipse(ang_top[0], ang_top[1] - 1, 1.2, 2.2, metal if not evo else GOLD, metal, metal_l)
    elif g == "hammer":
        top = {-1: (hand[0] - 1, hand[1] - hr * 1.9), 0: (hand[0] + 1, hand[1] - hr * 1.5), 1: (hand[0] + hr * 1.3, hand[1] - hr * 0.6)}[pose]
        cv.line(hand[0], hand[1] + hr * 0.3, top[0], top[1], wood)
        hc = hx("#8E6A4E") if not evo else GOLD
        cv.rect(top[0] - hr * 0.55, top[1] - hr * 0.4, top[0] + hr * 0.55, top[1] + hr * 0.2, hc)
        cv.rect(top[0] - hr * 0.55, top[1] - hr * 0.4, top[0] + hr * 0.55, top[1] - hr * 0.3, mix(hc, (255, 255, 255, 255), 0.4))
    elif g == "sling":
        top = (hand[0] + (0 if pose < 1 else 1), hand[1] - hr * (1.3 if pose >= 0 else 1.6))
        cv.line(hand[0], hand[1] + 1, top[0], top[1], wood_d)
        cv.line(top[0] - 1.5, top[1] - 1.5, top[0], top[1], wood_d)
        cv.line(top[0] + 1.5, top[1] - 1.5, top[0], top[1], wood_d)
        if pose == 1:
            cv.set(top[0], top[1] - 4, hx("#9AA6B8"))
    elif g == "mage":
        top = {-1: (hand[0], hand[1] - hr * 2.0), 0: (hand[0] + 1, hand[1] - hr * 1.8), 1: (hand[0] + hr * 1.2, hand[1] - hr * 1.4)}[pose]
        cv.line(hand[0], hand[1] + hr * 0.6, top[0], top[1], wood)
        star = GOLD if not evo else hx("#FF8FD8")
        for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0), (0, 0), (-1, -1), (1, 1), (1, -1), (-1, 1)):
            cv.set(top[0] + dx, top[1] - 2 + dy, star)
    elif g == "runner":
        pass
    elif g == "giant":
        top = {-1: (hand[0], hand[1] - hr * 1.5), 0: (hand[0] + 1, hand[1] - hr * 1.2), 1: (hand[0] + hr * 1.1, hand[1] - hr * 0.4)}[pose]
        cv.line(hand[0], hand[1] + hr * 0.4, top[0], top[1], wood_d, 2)
        cv.ellipse(top[0], top[1], hr * 0.45, hr * 0.45, wood, wood_d, hx("#C99466"))


def quokka(spec, view, frame, evo=False):
    W = spec["cell"] + (2 if evo else 0)
    cv = Canvas(W, W)
    hr = spec["head"] * (1.08 if evo else 1.0)
    cx = W / 2 - 0.5
    foot = W - 2
    bob = 0
    arms_up = False
    eyes = "open"
    pose = 0
    walk_phase = frame
    if view == "walk":
        bob = (0, -1, 0, -1)[frame]
    if view == "attack":
        pose = (-1, 1, 1, 0)[frame]
        bob = (0, 1, 1, 0)[frame]
    if view == "front":
        if frame == 1:
            arms_up = True
            eyes = "happy"
            bob = -1
        elif frame == 2:
            eyes = "closed"
        elif frame == 3:
            eyes = "hurt"
    back = view != "front"
    body_r = hr * 0.78
    by = foot - body_r * 0.95 + bob            # 몸통 중심
    hy = by - body_r * 0.55 - hr * 0.72 + (1 if view == "attack" and pose == 1 else 0)
    # 망토 (진화)
    if evo:
        cape = hx("#C43A5A")
        for y in range(int(hy + hr * 0.6), int(foot)):
            w = body_r * (0.9 + (y - hy) * 0.05)
            for x in range(int(cx - w), int(cx + w) + 1):
                cv.set(x, y, cape if (x + y) % 6 else mix(cape, (255, 255, 255, 255), 0.2))
    # 꼬리 (뒷모습에서 보인다)
    if back:
        sway = (-1, 0, 1, 0)[walk_phase % 4] if view == "walk" else 0
        cv.ellipse(cx + sway, by + body_r * 0.55, body_r * 0.28, body_r * 0.42, FUR_D, FUR_D, FUR)
    # 발
    for side in (-1, 1):
        lift = 0
        if view == "walk":
            lift = 1 if (walk_phase + (0 if side < 0 else 2)) % 4 == 0 else 0
        cv.ellipse(cx + side * body_r * 0.5, foot - 0.5 - lift, body_r * 0.32, body_r * 0.22, FUR_D, FUR_D, FUR)
    # 몸통
    cv.ellipse(cx, by, body_r, body_r * 0.92, FUR, FUR_D, FUR_L)
    if not back:
        cv.ellipse(cx, by + 0.6, body_r * 0.6, body_r * 0.62, BELLY, mix(BELLY, FUR, 0.3), BELLY)
    # 팔
    for side in (-1, 1):
        if arms_up:
            cv.line(cx + side * body_r * 0.8, by - body_r * 0.3, cx + side * body_r * 1.25, by - body_r * 1.4, FUR_D, 1)
            cv.ellipse(cx + side * body_r * 1.25, by - body_r * 1.45, 1.2, 1.2, FUR, FUR, FUR)
        else:
            cv.ellipse(cx + side * body_r * 0.92, by + body_r * 0.05, body_r * 0.24, body_r * 0.42, FUR_D, FUR_D, FUR)
    # 귀
    for side in (-1, 1):
        ex, ey = cx + side * hr * 0.72, hy - hr * 0.72
        cv.ellipse(ex, ey, hr * 0.34, hr * 0.32, FUR_D if back else FUR, FUR_D, FUR_L)
        if not back:
            cv.ellipse(ex, ey + 0.3, hr * 0.17, hr * 0.15, hx("#E9A7A0"), hx("#E9A7A0"), hx("#E9A7A0"))
    # 머리
    cv.ellipse(cx, hy, hr, hr * 0.9, FUR if not back else mix(FUR, FUR_D, 0.35), FUR_D, FUR_L)
    if not back:
        # 얼굴: 주둥이 · 코 · 눈 · 볼 · 입
        cv.ellipse(cx, hy + hr * 0.38, hr * 0.48, hr * 0.32, BELLY, BELLY, BELLY)
        cv.ellipse(cx, hy + hr * 0.2, hr * 0.15, hr * 0.11, NOSE, NOSE, NOSE)
        exo = hr * 0.44
        for side in (-1, 1):
            x = cx + side * exo
            y = hy - hr * 0.08
            if eyes == "open":
                cv.ellipse(x, y, hr * 0.17, hr * 0.21, EYE_P, EYE_P, EYE_P)
                cv.set(x - hr * 0.06, y - hr * 0.1, EYE_W)
            elif eyes == "happy" or eyes == "closed":
                cv.set(x - 1, y, EYE_P)
                cv.set(x, y - 1, EYE_P)
                cv.set(x + 1, y, EYE_P)
            elif eyes == "hurt":
                cv.line(x - 1, y - 1, x + 1, y, EYE_P)
                cv.line(x - 1, y + 1, x + 1, y, EYE_P)
            cv.set(cx + side * hr * 0.72, hy + hr * 0.28, BLUSH)
            cv.set(cx + side * hr * 0.62, hy + hr * 0.32, BLUSH)
        my = hy + hr * 0.5
        if eyes == "happy":
            cv.ellipse(cx, my + 0.6, hr * 0.2, hr * 0.16, hx("#7A1E2C"), hx("#7A1E2C"), hx("#7A1E2C"))
        else:
            cv.set(cx - 1, my, NOSE)
            cv.set(cx + 1, my, NOSE)
    # 장비
    hat(cv, spec, cx, hy - hr * 0.95, hr, back, evo)
    if spec["gear"] == "runner":
        for side in (-1, 1):
            cv.rect(cx + side * body_r * 0.5 - 1.2, foot - 1, cx + side * body_r * 0.5 + 1.2, foot, hx("#FF6B6B"))
    weapon(cv, spec, cx, by, hr, pose, back, evo)
    cv.outline()
    return cv.image()


def sheet(spec, evo):
    W = spec["cell"] + (2 if evo else 0)
    im = Image.new("RGBA", (W * 4, W * 3), (0, 0, 0, 0))
    for f in range(4):
        im.paste(quokka(spec, "front", f, evo), (f * W, 0))
        im.paste(quokka(spec, "attack", f, evo), (f * W, W))
        im.paste(quokka(spec, "walk", f, evo), (f * W, W * 2))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for uid, spec in UNITS.items():
        sheet(spec, False).save(os.path.join(OUT, "quokka-%s.png" % uid))
        sheet(spec, True).save(os.path.join(OUT, "quokka-%s-2.png" % uid))
    print("quokka sheets:", len(UNITS) * 2)


if __name__ == "__main__":
    main()
