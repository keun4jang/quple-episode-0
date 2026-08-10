#!/usr/bin/env python3
"""45도로 그려진 소품을 **정면 그림**으로 갈아 끼운다.

    PYTHONHASHSEED=0 python3 tools/pixel/make-front-props.py

## 왜 코드로 그리나

만든 사람이 두 번 말했다 — 건물·창문이 비스듬하다. 그림을 밖에서
받으려면 기다려야 하는데, 그동안 게임이 틀린 시점으로 남아 있을
이유가 없다. 픽셀 정면 건물은 단순한 도형이라 코드로 그릴 수 있다.
색은 **지금 그림에서 뽑아 쓴다** — 화풍이 이어져야 한다.

밖에서 더 예쁜 그림이 오면 같은 이름으로 덮으면 끝이다.

## 시점 규칙 (스타듀와 같다)

- 정면 벽이 똑바로 보인다. 옆면 없음, 모서리 없음
- 지붕은 위에 얹힌 띠로 보인다 (살짝 앞으로 기운 면)
- 바닥에 놓이는 것(밭·평상)은 **바로 위에서** 본다 — 마름모 금지
- 빛은 왼쪽 위. 오른쪽과 아래가 살짝 어둡다
"""

import numpy as np
from PIL import Image

OUT = "assets/sprites"


