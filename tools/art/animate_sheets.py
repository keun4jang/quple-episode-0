#!/usr/bin/env python3
"""그림 모델이 그린 캐릭터 시트(lane-unit-*, lane-bug-*)에 진짜 동작 칸을 만든다.

    python3 tools/art/animate_sheets.py            # 전부
    python3 tools/art/animate_sheets.py tiny ant   # 몇 개만
    python3 tools/art/animate_sheets.py --preview  # 결과를 한 장에 모아 scratch 로

## 왜
그림 모델은 서 있는 앞모습 한 장만 그린다 (프레임마다 그리면 얼굴이 달라져 출렁인다).
그래서 예전 시트는 같은 그림을 위아래로 1~3칸 옮겨 12칸을 채웠다 → 걸어도 때려도 그대로 서 있는 것처럼 보였다.
여기서는 그 한 장을 **잘라서 비틀어** 칸마다 다른 자세를 만든다:
- 걷기: 다리(아래 26%)를 왼쪽·오른쪽으로 나눠 번갈아 2칸 들어 올리고, 몸은 위아래로 들썩이며 좌우로 살짝 기운다
- 공격: 반대로 젖혀 힘을 모았다가(웅크림) → 크게 기울며 휘두르고(늘어남) → 따라가고 → 돌아온다
- 맞음: 뒤로 젖히며 납작해진다 · 환호: 위로 늘어나며 뛴다
- 벌레: 기는 벌레는 몸을 꿈틀(눌림·늘림·다리 엇갈림), 나는 벌레는 둥실둥실 떠다닌다
비틀기(회전·늘림)는 발 밑 가운데를 축으로, 이웃 보간이라 픽셀이 뭉개지지 않는다.

시트 모양은 그대로 (4칸 x 3줄 정사각 칸, 발이 칸 바닥) - 게임 코드는 안 바꿔도 된다.
  캐릭터: 0줄 앞모습(서 있음·환호·숨쉬기·아파함) · 1줄 공격(웅크림·휘두름·따라감·돌아옴) · 2줄 걷기 4칸
  벌레:   0줄 걷기 4칸 · 1줄 공격 · 2줄 밀려남
첫 칸(0,0)은 원래 그림 그대로라, 이 도구를 여러 번 돌려도 같은 결과가 나온다.
"""
import glob
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(HERE, "..", "..", "assets", "sprites")
PAD = 8          # 기울여도 칸 밖으로 안 나가게 칸을 이만큼 넓힌다 (한 번만 - 이미 넓힌 시트는 표시로 안다)
FLYERS = {"mosquito", "fly", "bee", "moth", "wasp", "mosquito_king", "hornet", "fly_king", "moth_queen"}


def base_sprite(sheet: Image.Image) -> Image.Image:
    side = sheet.width // 4
    cell = sheet.crop((0, 0, side, side))
    return cell.crop(cell.getbbox())


def xform(sp: Image.Image, ang: float = 0.0, sx: float = 1.0, sy: float = 1.0) -> Image.Image:
    """발 밑 가운데를 축으로 기울이고(도, +는 시계 방향) 늘린다. 결과 그림의 발 밑 가운데는 (W/2, H-1)."""
    w, h = sp.size
    big = int(max(w, h) * 1.6) + 8
    W, H = big, big
    px, py = w / 2.0, h - 0.5          # 원본에서의 축
    qx, qy = W / 2.0, H - 0.5          # 결과에서의 축
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    # 결과 좌표 → 원본 좌표 (역변환): 축 기준으로 되돌려 돌리고, 늘림을 되돌린다
    m00, m01 = ca / sx, sa / sx
    m10, m11 = -sa / sy, ca / sy
    c0 = px - (m00 * qx + m01 * qy)
    c1 = py - (m10 * qx + m11 * qy)
    out = sp.transform((W, H), Image.AFFINE, (m00, m01, c0, m10, m11, c1), resample=Image.NEAREST)
    return out


def lift_legs(sp: Image.Image, side: int, up: int) -> Image.Image:
    """아래 26%(다리)를 가운데에서 나눠 한쪽(side -1 왼쪽, +1 오른쪽)을 up 칸 들어 올린다."""
    w, h = sp.size
    hip = int(h * 0.74)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(sp.crop((0, 0, w, hip)), (0, 0))
    mid = w // 2
    left = sp.crop((0, hip, mid, h))
    right = sp.crop((mid, hip, w, h))
    out.alpha_composite(left, (0, hip - (up if side < 0 else 0)))
    out.alpha_composite(right, (mid, hip - (up if side > 0 else 0)))
    return out


def shift_legs(sp: Image.Image, dx: int) -> Image.Image:
    """다리 줄을 좌우로 엇갈리게 (벌레가 기어갈 때)."""
    w, h = sp.size
    hip = int(h * 0.62)
    out = Image.new("RGBA", (w + 2, h), (0, 0, 0, 0))
    out.alpha_composite(sp.crop((0, 0, w, hip)), (1, 0))
    out.alpha_composite(sp.crop((0, hip, w, h)), (1 + dx, hip))
    return out


