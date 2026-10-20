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


import math

# 공격 4칸 (뒷모습 - 적은 화면 위쪽): 0 웅크려 당김 · 1 위로 크게 휘두름(잔상) · 2 끝에서 반짝 · 3 돌아옴
ATTACK_POSE = ("low", "up", "up", "mid")
ATTACK_BOB = (1, -2, -1, 0)


def hand_at(cx, by, hr, pose):
    """오른손 위치 - 당기면 아래, 휘두르면 머리 위로."""
    if pose == "low":
        return (cx + hr * 1.05, by + hr * 0.2)
    if pose == "up":
        return (cx + hr * 0.8, by - hr * 1.05)
    return (cx + hr * 0.95, by - hr * 0.2)


def aim(pose):
    """무기가 가리키는 방향 (라디안, 화면 좌표: -90도 = 위)."""
    return {"low": math.radians(35), "up": math.radians(-92), "mid": math.radians(-62)}[pose]


WEAPON_LEN = {"spear": 2.4, "hammer": 1.7, "mage": 2.1, "giant": 1.5, "sling": 1.3}


def weapon_tip(spec, cx, by, hr, pose):
    g = spec["gear"]
    hand = hand_at(cx, by, hr, pose)
    L = WEAPON_LEN.get(g, 0.9) * hr * (1.15 if pose == "up" else 1.0)
    a = aim(pose)
    return hand, (hand[0] + math.cos(a) * L, hand[1] + math.sin(a) * L)


def weapon(cv, spec, cx, by, hr, pose, back, evo):
    """pose: low(당김) · mid(보통) · up(휘두름). 뒷모습에선 오른손에 든다."""
    g = spec["gear"]
    wood, wood_d = hx("#A9754A"), hx("#6E4628")
    metal, metal_l = hx("#BFC8D6"), hx("#F0F4FA")
    hand, tip = weapon_tip(spec, cx, by, hr, pose)
    if g == "shield":
        # 방패 밀치기 - 휘두르면 방패가 머리 앞(위)으로 올라간다
        if pose == "up":
            sx, sy = cx + hr * 0.2, by - hr * 1.15
        elif pose == "low":
            sx, sy = cx - hr * 1.0, by + hr * 0.2
        else:
            sx, sy = (cx - hr * 0.95 if back else cx - hr * 0.6), by + hr * 0.05
        col = hx("#5B8FD8") if not evo else hx("#E0B030")
        cv.ellipse(sx, sy, hr * 0.62, hr * 0.78, col, mix(col, (0, 0, 0, 255), 0.3), mix(col, (255, 255, 255, 255), 0.4))
        cv.set(sx, sy, GOLD)
    elif g == "spear":
        cv.line(hand[0], hand[1], tip[0], tip[1], wood)
        # 손 뒤로 자루가 조금 남는다
        a = aim(pose)
        cv.line(hand[0], hand[1], hand[0] - math.cos(a) * hr * 0.5, hand[1] - math.sin(a) * hr * 0.5, wood)
        cv.ellipse(tip[0], tip[1], 1.4, 1.4, metal if not evo else GOLD, metal, metal_l)
        cv.set(tip[0] + math.cos(a) * 1.5, tip[1] + math.sin(a) * 1.5, metal_l)
    elif g == "hammer":
        cv.line(hand[0], hand[1], tip[0], tip[1], wood)
        hc = hx("#8E6A4E") if not evo else GOLD
        cv.rect(tip[0] - hr * 0.6, tip[1] - hr * 0.42, tip[0] + hr * 0.6, tip[1] + hr * 0.28, hc)
        cv.rect(tip[0] - hr * 0.6, tip[1] - hr * 0.42, tip[0] + hr * 0.6, tip[1] - hr * 0.3, mix(hc, (255, 255, 255, 255), 0.4))
    elif g == "sling":
        cv.line(hand[0], hand[1], tip[0], tip[1], wood_d)
        cv.line(tip[0] - 1.5, tip[1] - 1.5, tip[0], tip[1], wood_d)
        cv.line(tip[0] + 1.5, tip[1] - 1.5, tip[0], tip[1], wood_d)
        if pose == "low":
            cv.line(tip[0] - 1.5, tip[1] - 1.5, hand[0] - 1, hand[1] + 2, hx("#E8DCC8"))   # 당긴 고무줄
    elif g == "mage":
        cv.line(hand[0], hand[1], tip[0], tip[1], wood)
        star = GOLD if not evo else hx("#FF8FD8")
        big = 2 if pose == "up" else 1
        for dx in range(-big - 1, big + 2):
            cv.set(tip[0] + dx, tip[1], star)
        for dy in range(-big - 1, big + 2):
            cv.set(tip[0], tip[1] + dy, star)
        for d in (-1, 1):
            cv.set(tip[0] + d, tip[1] + d, star)
            cv.set(tip[0] + d, tip[1] - d, star)
    elif g == "giant":
        cv.line(hand[0], hand[1], tip[0], tip[1], wood_d, 2)
        cv.ellipse(tip[0], tip[1], hr * 0.5, hr * 0.5, wood, wood_d, hx("#C99466"))