def C(hexs: str):
    return tuple(int(hexs[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def shade(c, k: float):
    return tuple(min(255, max(0, int(v * k))) for v in c[:3]) + (255,)


def canvas(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)


def rect(a, x0, y0, x1, y1, c):
    a[max(0, y0):y1, max(0, x0):x1] = c


def hline(a, x0, x1, y, c):
    if 0 <= y < a.shape[0]:
        a[y, max(0, x0):x1] = c


def vline(a, x, y0, y1, c):
    if 0 <= x < a.shape[1]:
        a[max(0, y0):y1, x] = c


def speck(a, x0, y0, x1, y1, c, seed, n):
    """옅은 점을 흩어 결을 만든다. 씨앗 고정 — 돌릴 때마다 같아야 한다."""
    g = np.random.default_rng(seed)
    for _ in range(n):
        x = int(g.integers(x0, x1))
        y = int(g.integers(y0, y1))
        a[y, x] = c


def save(a, name):
    Image.fromarray(a, "RGBA").save(f"{OUT}/{name}.png")
    print("  %-16s %dx%d" % (name, a.shape[1], a.shape[0]))


# ── 공용 조각 ─────────────────────────────────────────────────────────

def roof_band(a, x0, x1, y0, y1, base, ridge=True):
    """앞으로 살짝 기운 지붕 띠. 가로 골이 지나간다."""
    dark = shade(base, 0.78)
    lite = shade(base, 1.12)
    rect(a, x0, y0, x1, y1, base)
    for y in range(y0 + 2, y1, 3):
        hline(a, x0, x1, y, dark)
    hline(a, x0, x1, y0, lite)                      # 위 모서리 빛
    hline(a, x0, x1, y1 - 1, shade(base, 0.62))     # 처마 그림자
    if ridge:
        hline(a, x0, x1, y0 + 1, base)


def window(a, x, y, w, h, frame, glass, shutters=None, lit=False):
    rect(a, x - 1, y - 1, x + w + 1, y + h + 1, frame)
    rect(a, x, y, x + w, y + h, glass)
    if lit:
        rect(a, x + 1, y + 1, x + w - 1, y + h - 1, C("#F5D98A"))
        a[y + 1, x + 1] = C("#FFF2C0")
    else:
        vline(a, x + w // 2, y, y + h, frame)
        hline(a, x, x + w, y + h // 2, frame)
    if shutters:
        rect(a, x - 3, y, x - 1, y + h, shutters)
        rect(a, x + w + 1, y, x + w + 3, y + h, shutters)


def door(a, x, y, w, h, wood):
    rect(a, x, y, x + w, y + h, wood)
    rect(a, x + 1, y + 1, x + w - 1, y + h, shade(wood, 1.15))
    a[y + h // 2, x + w - 2] = shade(wood, 0.6)     # 손잡이


# ── 건물 넷 ───────────────────────────────────────────────────────────

def guesthouse():
    """쿼스텔. 크림 벽 + 테라코타 지붕. 2층집답게 키운다 (사람 24px)."""
    w, h = 72, 92
    a = canvas(w, h)
    wall = C("#F5DEBC")
    roof = C("#C17D60")
    wood = C("#976C52")
    green = C("#8FA070")
    rect(a, 4, 26, w - 4, h, wall)
    speck(a, 5, 28, w - 5, h - 2, shade(wall, 0.94), 11, 90)
    vline(a, 4, 26, h, shade(wall, 0.82))
    vline(a, w - 5, 26, h, shade(wall, 0.80))
    hline(a, 4, w - 4, h - 1, shade(wall, 0.72))
    # 층 사이 나무 띠
    rect(a, 4, 56, w - 4, 59, shade(wood, 0.9))
    # 지붕
    roof_band(a, 0, w, 14, 28, roof)
    hline(a, 0, w, 13, shade(roof, 1.2))
    # 굴뚝
    rect(a, w - 18, 4, w - 10, 15, shade(wood, 0.8))
    rect(a, w - 19, 2, w - 9, 5, shade(wood, 0.65))
    # 2층 창 둘 (불 켜짐)
    window(a, 12, 36, 10, 12, wood, C("#A3856F"), green, lit=True)
    window(a, w - 24, 36, 10, 12, wood, C("#A3856F"), green, lit=True)
    # 1층 문 + 창
    door(a, w // 2 - 6, h - 24, 13, 24, wood)
    window(a, 10, h - 22, 10, 11, wood, C("#A3856F"), green)
    window(a, w - 22, h - 22, 10, 11, wood, C("#A3856F"), green)
    # 문 앞 팻말
    rect(a, w // 2 + 12, h - 14, w // 2 + 22, h - 8, shade(wood, 1.1))
    vline(a, w // 2 + 16, h - 8, h, shade(wood, 0.7))
    save(a, "guesthouse")


def shop():
    """가게. 옥색 벽 + 줄무늬 차양."""
    w, h = 56, 62
    a = canvas(w, h)
    wall = C("#AFC8B6")
    wood = C("#835B4A")
    cream = C("#F1E4CC")
    coral = C("#C97F63")
    rect(a, 3, 14, w - 3, h, wall)
    speck(a, 4, 16, w - 4, h - 2, shade(wall, 0.93), 12, 60)
    vline(a, 3, 14, h, shade(wall, 0.8))
    vline(a, w - 4, 14, h, shade(wall, 0.8))
    hline(a, 3, w - 3, h - 1, shade(wall, 0.7))
    roof_band(a, 0, w, 4, 16, C("#7E9C8C"))
    # 차양 (줄무늬, 앞으로 기운 면)
    for i, x in enumerate(range(4, w - 4, 6)):
        rect(a, x, 24, min(x + 6, w - 4), 34, cream if i % 2 == 0 else coral)
    hline(a, 4, w - 4, 34, shade(coral, 0.6))
    for x in range(4, w - 4, 6):
        a[33, x] = shade(coral, 0.55)
    # 진열창 + 문
    window(a, 8, 40, 16, 12, wood, C("#D8E4D6"))
    rect(a, 9, 48, 23, 52, shade(wood, 1.25))       # 진열대
    door(a, w - 22, h - 20, 12, 20, wood)
    save(a, "shop")


def stall():
    """좌판. 사람(24px)보다 커야 한다 — 지금 것은 할머니보다 작았다."""
    w, h = 40, 42
    a = canvas(w, h)
    wood = C("#955F46")
    cream = C("#EFE0C4")
    coral = C("#C97F63")
    # 천장 줄무늬
    for i, x in enumerate(range(0, w, 5)):
        rect(a, x, 0, min(x + 5, w), 12, cream if i % 2 == 0 else coral)
    hline(a, 0, w, 11, shade(coral, 0.6))
    # 기둥 둘
    vline(a, 2, 12, h - 4, shade(wood, 0.8))
    vline(a, 3, 12, h - 4, wood)
    vline(a, w - 4, 12, h - 4, wood)
    vline(a, w - 3, 12, h - 4, shade(wood, 0.8))
    # 판매대 (정면)
    rect(a, 0, h - 18, w, h - 2, wood)
    hline(a, 0, w, h - 18, shade(wood, 1.2))
    speck(a, 1, h - 16, w - 1, h - 3, shade(wood, 0.85), 13, 30)
    hline(a, 0, w, h - 2, shade(wood, 0.6))
    # 물건들
    for i, (px, c) in enumerate([(5, "#C9A24E"), (13, "#B45A44"),
			(21, "#8FA070"), (29, "#C97F63")]):
        rect(a, px, h - 24, px + 6, h - 18, C(c))
        a[h - 25, px + 2] = shade(C(c), 1.2)
    save(a, "stall")


def home_house():
    """고향집. 흰 회벽 + 기와 지붕. 낮고 넓다."""
    w, h = 88, 74
    a = canvas(w, h)
    wall = C("#EDE3CE")
    tile = C("#5F6470")
    wood = C("#93634D")
    rect(a, 5, 26, w - 5, h - 6, wall)
    speck(a, 6, 28, w - 6, h - 8, shade(wall, 0.94), 14, 80)
    vline(a, 5, 26, h - 6, shade(wall, 0.82))
    vline(a, w - 6, 26, h - 6, shade(wall, 0.82))
    # 기와 지붕 — 처마가 벽보다 넓다
    roof_band(a, 0, w, 10, 28, tile)
    hline(a, 0, w, 9, shade(tile, 1.25))
    for x in range(2, w, 6):                        # 수막새 점
        a[26, x] = shade(tile, 1.3)
    # 툇마루 (정면 나무단)
    rect(a, 5, h - 8, w - 5, h, wood)
    hline(a, 5, w - 5, h - 8, shade(wood, 1.25))
    for x in range(8, w - 6, 9):
        vline(a, x, h - 7, h, shade(wood, 0.85))
    # 문(한지) + 창
    rect(a, w // 2 - 8, h - 30, w // 2 + 8, h - 8, C("#E7D8B8"))
    rect(a, w // 2 - 8, h - 30, w // 2 + 8, h - 29, wood)
    vline(a, w // 2, h - 30, h - 8, wood)
    vline(a, w // 2 - 8, h - 30, h - 8, wood)
    vline(a, w // 2 + 7, h - 30, h - 8, wood)
    hline(a, w // 2 - 8, w // 2 + 8, h - 19, wood)
    window(a, 14, h - 28, 10, 10, wood, C("#E7D8B8"))
    window(a, w - 26, h - 28, 10, 10, wood, C("#E7D8B8"))
    save(a, "home-house")


# ── 잿마루 사무 소품 ──────────────────────────────────────────────────

def office_window():
    """벽 띠에 박힌 정면 창. 밤 도시 불빛이 보인다.
    예전 것은 벽 없이 평행사변형 창이 카펫에 누워 있었다."""
    w, h = 48, 40
    a = canvas(w, h)
    wall = C("#8B8AA0")
    frame = C("#532F29")
    night = C("#2A2C44")
    rect(a, 0, 0, w, h, wall)
    speck(a, 1, 1, w - 1, h - 1, shade(wall, 0.94), 15, 40)
    hline(a, 0, w, h - 1, shade(wall, 0.75))
    hline(a, 0, w, 0, shade(wall, 1.1))
    rect(a, 5, 6, w - 5, h - 8, frame)
    rect(a, 7, 8, w - 7, h - 10, night)
    vline(a, w // 2, 8, h - 10, frame)
    # 도시 불빛
    g = np.random.default_rng(21)
    for _ in range(26):
        x = int(g.integers(8, w - 8))
        y = int(g.integers(h - 22, h - 11))
        if x in (w // 2,):
            continue
        a[y, x] = C("#E8C97A") if g.integers(0, 3) else C("#9AB0C8")
    save(a, "office-window")


def desk():
    """책상 정면 + 모니터가 이쪽을 본다. 사람 허리는 넘게."""
    w, h = 26, 22
    a = canvas(w, h)
    wood = C("#9C8571")
    top = C("#BDBEAF")
    rect(a, 0, 9, w, 11, top)
    hline(a, 0, w, 9, shade(top, 1.15))
    rect(a, 1, 11, w - 1, h, wood)
    rect(a, 3, 13, w - 3, h, shade(wood, 0.88))
    vline(a, w // 2, 13, h, shade(wood, 0.75))      # 서랍 사이
    a[16, 6] = shade(wood, 0.6)                     # 손잡이
    a[16, w - 7] = shade(wood, 0.6)
    # 모니터
    rect(a, 7, 0, 19, 9, C("#3A3C46"))
    rect(a, 8, 1, 18, 8, C("#7A8FA6"))
    rect(a, 12, 9, 14, 11, C("#3A3C46"))
    save(a, "desk")


def reception():
    """접수대 정면. 나무 판 + 종."""
    w, h = 40, 26
    a = canvas(w, h)
    wood = C("#7B685B")
    top = C("#9D98A3")
    rect(a, 0, 6, w, 9, top)
    hline(a, 0, w, 6, shade(top, 1.15))
    rect(a, 1, 9, w - 1, h, wood)
    for x in range(6, w - 4, 8):
        vline(a, x, 11, h - 2, shade(wood, 0.85))
    hline(a, 1, w - 1, h - 1, shade(wood, 0.65))
    rect(a, w - 10, 2, w - 6, 6, C("#C9A24E"))      # 종
    a[1, w - 8] = shade(C("#C9A24E"), 0.7)
    save(a, "reception")


def icebox():
    """아이스박스 정면. 하늘색 상자 + 뚜껑."""
    w, h = 20, 18
    a = canvas(w, h)
    body = C("#92BFB3")
    rect(a, 1, 5, w - 1, h, body)
    rect(a, 0, 2, w, 7, shade(body, 1.12))
    hline(a, 0, w, 2, shade(body, 1.2))
    hline(a, 0, w, 6, shade(body, 0.8))
    hline(a, 1, w - 1, h - 1, shade(body, 0.65))
    rect(a, w // 2 - 2, 3, w // 2 + 2, 5, shade(body, 0.7))   # 손잡이
    save(a, "icebox")


# ── 마을 소품 ─────────────────────────────────────────────────────────

def bench():
    """벤치 정면. 앉는 판이 이쪽을 본다. 여섯 마을 20개가 쓴다."""
    w, h = 26, 15
    a = canvas(w, h)
    wood = C("#A08471")
    dark = C("#724D42")
    # 등받이
    rect(a, 1, 0, w - 1, 3, wood)
    hline(a, 1, w - 1, 0, shade(wood, 1.15))
    rect(a, 1, 4, w - 1, 6, wood)
    # 앉는 판
    rect(a, 0, 7, w, 10, shade(wood, 1.08))
    hline(a, 0, w, 7, shade(wood, 1.2))
    hline(a, 0, w, 9, shade(wood, 0.8))
    # 다리
    rect(a, 2, 10, 5, h, dark)
    rect(a, w - 5, 10, w - 2, h, dark)
    save(a, "bench")


def dock():
    """부두 끝단 정면 — 판자 마감 + 말뚝 둘 + 물그림자 한 줄."""
    w, h = 34, 20
    a = canvas(w, h)
    plank = C("#AB957C")
    dark = C("#5C3930")
    rect(a, 0, 0, w, 12, plank)
    for x in range(0, w, 6):
        vline(a, x, 0, 12, shade(plank, 0.85))
    for y in (3, 7):
        hline(a, 0, w, y, shade(plank, 0.92))
    hline(a, 0, w, 11, shade(plank, 0.7))
    # 말뚝
    rect(a, 2, 8, 6, h - 1, dark)
    rect(a, w - 6, 8, w - 2, h - 1, dark)
    hline(a, 2, 6, 8, shade(dark, 1.3))
    hline(a, w - 6, w - 2, 8, shade(dark, 1.3))
    # 물에 닿는 그림자
    hline(a, 1, w - 1, h - 1, (30, 40, 48, 120))
    save(a, "dock")


def home_garden():
    """밭뙈기 — 바로 위에서 본 반듯한 네모. 마름모였다."""
    w, h = 48, 30
    a = canvas(w, h)
    soil = C("#7B5444")
    sprout = C("#8F9978")
    rect(a, 0, 0, w, h, soil)
    speck(a, 1, 1, w - 1, h - 1, shade(soil, 0.9), 16, 60)
    for y in range(3, h - 2, 6):
        hline(a, 2, w - 2, y, shade(soil, 0.75))       # 고랑
        hline(a, 2, w - 2, y + 1, shade(soil, 1.12))
        for x in range(4, w - 3, 5):                   # 새싹
            a[y - 1, x] = sprout
            a[y - 2, x] = shade(sprout, 1.15)
    hline(a, 0, w, 0, shade(soil, 0.8))
    hline(a, 0, w, h - 1, shade(soil, 0.7))
    vline(a, 0, 0, h, shade(soil, 0.8))
    vline(a, w - 1, 0, h, shade(soil, 0.7))
    save(a, "home-garden")


def home_deck():
    """평상 — 바로 위에서 본 나무 단. 엔딩 자리인데 벤치보다 작았다."""
    w, h = 44, 30
    a = canvas(w, h)
    wood = C("#CDA078")
    rect(a, 0, 0, w, h - 3, wood)
    for y in range(0, h - 3, 5):
        hline(a, 1, w - 1, y, shade(wood, 0.86))       # 살
    speck(a, 1, 1, w - 1, h - 4, shade(wood, 0.93), 17, 40)
    hline(a, 0, w, 0, shade(wood, 1.12))
    vline(a, 0, 0, h - 3, shade(wood, 1.06))
    vline(a, w - 1, 0, h - 3, shade(wood, 0.8))
    # 아래로 보이는 옆판 — 두께 한 줄
    rect(a, 0, h - 3, w, h, shade(wood, 0.68))
    save(a, "home-deck")


def main():
    for fn in (guesthouse, shop, stall, home_house, office_window, desk,
               reception, icebox, bench, dock, home_garden, home_deck):
        fn()
    print("\n정면 그림 12장. 밖에서 더 예쁜 그림이 오면 같은 이름으로 덮는다.")


if __name__ == "__main__":
    main()
