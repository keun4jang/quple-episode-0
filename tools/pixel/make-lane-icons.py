#!/usr/bin/env python3
"""쿼카 군단의 보물·장신구 아이콘 (16x16, 한 줄 시트 `lane-icons.png`).
회색조로 그리고 게임에서 색을 곱한다(modulate) - 같은 모양을 여러 색으로 쓰려고.
순서는 `LaneData.ICONS` 와 같아야 한다.
    python3 tools/pixel/make-lane-icons.py
"""
import importlib.util
import math
import os
from PIL import Image

HERE = os.path.dirname(__file__)
_spec = importlib.util.spec_from_file_location("qk", os.path.join(HERE, "make-quokka-units.py"))
qk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qk)
Canvas, OUT = qk.Canvas, qk.OUT

ICONS = ["drop", "clover", "fluff", "pebble", "leaf", "orb", "jar", "flower", "ribbon", "acorn", "ring", "flute",
         "spool", "lantern", "gem", "coin", "button", "key", "moon", "bottle", "feather", "mushroom", "spoon", "cube",
         "cup", "crown", "bell", "sun", "star", "vest", "glove", "shoe", "candy", "shield"]
S = 16
B = (222, 222, 222, 255)    # 바탕 (게임에서 색이 곱해진다)
D = (150, 150, 150, 255)    # 그늘
L = (255, 255, 255, 255)    # 빛
K = (70, 70, 70, 255)       # 진한 부분
NONE = (0, 0, 0, 0)


def ell(cv, cx, cy, rx, ry):
    cv.ellipse(cx, cy, rx, ry, B, D, L)


def cut(cv):
    for (x, y), col in list(cv.px.items()):
        if col == NONE:
            del cv.px[(x, y)]


