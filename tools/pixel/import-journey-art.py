#!/usr/bin/env python3
"""제미나이로 받은 그림을 잘라 픽셀 타일·스프라이트로 만든다.

    python3 tools/pixel/import-journey-art.py            # 전부
    python3 tools/pixel/import-journey-art.py --only g1  # 한 장만
    python3 tools/pixel/import-journey-art.py --preview  # 결과를 한 장에 모아 보기

받는 그림은 두 종류뿐이다.

  **격자(grid)** — 바닥 텍스처. 마젠타 골로 칸이 나뉘어 있다.
                   칸을 찾아 16x16 타일로 내린다.
  **물체(objects)** — 건물·나무·캐릭터. 마젠타 위에 따로따로 떠 있다.
                   덩어리를 찾아 하나씩 잘라 낸다.

크기는 **유닛**으로 잡는다. 프롬프트에서 "캐릭터 키 = 3유닛" 으로 비례를
묶어 두었으므로, 1유닛 = 8px 로 정하면 모든 그림이 저절로 맞는다.
캐릭터 키 24px, 집 7유닛이면 56px.

마젠타를 뺄 때 JPEG 이 문제다. 압축 때문에 경계에 분홍 실이 남는다.
그래서 마젠타 판정을 넉넉히 하고, 찾은 마젠타를 **1px 부풀려** 실을 걷어낸다.
"""
import argparse
import os

import numpy as np
from PIL import Image

SRC = "assets/source/journey"
OUT_TILES = "assets/tiles"
OUT_SPRITES = "assets/sprites"

UNIT = 8          # 1유닛 = 8px  (캐릭터 3유닛 = 24px)
TILE = 16         # 바닥 타일 한 칸
## 바닥 타일에 남길 결의 세기 (0~255 기준 표준편차). 넘으면 눌러 준다.
TILE_NOISE = 5.0
## **너무 밋밋해도 안 된다.** 카펫이나 잔모래처럼 결이 고운 그림은 16px 로
## 줄이는 순간 평균으로 뭉개져 고유색 한 개짜리 판이 된다. 그러면 바닥이
## 아니라 색 띠(color bar)로 보인다. 이 아래로 떨어지면 결을 넣어 준다.
TILE_GRAIN_MIN = 2.6

# ── 팔레트 ────────────────────────────────────────────────────────────
#
# 색은 지금 게임에서 뽑아 쓴다. 화풍을 바꾸는 것이지 게임을 바꾸는 게 아니다.
# pixelize.py 와 같은 원칙이되, 여행 그림이 늘었으므로 색 수를 조금 늘린다.

PALETTE_SOURCES = [
    "assets/mascots/sheet/leader-front.png",
    "assets/mascots/sheet/partner-front.png",
    f"{SRC}/g1-home.jpg",
    f"{SRC}/g2-family.jpg",
    f"{SRC}/a-ground.jpg",
    f"{SRC}/e-folk.jpg",
]
PALETTE_SIZE = 60


def build_palette() -> Image.Image:
    """그림마다 **따로** 대표색을 뽑아 합친다.

    처음엔 전부 한 장에 이어 붙여 한 번에 줄였다. 그랬더니 갈색이 많은
    그림(집·쿼카)이 색 칸을 거의 다 차지해서, 감나무 잎이 녹색을 잃고
    앞치마의 청록이 죽었다. 그림마다 몫을 똑같이 나눠 줘야 각자의 색이
    살아남는다.
    """
    srcs = [p for p in PALETTE_SOURCES if os.path.exists(p)]
    if not srcs:
        raise SystemExit("팔레트를 뽑을 그림이 없다")
    per = max(4, PALETTE_SIZE // len(srcs))

    colors = []
    for path in srcs:
        a = np.asarray(Image.open(path).convert("RGB"))
        px = a[~magenta_mask(a)]
        if px.size == 0:
            continue
        side = 96
        idx = np.linspace(0, len(px) - 1, side * side).astype(int)
        tile = Image.fromarray(px[idx].reshape(side, side, 3).astype("uint8"))
        q = tile.quantize(colors=per, method=Image.MEDIANCUT)
        raw = q.getpalette()[: per * 3]
        colors += [tuple(raw[i * 3:i * 3 + 3]) for i in range(per)]

    # 같은 색은 한 번만. 순서는 유지한다.
    seen, uniq = set(), []
    for c in colors:
        if c not in seen:
            seen.add(c)
            uniq.append(c)
    uniq = uniq[:256]

    pal = Image.new("P", (1, 1))
    flat = []
    for c in uniq:
        flat += list(c)
    flat += [0, 0, 0] * (256 - len(uniq))
    pal.putpalette(flat)
    return pal


# ── 마젠타 빼기 ───────────────────────────────────────────────────────

def magenta_mask(a: np.ndarray) -> np.ndarray:
    """마젠타인 곳.

    밝기로 자르면 안 된다. 캐릭터 발밑 그림자가 **어두운 마젠타**라서
    밝기 문턱을 넘지 못하고 남았고, 스프라이트에 검붉은 발자국이 붙었다.
    그래서 밝기 대신 **색상**으로 본다 — 빨강과 파랑이 초록보다 뚜렷이
    높으면 배경이다. 캐릭터의 고동색 외곽선(파랑이 낮다)은 걸리지 않는다.
    """
    r = a[..., 0].astype(int)
    g = a[..., 1].astype(int)
    b = a[..., 2].astype(int)
    return (r - g > 28) & (b - g > 28) & (a.max(axis=-1) > 55)


def grow(mask: np.ndarray, n: int = 1) -> np.ndarray:
    """마스크를 n픽셀 부풀린다. 경계의 분홍 실을 마젠타 쪽으로 넘긴다."""
    m = mask.copy()
    for _ in range(n):
        p = np.pad(m, 1, constant_values=False)
        m = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:] | m)
    return m


