#!/usr/bin/env python3
"""화면에 뜨는 글자가 전부 폰트에 있는지 검사한다.

    python3 tools/pixel/check-font-glyphs.py

## 왜 필요한가

`CLAUDE.md` 의 폰트 규칙 — **폰트에 없는 글자를 쓰지 않는다.** 없으면
폰에서 네모 상자가 뜬다. 그런데 이건 데스크톱에서 안 보인다. 개발
기계에는 다른 폰트가 깔려 있어서 엔진이 조용히 대신 그려 주기 때문이다.
**폰에서만 깨지고, 폰에서만 보인다.**

실제로 "지금은 — " 의 줄표(—, U+2014)가 그렇게 새어 들어갔다. 눈으로는
멀쩡했고 테스트도 다 통과했다. 그래서 눈 대신 폰트 파일을 직접 읽는다.

## 무엇을 보나

`scripts/**/*.gd` 의 **문자열 리터럴만** 본다 (주석은 뺀다 — 주석은
화면에 안 뜬다). `res://` 로 시작하는 경로도 뺀다.

## 걸리면

그 글자를 지우거나, 폰트에 있는 것으로 바꾼다. 세모·점 같은 표시는
글자로 쓰지 말고 **직접 그린다** (`draw_colored_polygon`/`draw_circle`).
쓸 수 있는 문장부호: - · , . : ; ! ? ( ) [ ] … ' ' " " ~ * +
없는 것: — – 、 ▪ •

## 콘솔 출력은 예외다

`tools/shots/sim_journey.gd` 의 ✔/✘ 는 `print()` 로 터미널에만 찍힌다.
게임 폰트로 그리는 글자가 아니라서 건너뛴다.
"""

import os
import re
import sys
import glob

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _ttf_cmap import cmap_chars

FONT = "assets/fonts/PoorStory.ttf"

# 터미널에만 찍히는 글자를 쓰는 파일. 게임 화면이 아니다.
CONSOLE_ONLY = {"tools/shots/sim_journey.gd"}

STRING = re.compile(r'"""(.*?)"""|"((?:[^"\\\n]|\\.)*)"', re.S)


def strip_comments(src: str) -> str:
    """GDScript 주석(#)을 지운다. 문자열 안의 # 은 남긴다."""
    out = []
    for line in src.split("\n"):
        res, i, quote = [], 0, None
        while i < len(line):
            c = line[i]
            if quote:
                res.append(c)
                if c == "\\":
                    if i + 1 < len(line):
                        res.append(line[i + 1])
                        i += 1
                elif c == quote:
                    quote = None
            else:
                if c == "#":
                    break
                if c in "\"'":
                    quote = c
                res.append(c)
            i += 1
        out.append("".join(res))
    return "\n".join(out)


def main() -> int:
    have = cmap_chars(FONT)
    bad = {}
    files = glob.glob("scripts/**/*.gd", recursive=True)
    files += glob.glob("tools/**/*.gd", recursive=True)
    for path in files:
        if path.replace(os.sep, "/") in CONSOLE_ONLY:
            continue
        src = strip_comments(open(path, encoding="utf-8").read())
        for m in STRING.finditer(src):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            if s is None or s.startswith("res://") or s.startswith("user://"):
                continue
            for ch in s:
                o = ord(ch)
                if o < 0x20 or o in have:
                    continue
                line = src[: m.start()].count("\n") + 1
                bad.setdefault((ch, o), []).append(
                    "%s:%d  %r" % (path, line, s[:70]))

    if not bad:
        print("✔ 폰트에 없는 글자 없음 (%d 파일)" % len(files))
        return 0
    for (ch, o), where in sorted(bad.items(), key=lambda kv: -len(kv[1])):
        print("\n✘ U+%04X  %r  — %d곳" % (o, ch, len(where)))
        for w in where:
            print("     " + w)
    print("\n폰에서 네모 상자로 뜬다. 지우거나 폰트에 있는 글자로 바꿀 것.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
