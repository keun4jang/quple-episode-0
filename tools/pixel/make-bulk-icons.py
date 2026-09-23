#!/usr/bin/env python3
"""물건 그림을 한꺼번에 찍는다 (`docs/items-rewards.md`).

`make-item-icons.py` 가 한 장씩 손으로 찍던 방식은 스무 장까지였다.
백 장 가까이 되면 같은 손질(외곽선·명암)을 매번 되풀이하다 틀린다.
그래서 **모양만 적고, 외곽선과 명암은 저절로 입힌다.**

    - 모양 = 칠할 칸의 집합(마스크)과 색 한 겹씩
    - 외곽선 = 모든 겹을 합친 모양의 바깥 한 칸 (1px, 가장 어두운 색)
    - 명암 = 겹마다 오른쪽 아래 가장자리는 어둡게, 왼쪽 위는 밝게

16x16 안에서 **실루엣으로 구분되게** 그린다 — 잔무늬는 배낭 격자에서
안 보인다. 외부 그림은 한 장도 안 쓴다 (`CLAUDE.md`).

    python3 tools/pixel/make-bulk-icons.py        # 전부
    python3 tools/pixel/make-bulk-icons.py b-corn # 하나만
"""
import math
import os
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
S = 16


# ── 색 ────────────────────────────────────────────────────────────────

def hx(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


def mul(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))),
            max(0, min(255, int(c[2] * k))), 255)


# ── 모양 (칸 집합) ────────────────────────────────────────────────────

def ellipse(cx, cy, rx, ry):
    out = set()
    for y in range(S):
        for x in range(S):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                out.add((x, y))
    return out


def rect(x0, y0, x1, y1):
    """양끝 포함."""
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def rows(y0, spans):
    """줄마다 (시작, 끝) — 양끝 포함."""
    out = set()
    for i, (a, b) in enumerate(spans):
        for x in range(a, b + 1):
            out.add((x, y0 + i))
    return out


def poly(pts):
    out = set()
    n = len(pts)
    for y in range(S):
        for x in range(S):
            px, py = x + 0.5, y + 0.5
            inside = False
            j = n - 1
            for i in range(n):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > py) != (yj > py):
                    xc = (xj - xi) * (py - yi) / (yj - yi) + xi
                    if px < xc:
                        inside = not inside
                j = i
            if inside:
                out.add((x, y))
    return out


def line(x0, y0, x1, y1, w=1):
    out = set()
    steps = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        for dx in range(w):
            for dy in range(w):
                out.add((x + dx, y + dy))
    return out


def ring(cx, cy, r_out, r_in):
    return ellipse(cx, cy, r_out, r_out) - ellipse(cx, cy, r_in, r_in)


def clip(m):
    return {(x, y) for x, y in m if 0 <= x < S and 0 <= y < S}


# ── 찍기 ──────────────────────────────────────────────────────────────

def render(layers, dots=(), outline=None, shade=True):
    """layers: [(모양, 색)]. 뒤에 온 겹이 위에 그려진다.
    dots: [((x, y), 색)] — 명암 없이 마지막에 찍는 점 (빛·눈·무늬)."""
    px = {}
    union = set()
    for m, col in layers:
        m = clip(m)
        union |= m
        for (x, y) in m:
            c = col
            if shade:
                if (x + 1, y + 1) not in m and (x, y + 1) not in m:
                    c = mul(col, 0.78)
                elif (x - 1, y - 1) not in m and (x, y - 1) not in m:
                    c = mul(col, 1.14)
            px[(x, y)] = c
    if outline is None:
        outline = mul(layers[0][1], 0.42)
    else:
        outline = hx(outline)
    edge = set()
    for (x, y) in union:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in union and 0 <= q[0] < S and 0 <= q[1] < S:
                edge.add(q)
    for q in edge:
        px[q] = outline
    for (q, col) in dots:
        if 0 <= q[0] < S and 0 <= q[1] < S:
            px[q] = hx(col) if isinstance(col, str) else col
    return px


def save(name, px):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.putdata([px.get((x, y), (0, 0, 0, 0)) for y in range(S) for x in range(S)])
    img.save(os.path.join(OUT, name + ".png"))


# ── 되풀이 되는 틀 ─────────────────────────────────────────────────────