# (그림 만드는 법, 위로 띄움) - 그림 만드는 법은 원래 그림을 받아 새 그림을 돌려준다
def unit_frames(sp: Image.Image) -> list:
    h = sp.height
    up = max(2, round(h * 0.05))
    return [
        [  # 0줄 앞모습
            (lambda s: s, 0),
            (lambda s: xform(s, 0, 0.96, 1.07), round(h * 0.08)),          # 환호: 늘어나며 뛴다
            (lambda s: xform(s, 0, 1.02, 0.97), 0),                         # 숨쉬기
            (lambda s: xform(s, -9, 1.06, 0.9), 0),                         # 아파함: 뒤로 젖히며 납작
        ],
        [  # 1줄 공격
            (lambda s: xform(s, 10, 1.05, 0.93), 0),                        # 웅크림 (반대로 젖혀 힘 모으기)
            (lambda s: xform(s, -13, 0.96, 1.06), 0),                       # 휘두름
            (lambda s: xform(s, -7, 0.99, 1.02), 0),                        # 따라감
            (lambda s: xform(s, 3, 1.0, 1.0), 0),                           # 돌아옴
        ],
        [  # 2줄 걷기 - 다리 번갈아, 몸 들썩·기울기
            (lambda s: xform(s, 0, 1.01, 0.98), 0),
            (lambda s: xform(lift_legs(s, -1, up), 3, 1.0, 1.0), 1),
            (lambda s: xform(s, 0, 1.01, 0.98), 0),
            (lambda s: xform(lift_legs(s, 1, up), -3, 1.0, 1.0), 1),
        ],
    ]


def bug_frames(sp: Image.Image, flyer: bool) -> list:
    h = sp.height
    if flyer:
        walk = [(lambda s: s, 2), (lambda s: xform(s, 3, 1.0, 1.0), 4),
                (lambda s: xform(s, 0, 1.03, 0.97), 2), (lambda s: xform(s, -3, 1.0, 1.0), 0)]
    else:
        walk = [(lambda s: shift_legs(s, -1), 0), (lambda s: xform(shift_legs(s, 1), 0, 1.05, 0.94), 0),
                (lambda s: shift_legs(s, 1), 0), (lambda s: xform(shift_legs(s, -1), 0, 0.97, 1.04), 1)]
    return [
        walk,
        [  # 1줄 공격 (벌레는 위로 덤빈다 - 덤벼드는 이동은 게임이 한다)
            (lambda s: xform(s, -9, 1.07, 0.9), 0),
            (lambda s: xform(s, 12, 0.94, 1.09), round(h * 0.06)),
            (lambda s: xform(s, 6, 0.98, 1.03), 0),
            (lambda s: xform(s, -2, 1.0, 1.0), 0),
        ],
        [  # 2줄 밀려남
            (lambda s: xform(s, 14, 1.08, 0.88), 0),
            (lambda s: xform(s, 10, 1.05, 0.92), 0),
            (lambda s: xform(s, 6, 1.03, 0.95), 0),
            (lambda s: xform(s, 2, 1.0, 1.0), 0),
        ],
    ]


def animate(path: str) -> Image.Image:
    sheet = Image.open(path).convert("RGBA")
    sp = base_sprite(sheet)
    old_side = sheet.width // 4
    name = os.path.basename(path)[:-4]
    is_bug = name.startswith("lane-bug-")
    kind = name.split("-", 2)[2]
    frames = bug_frames(sp, kind in FLYERS) if is_bug else unit_frames(sp)
    # 칸 크기: 원래 그림보다 PAD 만큼 여유 - 기울여도 안 잘리게. 발 밑 가운데를 칸 바닥 가운데에 맞춘다.
    side = max(old_side, max(sp.width, sp.height) + 6 + PAD)
    out = Image.new("RGBA", (side * 4, side * 3), (0, 0, 0, 0))
    for r in range(3):
        for c in range(4):
            make, lift = frames[r][c]
            img = make(sp)
            bb = img.getbbox()
            if bb is None:
                continue
            # 어느 그림이든 발 밑 가운데가 (폭/2, 높이-1) - 그 점을 칸 바닥 가운데에 맞춘다
            dx = int(round(side / 2.0 - img.width / 2.0))
            dy = int(round(side - img.height - lift))
            # 칸 밖으로 나가는 부분은 잘린다 (이웃 칸 침범 금지)
            cell = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            cell.paste(img, (dx, dy), img)
            out.alpha_composite(cell, (c * side, r * side))
    # 첫 칸은 원래 그림 그대로 (다시 돌려도 같은 바탕에서 시작하게)
    first = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    first.alpha_composite(sp, ((side - sp.width) // 2, side - sp.height - 1))
    out.paste(first, (0, 0))
    return out


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    preview = "--preview" in sys.argv
    paths = sorted(glob.glob(os.path.join(SPR, "lane-unit-*.png")) + glob.glob(os.path.join(SPR, "lane-bug-*.png")))
    if args:
        paths = [p for p in paths if os.path.basename(p)[:-4].split("-", 2)[2] in args]
    outs = []
    for p in paths:
        im = animate(p)
        if preview:
            outs.append((os.path.basename(p), im))
        else:
            im.save(p)
            print("ok", os.path.basename(p), im.size)
    if preview:
        dst = os.environ.get("PREVIEW_OUT", "/tmp/anim_preview.png")
        W = max(i.width for _, i in outs)
        H = sum(i.height + 6 for _, i in outs)
        sheet = Image.new("RGBA", (W, H), (120, 170, 110, 255))
        y = 0
        for _, i in outs:
            sheet.alpha_composite(i, (0, y))
            y += i.height + 6
        sheet.resize((W * 3, H * 3), Image.NEAREST).save(dst)
        print("preview", dst)


if __name__ == "__main__":
    main()
