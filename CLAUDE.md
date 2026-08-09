# 쿼플 (Quople) — 작업 규칙

## 명칭 (고정)

- 게임 이름: **쿼플**
- 캐릭터: **쿼카 여행자** — 혼자 여행한다
- ~~퀴풀, 퀴카~~ 는 쓰지 않는다.
- ~~쿼카 커플 / 리더 / 파트너~~ 는 더 이상 쓰지 않는다.
  주제를 "혼자 떠나는 여행"으로 바꾸면서 접었다.
  여행지에서 만나는 이들은 **인연**이라 부른다 (붙박이 / 여행자).

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

`docs/redesign-journey.md` 참고. **이것이 현재 방향이다.**

탑다운 픽셀 여행 게임. 쿼카가 혼자 여행지를 걸어 다니며 하루를 보내고,
그곳에서 만난 인연들과 친해지고, 며칠 뒤 다음 여행지로 떠난다.
떠난 곳의 인연이 편지를 보내오거나 **다른 여행지에서 다시 만난다** —
이 재회가 이 게임의 심장이다.

- 대상: **전 연령 힐링**. 광고·인앱결제·개인정보 수집은 넣지 않는다
- 화면: 16px 타일 / 내부 480×270 / 두 손가락 확대·축소 (0.5 배율 스냅)
- 벌이 없다 — 체력·기절·시간제한·돈벌이 압박을 만들지 않는다

`docs/core-loop.md` 의 오프라인 진행(앱을 꺼도 여행이 진행됨)은 **접었다.**
앉아서 조작하는 게임이 되었기 때문이다.

### 지난 기획들 (보관, 되살리지 않음)

`redesign-simple` · `redesign-idle` · `redesign-quokka` · `redesign-kids` ·
`redesign-magic-english` · `design-hooked` — 전부 `redesign-journey.md` 가 대체한다.

## 실행 / 테스트

```bash
godot --path . res://tests/TestCoreLoop.tscn   # 코어 루프 테스트 31개
godot --path .                                 # 게임 실행
```

## 에셋 교체

스플래시 포스터는 **텍스트가 없는** 이미지여야 한다 (로고·문구는 코드로 렌더).
`assets/splash/splash-poster-no-text.png` 를 교체하거나
`python3 tools/splash/import-splash-art.py --file <파일>` 로 넣는다.