def cup(liquid, body="#F2E7D2", handle=True, steam=True, extra=()):
    """손잡이 달린 찻잔. 찻물을 두 줄 보여야 무슨 차인지 색으로 갈린다.
    extra: 잔 위나 곁에 얹는 것 (유자 한 조각, 꽃 한 송이) — 색만 다른 잔이
    일곱이라 그것 하나로 가른다."""
    b = rows(6, [(3, 11)] * 6 + [(4, 10)])
    h = (rect(12, 8, 13, 10) - rect(12, 9, 12, 9)) if handle else set()
    liq = rect(4, 6, 10, 7)
    dots = []
    if steam:
        dots = [((6, 3), "#E8DCCB"), ((6, 2), "#E8DCCB"), ((9, 4), "#E8DCCB"), ((9, 2), "#E8DCCB")]
    layers = [(b | h, hx(body)), (liq, hx(liquid))]
    layers += list(extra)
    return render(layers, dots)


def bowl(soup, rim="#E9E0D0", fill=None, dots=()):
    """국그릇. fill 은 국 위에 뜬 것."""
    b = rows(8, [(1, 14), (2, 13), (3, 12), (4, 11), (5, 10)])
    foot = rect(6, 13, 9, 13)
    top = rect(2, 7, 13, 8) - {(2, 8), (13, 8)}
    layers = [(b | foot, hx(rim)), (top, hx(soup))]
    if fill:
        layers.append(fill)
    return render(layers, dots)


def glass(liquid, cap=None):
    """키 큰 유리잔."""
    g = rows(3, [(5, 10)] * 11 + [(6, 9)])
    liq = rows(6, [(6, 9)] * 8)
    layers = [(g, hx("#DCEFF2")), (liq, hx(liquid))]
    dots = [((6, 4), "#FFFFFF"), ((6, 5), "#FFFFFF")]
    if cap:
        dots.append(((8, 5), cap))
    return render(layers, dots, outline="#5A7078")


def bun(col, top=None, dots=()):
    """둥근 빵."""
    b = ellipse(8, 9.5, 6.5, 4.8)
    layers = [(b, hx(col))]
    if top:
        layers.append(top)
    return render(layers, dots)


def skewer(pieces, stick="#B99562"):
    """꼬치 — 막대에 꿴 것들."""
    st = line(2, 14, 13, 3)
    layers = [(st, hx(stick))]
    for m, c in pieces:
        layers.append((m, hx(c)))
    return render(layers)


def stamp(ink, motif):
    """여행 도장 — 붉은 둥근 테 안에 마을 무늬."""
    paper = ellipse(8, 8, 7.5, 7.5)
    rim = ring(8, 8, 7.5, 6.0)
    layers = [(paper, hx("#F6EEDC")), (rim, hx(ink)), (motif, hx(ink))]
    return render(layers, outline="#6B4A3A", shade=False)


def shard(col, glow):
    """그늘 조각 — 뾰족한 결정 하나. 일곱이 한 벌이라 모양은 같고 색만 다르다."""
    m = poly([(8, 1), (12, 6), (11, 13), (7, 15), (4, 10), (5, 5)])
    face = poly([(8, 1), (12, 6), (9, 9), (7, 5)])
    return render([(m, hx(col)), (face, hx(glow))],
                  dots=[((7, 4), "#FFFFFF"), ((6, 6), mul(hx(glow), 1.2))])


def pouch(col, tie="#7A5230", dots=()):
    body = ellipse(8, 10.5, 5.5, 4.5)
    neck = rect(6, 4, 9, 6)
    top = rows(3, [(5, 10)])
    string = rect(5, 6, 10, 6)
    return render([(body | neck | top, hx(col)), (string, hx(tie))], dots)


# ── 그림 목록 ─────────────────────────────────────────────────────────

ICONS = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


# ── 먹을 것 ───────────────────────────────────────────────────────────

@icon("b-riceball")
def _():
    tri = poly([(8, 2), (14.5, 13.5), (1.5, 13.5)])
    nori = rect(4, 10, 11, 13) & tri
    return render([(tri, hx("#F7F4EC")), (nori, hx("#2E3A2E"))], outline="#6E6A60")


@icon("b-barleytea")
def _():
    return cup("#B8834A")


@icon("b-sweetpotato")
def _():
    body = ellipse(8, 8.5, 6.8, 3.6)
    body = {(x, y) for x, y in body if (x - y) > -6}
    end = ellipse(13, 6.5, 1.8, 2.2)
    return render([(body, hx("#8E3B55")), (end, hx("#F2C14E"))])


@icon("b-sikhye")
def _():
    return bowl("#EEDFB8", dots=[((6, 7), "#FFFFFF"), ((9, 7), "#FFFFFF"), ((11, 7), "#FFFFFF")])


