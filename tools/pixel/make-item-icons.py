#!/usr/bin/env python3
"""배낭에 들어갈 물건 그림을 찍는다.

16x16 안쪽에서 **실루엣으로 구분되게** 그린다. 잔무늬를 넣으면 배낭
격자에서 서로 구별이 안 된다 — 색 네댓과 1px 외곽선이면 충분하다.
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
S = 16


def hx(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def save(name, px):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.putdata([px.get((x, y), (0, 0, 0, 0))
                 for y in range(S) for x in range(S)])
    img.save(os.path.join(OUT, name + ".png"))
    print("만듦:", name)


def disc(px, cx, cy, r, col, line):
    """외곽선 있는 동그라미."""
    for y in range(S):
        for x in range(S):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r - 1.0:
                px[(x, y)] = col
            elif d <= r:
                px[(x, y)] = line


# ── 유리구슬 — 윤슬의 저녁 바다를 닮은 구슬 ──────────────────────────
px = {}
# 작은 원은 계산식으로 그리면 각져 보인다. 11px 원을 줄별로 적어 둔다.
ROWS = [(5, 10), (3, 12), (2, 13), (2, 13), (1, 14),
        (1, 14), (1, 14), (2, 13), (2, 13), (3, 12), (5, 10)]
for i, (a, b) in enumerate(ROWS):
    y = 3 + i
    for x in range(a, b):
        px[(x, y)] = hx("#6FA8B8")
    px[(a - 1, y)] = hx("#33555F")
    px[(b, y)] = hx("#33555F")
for x in range(5, 10):
    px[(x, 2)] = hx("#33555F")
    px[(x, 14)] = hx("#33555F")
# 아래쪽을 조금 짙게 — 유리가 두께를 갖는다
for y in range(9, 13):
    for x in range(2, 14):
        if px.get((x, y)) == hx("#6FA8B8"):
            px[(x, y)] = hx("#4E8492")
# 윗면 빛 한 점
px[(5, 5)] = hx("#EAF6F7")
px[(6, 5)] = hx("#C7E6EA")
px[(5, 6)] = hx("#C7E6EA")
save("i-marble", px)

# ── 찻잔 — 가게에서 마시는 따뜻한 차 ─────────────────────────────────
px = {}
body = hx("#F2E7D2")
line = hx("#7A6552")
tea = hx("#9C6B3E")
# 잔
for y in range(7, 13):
    w = 5 if y < 12 else 4
    for x in range(8 - w, 8 + w):
        px[(x, y)] = body
for y in range(7, 13):
    w = 5 if y < 12 else 4
    px[(8 - w, y)] = line
    px[(8 + w - 1, y)] = line
for x in range(4, 12):
    px[(x, 13)] = line
# 찻물
for x in range(4, 12):
    px[(x, 7)] = tea
px[(3, 7)] = line
px[(12, 7)] = line
# 손잡이
for y in (9, 10):
    px[(13, y)] = line
px[(12, 8)] = line
px[(12, 11)] = line
# 김 두 줄
px[(6, 4)] = hx("#D9CBB6")
px[(6, 3)] = hx("#D9CBB6")
px[(9, 4)] = hx("#D9CBB6")
px[(9, 2)] = hx("#D9CBB6")
save("i-tea", px)




# ── 미역 — 갯벌에서 걷어 온다. 물결치는 띠 하나가 위아래로 흔들린다.
px = {}
DK = hx("#25462F")
LT = hx("#4E8C4A")
HI = hx("#7BB86E")
COLS = [5, 5, 4, 4, 5, 6, 6, 5, 4, 4, 5, 6, 7, 7]  # 줄기가 좌우로 흔들린다
for y, cx in enumerate(COLS):
    px[(cx, y + 1)] = LT
    px[(cx + 1, y + 1)] = HI if y % 3 == 0 else LT
    px[(cx - 1, y + 1)] = DK
    px[(cx + 2, y + 1)] = DK
save("p-seaweed", px)


# ── 소라 — 조개(p-shell)와 실루엣이 갈라야 한다. 조개는 부채꼴,
# 소라는 위로 갈수록 좁아지다 끝이 옆으로 살짝 휘는 뿔 모양이다.
px = {}
line = hx("#5A4432")
body = hx("#D8B896")
shade = hx("#B8926C")
hi = hx("#F0DFC4")
# 아래(넓다)에서 위(좁다)로 - 끝은 오른쪽으로 휜다(말려 올라간 뿔)
ROWS = [(1, 10, 10), (1, 10, 9), (2, 9, 8), (2, 8, 7), (3, 8, 6),
        (4, 8, 5), (5, 8, 4), (6, 8, 3), (7, 9, 2)]
for a, b, y in ROWS:
    for x in range(a, b + 1):
        px[(x, y)] = body
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
px[(8, 1)] = line
px[(9, 1)] = line
# 밑동을 가로로 마감
for x in range(0, 12):
    px[(x, 11)] = line
# 나선 줄무늬 - 굵은 대각선 두 가닥이 뿔을 휘감는다
for x, y in [(3, 9), (4, 8), (5, 7), (6, 6), (7, 5)]:
    px[(x, y)] = shade
for x, y in [(2, 10), (3, 8), (5, 6)]:
    px[(x, y)] = hi
save("p-conch", px)


# ── 갈댓잎 — 길고 가는 잎 하나가 휘어 있다. 미역(물결)과 달리 곧고
# 뾰족해야 한다.
px = {}
line = hx("#5C6B2E")
body = hx("#8FAE4A")
hi = hx("#B8D473")
LEAF = [(7, 1), (7, 2), (6, 3), (6, 4), (5, 5), (5, 6), (4, 7), (4, 8),
        (3, 9), (3, 10), (2, 11), (2, 12), (1, 13)]
for x, y in LEAF:
    px[(x, y)] = body
    px[(x + 1, y)] = hi if y % 4 == 1 else body
for x, y in LEAF:
    px[(x - 1, y)] = line
    px[(x + 2, y)] = line
save("p-reed-leaf", px)


# ── 갈꽃 — 이삭 끝이 부풀어 오른 억새꽃. 줄기는 곧고 가늘게,
# 끝의 깃털만 부풀린다.
px = {}
stem = hx("#7A6A3E")
fluff = hx("#E8DCC0")
fluff_sh = hx("#C9B98F")
for y in range(9, 15):
    px[(7, y)] = stem
px[(6, 14)] = stem
# 깃털 - 위로 갈수록 좁아지는 타원 실루엣
ROWS = [(6, 8, 3), (5, 8, 4), (5, 9, 5), (5, 9, 6), (6, 8, 7), (6, 8, 8)]
for a, b, y in ROWS:
    for x in range(a, b + 1):
        px[(x, y)] = fluff
    px[(a, y)] = fluff_sh
    px[(b, y)] = fluff_sh
px[(7, 2)] = fluff
save("p-reed-plume", px)


# ── 귤 — 낙과만 줍는다(나무에서 안 딴다). 감(p-persimmon)과 실루엣이
# 갈라야 한다 - 감은 위아래로 길쭉하고, 귤은 동그랗다.
px = {}
line = hx("#8A4A1E")
body = hx("#E8912E")
shade = hx("#C77420")
hi = hx("#F7C878")
leaf = hx("#4E7A3A")
disc(px, 6, 8, 5, body, line)
# 아래쪽을 살짝 짙게 - 둥근 부피감
for y in range(9, 13):
    for x in range(2, 11):
        if px.get((x, y)) == body:
            px[(x, y)] = shade
px[(4, 5)] = hi
px[(5, 5)] = hi
# 꼭지 - 초록 잎 하나
px[(6, 2)] = leaf
px[(5, 3)] = leaf
px[(7, 3)] = leaf
save("p-tangerine", px)


# ── 귤잎 — 끝이 뾰족한 길쭉한 타원. 갈댓잎(p-reed-leaf, 가늘고 대각선)
# 과 달리 통통하고 짧다.
px = {}
line = hx("#3A5A2A")
body = hx("#6FA050")
hi = hx("#93C46E")
LEAF = [(6, 6, 1), (5, 7, 2), (5, 8, 3), (4, 8, 4),
        (4, 8, 5), (5, 7, 6), (5, 7, 7), (6, 7, 8),
        (6, 6, 9)]
for a, b, y in LEAF:
    for x in range(a, b + 1):
        px[(x, y)] = body
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
# 가운데 잎맥
for y in range(2, 9):
    px[(6, y)] = hi
save("p-citrus-leaf", px)


# ── 감잎 — 가을에 붉게 드는 넓은 타원 잎. 귤잎(둥글고 초록)과
# 갈댓잎(가늘고 대각선)과 갈라지게 넓고 붉은 기가 돈다.
px = {}
line = hx("#7A3A1E")
body = hx("#C97A3E")
hi = hx("#E8A868")
LEAF = [(6, 6, 0), (5, 7, 1), (4, 8, 2), (3, 9, 3), (3, 9, 4),
        (3, 9, 5), (4, 8, 6), (4, 8, 7), (5, 7, 8), (5, 7, 9), (6, 6, 10)]
for a, b, y in LEAF:
    for x in range(a, b + 1):
        px[(x, y)] = body
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
for y in range(1, 10):
    px[(6, y)] = hi
save("p-persimmon-leaf", px)


# ── 버섯 — 솔밭 그늘에서 돋는 것. 동그란 모자에 짧은 대.
px = {}
line = hx("#5C3A2E")
cap = hx("#B8543E")
cap_hi = hx("#D97858")
stem = hx("#EDE0C8")
CAP = [(3, 8, 4), (2, 9, 5), (1, 10, 6), (1, 10, 7)]
for a, b, y in CAP:
    for x in range(a, b + 1):
        px[(x, y)] = cap
    px[(a - 1, y)] = line
    px[(b + 1, y)] = line
px[(3, 5)] = cap_hi
px[(7, 6)] = cap_hi
for y in range(8, 12):
    for x in range(4, 8):
        px[(x, y)] = stem
    px[(3, y)] = line
    px[(8, y)] = line
for x in range(3, 9):
    px[(x, 12)] = line
save("p-mushroom", px)


# ── 솔잎 — 솔방울(p-pinecone, 둥글다)과 갈라지게, 가는 바늘잎 한
# 뭉치가 한 점에서 갈라져 나온다. 점을 듬성듬성 찍으면 흩어진
# 점무늬로 보인다 - 한 칸씩 이어 **선**으로 그린다.
px = {}
needle = hx("#4E8A5E")
hi = hx("#7BB86E")

def line_to(x0, y0, x1, y1, col):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        t = i / float(steps)
        px[(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t))] = col

BASE = (7, 13)
for tip, col in [((7, 1), needle), ((1, 4), hi), ((13, 4), needle)]:
    line_to(BASE[0], BASE[1], tip[0], tip[1], col)
save("p-pine-needle", px)


# ══ 화면 왼쪽 위 메뉴 아이콘 넷 ══════════════════════════════════════
#
# 배낭(i-pack)만 그림이고 나머지 넷은 글자 버튼이었다. 글자를 그림으로
# 바꾸면서 넷을 새로 그린다. 88px 로 크게 띄우는 것이라 **실루엣이
# 서로 달라야** 한다 — 봉투(가로로 넓다) · 사진(네모 액자 두 장) ·
# 책(세로로 길고 등이 있다) · 쪽지(세로로 길고 줄이 있다).

def box(px, x0, y0, x1, y1, fill, line):
    """외곽선 있는 네모. 끝값을 포함한다."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            px[(x, y)] = line if edge else fill


