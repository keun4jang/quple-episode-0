#!/usr/bin/env python3
"""APK 에서 제외한 에셋을 게임이 참조하고 있지 않은지 검사한다.

export_presets 의 exclude_filter 는 APK 용량을 95 MB → 51 MB 로 줄여 주지만,
나중에 누가 제외된 에셋을 씬이나 스크립트에서 쓰기 시작하면
에디터에서는 멀쩡히 돌아가고 APK 에서만 깨진다. 그 사고를 미리 잡는다.

    python3 tools/check-export-assets.py

빌드 스크립트가 자동으로 호출한다.
"""
import fnmatch
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, "export_presets.template.cfg")

# 게임이 실제로 로드하는 파일들. 도구(tools/)와 문서는 APK 에 안 들어가므로 뺀다.
GAME_EXT = (".gd", ".tscn", ".tres", ".godot")
SKIP_DIRS = {".git", ".godot", "build", "tools", "docs", "tests"}


def exclude_patterns() -> list[str]:
    with open(TEMPLATE, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("exclude_filter="):
                raw = line.split("=", 1)[1].strip().strip('"')
                return [p.strip() for p in raw.split(",") if p.strip()]
    sys.exit(f"✗ {TEMPLATE} 에 exclude_filter 가 없다.")


def referenced() -> dict[str, set[str]]:
    """res:// 경로 → 그걸 참조하는 게임 파일들."""
    found: dict[str, set[str]] = {}
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(GAME_EXT):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
            for m in re.findall(r"res://([A-Za-z0-9_@/\-\.]+)", text):
                found.setdefault(m, set()).add(os.path.relpath(path, ROOT))
    return found


def main() -> int:
    patterns = exclude_patterns()
    problems = []
    missing = []

    for res, users in sorted(referenced().items()):
        if res.endswith("/") or res.startswith("uid:"):
            continue
        if not os.path.exists(os.path.join(ROOT, res)):
            # 실행 중 생성되는 경로(user:// 저장물 등)가 아닌 진짜 누락만 본다.
            missing.append((res, users))
            continue
        for pat in patterns:
            if fnmatch.fnmatch(res, pat):
                problems.append((res, pat, users))
                break

    for res, users in missing:
        print(f"⚠ 참조하는 파일이 저장소에 없다: {res}")
        for u in sorted(users):
            print(f"    ← {u}")

    if problems:
        print("\n✗ APK 에서 제외되는데 게임이 참조하는 에셋이 있다:\n")
        for res, pat, users in problems:
            print(f"  {res}")
            print(f"    제외 패턴: {pat}")
            for u in sorted(users):
                print(f"    ← {u}")
        print(
            "\nexport_presets.template.cfg 의 exclude_filter 에서 해당 패턴을 좁히거나,"
            "\n다른 에셋을 쓰도록 고쳐라."
        )
        return 1

    print("✓ 게임이 참조하는 에셋은 전부 APK 에 포함된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
