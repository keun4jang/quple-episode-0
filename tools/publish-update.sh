#!/usr/bin/env bash
# 재설치 없이 폰에 반영되는 내용 갱신을 배포한다.
#
#   tools/publish-update.sh 0.1.2
#
# 하는 일:
#   1. project.godot 의 버전을 올린다
#   2. 리소스 팩(update/quple.pck)을 만든다
#   3. update/manifest.json 에 버전·크기·sha256 을 적는다
#   4. 커밋하고 push 한다
#
# push 하는 순간 폰이 다음 실행 때 새 내용을 받아 적용한다.
# 앱을 지우거나 APK 를 다시 깔 필요가 없다.
#
# 단, 팩으로 못 바꾸는 것도 있다 — 엔진, 안드로이드 권한, 앱 이름·아이콘,
# 네이티브 라이브러리. 그건 APK 를 새로 배포해야 한다.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=${1:-}
[ -n "$VERSION" ] || { echo "✗ 버전을 달라. 예: tools/publish-update.sh 0.1.2" >&2; exit 1; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ 버전 형식은 X.Y.Z (받은 값: $VERSION)" >&2; exit 1; }

GODOT=${GODOT:-godot}
command -v "$GODOT" >/dev/null || { echo "✗ godot 을 찾을 수 없다. GODOT=/경로/godot" >&2; exit 1; }

BRANCH=$(git rev-parse --abbrev-ref HEAD)
CUR=$(grep -oP 'config/version="\K[^"]+' project.godot)
echo "현재 $CUR → 새 버전 $VERSION  (브랜치 $BRANCH)"

# manifest 가 가리키는 브랜치와 지금 브랜치가 다르면 폰은 영영 못 받는다
MANIFEST_BRANCH=$(grep -oP 'quple-episode-0/\K[^/]+(/[^/]+)*(?=/update/manifest.json)' \
	scripts/systems/auto_update.gd || true)
if [ -n "$MANIFEST_BRANCH" ] && [ "$MANIFEST_BRANCH" != "$BRANCH" ]; then
	echo "✗ 앱은 '$MANIFEST_BRANCH' 를 보고 있는데 지금 브랜치는 '$BRANCH' 다." >&2
	echo "  그 브랜치에서 배포하거나 auto_update.gd 의 MANIFEST_URL 을 고쳐라." >&2
	exit 1
fi

sed -i "s|config/version=\"$CUR\"|config/version=\"$VERSION\"|" project.godot

mkdir -p update
echo "→ 리소스 팩 생성"
"$GODOT" --headless --path . --export-pack "Android arm64" "$PWD/update/quple.pck"
[ -s update/quple.pck ] || { echo "✗ 팩이 만들어지지 않았다" >&2; exit 1; }

SHA=$(sha256sum update/quple.pck | cut -d' ' -f1)
SIZE=$(stat -c %s update/quple.pck)
URL="https://raw.githubusercontent.com/keun4jang/quple-episode-0/$BRANCH/update/quple.pck"

cat > update/manifest.json <<EOF
{
  "version": "$VERSION",
  "url": "$URL",
  "sha256": "$SHA",
  "size": $SIZE,
  "notes": "${2:-}"
}
EOF

echo "→ 팩 $(du -h update/quple.pck | cut -f1) / sha256 ${SHA:0:16}…"

git add project.godot update/quple.pck update/manifest.json
git commit -q -m "Publish content update $VERSION"
git push -u origin "$BRANCH"

echo
echo "✓ $VERSION 배포 완료. 폰에서 앱을 껐다 켜면 받아서 그 다음 실행에 적용된다."