def poly_fill(cv, pts, shade):
    for y in range(S):
        for x in range(S):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > y + 0.5) != (yj > y + 0.5) and x + 0.5 < (xj - xi) * (y + 0.5 - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                cv.set(x, y, shade(x, y))


def draw(name):
    cv = Canvas(S, S)
    c = 7.5
    if name == "drop":
        for y in range(2, 14):
            w = (y - 2) * 0.55 if y < 9 else math.sqrt(max(0, 16 - (y - 9.5) ** 2))
            for x in range(int(c - w), int(c + w) + 1):
                cv.set(x, y, D if x > c + w * 0.3 or y > 11 else B)
        cv.set(6, 8, L)
        cv.set(6, 9, L)
    elif name == "clover":
        for dx, dy in ((-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)):
            ell(cv, c + dx, c + dy - 1, 2.6, 2.6)
        cv.line(c, c + 2, c + 2, 14, K)
    elif name == "fluff":
        cv.line(c, 8, c, 14, K)
        for a in range(0, 360, 30):
            r = math.radians(a)
            cv.line(c, 6, c + math.cos(r) * 5.5, 6 + math.sin(r) * 5.5, B)
        ell(cv, c, 6, 1.5, 1.5)
    elif name == "pebble":
        ell(cv, c, 9, 6.0, 4.2)
        cv.set(5, 7, L)
        cv.set(6, 7, L)
    elif name == "leaf":
        ell(cv, c, 7.5, 5.5, 5.5)
        cv.line(c, 7.5, c + 4, 3.5, D)
        cv.line(c - 4, 12, c - 1, 9, K)
    elif name == "orb":
        ell(cv, c, c, 5.5, 5.5)
        cv.ellipse(5.5, 5.5, 1.5, 1.5, L, L, L)
    elif name == "jar":
        ell(cv, c, 9.5, 5.2, 4.8)
        cv.rect(4, 3, 11, 5, D)
        cv.rect(5, 2, 10, 2, K)
        cv.rect(5, 9, 10, 10, L)
    elif name == "flower":
        for a in range(0, 360, 72):
            r = math.radians(a - 90)
            ell(cv, c + math.cos(r) * 3.6, c + math.sin(r) * 3.6, 2.4, 2.4)
        cv.ellipse(c, c, 1.8, 1.8, K, K, D)
    elif name == "ribbon":
        for side in (-1, 1):
            poly_fill(cv, [(c, 7.5), (c + side * 6.5, 3.5), (c + side * 6.5, 11.5)],
                      lambda x, y: B if abs(y - 7.5) < 2.5 else D)
        ell(cv, c, 7.5, 1.6, 1.6)
        cv.line(c - 1, 9, c - 3, 14, D)
        cv.line(c + 1, 9, c + 3, 14, D)
    elif name == "acorn":
        ell(cv, c, 9.5, 4.5, 4.8)
        cv.ellipse(c, 5.5, 5.2, 2.6, D, K, B)
        cv.line(c, 3, c + 1, 1, K)
    elif name == "ring":
        for a in range(0, 360, 6):
            r = math.radians(a)
            cv.set(c + math.cos(r) * 5, 9.5 + math.sin(r) * 4, B if a < 180 else D)
            cv.set(c + math.cos(r) * 4.2, 9.5 + math.sin(r) * 3.2, D)
        cv.ellipse(c, 4, 2.2, 2.2, L, B, L)
    elif name == "flute":
        cv.line(2, 12, 13, 3, B, 2)
        for t in (0.3, 0.5, 0.7):
            cv.set(2 + 11 * t, 12 - 9 * t, K)
    elif name == "spool":
        cv.rect(4, 4, 11, 12, B)
        for y in range(5, 12, 2):
            cv.line(4, y, 11, y, D)
        cv.rect(3, 3, 12, 3, K)
        cv.rect(3, 13, 12, 13, K)
    elif name == "lantern":
        cv.rect(5, 5, 10, 12, B)
        cv.rect(6, 6, 9, 11, L)
        cv.rect(4, 4, 11, 4, K)
        cv.rect(4, 13, 11, 13, K)
        cv.line(c, 1, c, 3, K)
    elif name == "gem":
        for y in range(3, 14):
            w = (y - 3) * 1.4 if y < 7 else (13 - y) * 0.9
            for x in range(int(c - w), int(c + w) + 1):
                cv.set(x, y, L if y < 7 and x < c else (B if x < c + 1 else D))
    elif name == "coin":
        ell(cv, c, c, 5.8, 5.8)
        cv.ellipse(c, c, 3.6, 3.6, D, D, D)
        cv.line(c, 5, c, 10, L)
    elif name == "button":
        ell(cv, c, c, 5.8, 5.8)
        for dx, dy in ((-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)):
            cv.set(c + dx, c + dy, K)
    elif name == "key":
        for a in range(0, 360, 15):
            r = math.radians(a)
            cv.set(4.5 + math.cos(r) * 2.8, 5 + math.sin(r) * 2.8, B)
        cv.line(6.5, 7, 13, 13, B, 2)
        cv.line(11, 11, 9, 13, D)
        cv.line(13, 13, 11, 15, D)
    elif name == "moon":
        ell(cv, c, c, 6, 6)
        cv.ellipse(c + 3, c - 2, 5, 5, NONE, NONE, NONE)
        cut(cv)
    elif name == "bottle":
        ell(cv, c, 10, 4.8, 4.2)
        cv.rect(6, 3, 9, 6, D)
        cv.rect(6, 2, 9, 2, K)
        for x, y in ((6, 10), (9, 9), (7, 12)):
            cv.set(x, y, L)
    elif name == "feather":
        for i in range(12):
            y = 2 + i
            w = math.sin(i / 11 * math.pi) * 3.2
            x0 = c + 2 - i * 0.4
            for x in range(int(x0 - w), int(x0 + w) + 1):
                cv.set(x, y, B if x < x0 else D)
        cv.line(c + 2, 2, c - 3, 15, K)
    elif name == "mushroom":
        cv.ellipse(c, 6, 6.5, 4.2, B, D, L)
        cv.rect(6, 9, 9, 14, L)
        for x, y in ((5, 5), (9, 4), (11, 7)):
            cv.set(x, y, L)
    elif name == "spoon":
        ell(cv, 5, 5, 3.2, 3.8)
        cv.line(7, 8, 13, 14, B, 2)
    elif name == "cube":
        cv.rect(3, 5, 10, 12, B)
        for i in range(3):
            cv.line(3 + i, 4 - i, 10 + i, 4 - i, L)
            cv.line(11 + i, 5 - i, 11 + i, 12 - i, D)
    elif name == "cup":
        cv.rect(3, 6, 11, 12, B)
        cv.rect(3, 6, 11, 6, L)
        for a in range(-90, 91, 15):
            r = math.radians(a)
            cv.set(12 + math.cos(r) * 2, 9 + math.sin(r) * 2, D)
        cv.rect(2, 13, 12, 13, D)
    elif name == "crown":
        cv.rect(2, 8, 13, 12, B)
        for x in (2, 7, 12):
            cv.line(x, 3, x, 8, B, 2)
        cv.set(7.5, 10, K)
        cv.set(4, 10, D)
        cv.set(11, 10, D)
    elif name == "bell":
        for y in range(3, 12):
            w = 2 + (y - 3) * 0.6
            for x in range(int(c - w), int(c + w) + 1):
                cv.set(x, y, L if x < c - w * 0.4 else (B if x < c + w * 0.4 else D))
        cv.rect(3, 12, 12, 12, D)
        cv.ellipse(c, 13.5, 1.3, 1.1, K, K, K)
    elif name == "sun":
        for a in range(0, 360, 45):
            r = math.radians(a)
            cv.line(c + math.cos(r) * 4.5, c + math.sin(r) * 4.5, c + math.cos(r) * 7, c + math.sin(r) * 7, D)
        ell(cv, c, c, 4, 4)
    elif name == "star":
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            r = 6.8 if i % 2 == 0 else 2.9
            pts.append((c + math.cos(a) * r, c + 0.8 + math.sin(a) * r))
        poly_fill(cv, pts, lambda x, y: L if x < c and y < c else (B if x < c + 2 else D))
    elif name == "vest":
        cv.rect(3, 4, 12, 13, B)
        cv.rect(6, 4, 9, 7, NONE)
        cut(cv)
        cv.line(c, 8, c, 13, D)
        cv.set(6, 10, L)
        cv.set(6, 12, L)
    elif name == "glove":
        ell(cv, c, 8.5, 4.5, 4.5)
        for i, x in enumerate((4.5, 6.5, 8.5, 10.5)):
            cv.rect(x - 0.5, 2 + (i % 2), x + 0.5, 6, B)
        cv.rect(4, 12, 11, 14, D)
    elif name == "shoe":
        cv.rect(3, 6, 8, 11, B)
        ell(cv, 9, 10, 5, 2.6)
        cv.rect(2, 12, 14, 13, K)
        cv.set(5, 8, L)
        cv.set(6, 7, L)
    elif name == "candy":
        ell(cv, c, c, 4, 4)
        for side in (-1, 1):
            for i in range(3):
                cv.line(c + side * (4 + i), c - i, c + side * (4 + i), c + i, D)
        cv.line(c - 2, c - 2, c + 2, c + 2, L)
    elif name == "shield":
        for y in range(2, 15):
            w = 5.5 if y < 9 else 5.5 - (y - 9) * 0.9
            for x in range(int(c - w), int(c + w) + 1):
                cv.set(x, y, L if x < c - 2 and y < 7 else (B if x < c + 1 else D))
        cv.line(c, 4, c, 12, K)
    cv.outline()
    return cv.image()


def main():
    im = Image.new("RGBA", (S * len(ICONS), S), (0, 0, 0, 0))
    for i, n in enumerate(ICONS):
        im.paste(draw(n), (i * S, 0))
    im.save(os.path.join(OUT, "lane-icons.png"))
    print("icons:", len(ICONS))


if __name__ == "__main__":
    main()