@icon("b-yakgwa")
def _():
    petals = set()
    for a in range(8):
        t = a * math.pi / 4
        petals |= ellipse(8 + 4.2 * math.cos(t), 8 + 4.2 * math.sin(t), 2.4, 2.4)
    petals |= ellipse(8, 8, 4.5, 4.5)
    hole = ellipse(8, 8, 1.4, 1.4)
    return render([(petals, hx("#B8742E")), (hole, hx("#7A4418"))])


@icon("b-honeycake")
def _():
    plate = rows(12, [(1, 14), (2, 13)])
    a = ellipse(5, 9, 2.8, 2.6)
    b = ellipse(11, 9, 2.8, 2.6)
    c = ellipse(8, 6.5, 2.8, 2.6)
    return render([(plate, hx("#E4DCCF")), (a, hx("#8CC57A")), (b, hx("#F2A7B8")),
                   (c, hx("#F7F0DA"))], dots=[((7, 5), "#FFFFFF")])


@icon("b-citron-tea")
def _():
    return cup("#F2B84A", steam=False, extra=[(ellipse(12, 4, 2.4, 2.4), hx("#F7D84A"))])


@icon("b-cookie")
def _():
    bag = rect(3, 3, 12, 14)
    crimp = rect(3, 2, 12, 2)
    win = rect(5, 7, 10, 11)
    return render([(bag | crimp, hx("#E86A5A")), (win, hx("#F2D49A"))],
                  dots=[((6, 8), "#B8742E"), ((9, 10), "#B8742E"), ((8, 8), "#B8742E"),
                        ((5, 4), "#FFFFFF"), ((10, 4), "#FFFFFF")])


@icon("b-candy")
def _():
    ball = ellipse(8, 8, 4, 4)
    wl = poly([(4.5, 8), (1, 5), (1, 11)])
    wr = poly([(11.5, 8), (15, 5), (15, 11)])
    return render([(wl | wr, hx("#9BD0E8")), (ball, hx("#E85A7A"))],
                  dots=[((6, 6), "#FFFFFF"), ((7, 6), "#FFD4DE")])


@icon("b-lunchbox")
def _():
    box = rect(2, 6, 13, 13)
    knot = ellipse(8, 5, 3.2, 2.2) | rect(7, 3, 8, 6)
    cloth = rect(2, 8, 13, 9)
    return render([(box, hx("#D95F4B")), (cloth, hx("#F2D06B")), (knot, hx("#F2D06B"))],
                  dots=[((4, 11), "#F7E6C0"), ((11, 11), "#F7E6C0")])


@icon("b-apple")
def _():
    plate = rows(11, [(0, 15), (1, 14), (3, 12)])
    layers = [(plate, hx("#EAE2D4"))]
    for cx in (4.5, 11.5):
        wedge = ellipse(cx, 10, 3.6, 5) - rect(0, 10, 15, 15)
        skin = wedge - ellipse(cx, 10, 2.6, 4)
        layers += [(wedge, hx("#F7EDC8")), (skin, hx("#D8423A"))]
    return render(layers, dots=[((4, 8), "#8A5A2A"), ((11, 8), "#8A5A2A")])


@icon("b-fishcake")
def _():
    folds = set()
    for i, (cx, cy) in enumerate([(5, 11), (8, 8), (11, 5)]):
        folds |= ellipse(cx, cy, 2.4, 2.4)
    return skewer([(folds, "#E8C27A")])


@icon("b-gimbap")
def _():
    layers = []
    for cx, cy in [(4.5, 10), (11.5, 10), (8, 5)]:
        layers.append((ellipse(cx, cy, 3.4, 3.4), hx("#2E3A2E")))
        layers.append((ellipse(cx, cy, 2.5, 2.5), hx("#F7F4EC")))
        layers.append((ellipse(cx, cy, 1.0, 1.0), hx("#F2A03A")))
    return render(layers, shade=False, outline="#1E261E")


@icon("b-redbean-bread")
def _():
    return bun("#B86B34", dots=[((8, 7), "#F7EAD0"), ((7, 7), "#F7EAD0"), ((5, 7), "#E09A5E")])


@icon("b-garaetteok")
def _():
    a = rect(1, 5, 14, 7)
    b = rect(2, 9, 13, 11)
    return render([(a, hx("#F7F4EC")), (b, hx("#F7F4EC"))], outline="#8C857A")


@icon("b-noodle")
def _():
    noodles = rect(3, 7, 12, 7)
    return bowl("#F2E7C8", fill=(noodles, hx("#F7F0DA")),
                dots=[((5, 6), "#F7F0DA"), ((8, 5), "#F7F0DA"), ((10, 6), "#F7F0DA"),
                      ((7, 7), "#8CC57A"), ((11, 7), "#E8C27A")])


