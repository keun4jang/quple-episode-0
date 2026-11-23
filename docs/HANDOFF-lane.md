# 쿼카 군단 - 이어서 하기

"쿼카 시작" 이라고 하면 새 대화가 이 파일부터 읽는다. 일이 끝날 때마다 맨 아래 **현재 상태** 를 고친다.

## 시작할 때

1. `cd /c/Projects/quqle-episode-0/happy-game` 그리고 `git status`, `git log --oneline -5`
2. 이 파일, `CLAUDE.md`, **`docs/lane-principles.md`(판단 기준 - 왜)**, `docs/redesign-lane.md`(설계·바꾼 이력 - 무엇)를 읽는다
3. 아래 **현재 상태** 를 사용자에게 2~3줄로 알려 주고, 이어서 할지 새 일을 할지 묻는다

## 늘 지키는 것

- 답은 한국어로 한다
- 게임 코드는 `scripts/lane/`에 있다. Godot 4.3: `C:\Tools\godot43\`
- 테스트: `Godot_v4.3-stable_win64_console.exe --headless --path . res://tests/TestLane.tscn`
- 글자 검사: `.sdenv/Scripts/python.exe tools/pixel/check-font-glyphs.py` 와 `check-font-sizes.py`(글 크기 단계, 기준선 래칫)
- 고치기 전에 `docs/lane-principles.md` 의 세 질문을 거친다. 같은 문제가 두 번 나오면 검사 도구를 하나 더한다
- 화면 찍기: **무음이고 화면 밖**에서 실행한다 (사용자가 일하는 중이다)
  - `Start-Process -FilePath C:\Tools\godot43\Godot_v4.3-stable_win64.exe -ArgumentList '--path','.','--audio-driver','Dummy','--resolution','1560x720','--position','-6000,-6000','res://tools/sim/ShotLane.tscn'`
  - **가로 해상도로 찍는다** (1560x720 폰 · 1280x720 PC). 세로 해상도를 주면 `_go_landscape` 가 창을 가로로 바꿔 화면 가운데로 옮긴다
  - 환경 변수 `SHOT_MODE`·`SHOT_OUT` 등으로 고른다. 모드 목록은 `tools/sim/shot_lane.gd` 2번 줄에 있다