def cutout(im: Image.Image) -> Image.Image:
    """마젠타를 투명으로 바꾼 RGBA."""
    a = np.asarray(im.convert("RGB"))
    m = grow(magenta_mask(a), 1)
    rgba = np.dstack([a, np.where(m, 0, 255).astype("uint8")])
    return Image.fromarray(rgba, "RGBA")


# ── 격자 찾기 ─────────────────────────────────────────────────────────

def _gutters(flags: np.ndarray, min_len: int = 3) -> list:
    """전부 마젠타인 줄이 이어진 구간."""
    out, s = [], None
    for i, v in enumerate(flags):
        if v and s is None:
            s = i
        elif not v and s is not None:
            if i - s >= min_len:
                out.append((s, i - 1))
            s = None
    if s is not None and len(flags) - s >= min_len:
        out.append((s, len(flags) - 1))
    return out


def _spans(gutters: list, total: int) -> list:
    """골 사이의 알맹이 구간."""
    out, pos = [], 0
    for a, b in gutters:
        if a - pos > 8:
            out.append((pos, a - 1))
        pos = b + 1
    if total - pos > 8:
        out.append((pos, total - 1))
    return out


def cut_grid(im: Image.Image) -> list:
    """마젠타 골로 나뉜 칸들을 (x0,y0,x1,y1) 로 돌려준다. 읽는 순서."""
    a = np.asarray(im.convert("RGB"))
    m = magenta_mask(a)
    rows = _spans(_gutters(m.all(axis=1)), m.shape[0])
    cols = _spans(_gutters(m.all(axis=0)), m.shape[1])
    return [(x0, y0, x1, y1) for (y0, y1) in rows for (x0, x1) in cols]


def cut_cells(im: Image.Image) -> list:
    """마젠타 골로 칸을 나눈다. **세로로 먼저, 그다음 열 안에서 가로로.**

    처음엔 덩어리(연결 성분)를 찾아 잘랐다. 대개 잘 됐지만 사무실 시트에서
    책상과 창문이 보이지 않는 실 한 줄로 이어져 한 덩어리가 됐고, 아무리
    깎아도 안 끊어졌다.

    골로 나누면 그런 일이 없다. 물체가 서로 안 닿게 그려 달라고 이미
    부탁해 두었으므로, 사이에는 반드시 마젠타 골이 있다.

    행을 먼저 나누지 않고 **열을 먼저** 나누는 이유는, 한 열에만 물체가
    둘 있는 시트(고향집: 오른쪽 열에 평상과 밭)가 있기 때문이다.
    """
    a = np.asarray(im.convert("RGB"))
    m = magenta_mask(a)
    h, w = m.shape

    out = []
    for x0, x1 in _spans(_gutters(m.all(axis=0)), w):
        band = m[:, x0:x1 + 1]
        for y0, y1 in _spans(_gutters(band.all(axis=1)), h):
            out.append((x0, y0, x1, y1))

    # 읽는 순서로 (위 줄부터, 왼쪽부터)
    tol = h * 0.18
    rows = []
    for b in sorted(out, key=lambda b: (b[1] + b[3]) / 2.0):
        cy = (b[1] + b[3]) / 2.0
        if rows and abs(rows[-1][0] - cy) < tol:
            rows[-1][1].append(b)
        else:
            rows.append([cy, [b]])
    ordered = []
    for _, group in rows:
        ordered += sorted(group, key=lambda b: b[0])
    return ordered


