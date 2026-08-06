#!/usr/bin/env bash
# Godot 을 한 번에 하나씩만 돌린다.
#
# 에이전트 여럿이 동시에 Godot 을 띄우면 `.godot` 임포트 캐시를 같이 만지다가
# 서로 죽는다. 실제로 다섯이 함께 돌 때 렌더가 반복해서 시간 초과로 죽었다.
# 테스트가 통과하는지 아닌지가 아니라 **아예 실행이 안 되는** 문제라 더 나쁘다.
#
# 그래서 파일 락을 하나 두고 줄을 세운다. 기다리는 시간이 생기지만
# 죽고 다시 하는 것보다 빠르다.
#
# 쓰는 법 — godot 자리에 이걸 넣으면 된다:
#   tools/godot-run.sh --headless --path . --check-only --script foo.gd
#   tools/godot-run.sh --path . res://tests/TestTouch.tscn
#   QUPLE_TOUCH=1 tools/godot-run.sh --render --path . res://tests/_X.tscn
#
# --render 를 첫 인자로 주면 xvfb 화면을 띄운다 (해상도는 QUPLE_RES, 기본 2400x1080).
set -euo pipefail

GODOT=${GODOT:-/tmp/gd/Godot_v4.3-stable_linux.x86_64}
LOCK=${QUPLE_LOCK:-/tmp/quple-godot.lock}
WAIT=${QUPLE_LOCK_WAIT:-900}      # 최대 대기 (초)
RES=${QUPLE_RES:-2400x1080}

[ -x "$GODOT" ] || { echo "✗ Godot 을 찾을 수 없다: $GODOT" >&2; exit 1; }

RENDER=0
if [ "${1:-}" = "--render" ]; then
	RENDER=1
	shift
fi

# flock 이 없는 환경이면 그냥 실행한다. 줄 서기는 최선의 노력이지 필수가 아니다.
if ! command -v flock >/dev/null 2>&1; then
	if [ "$RENDER" = "1" ]; then
		exec xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --resolution "$RES" "$@"
	fi
	exec xvfb-run -a "$GODOT" "$@"
fi

exec 9>"$LOCK"
if ! flock -w "$WAIT" 9; then
	echo "✗ ${WAIT}초를 기다렸는데 Godot 락을 못 잡았다. 누가 오래 붙잡고 있다." >&2
	exit 1
fi

if [ "$RENDER" = "1" ]; then
	xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --resolution "$RES" "$@"
else
	xvfb-run -a "$GODOT" "$@"
fi
