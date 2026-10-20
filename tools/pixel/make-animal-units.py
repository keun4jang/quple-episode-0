#!/usr/bin/env python3
"""뽑기로 만나는 동물 친구 16종 도트 시트. 규칙·시트 모양은 `make-quokka-units.py` 와 같다
(한 픽셀 크기 · 왼쪽 위 빛 · 겉테두리 · 2등신 · 볼터치, 4칸 x 3줄: 앞모습 / 뒷모습 공격 / 뒷모습 걷기).
진화(레벨 10): `animal-<id>-2.png` - 금테·망토.
    python3 tools/pixel/make-animal-units.py
"""
import importlib.util
import os
from PIL import Image

HERE = os.path.dirname(__file__)
_spec = importlib.util.spec_from_file_location("qk", os.path.join(HERE, "make-quokka-units.py"))
qk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qk)
Canvas, hx, mix = qk.Canvas, qk.hx, qk.mix
INK, EYE_W, EYE_P, BLUSH, GOLD = qk.INK, qk.EYE_W, qk.EYE_P, qk.BLUSH, qk.GOLD
OUT = qk.OUT
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

# fur 몸 · belly 배 · ears 귀 · face 얼굴 · tail 꼬리 · arms 팔 · pat 무늬 · acc 소품
ANIMALS = {
    # 희귀
    "chick":    dict(cell=20, head=5.6, fur="#FFD84A", belly="#FFF0A8", ears="tuft", face="beak", beak="#FF9A3C",
                     tail="none", arms="wing", acc="eggshell"),
    "hedgehog": dict(cell=24, head=6.4, fur="#9C7A5E", belly="#F2D9BC", ears="small", face="snout", tail="none",
                     arms="paw", pat="spikes", spike="#5E4636"),
    "squirrel": dict(cell=24, head=6.2, fur="#D9783A", belly="#FBE3C4", ears="pointy", face="snout", tail="bushy",
                     arms="paw", acc="acorn"),
    "frog":     dict(cell=24, head=6.8, fur="#6CC24A", belly="#DDF5B0", ears="none", face="frog", tail="none",
                     arms="paw", acc="leafhat"),
    "rabbit":   dict(cell=24, head=6.2, fur="#F4EEF2", belly="#FFFFFF", ears="long", face="snout", tail="puff",
                     arms="paw", inner="#FFB3C6", acc="carrot"),
    "duck":     dict(cell=24, head=6.4, fur="#FFFFFF", belly="#F4F4F4", ears="none", face="beak", beak="#FFA62B",
                     tail="duck", arms="wing", acc="sailor"),
    "mole":     dict(cell=24, head=6.4, fur="#5E5470", belly="#8E83A0", ears="none", face="mole", tail="none",
                     arms="claw", acc="lamp"),
    "sheep":    dict(cell=24, head=6.4, fur="#4A3C48", belly="#4A3C48", ears="side", face="sheep", tail="none",
                     arms="paw", pat="wool"),
    # 특급
    "turtle":   dict(cell=26, head=6.4, fur="#7CC48A", belly="#F2E3A6", ears="none", face="snout", tail="none",
                     arms="paw", pat="shell", shell="#3E8E5A"),
    "penguin":  dict(cell=24, head=6.6, fur="#2F3550", belly="#FFFFFF", ears="none", face="beak", beak="#FFB23E",
                     tail="none", arms="flipper", acc="scarf"),
    "owl":      dict(cell=24, head=7.0, fur="#9A6C4A", belly="#EBD3B0", ears="tuft", face="owl", beak="#F4B23A",
                     tail="none", arms="wing", acc="glasses"),
    "panda":    dict(cell=28, head=7.6, fur="#FFFFFF", belly="#FFFFFF", ears="round_dark", face="panda", tail="none",
                     arms="dark", acc="bamboo"),
    "otter":    dict(cell=24, head=6.4, fur="#8C5A3A", belly="#E9C9A4", ears="small", face="otter", tail="flat",
                     arms="paw", acc="clam"),
    # 전설
    "tiger":    dict(cell=30, head=8.0, fur="#F08A2C", belly="#FFF3E0", ears="round", face="tiger", tail="striped",
                     arms="paw", pat="stripes", acc="claw"),
    "polar":    dict(cell=36, head=9.6, fur="#F4F8FC", belly="#FFFFFF", ears="round", face="bear", tail="none",
                     arms="paw", acc="icescarf"),
    "eagle":    dict(cell=30, head=7.6, fur="#6B4A32", belly="#FFFFFF", ears="none", face="eagle", beak="#FFC23A",
                     tail="none", arms="bigwing", acc="goggles"),
}


