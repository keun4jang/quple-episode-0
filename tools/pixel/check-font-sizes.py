#!/usr/bin/env python3
"""쿼카 군단 UI 의 글자 크기가 정한 단계 안에 있는지 본다.

    python tools/pixel/check-font-sizes.py          # 요약 + 기준선 검사
    python tools/pixel/check-font-sizes.py --list   # 단계 밖 크기를 쓴 자리 전부

## 왜
화면마다 그때그때 숫자를 골라 16~84 사이 22가지 크기가 쌓였다 (2026-11 아트 검토).
크기가 많으면 무엇이 제목이고 무엇이 설명인지 눈이 못 가린다. 결과(한 화면)를 고치는 대신
판단 기준(크기 단계)을 정하고, 단계 밖 크기가 **늘어나지 않게** 막는다.

## 규칙
- 글 크기 단계: SCALE (18 · 22 · 28 · 34 · 44). 50 이상은 숫자·큰 제목용이라 자유.
- 단계 밖 크기는 BASELINE 개수를 넘으면 실패한다. 줄였으면 BASELINE 도 같이 줄인다 (래칫).
"""
import glob
import re
import sys

SCALE = {18, 22, 28, 34, 44}
DISPLAY_MIN = 50
BASELINE = 76  # 2026-11-16 기준 (19·21 을 18·22 로 합친 뒤). 줄일 때만 고친다.
FILES = sorted(p.replace("\\", "/") for p in glob.glob("scripts/lane/*.gd"))

CALL = re.compile(r"\b(?:IdleUi\.)?(label|button)\(")
SIZE_OVR = re.compile(r'"font_size",\s*(\d+)')


def second_arg(src, i):
    """src[i] 는 '(' 다음 글자. 맨 위 단계의 둘째 인자를 돌려준다."""
    depth, quote, arg, cur = 0, None, 0, []
    while i < len(src):
        c = src[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return "".join(cur).strip() if arg == 1 else None
            depth -= 1
        elif c == "," and depth == 0:
            if arg == 1:
                return "".join(cur).strip()
            arg += 1
            i += 1
            continue
        if arg == 1:
            cur.append(c)
        i += 1
    return None


def main():
    show = "--list" in sys.argv
    off, count = [], {}
    for path in FILES:
        src = open(path, encoding="utf-8").read()
        hits = []
        for m in CALL.finditer(src):
            a = second_arg(src, m.end())
            if a and a.isdigit():
                hits.append((m.start(), int(a)))
        for m in SIZE_OVR.finditer(src):
            hits.append((m.start(), int(m.group(1))))
        for pos, fs in hits:
            if fs == 0:
                continue
            count[fs] = count.get(fs, 0) + 1
            if fs not in SCALE and fs < DISPLAY_MIN:
                off.append((path, src[:pos].count("\n") + 1, fs))
    print("쓰인 크기: " + "  ".join("%d(%d)" % kv for kv in sorted(count.items())))
    print("단계: %s, %d 이상 자유" % (" · ".join(map(str, sorted(SCALE))), DISPLAY_MIN))
    if show:
        for p, ln, fs in off:
            print("   %s:%d  %d" % (p, ln, fs))
    n = len(off)
    if n > BASELINE:
        print("✘ 단계 밖 크기 %d곳 - 기준선 %d 보다 늘었다. 단계 안 크기를 쓸 것 (--list)" % (n, BASELINE))
        return 1
    note = " - 줄었으니 BASELINE 을 %d 로 낮출 것" % n if n < BASELINE else ""
    print("✔ 단계 밖 크기 %d곳 (기준선 %d)%s" % (n, BASELINE, note))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
