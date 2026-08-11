#!/usr/bin/env python3
"""정지 그림 한 장을 걷기 시트 자리에 맞는 4x3 격자로 채운다.

    python3 tools/pixel/make-fake-walk-sheet.py

## 왜 필요한가

`QuoSprite`(걷기를 다루는 코드)는 "-walk.png" 파일이 **가로 4프레임 x
세로 3방향**(아래/옆/위) 격자라고 가정하고 칸 크기를 계산한다
(`scripts/journey/quo_sprite.gd`). 정지 그림 한 장만 있어도 `Folk`로
세우려면 이 격자 모양은 맞춰야 한다 — 안 그러면 칸 크기 계산이 어긋나
그림이 잘리거나 늘어난다.

## 이게 진짜 걷기 애니메이션이 아니다

한 장을 4x3 칸에 그대로 복사해 넣을 뿐이다. **걷지도, 방향이 바뀌지도
않는다** — 셋 다 같은 정지 자세로 보인다. 2탄 첫 세 마을(굽이나루·
방울못·갈밭머리)의 카피바라·수달·개구리·고라니는 애초에 **자리를 안
뜨는 붙박이**로 설계했으니(다른 창 브레인스토밍 결론 — 걷기
애니메이션이 생기기 전까지는 이동 NPC로 안 쓴다) 이 정도로 충분하다.
실제 걷기 시트를 받으면 이 파일을 그걸로 덮어쓰면 된다.
"""

import os
from PIL import Image

SPRITES = "assets/sprites"
FRAMES = 4
ROWS = 3

# 정지 그림 이름 그대로 "-walk.png" 를 만든다 (put_folk 의 sheet 인자와
# 그대로 맞춰 쓰려고 — 이름을 두 번 기억할 필요가 없다).
NAMES = [
    "capybara-a", "capybara-b", "capybara-c",
    "otter", "frog", "deer", "squirrel", "magpie", "owl", "snail",
]


def main() -> None:
    for name in NAMES:
        path = os.path.join(SPRITES, name + ".png")
        if not os.path.exists(path):
            print("없음, 건너뜀: %s" % path)
            continue
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        sheet = Image.new("RGBA", (w * FRAMES, h * ROWS), (0, 0, 0, 0))
        for row in range(ROWS):
            for col in range(FRAMES):
                sheet.paste(im, (col * w, row * h))
        sheet.save(os.path.join(SPRITES, name + "-walk.png"))
        print("  %-14s %dx%d" % (name + "-walk", w * FRAMES, h * ROWS))


if __name__ == "__main__":
    main()
