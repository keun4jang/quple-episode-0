#!/usr/bin/env bash
# PC 버전(윈도우 · 맥)을 만든다.  →  build/desktop/진짜행복-윈도우-<버전>.zip · 진짜행복-맥-<버전>.zip
#
#   GODOT=/path/to/Godot_v4.3-stable bash tools/build-desktop.sh
#
# 필요한 것: Godot 4.3 내보내기 템플릿 중 windows_release_x86_64.exe 와 macos.zip
# (~/.local/share/godot/export_templates/4.3.stable/). 없으면 받는 법을 알려 주고 멈춘다.
#
# 맥 앱은 애플 개발자 인증 없이 **임시 서명(ad-hoc)** 만 한다. 처음 열 때 "확인되지 않은
# 개발자" 경고가 뜬다 - 여는 법은 build/desktop/맥에서-여는-법.txt 에 같이 넣는다.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
VER=$(grep -m1 '^config/version=' project.godot | sed 's/.*="\(.*\)"/\1/')
TPL=${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.3.stable
for f in windows_release_x86_64.exe macos.zip; do
	if [ ! -f "$TPL/$f" ]; then
		echo "✗ 내보내기 템플릿이 없다: $TPL/$f" >&2
		echo "  https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz" >&2
		echo "  를 받아 templates/$f 를 $TPL/ 에 풀어 둘 것" >&2
		exit 1
	fi
done
# 내보내기 설정 - 안드로이드용이 템플릿에서 만들어지는 것과 같이, PC 것은 따로 붙인다.
[ -f export_presets.cfg ] || { echo "✗ export_presets.cfg 가 없다 - tools/build-android.sh 로 먼저 만들 것" >&2; exit 1; }
grep -q 'name="Windows"' export_presets.cfg || cat export_presets.desktop.cfg >> export_presets.cfg

OUT=build/desktop
rm -rf "$OUT"
mkdir -p "$OUT/windows" "$OUT/mac"
"$GODOT" --headless --path . --import --quit >/dev/null 2>&1 || true

echo "→ 윈도우"
"$GODOT" --headless --path . --export-release "Windows" "$PWD/$OUT/windows/JinjjaHaengbok.exe"
[ -s "$OUT/windows/JinjjaHaengbok.exe" ] || { echo "✗ 윈도우 exe 가 안 만들어졌다" >&2; exit 1; }
echo "→ 맥"
"$GODOT" --headless --path . --export-release "macOS" "$PWD/$OUT/mac/JinjjaHaengbok.zip"
[ -s "$OUT/mac/JinjjaHaengbok.zip" ] || { echo "✗ 맥 앱이 안 만들어졌다" >&2; exit 1; }

cat > "$OUT/맥에서-여는-법.txt" <<'TXT'
진짜 행복 - 맥에서 여는 법

1. 받은 zip 을 두 번 눌러 풀면 "진짜 행복" 앱이 나온다. 응용 프로그램 폴더로 옮겨도 된다.
2. 처음 한 번만: 앱을 **오른쪽 클릭(또는 control+클릭) → 열기 → 열기**.
   ("확인되지 않은 개발자" 경고 - 애플 개발자 인증을 안 받은 앱이라 뜬다.)
3. 그래도 "손상되었기 때문에 열 수 없습니다" 가 뜨면, 터미널에서 한 줄:
       xattr -cr "/Applications/진짜 행복.app"
   (앱을 다른 곳에 두었으면 그 경로로.) 그다음 다시 열면 된다.
4. 시스템 설정 → 개인정보 보호 및 보안 → 아래쪽 "그래도 열기" 로도 된다.

키보드: 화살표 이동 · Z 공격 · 1~7 스킬 · 스페이스 말 걸기 · 마우스 클릭으로 걷기
        I 배낭 · Q 할 일 · C 캐릭터 · M 지도 · H 하는 법 · F11 전체 화면 · Esc 닫기
저장: 자동 (30초마다·몬스터를 잡을 때·맵을 옮길 때·끌 때)
업데이트: 켤 때 새 내용을 저절로 받는다 (다음에 켤 때 적용)
TXT
cat > "$OUT/윈도우에서-여는-법.txt" <<'TXT'
진짜 행복 - 윈도우에서 여는 법

1. 받은 zip 을 풀면 JinjjaHaengbok.exe 하나가 나온다. 두 번 눌러 실행.
2. 처음 한 번 "Windows의 PC 보호" 파란 창이 뜨면: **추가 정보 → 실행**.
   (코드 서명 인증서를 안 산 게임이라 뜬다.)

키보드: 화살표 이동 · Z 공격 · 1~7 스킬 · 스페이스 말 걸기 · 마우스 클릭으로 걷기
        I 배낭 · Q 할 일 · C 캐릭터 · M 지도 · H 하는 법 · F11 전체 화면 · Esc 닫기
저장: 자동 · 업데이트: 켤 때 새 내용을 저절로 받는다 (다음에 켤 때 적용)
TXT
# 한글 파일 이름을 zip 에 UTF-8 로 넣으려고 파이썬을 쓴다 (zip 명령은 맥에서 이름이 깨졌다).
mv "$OUT/mac/JinjjaHaengbok.zip" "$OUT/진짜행복-맥-$VER.zip"
python3 - "$OUT" "$VER" <<'PY'
import sys, zipfile, os
out, ver = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(f"{out}/진짜행복-맥-{ver}.zip", "a") as z:
    z.write(f"{out}/맥에서-여는-법.txt", "맥에서-여는-법.txt")
with zipfile.ZipFile(f"{out}/진짜행복-윈도우-{ver}.zip", "w", zipfile.ZIP_DEFLATED) as z:
    z.write(f"{out}/windows/JinjjaHaengbok.exe", "JinjjaHaengbok.exe")
    z.write(f"{out}/윈도우에서-여는-법.txt", "윈도우에서-여는-법.txt")
PY
ls -la "$OUT"/*.zip
echo "✓ PC 버전 $VER"