def cut_cells_shaped(im: Image.Image, rows: int, cols: int) -> list:
    """칸 수를 알고 있을 때. 골이 없으면 **제일 얇은 줄**에서 끊는다.

    사무실 시트에서 책상 그림자가 아래 창문까지 이어져 골이 아예 없었다.
    그대로 두었더니 둘이 한 덩어리가 되고 이름이 한 칸씩 밀렸다 —
    창문 자리에 접수대 그림이, 접수대 자리에 반납함 그림이 들어갔다.

    몇 행 몇 열인지는 우리가 안다. 그러니 나눌 자리만 찾으면 된다.
    """
    a = np.asarray(im.convert("RGB"))
    m = magenta_mask(a)
    h, w = m.shape

    bands = _spans(_gutters(m.all(axis=0)), w)
    if len(bands) != cols:                      # 열 골이 안 맞으면 고르게 나눈다
        step = w / cols
        bands = [(int(i * step), int((i + 1) * step) - 1) for i in range(cols)]

    out = []
    for x0, x1 in bands:
        band = m[:, x0:x1 + 1]
        spans = _spans(_gutters(band.all(axis=1)), h)
        if len(spans) != rows:
            # 골이 없다. 알맹이 구간을 쪼갠다 — 가운데 언저리에서 비마젠타
            # 픽셀이 가장 적은 행이 두 물체 사이다.
            filled = np.nonzero(~band.all(axis=1))[0]
            if filled.size == 0:
                continue
            top, bot = int(filled[0]), int(filled[-1])
            count = (~band).sum(axis=1)
            spans, start = [], top
            for i in range(1, rows):
                lo = int(top + (bot - top) * (i / rows) - (bot - top) * 0.12)
                hi = int(top + (bot - top) * (i / rows) + (bot - top) * 0.12)
                lo, hi = max(start + 4, lo), min(bot - 4, hi)
                cut = (lo + hi) // 2 if hi <= lo else lo + int(np.argmin(count[lo:hi + 1]))
                spans.append((start, cut))
                start = cut + 1
            spans.append((start, bot))
        for y0, y1 in spans:
            out.append((x0, y0, x1, y1))

    out.sort(key=lambda b: (round((b[1] + b[3]) / 2.0 / (h * 0.36)), b[0]))
    return out


# ── 물체 찾기 (옛 방식, 골이 없을 때만) ───────────────────────────────

def cut_objects(im: Image.Image, min_area: int = 2500, sep: int = 4) -> list:
    """마젠타 위에 떠 있는 덩어리들의 상자. 왼쪽→오른쪽, 위→아래 순.

    나눌 때만 마스크를 `sep` 픽셀 더 깎는다. 감나무 가지 끝이 평상에 1px
    닿아서 둘이 한 덩어리로 잡혔다. 깎아서 끊고, 상자는 다시 그만큼 넓힌다.
    """
    a = np.asarray(im.convert("RGB"))
    solid = ~grow(magenta_mask(a), sep)
    h, w = solid.shape

    # 너비 우선 탐색으로 덩어리를 센다. 재귀는 깊이가 터진다.
    label = np.zeros((h, w), dtype=np.int32)
    boxes = []
    nxt = 0
    ys, xs = np.nonzero(solid)
    for sy, sx in zip(ys, xs):
        if label[sy, sx]:
            continue
        nxt += 1
        stack = [(sy, sx)]
        label[sy, sx] = nxt
        y0 = y1 = sy
        x0 = x1 = sx
        n = 0
        while stack:
            cy, cx = stack.pop()
            n += 1
            y0, y1 = min(y0, cy), max(y1, cy)
            x0, x1 = min(x0, cx), max(x1, cx)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not label[ny, nx]:
                    label[ny, nx] = nxt
                    stack.append((ny, nx))
        if n >= min_area:
            # 깎은 만큼 도로 넓힌다
            boxes.append((max(0, x0 - sep), max(0, y0 - sep),
                          min(w - 1, x1 + sep), min(h - 1, y1 + sep), n))

    # 그림자가 본체와 떨어져 나오는 일이 있다. 겹치는 상자는 합친다.
    boxes.sort(key=lambda b: -b[4])
    merged = []
    for x0, y0, x1, y1, n in boxes:
        hit = None
        for i, (mx0, my0, mx1, my1) in enumerate(merged):
            if not (x1 < mx0 or x0 > mx1 or y1 < my0 or y0 > my1):
                hit = i
                break
        if hit is None:
            merged.append([x0, y0, x1, y1])
        else:
            m = merged[hit]
            m[0], m[1] = min(m[0], x0), min(m[1], y0)
            m[2], m[3] = max(m[2], x1), max(m[3], y1)

    # 위 줄부터, 왼쪽부터.
    #
    # 처음엔 y0 // 80 으로 줄을 나눴다. 그런데 같은 줄에 있는 물체라도 키가
    # 다르면 y0 이 80 을 넘나들어 **한 줄이 두 줄로 쪼개졌다.** 소품 시트에서
    # 담장이 맨 뒤로 밀려 이름이 통째로 어긋났다.
    # 그래서 세로 **중심**을 그림 높이에 견줘 묶는다.
    tol = h * 0.18
    rows = []
    for b in sorted(merged, key=lambda b: (b[1] + b[3]) / 2.0):
        cy = (b[1] + b[3]) / 2.0
        if rows and abs(rows[-1][0] - cy) < tol:
            rows[-1][1].append(b)
        else:
            rows.append([cy, [b]])
    out = []
    for _, group in rows:
        out += sorted(group, key=lambda b: b[0])
    return [tuple(b) for b in out]


