#!/usr/bin/env python3
"""흰 배경에 여러 개가 흩어진 시트 이미지를 한 장씩 잘라낸다.

    python3 tools/cut-sheet.py <시트.png> <나갈 폴더> <이름1,이름2,...>

제미나이·미드저니 같은 데서 받은 아이콘/소품 모음은 **격자가 반듯하지 않다.**
칸이 비기도 하고 줄이 밀리기도 한다. 그래서 칸 수를 미리 정해 자르지 않고,
실제로 뭔가 그려진 덩어리를 찾아서 그 덩어리마다 자른다.

배경 지우기 규칙 — 흰 배경과 회색 그림자만 지우고 크림색은 남긴다.
이 둘을 밝기만으로 가르면 크림색 물건(예: X 표시, 책 종이)이 같이 지워진다.
`무채색(RGB 차이가 거의 없음) + 밝음` 인 것만 배경으로 본다.
크림색은 R 과 B 가 30 넘게 벌어져서 살아남는다.

PIL 만 쓴다. numpy·scipy 는 이 환경에 없고, 새로 깔지 않는다.
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

# 배경으로 볼 조건
NEUTRAL_MAX_DIFF = 14     # R·G·B 가 이만큼 안에서 붙어 있으면 무채색
BRIGHT_MIN = 198          # 이보다 밝으면 배경 후보 (그림자 포함)
# 무채색 덩어리가 이보다 크면 배경이나 그림자로 본다.
# 아이콘 위의 작은 흰 하이라이트는 이보다 작아서 살아남는다.
BLOB_MIN_AREA = 300
# 물체로 인정할 최소 크기
OBJ_MIN_SIDE = 40
# 잘라낼 때 둘레에 남길 여백 (물체 크기 대비)
PAD = 0.06


def neutral_bright(px):
    r, g, b = px[0], px[1], px[2]
    return max(r, g, b) - min(r, g, b) <= NEUTRAL_MAX_DIFF and (r + g + b) / 3 >= BRIGHT_MIN


def label(mask, w, h):
    """mask[i] 가 True 인 칸들을 4-이웃으로 묶어 [(넓이, [인덱스…])] 로 돌려준다."""
    seen = bytearray(w * h)
    out = []
    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        q = deque([start])
        seen[start] = 1
        cells = []
        while q:
            i = q.popleft()
            cells.append(i)
            x, y = i % w, i // w
            if x > 0 and mask[i - 1] and not seen[i - 1]:
                seen[i - 1] = 1; q.append(i - 1)
            if x < w - 1 and mask[i + 1] and not seen[i + 1]:
                seen[i + 1] = 1; q.append(i + 1)
            if y > 0 and mask[i - w] and not seen[i - w]:
                seen[i - w] = 1; q.append(i - w)
            if y < h - 1 and mask[i + w] and not seen[i + w]:
                seen[i + w] = 1; q.append(i + w)
        out.append(cells)
    return out


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    sheet = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    names = [n for n in sys.argv[3].split(",") if n]
    outdir.mkdir(parents=True, exist_ok=True)

    im = Image.open(sheet).convert("RGB")
    w, h = im.size
    px = list(im.getdata())

    # 1) 배경(무채색+밝음) 덩어리를 찾아 알파를 0 으로
    bg_mask = [neutral_bright(p) for p in px]
    alpha = bytearray(255 for _ in range(w * h))
    for cells in label(bg_mask, w, h):
        if len(cells) >= BLOB_MIN_AREA:
            for i in cells:
                alpha[i] = 0

    # 2) 남은 것(=물체)을 덩어리로 묶는다.
    #    한 물체가 여러 조각(예: 반짝이 + 작은 별)일 수 있어서 살짝 부풀려 묶는다.
    solid = Image.frombytes("L", (w, h), bytes(alpha))
    grown = solid.filter(ImageFilter.MaxFilter(9)).point(lambda v: 255 if v > 40 else 0)
    gm = [v > 0 for v in grown.getdata()]

    boxes = []
    for cells in label(gm, w, h):
        xs = [i % w for i in cells]
        ys = [i // w for i in cells]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        if x1 - x0 < OBJ_MIN_SIDE or y1 - y0 < OBJ_MIN_SIDE:
            continue
        boxes.append((x0, y0, x1, y1))

    # 3) 줄 → 칸 순서로 정렬. 같은 줄인지는 세로 겹침으로 판단한다.
    boxes.sort(key=lambda b: b[1])
    rows = []
    for b in boxes:
        placed = False
        for row in rows:
            ref = row[0]
            if b[1] <= (ref[1] + ref[3]) / 2 <= b[3] or ref[1] <= (b[1] + b[3]) / 2 <= ref[3]:
                row.append(b); placed = True; break
        if not placed:
            rows.append([b])
    ordered = []
    for row in rows:
        row.sort(key=lambda b: b[0])
        ordered += row

    print("찾은 물체 %d 개 / 이름 %d 개" % (len(ordered), len(names)))
    if len(ordered) != len(names):
        print("  → 개수가 다르다. 자른 뒤 눈으로 확인해라.")

    rgba = im.convert("RGBA")
    rgba.putalpha(Image.frombytes("L", (w, h), bytes(alpha)))

    for i, (x0, y0, x1, y1) in enumerate(ordered):
        name = names[i] if i < len(names) else "extra%02d" % (i - len(names) + 1)
        bw, bh = x1 - x0, y1 - y0
        pad = int(max(bw, bh) * PAD)
        # 정사각형으로 맞춘다. 아이콘마다 비율이 다르면 버튼에서 크기가 들쭉날쭉해진다.
        side = max(bw, bh) + pad * 2
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        crop = rgba.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))
        crop = crop.resize((256, 256), Image.LANCZOS)
        crop.save(outdir / ("%s.png" % name))
        print("   %-14s %dx%d" % (name, bw, bh))
    return 0


if __name__ == "__main__":
    sys.exit(main())
