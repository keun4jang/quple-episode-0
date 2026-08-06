#!/usr/bin/env python3
"""UI 코드가 디자인 규칙을 지키는지 검사한다.

눈으로 봐야 아는 것은 design-review 에이전트가 본다.
이 스크립트는 **눈이 필요 없는 것**만 본다 — 하드코딩된 값, 금지된 색, 너무 작은 글자.

    python3 tools/check-design-tokens.py

규칙은 scripts/ui/design.gd 에 있다. 값을 바꾸려면 거기서 바꾼다.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "scripts/ui/design.gd"

# 디자인 토큰 자체와 절차적 생성 코드는 값을 직접 쓰는 게 맞다.
SKIP = {
    "scripts/ui/design.gd",
    "scripts/travel/palette.gd",
    "scripts/systems/mood_palette.gd",
    "scripts/systems/prop_kit.gd",
    "scripts/systems/surface_kit.gd",
    "scripts/systems/bevel_kit.gd",
    "scripts/systems/depth_shading.gd",
    "scripts/systems/living_scene.gd",
    "scripts/systems/cinematic_look.gd",
}

MIN_FONT = 26          # design.gd 의 하한(30)보다 살짝 느슨하게. 확실한 것만 잡는다.
CORAL_HUE = (0.98, 0.07)   # 산호~주황. 쿼카 스카프 색이라 배경·UI 금지.


def read_floor() -> int:
    m = re.search(r"const TEXT_S := (\d+)", DESIGN.read_text(encoding="utf-8"))
    return int(m.group(1)) if m else MIN_FONT


def is_coral(r: float, g: float, b: float) -> bool:
    import colorsys
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.5:
        return False
    # 거의 검정인 색은 색조가 무엇이든 산호로 읽히지 않는다.
    # (씬 전환의 "긴장" 페이드가 Color(0.08, 0, 0) 이라 여기 걸렸다.)
    if l < 0.18:
        return False
    return h >= CORAL_HUE[0] or h <= CORAL_HUE[1]


def main() -> int:
    floor = read_floor()
    problems: list[str] = []

    for path in sorted(ROOT.glob("scripts/**/*.gd")) + sorted(ROOT.glob("scenes/**/*.tscn")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in SKIP or rel.startswith("tests/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")

        # 1. 너무 작은 글자 — 폰에서 안 읽힌다
        for m in re.finditer(r'font_size(?:_override)?["\s,\(]*[=:]?\s*(\d+)', text):
            size = int(m.group(1))
            if size < floor:
                line = text[: m.start()].count("\n") + 1
                problems.append(f"{rel}:{line}  글자 {size}pt — 하한 {floor}pt 미만")

        # 2. 배경·UI 에 산호색 — 쿼카가 묻힌다
        #
        # 단, 빛과 하늘은 예외다. 노을 지평선이나 전구색은 원래 따뜻하고,
        # 그건 캐릭터를 덮는 "면" 이 아니라 멀리 있는 빛이다. 금지 대상은
        # 캐릭터 뒤에 깔리는 넓은 색면과 UI 다.
        lines = text.split("\n")
        for m in re.finditer(r"Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)", text):
            r, g, b = (float(x) for x in m.groups())
            if max(r, g, b) > 1.0 or not is_coral(r, g, b):
                continue
            idx = text[: m.start()].count("\n")
            ctx = "\n".join(lines[max(0, idx - 1): idx + 1]).lower()
            if re.search(r"horizon|sun_|_sun|light|emission|glow|lamp|fade|sky|shadow", ctx):
                continue
            problems.append(
                f"{rel}:{idx + 1}  산호 계열 Color({r}, {g}, {b}) — 스카프 색이라 UI 금지")

    if problems:
        print("✗ 디자인 규칙 위반 %d 건\n" % len(problems))
        for p in problems:
            print("  " + p)
        print("\n규칙: scripts/ui/design.gd")
        return 1

    print("✓ 글자 크기와 색 규칙을 지키고 있다")
    return 0


if __name__ == "__main__":
    sys.exit(main())