# ── 픽셀로 내리기 ─────────────────────────────────────────────────────

def to_pixel(im: Image.Image, w: int, h: int, pal: Image.Image) -> Image.Image:
    small = im.resize((max(1, w), max(1, h)), Image.BOX)   # 면적 평균
    alpha = small.getchannel("A").point(lambda v: 255 if v > 120 else 0)
    rgb = small.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def center_crop(im: Image.Image) -> Image.Image:
    """가운데만 쓴다. 그림 가장자리는 원본에서도 어두울 때가 많다."""
    w, h = im.size
    m = int(min(w, h) * 0.15)
    return im.crop((m, m, w - m, h - m))


def flatten_ground(im: Image.Image, noise: float = TILE_NOISE) -> Image.Image:
    """바닥 타일은 **거의 평평해야** 한다.

    처음엔 가장자리끼리 섞어 이음매를 지웠다. 그런데 그 섞임이 타일마다
    어두운 테를 만들었고, 깔아 놓으니 테가 이어져 **격자선**이 됐다.
    칸마다 뒤집고 돌려 봐도 대칭이 맞물려 오히려 더 또렷한 무늬가 됐다.

    16px 로 줄이면 무늬 하나가 칸 하나를 차지한다. 그러면 무엇을 해도
    규칙적으로 반복된다. 답은 이음매를 감추는 게 아니라 **무늬를 줄이는**
    것이다 — 평균색 쪽으로 당겨 놓고, 아주 옅은 결만 남긴다.

    **반드시 팔레트를 입힌 뒤에** 불러야 한다. 처음엔 줄이기 전에 눌렀는데,
    뒤이은 양자화가 미묘한 차이를 서로 다른 팔레트 색으로 갈라놓아 대비가
    고스란히 되살아났다. 눈으로 안 봤으면 못 찾을 뻔했다.
    """
    a = np.asarray(im.convert("RGBA")).astype(float)
    rgb = a[..., :3]
    mean = rgb.reshape(-1, 3).mean(axis=0)
    std = float(np.sqrt(((rgb - mean) ** 2).mean()))
    if std > noise:
        rgb = mean + (rgb - mean) * (noise / std)
    a[..., :3] = rgb.clip(0, 255)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def grain_ground(im: Image.Image, floor: float = TILE_GRAIN_MIN) -> Image.Image:
    """너무 평평한 바닥에 아주 옅은 결을 넣는다.

    무작위를 쓰지 않는다 — 다시 돌릴 때마다 바닥이 달라지면 안 된다.
    칸 좌표로 정해지는 값을 쓴다. 세기는 눈에 "무늬"로 안 보일 만큼만:
    바닥은 걸어 다니는 곳이지 쳐다보는 곳이 아니다.
    """
    a = np.asarray(im.convert("RGBA")).astype(float)
    rgb = a[..., :3]
    y = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    if float(y.std()) >= floor:
        return im
    h, w = y.shape
    xs, ys = np.meshgrid(np.arange(w), np.arange(h))
    n = ((xs * 73856093) ^ (ys * 19349663)) % 1000
    d = (n / 999.0 - 0.5) * (floor * 3.2)
    a[..., :3] = (rgb + d[..., None]).clip(0, 255)
    return Image.fromarray(a.astype("uint8"), "RGBA")