@icon("b-potato")
def _():
    a = ellipse(6, 9, 4.5, 4)
    b = ellipse(10.5, 8, 4, 3.6)
    return render([(a | b, hx("#C9A26A"))],
                  dots=[((5, 8), "#8A6A3E"), ((11, 7), "#8A6A3E"), ((8, 11), "#8A6A3E")])


@icon("b-citrus-juice")
def _():
    return glass("#F2A03A", cap="#FFE0A0")


@icon("b-citrus-bread")
def _():
    b = ellipse(8, 9, 5.5, 5.2)
    return render([(b, hx("#E8A04A"))],
                  dots=[((8, 3), "#4E7A3A"), ((9, 3), "#4E7A3A"), ((6, 6), "#F7D09A"),
                        ((6, 10), "#C77A2E"), ((10, 11), "#C77A2E")])


@icon("b-corn")
def _():
    cob = ellipse(9, 8, 3, 6.5)
    husk = poly([(3, 15), (6, 6), (8, 14)]) | poly([(14, 15), (12, 5), (10, 14)])
    dots = [((x, y), "#D9A11E") for y in range(3, 14, 2) for x in (8, 10)]
    return render([(cob, hx("#F2CE4A")), (husk, hx("#7BB86E"))], dots)


@icon("b-plum-tea")
def _():
    return cup("#C9D46A", steam=False, extra=[(ellipse(4, 4, 2.2, 2.2), hx("#7BB84A"))])


@icon("b-cream-bread")
def _():
    b = ellipse(8, 9, 7, 4)
    cream = rect(3, 8, 12, 9)
    return render([(b, hx("#D9A05E")), (cream, hx("#FFF6E0"))])


@icon("b-lotus-tea")
def _():
    leaf = ellipse(8, 4, 4.5, 1.8)
    return cup("#8FBF8A", body="#E4EDE0", steam=False, extra=[(leaf, hx("#5AA05A"))])


@icon("b-chestnut")
def _():
    layers = []
    dots = []
    for cx, cy in [(5, 10), (11, 10), (8, 5)]:
        nut = poly([(cx, cy - 4), (cx + 3.2, cy + 1), (cx + 2, cy + 3), (cx - 2, cy + 3), (cx - 3.2, cy + 1)])
        layers.append((nut, hx("#7A4A2A")))
        layers.append((rect(int(cx) - 2, int(cy) + 1, int(cx) + 1, int(cy) + 2), hx("#E8C890")))
        dots.append(((int(cx) - 1, int(cy) - 2), "#B8805A"))
    return render(layers, dots)


@icon("b-sujeonggwa")
def _():
    return bowl("#9A4A2E", dots=[((6, 7), "#E86A4A"), ((10, 7), "#F2D06B")])


@icon("b-pine-tea")
def _():
    sprig = line(9, 5, 13, 1) | line(11, 3, 12, 5) | line(10, 2, 11, 4)
    return cup("#6E9E5A", steam=False, extra=[(sprig, hx("#3E7A3E"))])


@icon("b-acorn-jelly")
def _():
    plate = rows(12, [(1, 14), (2, 13)])
    c1 = rect(2, 7, 6, 11)
    c2 = rect(9, 7, 13, 11)
    c3 = rect(5, 3, 10, 7)
    return render([(plate, hx("#E4DCCF")), (c1, hx("#7A5236")), (c2, hx("#7A5236")),
                   (c3, hx("#8C6242"))])


@icon("b-strawberry")
def _():
    berry = poly([(2, 6), (14, 6), (8, 15)]) | ellipse(5, 7, 3.2, 2.5) | ellipse(11, 7, 3.2, 2.5)
    leaf = rows(3, [(6, 9), (4, 11)])
    dots = [((x, y), "#F7E6A0") for (x, y) in [(5, 8), (9, 8), (7, 10), (11, 9), (8, 12)]]
    return render([(berry, hx("#E0404A")), (leaf, hx("#4E8C4A"))], dots)


@icon("b-hwajeon")
def _():
    cake = ellipse(8, 9, 6, 5)
    flower = set()
    for cx, cy in [(8, 7), (6.5, 8.5), (9.5, 8.5), (7, 10), (9, 10)]:
        flower |= ellipse(cx, cy, 1.1, 1.1)
    return render([(cake, hx("#F7F0E4")), (flower, hx("#E87AA0"))],
                  dots=[((8, 9), "#F2D06B"), ((4, 7), "#6FA85A"), ((12, 11), "#6FA85A")])


