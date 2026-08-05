# 모바일 터치 조작

`scenes/ui/TouchControls.tscn` · `scripts/ui/touch_controls.gd`

## 원칙 — 게임 코드를 고치지 않는다

터치를 **기존 입력 액션으로 변환**해서 넣는다. 그래서 키보드로 만든 모든 로직이
한 줄도 안 고치고 그대로 동작한다.

```gdscript
Input.action_press("move_right", 0.62)   # 아날로그 세기까지 전달
```

## 조작

| 위치 | 조작 |
|---|---|
| 화면 왼쪽 절반 | 가상 조이스틱. **손가락을 대는 곳이 중심**이 된다 |
| 오른쪽 위 | 조사(Space) · 사진(F) · 바람 노트(D) · 앨범(B) |

- **아날로그** — 살살 밀면 천천히 걷는다 (세기 0~1)
- **데드존 16%** — 손 떨림으로 캐릭터가 흔들리지 않는다
- 손을 떼면 즉시 멈춘다
- 씬이 바뀔 때 눌린 입력이 남지 않게 `_exit_tree()` 에서 정리한다

## 언제 보이나

1. 모바일 OS (`OS.has_feature("mobile")`)
2. 터치스크린이 있는 기기 (`DisplayServer.is_touchscreen_available()`)
3. PC 라도 **실제로 화면을 터치하면** 그때 나타난다
4. 테스트: `QUPLE_TOUCH=1 godot --path .`

터치 조작이 보이면 **키 안내(오른쪽 아래)는 자동으로 숨는다.** 모바일엔 키보드가 없다.

## 붙어 있는 화면

이동이 필요한 3D 씬 5개 — 회사 앞 · 로비 · 사무실 · 대표실 복도 · 기념품 방.
여행 허브·통계·앨범은 원래 버튼 UI라 터치가 그냥 된다.

## 프로젝트 설정

```
window/handheld/orientation=6          # sensor_landscape
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
input_devices/pointing/emulate_touch_from_mouse=false
```

마우스를 터치로 흉내내는 옵션은 **꺼야 한다.** 켜두면 PC 에서 마우스 클릭이
조이스틱을 잡아버린다.

## 검증

`tests/TestTouch.tscn` — 17개. 조이스틱→액션 변환, 아날로그 세기,
데드존, 손 뗐을 때 정지, 버튼→키, 씬 전환 시 입력 누수까지 확인한다.
