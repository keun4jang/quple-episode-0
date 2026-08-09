#!/usr/bin/env bash
# 쿼플 안드로이드 APK 빌드 — 전부 무료 도구.
#
#   tools/build-android.sh            # 디버그 + 릴리스 둘 다
#   tools/build-android.sh debug      # 디버그만
#   tools/build-android.sh release    # 릴리스만
#
# 준비물 설치는 docs/android-build.md 참고.
#
# 키스토어는 환경변수로 덮어쓸 수 있다:
#   QUPLE_KEYSTORE / QUPLE_KEYSTORE_USER / QUPLE_KEYSTORE_PASS
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)

GODOT=${GODOT:-godot}
ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/sdk}
export ANDROID_HOME

KEYSTORE=${QUPLE_KEYSTORE:-$HOME/.android/quple-release.keystore}
KEYSTORE_USER=${QUPLE_KEYSTORE_USER:-quple}
KEYSTORE_PASS=${QUPLE_KEYSTORE_PASS:-quple2026}   # 개발용 임시값. 출시 키는 환경변수로 넘겨라.

TARGET=${1:-all}

# APK 버전을 project.godot 에 맞춘다.
#
# 여기가 손으로 적은 값(0.1.0 / code 1)에 굳어 있었다. project.godot 이
# 0.1.47 인데 폰에 깔린 APK 는 0.1.0 이었고, versionCode 가 1 에 멈춰
# 있으면 스토어 업로드가 막히고 같은 코드끼리 덮어 깔 때 기기가 거부한다.
# 팩 갱신과 달리 이건 APK 를 새로 내야 고쳐지므로, 빌드할 때마다 맞춘다.
#
# code 는 X.Y.Z 를 자릿수로 눌러 담는다 (0.1.47 → 147). 늘 커진다.
VER=$(grep -oP 'config/version="\K[^"]+' project.godot)
IFS=. read -r VMA VMI VPA <<<"$VER"
VCODE=$(( VMA * 10000 + VMI * 100 + VPA ))
echo "→ APK 버전 $VER (code $VCODE)"
sed -i -E "s|^version/code=.*|version/code=$VCODE|; s|^version/name=.*|version/name=\"$VER\"|" \
	export_presets.cfg

die() { echo "✗ $*" >&2; exit 1; }

# --- 사전 점검 -------------------------------------------------------------
command -v "$GODOT" >/dev/null || die "godot 을 찾을 수 없다. GODOT=/경로/godot 로 지정해라."

TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
[ -d "$TPL_DIR" ] || die "export template 이 없다 ($TPL_DIR). docs/android-build.md 의 설치 절차를 먼저 해라."

[ -d "$ANDROID_HOME" ] || die "Android SDK 가 없다 ($ANDROID_HOME). docs/android-build.md 참고."

if [ "$TARGET" != "debug" ]; then
	[ -f "$KEYSTORE" ] || die "릴리스 키스토어가 없다 ($KEYSTORE). QUPLE_KEYSTORE 로 지정하거나 debug 만 빌드해라."
fi

# --- 제외 에셋 검사 --------------------------------------------------------
# exclude_filter 가 게임이 실제로 쓰는 에셋을 빼 버리면
# 에디터에서는 멀쩡하고 APK 에서만 깨진다. 빌드 전에 잡는다.
python3 tools/check-export-assets.py || die "제외 필터가 필요한 에셋을 빼고 있다."

# --- export_presets.cfg 생성 ----------------------------------------------
# 비밀번호가 들어가는 파일이라 저장소에 없다. 템플릿에서 만들어 낸다.
if [ ! -f export_presets.cfg ]; then
	echo "→ 템플릿에서 export_presets.cfg 생성"
	sed -e '/^;/d' \
	    -e "s|__KEYSTORE__|$KEYSTORE|" \
	    -e "s|__KEYSTORE_USER__|$KEYSTORE_USER|" \
	    -e "s|__KEYSTORE_PASS__|$KEYSTORE_PASS|" \
	    export_presets.template.cfg > export_presets.cfg
fi

# --- 에디터 설정 (SDK 경로) -----------------------------------------------
# 이게 없으면 "Android SDK path not set" 으로 실패한다.
ES="$HOME/.config/godot/editor_settings-4.3.tres"
if [ ! -f "$ES" ]; then
	echo "→ 에디터 설정 생성 ($ES)"
	mkdir -p "$(dirname "$ES")"
	JAVA_HOME_GUESS=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}
	cat > "$ES" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/debug_keystore = "$HOME/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/java_sdk_path = "$JAVA_HOME_GUESS"
EOF
fi

# 디버그 키스토어가 없으면 만든다 (디버그 빌드에 필요).
if [ ! -f "$HOME/.android/debug.keystore" ]; then
	echo "→ 디버그 키스토어 생성"
	mkdir -p "$HOME/.android"
	keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
		-keystore "$HOME/.android/debug.keystore" -storepass android \
		-dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
fi

mkdir -p build

# --- 빌드 ------------------------------------------------------------------
# 프리셋이 둘이다:
#   "Android"       — arm64-v8a + x86_64. 디버그용. x86_64 는 에뮬레이터 테스트에 필요.
#   "Android arm64" — arm64-v8a 만. 배포용. 실제 폰은 전부 arm64 라 x86_64 는 낭비다.
build_one() {
	local mode=$1 preset=$2 out=$3
	echo "→ $mode 빌드 ($preset) → $out"
	"$GODOT" --headless --path . "--export-$mode" "$preset" "$out"
	[ -f "$out" ] || die "$mode 빌드 실패 — $out 이 만들어지지 않았다."
	echo "✓ $out  ($(du -h "$out" | cut -f1))"
}

case "$TARGET" in
	debug)   build_one debug   "Android"       "$ROOT/build/quple.apk" ;;
	release) build_one release "Android arm64" "$ROOT/build/quple-release.apk" ;;
	all)     build_one debug   "Android"       "$ROOT/build/quple.apk"
	         build_one release "Android arm64" "$ROOT/build/quple-release.apk" ;;
	*)       die "알 수 없는 대상: $TARGET (debug | release | all)" ;;
esac

# --- 서명 검증 -------------------------------------------------------------
APKSIGNER=$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | head -1 || true)
if [ -n "$APKSIGNER" ]; then
	for f in build/quple.apk build/quple-release.apk; do
		[ -f "$f" ] || continue
		echo "→ 서명 검증: $f"
		"$APKSIGNER" verify --verbose "$f" | grep -E "^Verified using" || true
	done
fi

echo
echo "완료. 폰에 설치: adb install -r build/quple.apk"
