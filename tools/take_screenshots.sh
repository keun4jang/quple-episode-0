#!/usr/bin/env bash
# 모든 맵 씬의 스크린샷을 docs/screenshots/ 에 생성하는 도구
# 헤드리스 환경(웹/CI)에서 Godot를 소프트웨어 렌더링으로 실행한다.
#
# 사용법:
#   GODOT_BIN=/path/to/godot bash tools/take_screenshots.sh
# (GODOT_BIN 미지정 시 PATH의 godot 사용)

set -e
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export LIBGL_ALWAYS_SOFTWARE=1

DEST="$PROJECT_DIR/docs/screenshots"
mkdir -p "$DEST"

# 임시로 캡처 오토로드 추가
cp "$PROJECT_DIR/project.godot" "$PROJECT_DIR/project.godot.shotbak"
if ! grep -q "ShotCapture=" "$PROJECT_DIR/project.godot"; then
  sed -i 's#AudioManager="\*res://scripts/systems/audio_manager.gd"#AudioManager="*res://scripts/systems/audio_manager.gd"\nShotCapture="*res://tools/capture_autoload.gd"#' "$PROJECT_DIR/project.godot"
fi

USER_SHOTS="$HOME/.local/share/godot/app_userdata/QupleEpisode0/shots"
for scene in CompanyFront3D CompanyLobby3D Office3D BossDoorHallway3D; do
  SHOT_NAME=$scene timeout 90 xvfb-run -a -s "-screen 0 1200x2000x24" \
    "$GODOT_BIN" --rendering-driver opengl3 --resolution 1080x1920 \
    --path "$PROJECT_DIR" "res://scenes/maps/$scene.tscn" 2>&1 | grep -E "CAPTURE_SAVED" || true
done

cp "$USER_SHOTS"/*.png "$DEST"/ 2>/dev/null || true

# 원복
mv "$PROJECT_DIR/project.godot.shotbak" "$PROJECT_DIR/project.godot"
echo "스크린샷 생성 완료: $DEST"
