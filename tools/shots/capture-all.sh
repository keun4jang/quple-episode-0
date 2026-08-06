#!/usr/bin/env bash
# 전 화면을 찍어 /tmp/shots 에 넣는다. 디자인 리뷰용.
#
#   tools/shots/capture-all.sh [출력폴더]
set -u
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/shots}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$OUT"

for t in menu hub souvenir front lobby office hallway settings; do
  printf '%-10s ' "$t"
  QUPLE_TOUCH=1 QUPLE_TARGET="$t" QUPLE_SHOT="$OUT/$t.png" timeout 120 \
    xvfb-run -a -s "-screen 0 2400x1080x24" "$GODOT" \
    --resolution 2400x1080 --path "$ROOT" res://tools/shots/Capture.tscn \
    > "$OUT/$t.log" 2>&1
  [ -f "$OUT/$t.png" ] && echo "✓" || echo "✗  ($OUT/$t.log 참고)"
done
echo "→ $OUT"