# ── 편지 — 봉투. 가로로 넓은 것은 넷 중 이것뿐이다 ──────────────────
px = {}
INK = hx("#6E5C48")
CREAM = hx("#F7F1E4")
FLAP = hx("#E2D3BA")
box(px, 1, 4, 14, 12, CREAM, INK)
# 뚜껑 — 양 위 모서리에서 내려와 가운데서 만난다
for i in range(7):
    px[(1 + i, 4 + i)] = INK
    px[(14 - i, 4 + i)] = INK
# 접힌 뚜껑 면을 한 겹 짙게 — 안 그러면 그냥 빈 네모에 V 자국이다
for y in range(5, 11):
    for x in range(2, 14):
        if px.get((x, y)) == CREAM and (y - 4) < (x - 1) and (y - 4) < (14 - x):
            px[(x, y)] = FLAP
save("i-letter", px)


# ── 사진첩 — 뒤에 한 장 비죽 나온 폴라로이드 ────────────────────────
px = {}
INK = hx("#6E5C48")
BACK = hx("#D9CDBA")
WHITE = hx("#FFFDF6")
box(px, 4, 1, 14, 11, BACK, INK)        # 뒤에 겹쳐 둔 한 장
box(px, 1, 4, 11, 14, WHITE, INK)       # 앞장
box(px, 3, 6, 9, 11, hx("#A9D3E0"), INK)   # 속 그림 — 하늘
for y in range(9, 11):                     # 언덕
    for x in range(4, 9):
        px[(x, y)] = hx("#7FB08A")