# ── 턴어라운드 → 걷기 시트 ────────────────────────────────────────────
#
# 제미나이에 걷기 프레임을 통째로 시키면 프레임마다 얼굴이 달라진다.
# 그래서 **정지 자세 세 방향만** 받고, 걷기는 여기서 만든다.
#
# 24px 캐릭터의 걷기는 픽셀 몇 개가 움직이는 게 전부다. 16비트 시절
# 게임들이 다 이 방식이었고, 손으로 그린 것과 구분이 안 간다.

WALK_FRAMES = 4
LEG_PART = 0.34        # 아래 34% 를 다리로 본다


def make_walk(spr: Image.Image) -> list:
    """정지 자세 하나로 걷기 네 프레임을 만든다.

    ① 몸이 1px 위아래로 튄다 (가운데 두 프레임에서 뜬다)
    ② 다리가 좌우로 1px 엇갈린다
    이 둘이면 걷는 것으로 보인다. 더 넣으면 오히려 지저분해진다.

    좌우로 1px 밀어야 하므로 그림 양옆에 1px 여백을 두고 그린다.
    여백 없이 밀면 반대쪽이 잘려 나간다.
    """
    w, h = spr.size
    knee = int(h * (1.0 - LEG_PART))
    upper = spr.crop((0, 0, w, knee))
    legs = spr.crop((0, knee, w, h))

    out = []
    for i in range(WALK_FRAMES):
        f = Image.new("RGBA", (w + 2, h + 1), (0, 0, 0, 0))
        lift = 1 if i % 2 == 1 else 0          # 1,3 프레임에서 뜬다
        swing = (0, 1, 0, -1)[i]               # 다리 엇갈림
        f.alpha_composite(upper, (1, 1 - lift))
        f.alpha_composite(legs, (1 + swing, 1 + knee - lift))
        out.append(f)
    return out