def shade(c):
    return mix(c, BLACK, 0.28), mix(c, WHITE, 0.35)


def animal(spec, view, frame, evo=False):
    W = spec["cell"] + (2 if evo else 0)
    H = W + qk.head_room(W)
    cv = Canvas(W, H)
    hr = spec["head"] * (1.08 if evo else 1.0)
    cx = W / 2 - 0.5
    foot = H - 2
    FUR = hx(spec["fur"])
    FUR_D, FUR_L = shade(FUR)
    BEL = hx(spec["belly"])
    bob, pose, eyes, arms_up = 0, 0, "open", False
    if view == "walk":
        bob = (0, -1, 0, -1)[frame]
    if view == "attack":
        # 0 웅크림 · 1 앞발을 높이 들어 휘두름(잔상) · 2 내리꽂기/던지기(반짝) · 3 돌아옴
        pose = (0, -1, 1, 0)[frame]
        bob = (1, -2, -1, 0)[frame]
    if view == "front":
        if frame == 1:
            arms_up, eyes, bob = True, "happy", -1
        elif frame == 2:
            eyes = "closed"
        elif frame == 3:
            eyes = "hurt"
    back = view != "front"
    body_r = hr * 0.78
    by = foot - body_r * 0.95 + bob
    hy = by - body_r * 0.55 - hr * 0.72 + (1 if view == "attack" and frame == 0 else 0)
    if view == "attack" and spec["face"] in ("beak", "owl", "eagle") and frame in (1, 2):
        hy -= 1.5      # 쪼기 - 머리를 앞(위)으로 내민다
    face = spec["face"]
    if evo:
        cape = hx("#C43A5A")
        for y in range(int(hy + hr * 0.6), int(foot)):
            w = body_r * (0.9 + (y - hy) * 0.05)
            for x in range(int(cx - w), int(cx + w) + 1):
                cv.set(x, y, cape if (x + y) % 6 else mix(cape, WHITE, 0.2))
    # ── 꼬리 (뒷모습)
    sway = (-1, 0, 1, 0)[frame % 4] if view == "walk" else 0
    t = spec["tail"]
    if not back and t == "bushy":   # 앞에서도 몸 뒤로 큰 꼬리가 보인다
        cv.ellipse(cx + body_r * 1.45, by - body_r * 0.9, body_r * 0.6, body_r * 1.25, FUR, FUR_D, FUR_L)
        cv.ellipse(cx + body_r * 1.55, by - body_r * 1.5, body_r * 0.3, body_r * 0.45, FUR_L, FUR_L, FUR_L)
    if back and t != "none":
        tx, ty = cx + sway, by + body_r * 0.5
        if t == "bushy":
            pass
        elif t == "puff":
            cv.ellipse(tx, ty, body_r * 0.35, body_r * 0.32, WHITE, mix(WHITE, FUR_D, 0.3), WHITE)
        elif t == "flat":
            cv.ellipse(tx, ty + body_r * 0.3, body_r * 0.3, body_r * 0.6, FUR_D, FUR_D, FUR)
        elif t == "duck":
            cv.ellipse(tx, ty, body_r * 0.4, body_r * 0.22, FUR, FUR_D, FUR)
        elif t == "striped":
            for i in range(5):
                cv.ellipse(tx + i * 0.6, ty + body_r * 0.2 - i * 1.4, 1.3, 1.1, INK if i % 2 else FUR, FUR_D, FUR)
    # ── 발
    for side in (-1, 1):
        lift = 1 if view == "walk" and (frame + (0 if side < 0 else 2)) % 4 == 0 else 0
        fc = hx(spec.get("beak", spec["fur"])) if face in ("beak", "owl", "eagle") else FUR_D
        if face == "panda":
            fc = INK
        cv.ellipse(cx + side * body_r * 0.5, foot - 0.5 - lift, body_r * 0.32, body_r * 0.22, fc, mix(fc, BLACK, 0.2), fc)
    # ── 몸통
    pat = spec.get("pat", "")
    if pat == "wool":
        wool, wool_d = hx("#FFF9F2"), hx("#E3D6CC")
        for ang in range(0, 360, 40):
            import math
            a = math.radians(ang)
            cv.ellipse(cx + math.cos(a) * body_r * 0.75, by + math.sin(a) * body_r * 0.7, body_r * 0.45, body_r * 0.42,
                       wool, wool_d, WHITE)
        cv.ellipse(cx, by, body_r * 0.9, body_r * 0.85, wool, wool_d, WHITE)
    elif pat == "shell" and back:
        sh = hx(spec["shell"])
        cv.ellipse(cx, by - 0.5, body_r * 1.15, body_r * 1.05, sh, mix(sh, BLACK, 0.3), mix(sh, WHITE, 0.3))
        for dx, dy in ((0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
            cv.ellipse(cx + dx * body_r * 0.5, by + dy * body_r * 0.45, body_r * 0.22, body_r * 0.2,
                       mix(sh, WHITE, 0.25), mix(sh, WHITE, 0.25), mix(sh, WHITE, 0.45))
    else:
        cv.ellipse(cx, by, body_r, body_r * 0.92, FUR, FUR_D, FUR_L)
        if pat == "shell":
            sh = hx(spec["shell"])
            for side in (-1, 1):
                cv.ellipse(cx + side * body_r * 0.95, by, body_r * 0.3, body_r * 0.8, sh, mix(sh, BLACK, 0.3), sh)
        if not back:
            cv.ellipse(cx, by + 0.6, body_r * 0.6, body_r * 0.62, BEL, mix(BEL, FUR, 0.3), BEL)
        if pat == "stripes":
            for k in (-0.35, 0.0, 0.35):
                cv.line(cx - body_r * 0.95, by + k * body_r * 2, cx - body_r * 0.6, by + k * body_r * 2 + 1, INK)
                cv.line(cx + body_r * 0.95, by + k * body_r * 2, cx + body_r * 0.6, by + k * body_r * 2 + 1, INK)
            if back:
                for k in (-0.4, 0.1, 0.55):
                    cv.line(cx - 1.5, by + k * body_r, cx + 1.5, by + k * body_r, INK)
    if pat == "spikes":
        sp = hx(spec["spike"])
        rng = range(-3, 4)
        for i in rng:
            x = cx + i * body_r * 0.32
            top = by - body_r * (0.9 if back else 0.6) - (hr * 0.9 if back else 0)
            for j in range(3 if back else 1):
                yy = top + j * body_r * 0.6
                cv.line(x, yy + 3, x + (1 if i > 0 else -1 if i < 0 else 0), yy - 1, sp)
    if back and t == "bushy":   # 뒤에서 보면 몸 위로 꼬리가 덮인다
        tl = mix(FUR, WHITE, 0.3)
        cv.ellipse(cx + sway, by - body_r * 0.2, body_r * 0.62, body_r * 1.0, tl, FUR_D, mix(FUR, WHITE, 0.55))
        cv.line(cx + sway, by - body_r * 0.9, cx + sway, by + body_r * 0.5, FUR)
    # ── 팔
    arms = spec["arms"]
    ac = INK if arms == "dark" else FUR_D
    for side in (-1, 1):
        if arms in ("wing", "bigwing", "flipper"):
            big = 1.6 if arms == "bigwing" else 1.0
            if arms_up or (back and view == "attack" and frame in (1, 2)):
                cv.ellipse(cx + side * body_r * 1.1, by - body_r * 0.7, body_r * 0.3 * big, body_r * 0.55 * big, ac, ac, FUR)
            else:
                cv.ellipse(cx + side * body_r * (0.95 + 0.2 * (big - 1)), by + body_r * 0.05, body_r * 0.26 * big,
                           body_r * 0.5 * big, ac, ac, FUR)
        elif arms_up:
            cv.line(cx + side * body_r * 0.8, by - body_r * 0.3, cx + side * body_r * 1.25, by - body_r * 1.4, ac, 1)
            cv.ellipse(cx + side * body_r * 1.25, by - body_r * 1.45, 1.2, 1.2, ac, ac, FUR)
        else:
            raise_r = back and side > 0 and view == "attack" and frame in (1, 2)
            ay = by - body_r * ((1.35 if frame == 1 else 1.0) if raise_r else -0.05)
            if back and side > 0 and view == "attack" and frame == 0:
                ay = by + body_r * 0.3     # 웅크려 당김
            cv.ellipse(cx + side * body_r * 0.92, ay, body_r * 0.24, body_r * 0.42, ac, ac, FUR)
            if arms == "claw" or spec.get("acc") == "claw":
                for k in (-1, 0, 1):
                    cv.set(cx + side * body_r * 0.92 + k, ay + body_r * 0.45, hx("#F4F0E6"))
    # ── 귀
    ears = spec["ears"]
    inner = hx(spec.get("inner", "#E9A7A0"))
    for side in (-1, 1):
        ex = cx + side * hr * 0.72
        ey = hy - hr * 0.72
        if ears == "round" or ears == "round_dark":
            col = INK if ears == "round_dark" else FUR
            cv.ellipse(ex, ey, hr * 0.32, hr * 0.3, col, mix(col, BLACK, 0.2), col)
            if not back and ears == "round":
                cv.ellipse(ex, ey + 0.3, hr * 0.15, hr * 0.13, inner, inner, inner)
        elif ears == "small":
            cv.ellipse(ex * 0.98 + cx * 0.02, ey + hr * 0.15, hr * 0.22, hr * 0.2, FUR_D, FUR_D, FUR)
        elif ears == "pointy":
            ey -= hr * 0.3
            for i in range(int(hr * 0.7)):
                w = max(0.5, hr * 0.32 * (1 - i / (hr * 0.7)))
                cv.rect(ex - w, ey + hr * 0.2 - i, ex + w, ey + hr * 0.2 - i, FUR if i < hr * 0.5 else FUR_D)
            cv.set(ex, ey - hr * 0.5 + 1, INK)
        elif ears == "long":
            lean = side * (0.6 if view == "walk" and frame % 2 else 0.3)
            cv.ellipse(cx + side * hr * 0.42 + lean, hy - hr * 1.45, hr * 0.24, hr * 0.7, FUR, FUR_D, WHITE)
            if not back:
                cv.ellipse(cx + side * hr * 0.42 + lean, hy - hr * 1.4, hr * 0.1, hr * 0.5, inner, inner, inner)
        elif ears == "tuft":
            cv.line(ex - side * 1, ey + 1, ex + side * 0.5, ey - hr * 0.4, FUR_D)
            cv.line(ex - side * 0.0, ey + 1, ex + side * 1.5, ey - hr * 0.3, FUR_D)
        elif ears == "side":
            cv.ellipse(cx + side * hr * 1.0, hy - hr * 0.1, hr * 0.32, hr * 0.18, FUR, FUR_D, FUR_L)
    if pat == "spikes":   # 머리 뒤로 가시 왕관
        import math
        sp = hx(spec["spike"])
        for ang in range(195, 346, 15):
            a = math.radians(ang)
            x0, y0 = cx + math.cos(a) * hr * 0.75, hy - math.sin(a) * -hr * 0.0 + math.sin(a) * hr * 0.7
            x1, y1 = cx + math.cos(a) * hr * 1.35, hy + math.sin(a) * hr * 1.25
            cv.line(x0, y0, x1, y1, sp, 2)
            cv.set(x1, y1, hx("#F2D9BC"))
    # ── 머리
    hc = FUR if not back else mix(FUR, FUR_D, 0.35)
    if face == "frog":
        cv.ellipse(cx, hy + hr * 0.1, hr * 1.05, hr * 0.78, hc, FUR_D, FUR_L)
        for side in (-1, 1):  # 머리 위 툭 튀어나온 눈
            cv.ellipse(cx + side * hr * 0.5, hy - hr * 0.55, hr * 0.36, hr * 0.34, hc, FUR_D, FUR_L)
    elif face == "sheep":
        wool, wool_d = hx("#FFF9F2"), hx("#E3D6CC")
        cv.ellipse(cx, hy, hr * 0.85, hr * 0.85, hc, mix(hc, BLACK, 0.2), mix(hc, WHITE, 0.2))
        for dx in (-0.55, 0, 0.55):
            cv.ellipse(cx + dx * hr, hy - hr * 0.75, hr * 0.38, hr * 0.32, wool, wool_d, WHITE)
    else:
        cv.ellipse(cx, hy, hr, hr * 0.9, hc, FUR_D, FUR_L)
    if face == "owl" and not back:
        cv.ellipse(cx, hy + hr * 0.1, hr * 0.82, hr * 0.62, BEL, mix(BEL, FUR, 0.3), BEL)
    if face == "penguin" or (face == "beak" and spec["fur"] == "#2F3550"):
        if not back:
            cv.ellipse(cx, hy + hr * 0.15, hr * 0.75, hr * 0.62, WHITE, mix(WHITE, FUR, 0.2), WHITE)
    if face == "eagle":
        cv.ellipse(cx, hy - hr * 0.05, hr * 0.98, hr * 0.85, WHITE if not back else mix(WHITE, FUR_D, 0.2),
                   mix(WHITE, BLACK, 0.15), WHITE)
    if face == "tiger" and not back:
        cv.ellipse(cx, hy + hr * 0.38, hr * 0.55, hr * 0.32, BEL, BEL, BEL)
        for side in (-1, 1):
            cv.line(cx + side * hr * 0.95, hy - hr * 0.1, cx + side * hr * 0.65, hy, INK)
            cv.line(cx + side * hr * 0.95, hy + hr * 0.15, cx + side * hr * 0.68, hy + hr * 0.18, INK)
        cv.line(cx, hy - hr * 0.85, cx, hy - hr * 0.55, INK)
        cv.line(cx - 1.5, hy - hr * 0.8, cx - 1, hy - hr * 0.6, INK)
        cv.line(cx + 1.5, hy - hr * 0.8, cx + 1, hy - hr * 0.6, INK)
    if face == "tiger" and back:
        for k in (-0.5, 0, 0.5):
            cv.line(cx + k * hr, hy - hr * 0.85, cx + k * hr, hy - hr * 0.4, INK)
    # ── 얼굴
    if not back:
        NOSE = hx("#3A2418")
        if face in ("snout", "bear", "otter", "mole"):
            mz = BEL if face != "mole" else hx("#FFB3C6")
            cv.ellipse(cx, hy + hr * 0.38, hr * (0.48 if face != "mole" else 0.3), hr * 0.3, mz, mz, mz)
            cv.ellipse(cx, hy + hr * 0.22, hr * 0.15, hr * 0.11, NOSE if face != "mole" else hx("#E06A8A"), NOSE, NOSE)
            if face == "otter":
                for side in (-1, 1):
                    cv.line(cx + side * hr * 0.35, hy + hr * 0.38, cx + side * hr * 0.85, hy + hr * 0.3, mix(BEL, BLACK, 0.4))
        if face == "panda":
            cv.ellipse(cx, hy + hr * 0.38, hr * 0.42, hr * 0.28, WHITE, mix(WHITE, BLACK, 0.1), WHITE)
            cv.ellipse(cx, hy + hr * 0.22, hr * 0.15, hr * 0.1, INK, INK, INK)
            for side in (-1, 1):
                cv.ellipse(cx + side * hr * 0.44, hy - hr * 0.05, hr * 0.3, hr * 0.34, INK, INK, INK)
        if face == "sheep":
            cv.ellipse(cx, hy + hr * 0.38, hr * 0.32, hr * 0.2, mix(hc, WHITE, 0.15), hc, hc)
        if face == "tiger":
            cv.ellipse(cx, hy + hr * 0.22, hr * 0.15, hr * 0.1, hx("#E06A8A"), NOSE, NOSE)
        if face in ("beak", "owl", "eagle"):
            bk = hx(spec["beak"])
            if face == "eagle":
                cv.ellipse(cx, hy + hr * 0.32, hr * 0.3, hr * 0.25, bk, mix(bk, BLACK, 0.25), mix(bk, WHITE, 0.3))
                cv.set(cx, hy + hr * 0.58, mix(bk, BLACK, 0.3))
            elif spec["fur"] == "#FFFFFF" or spec["fur"] == "#2F3550" and False:
                cv.ellipse(cx, hy + hr * 0.36, hr * 0.42, hr * 0.18, bk, mix(bk, BLACK, 0.2), mix(bk, WHITE, 0.3))
            else:
                cv.ellipse(cx, hy + hr * 0.3, hr * 0.25, hr * 0.17, bk, mix(bk, BLACK, 0.25), mix(bk, WHITE, 0.3))
        exo = hr * 0.44
        for side in (-1, 1):
            x = cx + side * exo
            y = hy - hr * 0.08
            if face == "frog":
                x, y = cx + side * hr * 0.5, hy - hr * 0.55
            if face == "mole":
                if eyes == "hurt":
                    cv.line(x - 1, y - 1, x + 1, y, EYE_P)
                    cv.line(x - 1, y + 1, x + 1, y, EYE_P)
                else:
                    cv.line(x - 1, y, x + 1, y, EYE_P)   # 실눈
            elif eyes == "open":
                r = 0.21 if face not in ("owl",) else 0.27
                if face == "owl":
                    cv.ellipse(x, y, hr * 0.3, hr * 0.3, WHITE, WHITE, WHITE)
                if face == "panda":
                    cv.ellipse(x + side * 0.3, y, hr * 0.13, hr * 0.16, WHITE, WHITE, WHITE)
                else:
                    cv.ellipse(x, y, hr * 0.17, hr * r, EYE_P, EYE_P, EYE_P)
                    cv.set(x - hr * 0.06, y - hr * 0.1, EYE_W)
                if face == "eagle":
                    cv.line(x - side * hr * 0.25, y - hr * 0.3, x + side * hr * 0.2, y - hr * 0.2, INK)  # 늠름한 눈썹
            elif eyes in ("happy", "closed"):
                col = WHITE if face == "panda" else EYE_P
                cv.set(x - 1, y, col)
                cv.set(x, y - 1, col)
                cv.set(x + 1, y, col)
            elif eyes == "hurt":
                col = WHITE if face == "panda" else EYE_P
                cv.line(x - 1, y - 1, x + 1, y, col)
                cv.line(x - 1, y + 1, x + 1, y, col)
            if face not in ("panda",):
                cv.set(cx + side * hr * 0.72, hy + hr * 0.28, BLUSH)
                cv.set(cx + side * hr * 0.62, hy + hr * 0.32, BLUSH)
        my = hy + hr * 0.5
        if face == "frog":
            cv.line(cx - hr * 0.5, hy + hr * 0.2, cx + hr * 0.5, hy + hr * 0.2, mix(FUR, BLACK, 0.5))
            if eyes == "happy":
                cv.ellipse(cx, hy + hr * 0.35, hr * 0.35, hr * 0.18, hx("#E8405A"), hx("#B02A40"), hx("#FF8FA3"))
        elif face not in ("beak", "owl", "eagle"):
            if eyes == "happy":
                cv.ellipse(cx, my + 0.6, hr * 0.2, hr * 0.16, hx("#7A1E2C"), hx("#7A1E2C"), hx("#7A1E2C"))
            else:
                cv.set(cx - 1, my, NOSE)
                cv.set(cx + 1, my, NOSE)
    # ── 소품
    acc = spec.get("acc", "")
    top = hy - hr * 0.95
    if acc == "eggshell":
        egg = hx("#FFFDF5")
        cv.rect(cx - hr * 0.7, top + hr * 0.1, cx + hr * 0.7, top + hr * 0.45, egg)
        for i in range(-3, 4):
            cv.set(cx + i * hr * 0.22, top + (0 if i % 2 else -0.6), egg)
    elif acc == "leafhat":
        cv.ellipse(cx + hr * 0.1, top - hr * 0.15, hr * 0.6, hr * 0.22, hx("#3E8E3A"), hx("#2C6A2A"), hx("#7CC15A"))
        cv.set(cx + hr * 0.1, top - hr * 0.4, hx("#2C6A2A"))
    elif acc == "sailor":
        cv.ellipse(cx, top + hr * 0.25, hr * 0.62, hr * 0.28, WHITE, hx("#C9D3E0"), WHITE)
        cv.rect(cx - hr * 0.62, top + hr * 0.35, cx + hr * 0.62, top + hr * 0.45, hx("#3F6FD8"))
    elif acc == "lamp":
        cv.ellipse(cx, top + hr * 0.4, hr * 0.85, hr * 0.5, hx("#F2C14E"), hx("#C9921E"), hx("#FFE59A"))
        if not back:
            cv.ellipse(cx, top + hr * 0.3, hr * 0.2, hr * 0.18, WHITE, hx("#FFF3B0"), WHITE)
    elif acc == "scarf" or acc == "icescarf":
        sc = hx("#E8405A") if acc == "scarf" else hx("#7FD0FF")
        cv.rect(cx - body_r * 0.8, by - body_r * 0.85, cx + body_r * 0.8, by - body_r * 0.6, sc)
        cv.rect(cx + body_r * 0.3, by - body_r * 0.6, cx + body_r * 0.55, by + body_r * 0.1, sc)
    elif acc == "glasses" and not back:
        for side in (-1, 1):
            x = cx + side * hr * 0.44
            for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                cv.set(x + dx * hr * 0.15, hy - hr * 0.08 + dy * hr * 0.15, hx("#C9921E"))
    elif acc == "goggles":
        cv.rect(cx - hr * 0.95, top + hr * 0.45, cx + hr * 0.95, top + hr * 0.6, hx("#5A4A3A"))
        for side in (-1, 1):
            cv.ellipse(cx + side * hr * 0.42, top + hr * 0.5, hr * 0.26, hr * 0.2, hx("#7FD0FF"), hx("#3F8FC8"), WHITE)
    # 휘두르는 앞발은 머리 앞에 다시 그린다 (머리에 가려 안 보였다)
    if back and view == "attack" and frame in (1, 2) and spec["arms"] not in ("wing", "bigwing", "flipper") \
            and face != "frog":
        ac2 = INK if spec["arms"] == "dark" else FUR_D
        px_, py_ = cx + body_r * 1.0, by - body_r * (1.35 if frame == 1 else 1.0)
        cv.line(cx + body_r * 0.7, by - body_r * 0.3, px_, py_, ac2, 2)
        cv.ellipse(px_, py_, body_r * 0.3, body_r * 0.3, FUR, ac2, FUR_L)
        for k in (-1, 0, 1):
            cv.set(px_ + k, py_ - body_r * 0.32, hx("#F4F0E6"))
    # 손에 쥐는 것 (뒷모습 공격에선 오른손)
    hand = (cx + body_r * 0.95, by - body_r * (1.2 if back and view == "attack" and frame in (1, 2) else 0.0))
    if view == "attack" and face == "frog" and frame in (1, 2):
        # 혀를 위로 쭉 - 끝에 동그란 혀끝
        L = hr * (1.7 if frame == 1 else 2.4)
        tongue = hx("#FF7AA8")
        cv.line(cx, hy - hr * 0.2, cx, hy - hr * 0.2 - L, tongue, 2)
        cv.ellipse(cx + 0.5, hy - hr * 0.2 - L, 1.6, 1.6, tongue, hx("#D04A7A"), hx("#FFC0D8"))
    if acc == "acorn":
        if not (back and pose == 1):
            cv.ellipse(hand[0], hand[1] - 1, 1.3, 1.5, hx("#A9754A"), hx("#6E4628"), hx("#C99466"))
            cv.rect(hand[0] - 1.3, hand[1] - 2.5, hand[0] + 1.3, hand[1] - 2, hx("#5E3C22"))
        else:
            cv.ellipse(hand[0] + 1, hand[1] - hr * 1.6, 1.3, 1.5, hx("#A9754A"), hx("#6E4628"), hx("#C99466"))
    elif acc == "carrot":
        cv.line(hand[0], hand[1] + 1, hand[0] + (2 if pose == 1 else 0), hand[1] - 3, hx("#FF8A2A"), 2)
        cv.set(hand[0] + (2 if pose == 1 else 0), hand[1] - 4, hx("#4E8A35"))
    elif acc == "bamboo":
        tip = (hand[0] + (hr * 1.0 if pose == 1 else 1), hand[1] - hr * (1.0 if pose == 1 else 1.8))
        cv.line(hand[0], hand[1] + hr * 0.4, tip[0], tip[1], hx("#7CC15A"), 2)
        cv.set((hand[0] + tip[0]) / 2, (hand[1] + tip[1]) / 2, hx("#3E8E3A"))
        cv.set(tip[0] + 1, tip[1], hx("#3E8E3A"))
    elif acc == "clam":
        cv.ellipse(hand[0], hand[1] - 0.5, 1.8, 1.4, hx("#F4B6C2"), hx("#D07A90"), WHITE)
    if back and pose == 1 and acc in ("claw",) or (back and pose == 1 and spec["arms"] == "claw"):
        for k in range(3):   # 할퀴기 자국
            cv.line(hand[0] + 1 + k, hand[1] - hr * 1.2, hand[0] + 3 + k, hand[1] - hr * 0.4, hx("#FFFFFF"))
    if evo:
        cv.rect(cx - hr * 0.7, top + hr * 0.1, cx + hr * 0.7, top + hr * 0.25, GOLD)
        for k in (-1, 0, 1):
            cv.set(cx + k * hr * 0.5, top - 0.5, GOLD)
        cv.set(cx, top - 1.5, hx("#E8405A"))
    cv.outline()
    if view == "attack" and face != "frog":
        qk.strike_fx(cv, {"gear": "leaf"}, cx, by, hr, frame)
    return cv.image()


def sheet(spec, evo):
    W = spec["cell"] + (2 if evo else 0)
    H = W + qk.head_room(W)
    im = Image.new("RGBA", (W * 4, H * 3), (0, 0, 0, 0))
    for f in range(4):
        im.paste(animal(spec, "front", f, evo), (f * W, 0))
        im.paste(animal(spec, "attack", f, evo), (f * W, H))
        im.paste(animal(spec, "walk", f, evo), (f * W, H * 2))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for uid, spec in ANIMALS.items():
        sheet(spec, False).save(os.path.join(OUT, "animal-%s.png" % uid))
        sheet(spec, True).save(os.path.join(OUT, "animal-%s-2.png" % uid))
    print("animal sheets:", len(ANIMALS) * 2)


if __name__ == "__main__":
    main()