for y in range(7, 9):                      # 해
    for x in range(7, 9):
        px[(x, y)] = hx("#FFE39A")
save("i-album", px)


# ── 행복첩 — 겉장에 하트가 박힌 책 ──────────────────────────────────
px = {}
INK = hx("#4A3038")
COVER = hx("#C8788A")
SPINE = hx("#A05C6E")
PAGE = hx("#F6EFE2")
box(px, 2, 1, 13, 14, COVER, INK)
for y in range(2, 14):
    px[(3, y)] = SPINE                  # 책등
    px[(4, y)] = SPINE
    px[(12, y)] = PAGE                  # 쪽 끝
HEART = hx("#FFE9EC")
ROWS = [(5, [7, 8, 10, 11]), (6, list(range(6, 13))), (7, list(range(6, 13))),
        (8, list(range(7, 12))), (9, list(range(8, 11))), (10, [9])]
for y, xs in ROWS:
    for x in xs:
        px[(x, y)] = HEART
save("i-heartbook", px)


# ── 이 마을 — 해볼 일 쪽지. 첫 칸은 이미 채워져 있다 ────────────────
px = {}
INK = hx("#6E5C48")
PAPER = hx("#F4EDE2")
PEN = hx("#8A7B6A")
DONE = hx("#5E8C63")
box(px, 2, 1, 13, 14, PAPER, INK)
for k, r in enumerate([3, 7, 11]):
    for x in range(4, 7):               # 네모 칸 위아래
        px[(x, r)] = PEN
        px[(x, r + 2)] = PEN
    px[(4, r + 1)] = PEN                # 네모 칸 양옆
    px[(6, r + 1)] = PEN
    if k == 0:
        px[(5, r + 1)] = DONE           # 첫 칸은 채워 둔다
    for x in range(8, 12):              # 줄
        px[(x, r + 1)] = PEN
save("i-list", px)


# ── 마음 — 왼쪽 위 여섯째 버튼 (레벨·체력·마음력·배운 것) ───────────
#
# 앞의 다섯(배낭·액자·봉투·책·쪽지)이 죄다 네모라, 이것만 **둥글게**
# 간다. 실루엣만으로 갈리는 게 먼저다. 16x16 밖으로 나가는 점은 그냥
# 버려지므로(그렇게 빛살 아랫단을 통째로 잃었다) 좌표는 0~15 안에 둔다.
px = {}
LINE = hx("#6B4A2E")
GLOW = hx("#FFE39A")
CORE = hx("#FFC46B")
HOT = hx("#FFF4D4")
disc(px, 7.5, 8.0, 5.4, GLOW, LINE)
disc(px, 7.5, 8.0, 3.2, CORE, CORE)
px[(6, 6)] = HOT
px[(7, 6)] = HOT
px[(6, 7)] = HOT
# 네 귀퉁이로 튀는 작은 불티. 동그라미만 두면 동전으로 보인다.
for (x, y) in [(2, 2), (13, 2), (2, 13), (13, 13), (7, 1), (8, 14)]:
    px[(x, y)] = GLOW
save("i-mind", px)