- 밸런스 시뮬레이션: `tools/sim/SimLane.tscn`. 판 빠르기·둥지·벌레는 `SIM_PACE`·`SIM_NEST`·`SIM_BUG`로 조절한다
- 커밋 메시지는 Bash로 파일에 쓰고 `git commit -F`로 넘긴다
- 배포: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\publish-update.ps1 0.1.X "메모"`. 폰에서는 앱을 껐다 켜면 받는다
- 지키는 규칙:
  - 배틀캣 이름·그림, 현금 결제, 광고는 넣지 않는다
  - 노랑·산호색은 UI에 쓰지 않는다
  - 폰트에 없는 글자는 쓰지 않는다
  - `assets/source/`는 커밋하지 않는다
  - 돈이 드는 일은 먼저 묻는다

## 현재 상태 (2026-11-23, 0.1.284)

- 0.1.284: **싸움 룰렛** - 사용자가 원한 건 뽑기 룰렛이 아니라 "싸움에서 룰렛이 나올 친구를 정하는 것"이었다
  - `LaneBattle.wheel_on`: 웃음이 `spin_cost`(편성 친구 값의 평균)만큼 모이면 저절로 돌고, `SPIN_TIME` 2.4 뒤 바늘이 선 친구가 나온다.
    친구 카드는 누르는 단추가 아니라 나올 확률(%)을 보여 준다. 사람은 수입·바주카포만 누른다
  - 수입 단추를 웃음이 모자랄 때 누르면 `saving` - 룰렛이 쉬고 모은다 (안 그러면 룰렛이 웃음을 다 써 수입을 못 올린다). 자동도 같은 규칙
  - 칸 넓히기(친구 탭, 만난 친구만, 기본 쿼카 포함): 칸 무게 1 + 0.5 x 단계, 비용 기본 500 · 희귀 800 · 특급 1500 · 전설 3000 x (단계+1)
  - 뽑기는 **캡슐로 되돌렸다** (확률도 원래대로 - 못 만난 친구 1.5배). `LaneGacha` 의 룰렛 연출 갈래는 안 쓴다
  - SimLane 1장 100판: 룰렛 1.1시간 · 진 판 0 (옛 방식 1.0시간 · 0). `SIM_WHEEL=0` 으로 옛 방식과 견준다. TestLane 245
  - 처음 안내: 룰렛 → "칸이 넓을수록 잘 나와요" → 수입 → 바주카포 → 자동(수입·바주카포)

- 0.1.283 (2026-11-18): **앱 전체 가로 화면** + 행운 룰렛 뽑기(0.1.284 에서 싸움 룰렛으로 옮김)
  - 가로: `SceneTransition._go_landscape` (1280x720 기준, 폰은 SENSOR_LANDSCAPE - 깔린 APK 도 팩으로 바뀐다).
    project.godot 도 1280x720 · orientation 4. 화면마다 `_wide()` 갈래: 홈은 왼쪽 무대(제목·친구·출전) + 오른쪽 카드·탭,
    싸움은 **가로 길**(왼쪽 성 → 오른쪽 둥지, `LaneField.horizontal`, 뒤 풍경은 IdleBackdrop) + 낮은 아래 판(친구 한 줄).
    세로 길 그림 `lane-bg-N.png` 은 가로에선 안 쓴다. 창(`_popup`)은 폭 980 가운데
  - 룰렛: `LaneWheel` (한 칸 = 친구 한 명, 칸 크기 = 확률). 친구 탭 '룰렛 칸 넓히기' 0~4단계 (행복 조각,
    무게 1 + 0.5 x 단계, **같은 등급 안에서만** - 등급 확률 72·24·4 그대로). 못 만난 친구도 넓힐 수 있다. TestLane 240
  - 폰에서 아직 못 본 것: 방향 전환, 노치 쪽 여백(`_side_insets`), 처음 안내(손가락·말풍선) 자리

- 0.1.282: **저장 코드** - 설정 창 "저장 코드 복사 / 붙여넣기" (`LaneState.export_code` · `import_code`, 서버 없음).
  붙여넣기는 두 번 눌러야 하고 바꾸기 전 저장을 `lane_backup.cfg` 에 남긴다. TestLane 229.
  설정 창 찍기: `ShotSettings.tscn` + `SHOT_SCROLL=1`, `SHOT_HINT=code`. 19px → 18 크기 정리도 함께 나갔다
- 다음 추천: 손으로만 1장 10판 시험(사람이 한다, 가설 H1·H2) → SimLane 으로 2장 난이도 곡선

- 2026-11-16 (배포 전): 판단 기준 문서 `docs/lane-principles.md`, 글 크기 검사 `tools/pixel/check-font-sizes.py`
  (단계 18·22·28·34·44, 단계 밖 76곳이 기준선). 19px → 18, 21px → 22 로 합쳤다
- 2026-11-16: 리뷰 분석 · 프리모템 · 가설 `docs/lane-premortem.md`. 가장 큰 진짜 위험은 **저장이 폰 안에만 있어
  앱을 지우면 다 사라지는 것**. 다음 추천: 저장 코드 내보내기 · 불러오기 → 손으로만 10판 시험 → 2장 난이도 곡선

- 최근에 바꾼 것:
  - 1장 100판을 약 1시간에 깨도록 맞췄다 (`LaneData.PACE` 3, `NEST_MULT` 0.6, `CH1_BUG` 0.5)
  - 후퇴 단추를 없앴다
  - 결과창을 짧게 했다
  - 배속 표시를 "1x / 3x / 20x"로 바꿨다
  - 스킬 이름 띠를 가운데 정렬했다
- 글자 다듬기 (0.1.279):
  - Jua에서 밭과 발이 같아 보여서 구역 이름을 바꿨다 (풀밭 → 초원, 꽃밭 → 꽃동산)
  - 테두리 두께는 `IdleUi.outline_for(fs)` 한 곳에서 정한다
- 0.1.280: 폰이 옛 APK 테마(PoorStory)를 쓰던 문제 - 첫 화면에서 `IdleUi.refresh_project_theme()` 로 팩 테마를 다시 읽는다
- 0.1.281 (아트 검토): `·` `…` `×` 를 QuokkaSymbols 에 좁게 넣었다 (Jua 에 없어 PoorStory 로 새며 자간이 벌어졌다),
  위험 버튼은 흰 바탕+빨간 테두리, 닫기·그만두기는 ghost, 메뉴 아이콘 색·진행 줄 대비, 확인창 간격, 로고 기울기 뺌,
  모자란 버튼은 흐리지 않고 회보라 바탕. **티켓 모두 뽑기** (`LaneState.pull_tickets`, 10장 넘으면 가장 좋은 하나만 열고 친구별로 묶어 보여 줌)
- 아트 검토에서 남은 것: 전투 아래 판 글자 크기 18/22/28 로 줄이기, 아래 탭 바탕 `#7E52B0`, 잠긴 판 번호 SUB,
  편성 칸 분홍 덩어리 → 흰 카드+테두리, 창 제목·닫기 버튼 통일, 지도 탭 아래 빈 공간
- 나중에 할 일:
  - 20x 배속은 시험용이다. 내놓기 전에 빼고 1x·3x만 남긴다
  - 자동 소환은 사용자가 나중에 없앨 예정이다 (`docs/redesign-lane.md` 끝의 계획)
  - 미룬 기능: 끝없는 길, 업적·칭호, 주말 우두머리 잔치, 3장
  - 받침이 또렷한 무료 폰트로 바꿀지는 아직 정하지 않았다. 새로 내려받아야 하니 사용자 승인이 먼저다
