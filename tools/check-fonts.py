#!/usr/bin/env python3
"""글자가 우리 폰트로 실제로 그려지는지 검사한다.

눈으로 봐야 아는 것(자간·줄바꿈·읽히는지)은 art-type 에이전트가 본다.
여기서는 **눈이 필요 없는 것**만 본다.

    python3 tools/check-fonts.py

보는 것 두 가지.

**1. 개별 폰트 지정** — CLAUDE.md 의 고정 규칙이다. 위젯마다 폰트를 지정하면
전역 테마의 굵기를 덮어써서 그 글자만 얇아진다. 크기는 바꿔도 되고
폰트 자체는 건드리면 안 된다.

**2. 폰트에 없는 글자** — 우리 폰트에는 한글·영문·숫자와 약간의 기호만 있다.
✦ ⚙ 🌿 같은 것을 쓰면 Godot 이 **기기의 시스템 폰트로 대신 그린다.**
그러면 기기마다 모양이 달라지고, 폰트가 없는 기기에서는 두부(□)가 뜬다.
개발 PC 에서 멀쩡했다고 폰에서도 멀쩡한 게 아니다 — 그래서 기계로 센다.

없는 글자를 쓰지 말라는 뜻은 아니다. **어디에 쓰고 있는지 알고 쓰라**는 뜻이다.
"""
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = ROOT / "assets/themes/quple_bold.tres"


def theme_font() -> Path:
    """전역 테마가 실제로 쓰는 폰트. 폰트를 갈아끼워도 검사가 따라오게."""
    m = re.search(r'path="res://(assets/fonts/[^"]+\.ttf)"', THEME.read_text(encoding="utf-8"))
    return ROOT / (m.group(1) if m else "assets/fonts/Jua.ttf")


# ── TTF cmap 읽기 ──────────────────────────────────────────────────────
#
# fontTools 를 쓰면 편하지만 새 의존성을 깔지 않는다는 규칙이 있다.
# cmap 은 우리가 필요한 만큼만 읽으면 짧다 (format 4 / 12).

def font_codepoints(path: Path) -> set[int]:
    data = path.read_bytes()
    num_tables = struct.unpack(">H", data[4:6])[0]
    cmap_off = 0
    for i in range(num_tables):
        rec = 12 + i * 16
        if data[rec:rec + 4] == b"cmap":
            cmap_off = struct.unpack(">I", data[rec + 8:rec + 12])[0]
            break
    if cmap_off == 0:
        raise ValueError("cmap 테이블이 없다")

    n = struct.unpack(">H", data[cmap_off + 2:cmap_off + 4])[0]
    best = 0
    best_score = -1
    for i in range(n):
        rec = cmap_off + 4 + i * 8
        pid, eid, off = struct.unpack(">HHI", data[rec:rec + 8])
        # 유니코드 서브테이블을 고른다. 4바이트(format 12)를 더 쳐 준다.
        score = {(3, 10): 3, (0, 4): 3, (3, 1): 2, (0, 3): 2}.get((pid, eid), 0)
        if score > best_score:
            best_score, best = score, cmap_off + off
    if best_score <= 0:
        raise ValueError("유니코드 cmap 서브테이블이 없다")

    fmt = struct.unpack(">H", data[best:best + 2])[0]
    out: set[int] = set()
    if fmt == 4:
        seg2 = struct.unpack(">H", data[best + 6:best + 8])[0]
        seg = seg2 // 2
        base = best + 14
        ends = struct.unpack(">%dH" % seg, data[base:base + seg2])
        starts_at = base + seg2 + 2
        starts = struct.unpack(">%dH" % seg, data[starts_at:starts_at + seg2])
        for s, e in zip(starts, ends):
            if s == 0xFFFF:
                continue
            out.update(range(s, e + 1))
    elif fmt == 12:
        ngroups = struct.unpack(">I", data[best + 12:best + 16])[0]
        for i in range(ngroups):
            g = best + 16 + i * 12
            s, e, _ = struct.unpack(">III", data[g:g + 12])
            out.update(range(s, e + 1))
    else:
        raise ValueError("모르는 cmap 형식: %d" % fmt)
    return out


# ── 플레이어에게 보이는 글자 모으기 ────────────────────────────────────

# .tscn 의 text = "…" 과 .gd 의 문자열 리터럴.
# 파일 경로·노드 경로·그룹 이름은 화면에 안 나오므로 뺀다.
NOT_TEXT = re.compile(r'^(res://|user://|/root/|[A-Za-z0-9_/\.]+\.(gd|tscn|png|ogg|json|ttf)$)')

def strings_of(path: Path) -> list[tuple[int, str]]:
    out = []
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        for s in re.findall(r'"([^"\\]*)"', line):
            if not s or NOT_TEXT.match(s):
                continue
            out.append((i, s))
    return out


def main() -> int:
    font_path = theme_font()
    if not font_path.exists():
        print("✗ 폰트를 찾을 수 없다: %s" % font_path)
        return 1
    have = font_codepoints(font_path)
    print("검사 기준 폰트: %s (글자 %d 종)" % (font_path.name, len(have)))

    overrides: list[str] = []
    missing: dict[str, list[str]] = {}

    for path in sorted(ROOT.glob("scripts/**/*.gd")) + sorted(ROOT.glob("scenes/**/*.tscn")):
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith("tests/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")

        # 1) 개별 폰트 지정 — 크기(font_size)는 괜찮고 폰트 자체가 문제다
        for i, line in enumerate(text.splitlines(), 1):
            if re.search(r'add_theme_font_override\(|theme_override_fonts/', line):
                overrides.append("%s:%d  %s" % (rel, i, line.strip()))

        # 2) 폰트에 없는 글자
        for lineno, s in strings_of(path):
            for ch in s:
                cp = ord(ch)
                if cp < 0x2000 or cp in have:   # 아스키·기본 문장부호는 넘어간다
                    continue
                missing.setdefault(ch, []).append("%s:%d" % (rel, lineno))

    bad = False
    if overrides:
        bad = True
        print("✗ 위젯에 폰트를 직접 지정했다 (전역 테마의 굵기가 깨진다)")
        for o in overrides:
            print("   " + o)
        print()

    if missing:
        print("· 폰트에 없어서 기기 폰트로 대신 그려지는 글자 %d 종" % len(missing))
        for ch, where in sorted(missing.items(), key=lambda kv: -len(kv[1])):
            spots = ", ".join(dict.fromkeys(where))
            if len(spots) > 90:
                spots = spots[:88] + "…"
            print("   %s  U+%04X  %2d곳  %s" % (ch, ord(ch), len(where), spots))
        print("   → 기기마다 모양이 다르고, 없는 기기에서는 □ 로 뜬다.")
        print("     핵심 정보를 이 글자에만 담지 마라 (예: 버튼 뜻을 아이콘 하나로만 표시).")
        print()

    if not bad:
        print("✓ 폰트 규칙을 지키고 있다 (개별 지정 없음)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