# ── 기념품 ────────────────────────────────────────────────────────────

@icon("k-lens")
def _():
    frame = ring(8, 8, 6.5, 4.8)
    glass_ = ellipse(8, 8, 4.8, 4.8)
    return render([(glass_, hx("#9FD4E0")), (frame, hx("#C9A24A"))],
                  dots=[((6, 6), "#FFFFFF"), ((7, 6), "#E8F8FA"), ((6, 7), "#E8F8FA")])


@icon("k-rope")
def _():
    loop1 = ring(5.5, 6, 3.6, 1.8)
    loop2 = ring(10.5, 6, 3.6, 1.8)
    tails = line(7, 9, 4, 14, 2) | line(9, 9, 12, 14, 2)
    return render([(loop1 | loop2 | tails, hx("#C9A26A"))])


@icon("k-roof-tile")
def _():
    tile = ring(8, 13, 7.5, 4.2)
    tile = {(x, y) for x, y in tile if y <= 12}
    return render([(tile, hx("#6E7E8C"))], dots=[((5, 7), "#A9B8C4"), ((8, 6), "#A9B8C4")])


@icon("k-clay-bell")
def _():
    bell = ellipse(8, 9, 5.5, 5.5)
    slit = rect(5, 10, 10, 10)
    loop = ring(8, 3, 1.8, 0.8)
    return render([(bell | loop, hx("#B8744A")), (slit, hx("#5A3420"))])


@icon("k-bookmark")
def _():
    card = rect(4, 1, 11, 14)
    stem = line(8, 12, 8, 7)
    petals = ellipse(8, 5.5, 2.4, 2.4)
    return render([(card, hx("#F2E7D2")), (stem, hx("#6FA85A")), (petals, hx("#E8A0C0"))],
                  dots=[((8, 5), "#F2D06B")])


@icon("k-ridge-stone")
def _():
    st = ellipse(8, 9, 6.5, 5)
    band = {(x, y) for x, y in st if 8 <= y <= 9}
    return render([(st, hx("#8C8A84")), (band, hx("#E88A4A"))])


@icon("k-anchor")
def _():
    shaft = rect(7, 3, 8, 13)
    ringt = ring(7.5, 2.5, 2.2, 1.0)
    bar = rect(4, 5, 11, 6)
    arms = line(2, 10, 7, 14, 2) | line(13, 10, 8, 14, 2)
    return render([(shaft | ringt | bar | arms, hx("#6E7E8C"))])


@icon("k-chopsticks")
def _():
    return render([(line(3, 14, 11, 1, 2), hx("#C9A26A")), (line(6, 15, 14, 3, 2), hx("#B8905A"))])


@icon("k-basket")
def _():
    b = rows(7, [(1, 14), (2, 13), (2, 13), (3, 12), (3, 12), (4, 11), (5, 10)])
    handle = ring(8, 7, 6, 4.8)
    handle = {(x, y) for x, y in handle if y < 7}
    dots = [((x, y), "#8A6A3E") for y in (8, 10, 12) for x in range(3, 13, 2) if (x, y) in b]
    return render([(b, hx("#C9A26A")), (handle, hx("#B8905A"))], dots)


@icon("k-pinwheel")
def _():
    stick = rect(7, 8, 8, 15)
    b1 = poly([(8, 8), (8, 1), (12, 5)])
    b2 = poly([(8, 8), (15, 8), (11, 12)])
    b3 = poly([(8, 8), (8, 15), (4, 11)])
    b4 = poly([(8, 8), (1, 8), (5, 4)])
    return render([(stick, hx("#B8905A")), (b1 | b3, hx("#E85A5A")), (b2 | b4, hx("#5AA0E8"))],
                  dots=[((8, 8), "#F2D06B")])


@icon("k-citrus-bell")
def _():
    bell = ellipse(8, 9.5, 5, 5)
    bow = ellipse(5.5, 3.5, 2, 1.5) | ellipse(10.5, 3.5, 2, 1.5)
    return render([(bell, hx("#F2A03A")), (bow, hx("#6FA85A"))],
                  dots=[((6, 7), "#FFE0A0"), ((7, 11), "#8A4A1E"), ((8, 11), "#8A4A1E")])


@icon("k-oar")
def _():
    shaft = line(3, 2, 10, 10, 2)
    blade = ellipse(12, 12.5, 2.8, 2.8)
    return render([(shaft, hx("#B8905A")), (blade, hx("#9A6A3A"))])