def strike_fx(cv, spec, cx, by, hr, frame):
    """윤곽선을 그린 뒤에 얹는다 - 잔상(1칸)과 끝에서 반짝(2칸). 윤곽선이 붙지 않아야 빛처럼 보인다."""
    hand, tip = weapon_tip(spec, cx, by, hr, "up")
    if spec["gear"] in ("leaf", "runner"):
        tip = (hand[0] + 0.5, hand[1] - hr * 0.6)
    if spec["gear"] == "shield":
        tip = (cx + hr * 0.2, by - hr * 1.9)
    if frame == 1:
        # 아래(당긴 곳)에서 위(휘두른 곳)까지 반달 잔상
        _, low_tip = weapon_tip(spec, cx, by, hr, "low")
        r = math.dist((cx, by), tip) * 0.95
        a0 = math.atan2(low_tip[1] - by, low_tip[0] - cx)
        a1 = math.atan2(tip[1] - by, tip[0] - cx)
        n = 14
        for i in range(n):
            t = i / (n - 1)
            a = a0 + (a1 - a0) * t
            for k in (0, 1, 2):
                x = cx + math.cos(a) * (r - k)
                y = by + math.sin(a) * (r - k)
                if cv.get(x, y) is None:
                    col = [(255, 255, 255), (255, 244, 170), (255, 214, 90)][k]
                    cv.set(x, y, col + (int(110 + 145 * t),))
    if frame == 2:
        # 끝에서 반짝 (십자 별)
        for d in range(-2, 3):
            cv.set(tip[0] + d, tip[1], (255, 255, 255, 255) if abs(d) < 2 else (255, 240, 150, 255))
            cv.set(tip[0], tip[1] + d, (255, 255, 255, 255) if abs(d) < 2 else (255, 240, 150, 255))


def head_room(W):
    """칸 위쪽 여유 - 무기를 머리 위로 휘둘러도 잘리지 않게. 게임은 (칸 높이 - 칸 폭)을 몸 위 여유로 안다."""
    return int(W * 0.62)


def quokka(spec, view, frame, evo=False):
    W = spec["cell"] + (2 if evo else 0)
    H = W + head_room(W)
    cv = Canvas(W, H)
    hr = spec["head"] * (1.08 if evo else 1.0)
    cx = W / 2 - 0.5
    foot = H - 2
    bob = 0
    arms_up = False
    eyes = "open"
    pose = "mid"
    walk_phase = frame
    if view == "walk":
        bob = (0, -1, 0, -1)[frame]
    if view == "attack":
        pose = ATTACK_POSE[frame]
        bob = ATTACK_BOB[frame]
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
    hy = by - body_r * 0.55 - hr * 0.72 + (1 if view == "attack" and frame == 0 else 0)
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
        if view == "attack" and side > 0:
            # 휘두르는 오른팔 - 어깨에서 손까지
            hx_, hy_ = hand_at(cx, by, hr, pose)
            cv.line(cx + body_r * 0.7, by - body_r * 0.35, hx_, hy_, FUR_D, 2)
            cv.ellipse(hx_, hy_, 1.4, 1.4, FUR, FUR_D, FUR)
            continue
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
    if view == "attack":
        strike_fx(cv, spec, cx, by, hr, frame)
    return cv.image()


def sheet(spec, evo):
    W = spec["cell"] + (2 if evo else 0)
    H = W + head_room(W)
    im = Image.new("RGBA", (W * 4, H * 3), (0, 0, 0, 0))
    for f in range(4):
        im.paste(quokka(spec, "front", f, evo), (f * W, 0))
        im.paste(quokka(spec, "attack", f, evo), (f * W, H))
        im.paste(quokka(spec, "walk", f, evo), (f * W, H * 2))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for uid, spec in UNITS.items():
        sheet(spec, False).save(os.path.join(OUT, "quokka-%s.png" % uid))
        sheet(spec, True).save(os.path.join(OUT, "quokka-%s-2.png" % uid))
    print("quokka sheets:", len(UNITS) * 2)


if __name__ == "__main__":
    main()