def save_walk_sheet(name: str, views: dict, out_dir: str) -> str:
    """4프레임 x 3방향 시트 하나로 묶는다.

    줄 순서는 아래(정면) / 옆 / 위(뒷모습). 오른쪽은 옆을 뒤집어 쓰므로
    따로 만들지 않는다 — 그림도 반, 파일도 반이다.
    """
    order = ["down", "side", "up"]
    bw = max(v.width for v in views.values())
    bh = max(v.height for v in views.values())
    cw, ch = bw + 2, bh + 1            # make_walk 이 두는 여백
    sheet = Image.new("RGBA", (cw * WALK_FRAMES, ch * len(order)), (0, 0, 0, 0))
    for r, key in enumerate(order):
        base = views[key]
        # 칸 안에서 가운데 아래로 붙인다. 발이 같은 높이여야 안 흔들린다.
        pad = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        pad.alpha_composite(base, ((bw - base.width) // 2, bh - base.height))
        for c, f in enumerate(make_walk(pad)):
            sheet.alpha_composite(f, (c * cw, r * ch))
    path = os.path.join(out_dir, name + "-walk.png")
    sheet.save(path)
    return path


def run_mascot(sheet: dict, pal: Image.Image) -> list:
    """주인공. 새로 그릴 필요가 없다 — 기존 3D 렌더에 앞·옆·뒤가 이미 있다.

    투명 배경 PNG 라 마젠타를 뺄 일도 없다. 픽셀로 내려서 같은 걷기 시트로
    묶기만 하면 인연들과 나란히 선다.
    """
    os.makedirs(sheet["out"], exist_ok=True)
    crops = {}
    for key, path in sheet["views"].items():
        if not os.path.exists(path):
            print("  건너뜀 (파일 없음): %s" % path)
            return []
        im = Image.open(path).convert("RGBA")
        bb = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        crops[key] = im.crop(bb) if bb else im

    name, units = sheet["names"][0]
    scale = (units * UNIT) / crops["down"].height
    views = {k: to_pixel(c, max(1, round(c.width * scale)),
                         max(1, round(c.height * scale)), pal)
             for k, c in crops.items()}
    out = save_walk_sheet(name, views, sheet["out"])
    print("    %-10s 3방향 x %d프레임  →  %s" % (name, WALK_FRAMES, out))
    return [out]


def run_turnaround(sheet: dict, pal: Image.Image) -> list:
    """3행 x N열 턴어라운드에서 앞·옆·뒤를 골라 걷기 시트를 만든다."""
    path = os.path.join(SRC, sheet["file"])
    if not os.path.exists(path):
        print("  건너뜀 (파일 없음): %s" % path)
        return []
    im = Image.open(path).convert("RGB")
    rgba = cutout(im)
    os.makedirs(sheet["out"], exist_ok=True)

    boxes = cut_cells(im)
    rows = {}
    for b in boxes:
        cy = (b[1] + b[3]) // 2
        near = [k for k in rows if abs(k - cy) < 90]
        rows.setdefault(near[0] if near else cy, []).append(b)
    rows = [sorted(rows[k], key=lambda b: b[0]) for k in sorted(rows)]

    pick = sheet["columns"]          # (앞, 옆, 뒤) 열 번호 (1부터)
    made = []
    for r, cells in enumerate(rows):
        if r >= len(sheet["names"]):
            break
        name, units = sheet["names"][r]
        target = max(1, round(units * UNIT))

        # 세 방향을 같은 픽셀 높이로 맞추면 안 된다. 옆모습은 꼬리가 뒤로
        # 늘어져 상자가 세로로 커지는데, 억지로 같은 높이에 우겨넣으면
        # 몸이 눌리고 꼬리와 사이가 벌어진다.
        # **정면을 기준으로 배율 하나를 정해** 세 방향에 똑같이 쓴다.
        crops = {}
        for key, col in zip(("down", "side", "up"), pick):
            if col - 1 >= len(cells):
                continue
            x0, y0, x1, y1 = cells[col - 1]
            c = rgba.crop((x0, y0, x1 + 1, y1 + 1))
            bb = c.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            crops[key] = c.crop(bb) if bb else c
        if "down" not in crops:
            print("    %s: 정면이 없어 건너뜀" % name)
            continue
        scale = target / crops["down"].height

        views = {}
        for key, c in crops.items():
            views[key] = to_pixel(c, max(1, round(c.width * scale)),
                                  max(1, round(c.height * scale)), pal)
        if len(views) < 3:
            print("    %s: 방향이 모자라 건너뜀" % name)
            continue
        out = save_walk_sheet(name, views, sheet["out"])
        made.append(out)
        print("    %-10s %d방향 x %d프레임  →  %s"
              % (name, len(views), WALK_FRAMES, out))
    return made


# ── 어떤 그림을 어떻게 다룰지 ─────────────────────────────────────────
#
# 유닛으로 적어 둔다. 1유닛 = 8px.

SHEETS = [
    {
        "id": "a",
        "file": "a-ground.jpg",
        "mode": "grid",
        "out": OUT_TILES,
        "names": ["grass", "sand", "dirt", "cobble", "water", "deck"],
    },
    {
        # Q장 — 여섯 곳이 다 같은 색이라 갈라 주려고 받은 바닥.
        # 쿼울 실내 둘(카펫·대리석)과, 여행지를 구별해 주는 넷.
        "id": "q",
        "file": "q-floors.jpg",
        "mode": "grid",
        "out": OUT_TILES,
        "names": ["office-carpet", "lobby-marble", "basalt",
                  "granite-step", "clay-earth", "slate-path"],
        # 무늬가 또렷한 셋만 조금 눌러 준다. 더 누르면 재질이 사라져
        # 색 띠(color bar)가 된다 — 실제로 한 번 그렇게 만들었다.
        "noise": {"lobby-marble": 3.4, "granite-step": 3.6, "slate-path": 3.6},
    },
    {
        "id": "g3",
        "file": "g3-yard-ground.jpg",
        "mode": "grid",
        "out": OUT_TILES,
        # 2x4 로 나왔고 좌우가 거의 같은 그림이 겹쳤다. 쓸 것만 고른다.
        "names": ["wood-floor", None, "tilled-soil", None,
                  "dry-grass", None, "stone-slab", None],
    },
    {
        "id": "g1",
        "file": "g1-home.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        # (이름, 높이 유닛)
        "names": [("home-house", 7), ("home-persimmon", 8),
                  ("home-deck", 1.6), ("home-garden", 3)],
    },
    {
        "id": "g2",
        "file": "g2-family.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("mom", 3), ("dad", 3.2), ("sibling", 2.7)],
    },
    # J장(같은 화풍 턴어라운드)이 들어와서 이제 안 쓴다. 3D 렌더는 인연들과
    # 나란히 세우면 외곽선이 없어 혼자 물렁해 보였다.
    {
        "id": "hero3d",
        "file": "(기존 3D 렌더)",
        "mode": "mascot",
        "skip": True,
        "out": OUT_SPRITES,
        "views": {
            "down": "assets/mascots/sheet/leader-front.png",
            "side": "assets/mascots/sheet/leader-side.png",
            "up": "assets/mascots/sheet/leader-back.png",
        },
        "names": [("hero", 3)],
    },
    {
        "id": "h",
        "file": "h-family-turn.jpg",
        "mode": "turnaround",
        "out": OUT_SPRITES,
        "columns": (1, 2, 3),        # 앞 / 옆(오른쪽 보기) / 뒤
        "names": [("mom", 3), ("dad", 3.2), ("sibling", 2.7)],
    },
    {
        "id": "i",
        "file": "i-folk-turn.jpg",
        "mode": "turnaround",
        "out": OUT_SPRITES,
        # 6열로 나왔다. 1=앞 3=옆 6=뒤 가 제일 또렷하다.
        "columns": (1, 3, 6),
        "names": [("seal", 3), ("seagull", 2.9), ("raccoon", 3)],
    },
    {
        "id": "b",
        "file": "b-buildings.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("guesthouse", 9), ("shop", 6), ("lighthouse", 12)],
    },
    {
        "id": "c",
        "file": "c-nature.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("pine", 8), ("tree", 7), ("beach-grass", 2),
                  ("boulder", 3), ("pebbles", 1.2), ("shrub", 2)],
    },
    {
        "id": "d",
        "file": "d-props.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("bench", 2), ("street-lamp", 5), ("signpost", 4),
                  ("flower-pots", 1.6), ("fence", 2), ("dock", 2)],
    },
    {
        "id": "f",
        "file": "f-office.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        # 책상 그림자가 아래 창문까지 이어져 골이 없다. 3행2열임을 알려 준다.
        "shape": (2, 3),
        "names": [("desk", 2), ("office-chair", 2), ("cabinet", 4),
                  ("office-window", 5), ("reception", 2), ("return-box", 1.4)],
    },
    {
        "id": "k",
        "file": "k-yard.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "shape": (2, 3),
        "names": [("jars", 2.4), ("clothesline", 3), ("pump", 2.4),
                  ("firewood", 1.6), ("washtub", 1), ("tools", 2.2)],
    },
    {
        "id": "l",
        "file": "l-pickups.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "shape": (2, 4),
        # 줍는 것들. 발밑에 놓이므로 작다 — 다만 너무 작으면 형태를 잃는다.
        # 0.6~1.0 유닛(5~8px)으로 뽑았더니 감인지 도토리인지 구분이 안 갔다.
        "names": [("p-persimmon", 1.5), ("p-pebble", 1.1), ("p-flower", 1.7),
                  ("p-pinecone", 1.4), ("p-acorn", 1.3), ("p-feather", 1.5),
                  ("p-shell", 1.3), ("p-seaglass", 1.1)],
    },
    {
        "id": "m",
        "file": "m-shore.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "shape": (2, 3),
        "names": [("parasol", 3.4), ("stall", 2.6), ("net", 1.6),
                  ("buoy", 1.4), ("icebox", 1.2), ("mailbox", 2.4)],
    },
    {
        "id": "n",
        "file": "n-items.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        # 6칸을 부탁했는데 4열 8칸으로 왔다. 수첩 두 권과 동전 두 닢이
        # 생겼으니 그대로 살려 쓴다 — 수첩은 일기장과 행복첩으로 나누고,
        # 동전은 액면이 다른 쿼원으로 쓴다.
        "shape": (2, 4),
        # 아이콘은 세상에 놓이는 게 아니라 화면에 뜨는 것이라 크게 뽑는다.
        "names": [("i-camera", 2.6), ("i-pack", 3.0), ("i-postcard", 2.2),
                  ("i-notebook", 2.4), ("i-dexbook", 2.4), ("i-icecream", 2.8),
                  ("i-coin", 1.8), ("i-coin-big", 2.0)],
    },
    {
        "id": "j",
        "file": "j-hero-turn.jpg",
        "mode": "turnaround",
        "out": OUT_SPRITES,
        "columns": (1, 2, 3),
        "names": [("hero", 3)],
    },
    {
        "id": "e",
        "file": "e-folk.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("seal", 3), ("seagull", 2.9), ("raccoon", 3)],
    },
]