@icon("k-river-stone")
def _():
    st = ellipse(8, 9, 6.5, 4.5)
    return render([(st, hx("#7E9A8A"))], dots=[((5, 7), "#C4D8CC"), ((6, 7), "#C4D8CC")])


@icon("k-straw-hat")
def _():
    brim = ellipse(8, 10.5, 7.5, 3)
    crown = ellipse(8, 7, 4, 3.5)
    band = rect(4, 8, 11, 8) & crown
    return render([(brim, hx("#E8CC7A")), (crown, hx("#E0BE66")), (band, hx("#D9534A"))])


@icon("k-lotus-leaf")
def _():
    leaf = ellipse(8, 8.5, 6.8, 6) - poly([(8, 8), (8, 1), (11, 1)])
    return render([(leaf, hx("#5AA05A"))],
                  dots=[((6, 10), "#B4E0F0"), ((10, 11), "#B4E0F0"), ((8, 8), "#3E7A3E")])


@icon("k-wind-chime")
def _():
    bell = ellipse(8, 6, 4.5, 4) | rect(4, 6, 12, 8)
    string = rect(8, 9, 8, 11)
    paper = rect(6, 12, 10, 15)
    return render([(bell, hx("#9FD4E0")), (string, hx("#E86A5A")), (paper, hx("#F2E7D2"))],
                  dots=[((6, 4), "#FFFFFF"), ((8, 13), "#5AA0E8")])


@icon("k-rolling-pin")
def _():
    body = rect(3, 6, 12, 10)
    h1 = rect(0, 7, 2, 9)
    h2 = rect(13, 7, 15, 9)
    return render([(body, hx("#D9B07A")), (h1 | h2, hx("#B8905A"))])


@icon("k-reed-flute")
def _():
    tube = line(2, 13, 13, 2, 2)
    return render([(tube, hx("#C9B36A"))],
                  dots=[((5, 10), "#5A4A22"), ((7, 8), "#5A4A22"), ((9, 6), "#5A4A22")])


@icon("k-nest")
def _():
    n = rows(7, [(1, 14), (1, 14), (2, 13), (3, 12), (5, 10)])
    inner = rows(7, [(4, 11), (5, 10)])
    dots = [((2, 6), "#8A6A3E"), ((13, 6), "#8A6A3E"), ((6, 10), "#6E4E2A"), ((10, 9), "#6E4E2A")]
    return render([(n, hx("#A07A4A")), (inner, hx("#5A4228"))], dots)


@icon("k-straw-mat")
def _():
    roll = rect(2, 5, 13, 11)
    end = ellipse(13.5, 8, 1.8, 3.2)
    dots = [((x, 8), "#A08A4A") for x in range(3, 13, 2)]
    return render([(roll, hx("#D9C27A")), (end, hx("#C9B06A"))], dots)


@icon("k-gold-cone")
def _():
    cone = ellipse(8, 9, 4.5, 6)
    dots = [((x, y), "#A8801E") for y in range(5, 15, 2) for x in (6, 8, 10) if (x, y) in cone]
    return render([(cone, hx("#F2C84A"))], dots + [((6, 5), "#FFF4C0")])


@icon("k-pine-sachet")
def _():
    return pouch("#6E9E5A", dots=[((6, 10), "#A8D08A"), ((9, 12), "#A8D08A")])


@icon("k-walking-stick")
def _():
    stick = line(6, 5, 9, 15, 2)
    hook = ring(4.5, 4.5, 3, 1.6)
    hook = {(x, y) for x, y in hook if y <= 5 or x >= 5}
    return render([(stick | hook, hx("#9A6A3A"))])


@icon("k-petal-jar")
def _():
    jar = rows(5, [(3, 12)] * 9 + [(4, 11)])
    lid = rect(4, 2, 11, 4)
    petals = rect(4, 9, 11, 13)
    return render([(jar, hx("#DCEFF2")), (petals, hx("#F2A7C0")), (lid, hx("#C9A26A"))],
                  dots=[((5, 6), "#FFFFFF"), ((5, 7), "#FFFFFF")], outline="#5A7078")


@icon("k-scarecrow")
def _():
    pole = rect(7, 6, 8, 15)
    arms = rect(2, 7, 13, 8)
    head = ellipse(7.5, 4, 2.5, 2.5)
    hat = rect(4, 1, 11, 2)
    return render([(pole | arms, hx("#9A6A3A")), (head, hx("#F2E7D2")), (hat, hx("#E0BE66"))])


@icon("k-seed-pouch")
def _():
    return pouch("#B8905A", dots=[((7, 11), "#5A3A1E"), ((9, 10), "#5A3A1E"), ((8, 12), "#5A3A1E")])


