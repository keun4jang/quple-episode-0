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


# ── 물체 찾기 ─────────────────────────────────────────────────────────

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

    merged.sort(key=lambda b: (b[1] // 80, b[0]))     # 위 줄부터, 왼쪽부터
    return [tuple(b) for b in merged]


# ── 픽셀로 내리기 ─────────────────────────────────────────────────────

def to_pixel(im: Image.Image, w: int, h: int, pal: Image.Image) -> Image.Image:
    small = im.resize((max(1, w), max(1, h)), Image.BOX)   # 면적 평균
    alpha = small.getchannel("A").point(lambda v: 255 if v > 120 else 0)
    rgb = small.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def make_seamless(im: Image.Image) -> Image.Image:
    """이음매를 없앤다.

    제미나이가 "seamless" 를 지켜 주지 않는다. 가장자리가 안쪽보다 어둡거나
    무늬가 안 이어져서, 그대로 깔면 격자무늬가 보인다.

    가로세로로 절반씩 굴린 그림을 만들어 **가장자리끼리 섞는다.** 굴리면
    원래의 이음매가 한가운데로 오므로, 두 장을 가장자리 쪽에서 겹치면
    이음매가 서로를 덮는다.
    """
    w, h = im.size
    a = np.asarray(im.convert("RGB")).astype(float)
    rolled = np.roll(np.roll(a, w // 2, axis=1), h // 2, axis=0)

    # 가장자리에서 1, 가운데에서 0 이 되는 가중치
    xs = np.abs(np.linspace(-1, 1, w))
    ys = np.abs(np.linspace(-1, 1, h))
    wgt = np.maximum(xs[None, :], ys[:, None]) ** 2
    wgt = wgt[..., None]

    out = a * (1 - wgt * 0.5) + rolled * (wgt * 0.5)
    return Image.fromarray(out.clip(0, 255).astype("uint8"), "RGB")



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


def run_turnaround(sheet: dict, pal: Image.Image) -> list:
    """3행 x N열 턴어라운드에서 앞·옆·뒤를 골라 걷기 시트를 만든다."""
    path = os.path.join(SRC, sheet["file"])
    if not os.path.exists(path):
        print("  건너뜀 (파일 없음): %s" % path)
        return []
    im = Image.open(path).convert("RGB")
    rgba = cutout(im)
    os.makedirs(sheet["out"], exist_ok=True)

    boxes = cut_objects(im, min_area=1500)
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
        "id": "e",
        "file": "e-folk.jpg",
        "mode": "objects",
        "out": OUT_SPRITES,
        "names": [("seal", 3), ("seagull", 2.9), ("raccoon", 3)],
    },
]


def run_sheet(sheet: dict, pal: Image.Image) -> list:
    path = os.path.join(SRC, sheet["file"])
    if not os.path.exists(path):
        print("  건너뜀 (파일 없음): %s" % path)
        return []
    im = Image.open(path).convert("RGB")
    os.makedirs(sheet["out"], exist_ok=True)
    made = []

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
            # 정사각으로 맞춘 뒤 이음매를 지우고 타일 크기로 내린다
            side = min(cell.size)
            cell = cell.crop((0, 0, side, side))
            cell = make_seamless(cell)
            tile = to_pixel(cell.convert("RGBA"), TILE, TILE, pal)
            out = os.path.join(sheet["out"], name + ".png")
            tile.save(out)
            made.append(out)
            print("    %-14s %dx%d  →  %s" % (name, TILE, TILE, out))
    else:
        rgba = cutout(im)
        boxes = cut_objects(im)
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
        print("\n[%s] %s" % (sheet["id"], sheet["file"]))
        made += run_sheet(sheet, pal)

    print("\n%d개 만들었다." % len(made))
    if args.preview:
        print("미리보기: %s" % preview(made))


if __name__ == "__main__":
    main()
