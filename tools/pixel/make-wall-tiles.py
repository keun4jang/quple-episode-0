#!/usr/bin/env python3
"""실내 벽 얼굴 타일을 만든다.

실내는 여태 현무암 띠가 벽 노릇을 했다 — 바닥이 어두운 바닥으로 끝날
뿐, 방의 '벽'으로는 안 읽혔다. 위쪽 벽에서 방을 향한 마지막 한 줄만
**벽 얼굴**로 바꾼다: 위 3px 갓돌(어두움) + 12px 벽면(밝음) + 맨 아래
1px 어두운 선. 벽면엔 살짝 얼룩을 넣어 민판을 피한다.

- wall-plaster : 회벽 (가게 안)
- wall-stone   : 돌벽 (등대 안)
둘 다 -2 형제를 하나씩 만든다 (`Place._tile_for` 가 알아서 섞는다).
"""
import os
from PIL import Image

TILES = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tiles")
S = 16


def h2rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def make(name, cap, face, dark, seed):
    for suffix, s2 in (("", seed), ("-2", seed * 7 + 3)):
        img = Image.new("RGBA", (S, S))
        px = img.load()
        for y in range(S):
            for x in range(S):
                if y < 3:
                    c = cap
                elif y == S - 1:
                    c = dark
                else:
                    c = face
                    # 정해진 얼룩 — 무작위면 켤 때마다 벽이 달라진다.
                    n = (x * 374761393 + y * 668265263 + s2 * 97) & 0xffff
                    if n % 13 == 0:
                        c = tuple(max(0, v - 10) for v in face)
                    elif n % 17 == 0:
                        c = tuple(min(255, v + 8) for v in face)
                px[x, y] = c + (255,)
        # 갓돌 밑에 1px 밝은 선 — 갓돌이 벽면 위로 튀어나와 보인다.
        for x in range(S):
            px[x, 3] = tuple(min(255, v + 14) for v in face) + (255,)
        img.save(os.path.join(TILES, name + suffix + ".png"))
        print("만듦:", name + suffix + ".png")


make("wall-plaster", h2rgb("#BFAF96"), h2rgb("#DED1B9"), h2rgb("#756858"), 1)
make("wall-stone", h2rgb("#6B6470"), h2rgb("#8A8290"), h2rgb("#463E42"), 2)
