#!/usr/bin/env bash
# 맵·메뉴·전투·튜토리얼 스크린샷을 docs/screenshots/ 에 생성한다.
# 헤드리스 환경(웹/CI)에서 Godot를 소프트웨어 렌더링으로 실행한다.
#
# 사용법:
#   GODOT_BIN=/path/to/godot bash tools/take_screenshots.sh
#   GODOT_BIN=... bash tools/take_screenshots.sh ui_equip battle_boss   # 일부만
# (GODOT_BIN 미지정 시 PATH의 godot 사용)
#
# 새 화면을 추가하려면 아래 SHOTS 에 "씬|모드|파일이름" 한 줄을 넣으면 된다.
# 모드는 tools/capture_autoload.gd 주석 참고 (map / panel:<id> / battle:<적> / tutorial).

set -e
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export LIBGL_ALWAYS_SOFTWARE=1

DEST="$PROJECT_DIR/docs/screenshots"
mkdir -p "$DEST"

SHOTS=(
  # 맵 (HUD 포함 — GameUI가 오토로드라 같이 찍힌다)
  "CompanyFront3D|map|CompanyFront3D"
  "CompanyLobby3D|map|CompanyLobby3D"
  "Office3D|map|Office3D"
  "BossDoorHallway3D|map|BossDoorHallway3D"
  # 메뉴 창
  "CompanyFront3D|panel:inventory|ui_inventory"
  "CompanyFront3D|panel:equip|ui_equip"
  "CompanyFront3D|panel:skill|ui_skill"
  "CompanyFront3D|panel:quest|ui_quest"
  "CompanyFront3D|panel:shop|ui_shop"
  # 전투 — 패턴이 서로 다른 적들로
  "CompanyFront3D|battle:anxiety|battle_anxiety"
  "Office3D|battle:burnout|battle_burnout"
  "BossDoorHallway3D|battle:overtime|battle_boss"
  # 튜토리얼 첫 화면
  "CompanyFront3D|tutorial|tutorial"
)

# 인자를 주면 그 이름의 샷만 찍는다
WANTED=("$@")
want() {
  [ ${#WANTED[@]} -eq 0 ] && return 0
  for w in "${WANTED[@]}"; do [ "$w" = "$1" ] && return 0; done
  return 1
}

# 임시로 캡처 오토로드 추가 (GameUI 뒤에 넣어야 다른 오토로드가 먼저 준비된다)
cp "$PROJECT_DIR/project.godot" "$PROJECT_DIR/project.godot.shotbak"
cleanup() { mv -f "$PROJECT_DIR/project.godot.shotbak" "$PROJECT_DIR/project.godot" 2>/dev/null || true; }
trap cleanup EXIT

if ! grep -q "ShotCapture=" "$PROJECT_DIR/project.godot"; then
  sed -i 's#^GameUI="\*res://scripts/systems/game_ui.gd"#GameUI="*res://scripts/systems/game_ui.gd"\nShotCapture="*res://tools/capture_autoload.gd"#' "$PROJECT_DIR/project.godot"
fi

USER_SHOTS="$HOME/.local/share/godot/app_userdata/QupleEpisode0/shots"
COUNT=0
for entry in "${SHOTS[@]}"; do
  IFS='|' read -r scene mode name <<< "$entry"
  want "$name" || continue
  echo "== $name  ($scene / $mode)"
  SHOT_NAME="$name" SHOT_MODE="$mode" timeout 120 xvfb-run -a -s "-screen 0 1200x2000x24" \
    "$GODOT_BIN" --rendering-driver opengl3 --resolution 1080x1920 \
    --path "$PROJECT_DIR" "res://scenes/maps/$scene.tscn" 2>&1 | grep -E "CAPTURE_SAVED|SCRIPT ERROR" || true
  COUNT=$((COUNT + 1))
done

cp "$USER_SHOTS"/*.png "$DEST"/ 2>/dev/null || true
echo "스크린샷 $COUNT장 생성 완료: $DEST"
