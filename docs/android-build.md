# 안드로이드 APK 빌드

전부 무료 도구로 빌드한다. 실제로 빌드에 성공한 절차를 그대로 적는다.

## 결과물

| 파일 | 크기 | 용도 |
|---|---|---|
| `build/quple.apk` | 94 MB | 디버그. 폰에 바로 설치해 테스트 |
| `build/quple-release.apk` | 92 MB | 배포용 서명 |

- 패키지: `com.quple.episode0` / 앱 이름 **쿼플** / 버전 0.1.0
- 최소 안드로이드 5.0 (SDK 21), 타겟 SDK 34
- 지원: **arm64-v8a** (요즘 폰 전부) + x86_64 (에뮬레이터)
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

## Godot 에디터 설정

`~/.config/godot/editor_settings-4.3.tres` 에 SDK 경로를 알려줘야 한다.
이게 없으면 "Android SDK path not set" 으로 실패한다.

```
export/android/android_sdk_path = "/root/Android/sdk"
export/android/debug_keystore = "/root/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
```

## 빌드

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

현재 값 — alias `quple`, 비밀번호 `quple2026`. **실제 출시 전에 반드시 바꿀 것.**

## 빌드 설정 메모

- `exclude_filter="tests/*"` — 테스트 스크립트는 APK 에 안 들어간다
- `screen/immersive_mode=true` — 전체화면 (상단바 숨김)
- `architectures/armeabi-v7a=false` — 32비트 구형 기기 제외해 용량을 줄였다
