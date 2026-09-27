#!/usr/bin/env bash
# PC 버전을 GitHub 에 올린다 - 브랜치의 pc/ 폴더, 이름은 늘 같다(받는 링크가 안 바뀐다).
#
#   GODOT=/path/to/Godot_v4.3-stable bash tools/publish-desktop.sh
#
#   pc/JinjjaHaengbok-mac.zip       맥 (유니버설 - 인텔·애플 실리콘 둘 다)
#   pc/JinjjaHaengbok-windows.zip   윈도우 (64비트)
#   pc/README.md                    받는 링크 · 여는 법 · 버전
#
# 파일이 50MB 를 넘어 GitHub 가 경고를 하지만 100MB 아래라 올라간다. 버전마다 저장소가
# 불어나므로 **엔진이나 PC 쪽이 바뀔 때만** 올린다 - 게임 내용은 켤 때 갱신 팩으로 받는다.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
BRANCH=$(git rev-parse --abbrev-ref HEAD)
VER=$(grep -m1 '^config/version=' project.godot | sed 's/.*="\(.*\)"/\1/')
GODOT="$GODOT" bash tools/build-desktop.sh
mkdir -p pc
cp "build/desktop/진짜행복-맥-$VER.zip" pc/JinjjaHaengbok-mac.zip
cp "build/desktop/진짜행복-윈도우-$VER.zip" pc/JinjjaHaengbok-windows.zip
for f in pc/*.zip; do
	[ "$(stat -c %s "$f")" -lt 99000000 ] || { echo "✗ $f 가 100MB 에 가깝다 - GitHub 가 안 받는다" >&2; exit 1; }
done
BASE="https://github.com/keun4jang/quple-episode-0/raw/$BRANCH/pc"
cat > pc/README.md <<MD
# 진짜 행복 — PC 버전

지금 버전: **$VER** · 게임 내용은 켤 때 저절로 새것을 받는다 (다음에 켤 때 적용).
이 파일들은 엔진이나 PC 쪽이 바뀔 때만 새로 올린다.

| 받기 | |
|---|---|
| **맥** (인텔 · 애플 실리콘) | [JinjjaHaengbok-mac.zip]($BASE/JinjjaHaengbok-mac.zip) |
| **윈도우** (64비트) | [JinjjaHaengbok-windows.zip]($BASE/JinjjaHaengbok-windows.zip) |

## 맥에서 여는 법
1. 받은 zip 을 두 번 눌러 풀면 "진짜 행복" 앱이 나온다. 응용 프로그램 폴더로 옮겨도 된다.
2. 처음 한 번만: 앱을 **오른쪽 클릭(control+클릭) → 열기 → 열기** (애플 개발자 인증을 안 받은 앱이라 경고가 뜬다).
3. 그래도 "손상되었기 때문에 열 수 없습니다" 가 뜨면 터미널에서: \`xattr -cr "/Applications/진짜 행복.app"\` (앱이 있는 경로로)

## 윈도우에서 여는 법
1. zip 을 풀어 \`JinjjaHaengbok.exe\` 실행.
2. 처음 한 번 "Windows의 PC 보호" 가 뜨면 **추가 정보 → 실행**.

## 조작
화살표 이동 · 마우스 클릭으로 걷기 · Z 공격 · 1~7 스킬 · 스페이스 말 걸기 ·
I 배낭 · Q 할 일 · C 캐릭터 · M 지도 · H 하는 법 · F11 전체 화면 · Esc 닫기. 저장은 자동.
MD
git add pc/
git commit -q -m "PC 버전 $VER 올림 (pc/ - 맥 · 윈도우)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UQsgMEbgdW8Gttf4aniRwH"
for i in 1 2 3 4; do
	git push -u origin "$BRANCH" && break
	echo "… 다시 올린다 ($i)" >&2
	sleep $((2 ** i))
done
echo "✓ 올렸다: $BASE/JinjjaHaengbok-mac.zip"
echo "          $BASE/JinjjaHaengbok-windows.zip"