def run_sheet(sheet: dict, pal: Image.Image) -> list:
    if sheet["mode"] == "mascot":
        return run_mascot(sheet, pal)
    path = os.path.join(SRC, sheet["file"])
    if not os.path.exists(path):
        print("  건너뜀 (파일 없음): %s" % path)
        return []
    im = Image.open(path).convert("RGB")
    os.makedirs(sheet["out"], exist_ok=True)
    made = []

    if sheet["mode"] == "mascot":
        return run_mascot(sheet, pal)

    if sheet["mode"] == "turnaround":
        return run_turnaround(sheet, pal)

    if sheet["mode"] == "grid":
        boxes = cut_grid(im)
        names = sheet["names"]
        print("  칸 %d개 (이름 %d개)" % (len(boxes), len(names)))
        for i, (x0, y0, x1, y1) in enumerate(boxes):
            name = names[i] if i < len(names) else None
            if name is None:
                continue
            cell = im.crop((x0, y0, x1 + 1, y1 + 1))
            # 정사각 가운데만 쓰고, 팔레트를 입힌 뒤에 결을 눌러 준다
            side = min(cell.size)
            cell = center_crop(cell.crop((0, 0, side, side)))
            # 무늬가 또렷한 바닥(대리석 줄눈·기와 골·화강암 소용돌이)은 더
            # 눌러 준다. 16px 에서는 무늬 하나가 칸 하나를 차지해서, 깔아
            # 놓으면 무늬가 아니라 **격자**로 읽힌다.
            noise = sheet.get("noise", {}).get(name, TILE_NOISE)
            tile = flatten_ground(
                to_pixel(cell.convert("RGBA"), TILE, TILE, pal), noise)
            tile = grain_ground(tile)
            out = os.path.join(sheet["out"], name + ".png")
            tile.save(out)
            made.append(out)
            print("    %-14s %dx%d  →  %s" % (name, TILE, TILE, out))
    else:
        rgba = cutout(im)
        boxes = cut_cells(im)
        if len(boxes) != len(sheet["names"]) and sheet.get("shape"):
            boxes = cut_cells_shaped(im, *sheet["shape"])
        if len(boxes) < len(sheet["names"]):
            boxes = cut_objects(im, sep=sheet.get("sep", 4))
        names = sheet["names"]
        print("  덩어리 %d개 (이름 %d개)" % (len(boxes), len(names)))
        for i, (x0, y0, x1, y1) in enumerate(boxes):
            if i >= len(names):
                print("    남은 덩어리 무시: %s" % ((x0, y0, x1, y1),))
                continue
            name, units = names[i]
            crop = rgba.crop((x0, y0, x1 + 1, y1 + 1))
            # 알파 기준으로 한 번 더 바짝 자른다 (마젠타 여백 제거)
            bb = crop.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if bb:
                crop = crop.crop(bb)
            h = max(1, round(units * UNIT))
            w = max(1, round(crop.width * h / crop.height))
            spr = to_pixel(crop, w, h, pal)
            out = os.path.join(sheet["out"], name + ".png")
            spr.save(out)
            made.append(out)
            print("    %-16s %dx%d  →  %s" % (name, w, h, out))
    return made