@icon("k-family-photo")
def _():
    frame = rect(1, 3, 14, 13)
    pic = rect(3, 5, 12, 11)
    faces = []
    for x in (4, 6, 9, 11):
        faces.append(((x, 8), "#B8784F"))
        faces.append(((x, 9), "#B8784F"))
    return render([(frame, hx("#9A6A3A")), (pic, hx("#CFE4F0"))], faces)


@icon("k-ticket")
def _():
    t = rect(1, 4, 14, 11) - ellipse(1, 7.5, 1.5, 1.5) - ellipse(14.5, 7.5, 1.5, 1.5)
    stripe = rect(1, 4, 14, 5) & t
    return render([(t, hx("#F2E7D2")), (stripe, hx("#5AA0E8"))],
                  dots=[((4, 8), "#8C7B68"), ((6, 8), "#8C7B68"), ((8, 8), "#8C7B68"),
                        ((10, 9), "#E85A5A"), ((11, 9), "#E85A5A")])


@icon("k-lanyard")
def _():
    loop = ring(8, 6, 5.5, 4.4)
    loop = {(x, y) for x, y in loop if y <= 9}
    clip_ = rect(6, 10, 9, 14)
    return render([(loop, hx("#5A7AB8")), (clip_, hx("#A9B8C4"))])


# ── 여행 도장 ─────────────────────────────────────────────────────────

STAMP_INK = {
    "yunseul": "#C23B3B", "byeotnwi": "#B8603A", "gapuljae": "#C2503B",
    "hanuiseom": "#D0643A", "gubinaru": "#3B6EC2", "bangulmot": "#3B8EB0",
    "galbatmeori": "#A0863A", "soleunjae": "#3B8A5A", "kkonnunbeol": "#C23B7A",
}


def _wave():
    return line(4, 9, 6, 7) | line(6, 7, 8, 9) | line(8, 9, 10, 7) | line(10, 7, 12, 9)


STAMP_MOTIF = {
    "yunseul": _wave,
    "byeotnwi": lambda: rect(4, 6, 11, 6) | line(4, 7, 11, 7) | rect(5, 9, 10, 9),
    "gapuljae": lambda: line(3, 11, 7, 5) | line(7, 5, 10, 9) | line(10, 9, 12, 7),
    "hanuiseom": lambda: line(4, 6, 11, 6) | line(5, 9, 12, 9) | line(4, 12, 9, 12),
    "gubinaru": lambda: line(5, 3, 10, 6) | line(10, 6, 6, 9) | line(6, 9, 10, 12),
    "bangulmot": lambda: ellipse(8, 9, 2.6, 2.6) | line(8, 4, 8, 6),
    "galbatmeori": lambda: line(5, 12, 5, 4) | line(8, 12, 8, 3) | line(11, 12, 11, 5),
    "soleunjae": lambda: line(8, 3, 8, 12) | line(8, 5, 5, 8) | line(8, 5, 11, 8) | line(8, 8, 5, 11) | line(8, 8, 11, 11),
    "kkonnunbeol": lambda: (ellipse(8, 5.5, 1.6, 1.6) | ellipse(5.5, 8, 1.6, 1.6) | ellipse(10.5, 8, 1.6, 1.6)
                            | ellipse(6.5, 11, 1.6, 1.6) | ellipse(9.5, 11, 1.6, 1.6)),
}

for _v in STAMP_INK:
    ICONS["st-" + _v] = (lambda v: (lambda: stamp(STAMP_INK[v], STAMP_MOTIF[v]())))(_v)


# ── 그늘 조각 ─────────────────────────────────────────────────────────

SHARD = {
    "worry": ("#6E86A8", "#B4CCE6"), "hurry": ("#C27A3A", "#F2C08A"),
    "lonely": ("#4E5A9A", "#9AA6E0"), "tired": ("#7A6E8C", "#C4B8D6"),
    "regret": ("#3E7A7A", "#8CC4C4"), "envy": ("#5A8A3E", "#A8D08A"),
    "night": ("#2E3458", "#7A86C8"),
}
for _k in SHARD:
    ICONS["m-" + _k] = (lambda k: (lambda: shard(*SHARD[k])))(_k)


# ── 가게 먹거리 ───────────────────────────────────────────────────────

@icon("f-white-bread")
def _():
    loaf = ellipse(8, 6, 6, 3.5) | rect(2, 6, 13, 13)
    inner = ellipse(8, 6.5, 4.5, 2.4) | rect(4, 7, 11, 12)
    return render([(loaf, hx("#C98A4A")), (inner, hx("#F7EDD8"))])


