# 스플래시 통합 노트 (Godot 4)

## 스택
Godot 4 (GDScript). 웹/RN/Flutter 아님 → UI 텍스트/버튼/프레임/로고는 GDScript + Control 노드로 렌더.

## 에셋 로딩
`.import` 없이 런타임 PNG 로드:
```gdscript
var abs = ProjectSettings.globalize_path("res://assets/splash/splash-poster-no-text.png")
var img = Image.load_from_file(abs)
var tex = ImageTexture.create_from_image(img)
```
`main_menu_3d.gd`:
- `_inject_poster_background()` — 포스터 배경
- `_inject_mascot_couple()` — 3D 캐릭터 + halo glow + contact shadow (`_make_radial_glow`)

## 구현 UI 레이어
프레임(Panel 3겹), 로고(Label 7겹), 서브타이틀/카피(Label), 버튼(Button+StyleBoxFlat), 반짝임(Label).

## 유지된 버튼 기능
- 새 여행 시작 → `_on_start()` (Episode0State 초기화 + SceneTransition)
- 이어하기 → `_on_continue()` (SaveManager)
- 설정 → settings_ui.open()
- 종료 → get_tree().quit()

## 스크린샷 검증
```bash
QUPLE_SHOT=/tmp/shot.png xvfb-run godot --path <project> --rendering-driver opengl3 --resolution 1080x1920
```
`main_menu_3d.gd`의 `_capture_shot()`가 QUPLE_SHOT 환경변수 있을 때만 동작(프로덕션 무영향).

## 생성/검수/최적화
```bash
python3 tools/splash/generate-splash-assets.py   # 포스터 생성
python3 tools/splash/check-splash-assets.py       # 검수
python3 tools/splash/optimize-splash-assets.py    # WebP/리사이즈
```

## 추후 실제 일러스트 교체 시
`splash-poster-no-text.png`만 동일 경로/치수(1080x1920)로 교체하면 즉시 반영.
캐릭터는 `quica-couple-splash.png` 교체.
