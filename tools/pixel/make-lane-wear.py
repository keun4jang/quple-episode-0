#!/usr/bin/env python3
"""쿼카 군단 - 싸움 그림에 얹는 장신구 도트 (12x12 칸 한 줄, `lane-wear.png`).
캐릭터와 같은 픽셀 크기(3점)로 그려지므로 작게, 실루엣이 또렷하게. 순서는 `LaneData.ACC_ORDER` 와 같다.
    python3 tools/pixel/make-lane-wear.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
S = 12
K = (59, 37, 89, 255)          # 자두색 테두리


def hx(c, a=255):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


# 글자 그림: 칸마다 한 글자. '.' 빈칸, 'k' 테두리, 나머지는 팔레트
WEAR = {
    "feather_hat": (["............",
                     "........pp..",
                     ".......pPp..",
                     "......pPp...",
                     "...kkkkPkk..",
                     "..kHHHHHHHk.",
                     ".kHhhhhhhHHk",
                     ".kkkkkkkkkkk"],
                    {"p": "#FF8FB8", "P": "#FFC2D8", "H": "#8E6AC8", "h": "#B89AE8"}),
    "star_necklace": (["............",
                       ".c........c.",
                       "..c......c..",
                       "...cc..cc...",
                       ".....kk.....",
                       "....kYYk....",
                       "...kYyyYk...",
                       "....kYYk....",
                       ".....kk....."],
                      {"c": "#E8E0F0", "Y": "#FFD15A", "y": "#FFF3B0"}),
    "fluffy_vest": (["............",
                     ".kkk....kkk.",
                     "kWWWk..kWWWk",
                     "kWwWWkkWWwWk",
                     ".kWWWWWWWWk.",
                     "..kkkkkkkk.."],
                    {"W": "#FFF4E0", "w": "#FFFFFF"}),
    "clover_pin": (["............",
                    "...kk.kk....",
                    "..kGGkGGk...",
                    "..kGgGgGk...",
                    "...kGGGk....",
                    "..kGgGgGk...",
                    "..kGGkGGk...",
                    "...kk.kd....",
                    ".......d...."],
                   {"G": "#5DBE4A", "g": "#9CE07A", "d": "#3E7A30"}),
    "ice_bell": ([".....kk.....",
                  "....kBBk....",
                  "...kBbBBk...",
                  "...kBbBBk...",
                  "..kBBBBBBk..",
                  "..kkkkkkkk..",
                  ".....kk....."],
                 {"B": "#7FD0FF", "b": "#DFF5FF"}),
    "bolt_gloves": (["......kk....",
                     ".....kYk....",
                     "....kYk.....",
                     "...kYYYYk...",
                     ".....kYk....",
                     "....kYk.....",
                     "....kk......"],
                    {"Y": "#FFE05A"}),
    "wind_shoes": (["............",
                    ".kk.........",
                    "kWWk........",
                    "kWwWkkkkk...",
                    ".kWWBBBBBk..",
                    "..kBbBBBBBk.",
                    "...kkkkkkkk."],
                   {"W": "#FFFFFF", "w": "#DFF5FF", "B": "#5BA8E8", "b": "#9FD8FF"}),
    "honey_candy": (["............",
                     "..k.....k...",
                     ".kOk.kk.kOk.",
                     ".kOOkYYkOOk.",
                     ".kOOkYyYkOk.",
                     ".kOk.kYYkkOk",
                     "..k...kk..k."],
                    {"O": "#FFB84A", "Y": "#F2B33C", "y": "#FFE59A"}),
    "mirror_shield": (["...kkkkk....",
                       "..kSSSSSk...",
                       "..kSsSSSk...",
                       "..kSsSSSk...",
                       "..kSSSSSk...",
                       "...kSSSk....",
                       "....kSk.....",
                       ".....k......"],
                      {"S": "#D8DEE8", "s": "#FFFFFF"}),
    "dream_crown": (["............",
                     "..k...k...k.",
                     ".kYk.kYk.kYk",
                     ".kYYkYrYkYYk",
                     ".kYYYYYYYYYk",
                     ".kyyyyyyyyyk",
                     ".kkkkkkkkkkk"],
                    {"Y": "#FFD15A", "y": "#FFF3B0", "r": "#E8405A"}),
}
ORDER = ["feather_hat", "star_necklace", "fluffy_vest", "clover_pin", "ice_bell", "bolt_gloves",
         "wind_shoes", "honey_candy", "mirror_shield", "dream_crown"]


def draw(rows, pal):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    oy = S - len(rows)          # 아래에 붙인다 (머리 위 장신구가 머리에 닿게)
    for y, line in enumerate(rows):
        for x, ch in enumerate(line):
            if ch == ".":
                continue
            col = K if ch == "k" else hx(pal[ch])
            im.putpixel((x, y + oy), col)
    return im


def main():
    sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
    for i, k in enumerate(ORDER):
        rows, pal = WEAR[k]
        sheet.paste(draw(rows, pal), (i * S, 0))
    sheet.save(os.path.join(OUT, "lane-wear.png"))
    print("wear:", len(ORDER))


if __name__ == "__main__":
    main()