def preview(paths: list, scale: int = 6) -> str:
    """만든 것들을 한 장에 늘어놓는다. 눈으로 봐야 안다."""
    ims = [Image.open(p).convert("RGBA") for p in paths]
    if not ims:
        return ""
    pad = 6
    cols = 8
    cw = max(i.width for i in ims) + pad
    ch = max(i.height for i in ims) + pad
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (30, 26, 34, 255))
    for i, im in enumerate(ims):
        x = (i % cols) * cw + (cw - im.width) // 2
        y = (i // cols) * ch + (ch - im.height) - pad // 2
        sheet.alpha_composite(im, (x, y))
    big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    out = "/tmp/journey-preview.png"
    big.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="시트 id 하나만 (a/g1/g2/g3/e)")
    ap.add_argument("--preview", action="store_true", help="결과를 한 장에 모아 본다")
    args = ap.parse_args()

    print("팔레트 뽑는 중…")
    pal = build_palette()

    made = []
    for sheet in SHEETS:
        if args.only and sheet["id"] != args.only:
            continue
        if sheet.get("skip") and not args.only:
            continue
        print("\n[%s] %s" % (sheet["id"], sheet["file"]))
        made += run_sheet(sheet, pal)

    print("\n%d개 만들었다." % len(made))
    if args.preview:
        print("미리보기: %s" % preview(made))


if __name__ == "__main__":
    main()
