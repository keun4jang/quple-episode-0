# 안드로이드 APK 빌드

전부 무료 도구로 빌드한다. 실제로 빌드에 성공한 절차를 그대로 적는다.

## 결과물

| 파일 | 크기 | 용도 |
|---|---|---|
| `build/quple.apk` | 53 MB | 디버그. arm64 + x86_64(에뮬레이터) |
| `build/quple-release.apk` | **28 MB** | 배포용 서명. arm64 전용 |

- 패키지: `com.quple.episode0` / 앱 이름 **쿼플** / 버전 0.1.0
- 최소 안드로이드 5.0 (SDK 21), 타겟 SDK 34
- 지원: **arm64-v8a** (요즘 폰 전부). 디버그 빌드에만 x86_64(에뮬레이터) 추가
- 서명: v1 · v2 · v3 전부 검증 통과

## 필요한 것 (전부 무료)

| 도구 | 버전 | 용량 |
|---|---|---|
| JDK | 21 | (이미 설치됨) |
| Godot export templates | 4.3.stable | 1.0 GB |
| Android command-line tools | 11076708 | 146 MB |
| build-tools / platform-34 / platform-tools | 34.0.0 | 약 500 MB |

## 설치

```bash
# 1) Export templates
curl -L -o /tmp/t.tpz \
  https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.3.stable
cd /tmp && unzip -q t.tpz && mv templates/* ~/.local/share/godot/export_templates/4.3.stable/

# 2) Android SDK
curl -L -o /tmp/cmd.zip \
  https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
mkdir -p ~/Android/sdk/cmdline-tools && cd ~/Android/sdk/cmdline-tools
unzip -q /tmp/cmd.zip && mv cmdline-tools latest
export ANDROID_HOME=$HOME/Android/sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
yes | sdkmanager --licenses
sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"

# 3) 서명 키
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
  -keystore ~/.android/debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

## 빌드 (권장)

```bash
tools/build-android.sh            # 디버그 + 릴리스
tools/build-android.sh debug      # 디버그만
tools/build-android.sh release    # 릴리스만
```

스크립트가 알아서 해 주는 것:

- `export_presets.cfg` 생성 (`export_presets.template.cfg` 에서 — 비밀번호가 들어가는 파일이라 저장소에 없다)
- 에디터 설정(`editor_settings-4.3.tres`)에 Android SDK 경로 기록
- 디버그 키스토어가 없으면 생성
- 빌드 후 `apksigner verify` 로 서명 검증

환경변수로 덮어쓸 수 있다:

| 변수 | 기본값 |
|---|---|
| `GODOT` | `godot` (PATH 에 없으면 반드시 지정) |
| `ANDROID_HOME` | `~/Android/sdk` |
| `QUPLE_KEYSTORE` | `~/.android/quple-release.keystore` |
| `QUPLE_KEYSTORE_USER` | `quple` |
| `QUPLE_KEYSTORE_PASS` | 개발용 임시값 (출시 키는 반드시 이 변수로 넘긴다) |

릴리스 키스토어가 없으면 `debug` 만 빌드하면 된다. 폰 테스트에는 디버그 APK 로 충분하다.

## Godot 에디터 설정 (스크립트를 안 쓸 때)

`~/.config/godot/editor_settings-4.3.tres` 에 SDK 경로를 알려줘야 한다.
이게 없으면 "Android SDK path not set" 으로 실패한다.

```
export/android/android_sdk_path = "/root/Android/sdk"
export/android/debug_keystore = "/root/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
```

## 빌드 (스크립트를 안 쓸 때)

```bash
export ANDROID_HOME=$HOME/Android/sdk
godot --headless --path . --export-debug   "Android" build/quple.apk
godot --headless --path . --export-release "Android" build/quple-release.apk
```

## 폰에 설치

```bash
adb install -r build/quple.apk        # USB 디버깅 켠 폰 연결 후
```
또는 APK 파일을 폰으로 옮겨 직접 실행 (알 수 없는 앱 설치 허용 필요).

## ⚠️ 릴리스 키스토어 보관

`~/.android/quple-release.keystore` 는 **한 번 잃어버리면 같은 앱을 업데이트할 수 없다.**
스토어에 올린 앱은 항상 같은 키로 서명해야 하기 때문이다.

- 별도 백업 필수 (이 컨테이너는 없어진다)
- 비밀번호도 함께 보관
- 저장소에 커밋하지 말 것 (`.gitignore` 에 이미 제외)

이 저장소는 공개다. 키스토어 비밀번호를 문서·코드·커밋 메시지 어디에도 적지 말 것.

개발용 임시 키스토어는 `tools/build-android.sh` 의 기본값을 쓰고 있다.
실제 출시용 키는 새로 만들어 환경변수로 넘긴다:

```bash
keytool -genkeypair -v -keystore ~/.android/quple-release.keystore \
  -alias <별칭> -keyalg RSA -keysize 2048 -validity 10000

QUPLE_KEYSTORE=~/.android/quple-release.keystore \
QUPLE_KEYSTORE_USER=<별칭> \
QUPLE_KEYSTORE_PASS=<비밀번호> \
  tools/build-android.sh release
```

## 빌드 설정 메모

### APK 용량

처음엔 95 MB 였다. 게임이 실제로 로드하는 에셋은 5 개(7 MB)뿐인데
Blender 렌더 원본, 스플래시 후보안, GLB, 미사용 마스코트 PNG 등 54 MB 가
전부 따라 들어가고 있었다. `exclude_filter` 로 빼서 **51 MB / 49 MB** 가 됐다.

파일은 저장소에 그대로 있다 — APK 에만 안 들어간다. IP 원본이라 지우지 않았다.

게임이 실제로 쓰는 것:

| 파일 | 쓰는 곳 |
|---|---|
| `assets/splash/splash-poster-no-text.png` | `main_menu_3d.gd`, `travel_hub.gd` |
| `assets/mascots/quica-hero-diorama.png` | `main_menu_3d.gd` |
| `assets/fonts/Jua.ttf` | `quple_bold.tres` |
| `assets/themes/quple_bold.tres` | `project.godot` |
| `assets/icon/icon-512.png` | `project.godot` |

나중에 제외된 에셋을 쓰기 시작하면 **에디터에서는 멀쩡하고 APK 에서만 깨진다.**
`tools/check-export-assets.py` 가 그걸 잡는다 (빌드 스크립트가 자동 실행).

남은 용량은 거의 전부 Godot 엔진 네이티브 라이브러리다. 그래서 프리셋을 둘로 나눴다.

| 프리셋 | 아키텍처 | 쓰는 곳 | 크기 |
|---|---|---|---|
| `Android` | arm64-v8a + x86_64 | 디버그 | 53 MB |
| `Android arm64` | arm64-v8a | 릴리스 | **28 MB** |

실제 안드로이드 폰은 사실상 전부 arm64 라 배포본에 x86_64 를 넣을 이유가 없다.
에뮬레이터 테스트는 디버그 빌드로 하면 된다.

### 기타

- `exclude_filter="tests/*"` — 테스트 스크립트는 APK 에 안 들어간다
- `screen/immersive_mode=true` — 전체화면 (상단바 숨김)
- `architectures/armeabi-v7a=false` — 32비트 구형 기기 제외해 용량을 줄였다