@icon("f-milk")
def _():
    return glass("#FAFAF2")


@icon("f-anchovy-soup")
def _():
    return bowl("#D9B77A", dots=[((6, 7), "#8C8A84"), ((10, 7), "#8C8A84")])


@icon("f-kimchi")
def _():
    plate = rows(11, [(1, 14), (2, 13)])
    leaf = ellipse(6, 8, 4, 3) | ellipse(10, 7.5, 3.5, 3)
    return render([(plate, hx("#E4DCCF")), (leaf, hx("#D9463A"))],
                  dots=[((6, 7), "#F2D06B"), ((10, 7), "#F7EAD0"), ((8, 9), "#6FA85A")])


@icon("f-fresh-tangerine")
def _():
    segs = set()
    for a in range(6):
        t = a * math.pi / 3
        segs |= ellipse(8 + 3 * math.cos(t), 8.5 + 3 * math.sin(t), 2.3, 2.3)
    return render([(segs, hx("#F2A03A"))], dots=[((8, 8), "#F7E0B0"), ((8, 9), "#F7E0B0")])


@icon("f-peel-tea")
def _():
    peel = line(3, 3, 7, 5, 2)
    return cup("#E8903A", steam=False, extra=[(peel, hx("#F2A03A"))])


@icon("f-snail-soup")
def _():
    return bowl("#6EA89A", dots=[((5, 7), "#3E5A4A"), ((8, 7), "#3E5A4A"), ((11, 7), "#3E5A4A")])


@icon("f-grilled-ricecake")
def _():
    pieces = ellipse(5, 11, 2.2, 2.2) | ellipse(8, 8, 2.2, 2.2) | ellipse(11, 5, 2.2, 2.2)
    return skewer([(pieces, "#F2E0B0")])


@icon("f-cream-puff")
def _():
    puff = ellipse(8, 9, 6, 4.5)
    cream = rect(3, 9, 12, 9)
    top = ellipse(8, 6, 4, 2.5)
    return render([(puff, hx("#E0B070")), (cream, hx("#FFF6E0")), (top, hx("#E8BE80"))],
                  dots=[((6, 5), "#FFFFFF")])


@icon("f-cocoa")
def _():
    return cup("#7A4A2E", body="#E86A5A")


@icon("f-steamed-bun")
def _():
    return bun("#F7F2E8", dots=[((8, 5), "#E0D8C8"), ((7, 6), "#E0D8C8"), ((9, 6), "#E0D8C8")])


@icon("f-barley-rice")
def _():
    rice = ellipse(8, 7, 5.5, 2.2)
    return bowl("#E8DCC0", fill=(rice, hx("#E8DCC0")),
                dots=[((6, 6), "#9A7A4A"), ((9, 5), "#9A7A4A"), ((10, 7), "#9A7A4A")])


@icon("f-songpyeon")
def _():
    a = ellipse(5.5, 9, 3.6, 3) - ellipse(5.5, 11.5, 3.6, 1.6)
    b = ellipse(11, 9, 3.6, 3) - ellipse(11, 11.5, 3.6, 1.6)
    c = ellipse(8, 5, 3.6, 3) - ellipse(8, 7.5, 3.6, 1.6)
    return render([(a, hx("#A8D08A")), (b, hx("#F2F0E4")), (c, hx("#F2B8C8"))])


@icon("f-mushroom-soup")
def _():
    return bowl("#C9A26A", dots=[((5, 6), "#8A5A3A"), ((6, 6), "#8A5A3A"), ((10, 6), "#8A5A3A"),
                                ((11, 6), "#8A5A3A"), ((8, 7), "#F2E7D2")])


@icon("f-cucumber")
def _():
    c = line(2, 12, 13, 3, 3)
    return render([(c, hx("#5AA05A"))], dots=[((5, 9), "#B4E0A0"), ((8, 6), "#B4E0A0"), ((11, 4), "#B4E0A0")])


@icon("f-flower-tea")
def _():
    fl = ellipse(8, 4.5, 1.4, 1.4) | ellipse(6, 5.5, 1.4, 1.4) | ellipse(10, 5.5, 1.4, 1.4)
    return cup("#F2C0D0", steam=False, extra=[(fl, hx("#E8709A"))])


def main():
    only = set(sys.argv[1:])
    n = 0
    for name, fn in ICONS.items():
        if only and name not in only:
            continue
        save(name, fn())
        n += 1
    print("찍음: %d장" % n)


if __name__ == "__main__":
    main()
