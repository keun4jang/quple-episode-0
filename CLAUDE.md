# 쿼플 (Quople) — 작업 규칙

## 명칭 (고정)

- 게임 이름: **쿼플**
- 캐릭터: **쿼카 커플** (리더 / 파트너)
- ~~퀴풀, 퀴카~~ 는 쓰지 않는다.

## 폰트 (고정)

**폰트는 항상 굵은 것을 쓴다.**

전역 테마가 이미 적용돼 있으므로 새 UI를 만들 때 따로 신경 쓸 필요는 없다.

- 테마: `assets/themes/quple_bold.tres` (`project.godot` 의 `gui/theme/custom` 에 등록)
- 폰트: `assets/fonts/Jua.ttf` (둥근 한글, OFL) + `variation_embolden = 0.55`
- 더 굵게 필요하면: `assets/fonts/BlackHanSans.ttf` (OFL)

새 Label/Button 에 폰트를 개별 지정하지 말 것. 전역 테마를 덮어써서 굵기가 깨진다.
크기만 `theme_override_font_sizes/font_size` 로 조절한다.

## 비용 (중요)

**크레딧·요금이 드는 작업은 실행 전에 반드시 먼저 알리고 승인을 받는다.**

- 무료: Godot 개발, Blender(bpy) 렌더, PIL 이미지 처리, 로컬 렌더/테스트
- 유료: Higgsfield 이미지 생성(2크레딧/장), 3D 변환(20~38크레딧/개)
- 유료 API·에셋·폰트는 쓰지 않는다. AI 모델을 임의로 새로 내려받지 않는다.

## 코어 루프

`docs/core-loop.md` 참고.
앱을 끄면 쿼카 커플이 여행을 다녀오고, 켜면 사진과 일기를 확인하는 구조.
실제 시각(unix time) 기준이라 앱이 꺼져 있어도 진행된다.

## 실행 / 테스트

```bash
godot --path . res://tests/TestCoreLoop.tscn   # 코어 루프 테스트 31개
godot --path .                                 # 게임 실행
```

## 에셋 교체

스플래시 포스터는 **텍스트가 없는** 이미지여야 한다 (로고·문구는 코드로 렌더).
`assets/splash/splash-poster-no-text.png` 를 교체하거나
`python3 tools/splash/import-splash-art.py --file <파일>` 로 넣는다.
