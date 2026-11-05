# 쿼카 군단 - 이어서 하기

"쿼카 시작" 이라고 하면 새 대화가 이 파일부터 읽는다. 일이 끝날 때마다 맨 아래 **현재 상태** 를 고친다.

## 시작할 때

1. `cd /c/Projects/quqle-episode-0/happy-game` 그리고 `git status`, `git log --oneline -5`
2. 이 파일, `CLAUDE.md`, `docs/redesign-lane.md`(쿼카 군단 설계·바꾼 이력)를 읽는다
3. 아래 **현재 상태** 를 사용자에게 2~3줄로 알려 주고, 이어서 할지 새 일을 할지 묻는다

## 늘 지키는 것

- 답은 한국어로 한다
- 게임 코드는 `scripts/lane/`에 있다. Godot 4.3: `C:\Tools\godot43\`
- 테스트: `Godot_v4.3-stable_win64_console.exe --headless --path . res://tests/TestLane.tscn`
- 글자 검사: `.sdenv/Scripts/python.exe tools/pixel/check-font-glyphs.py`
- 화면 찍기: **무음이고 화면 밖**에서 실행한다 (사용자가 일하는 중이다)
  - `Start-Process -FilePath C:\Tools\godot43\Godot_v4.3-stable_win64.exe -ArgumentList '--path','.','--audio-driver','Dummy','--resolution','720x1560','--position','-6000,-6000','res://tools/sim/ShotLane.tscn'`
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

## 현재 상태 (2026-11-05, 0.1.279)

- 최근에 바꾼 것:
  - 1장 100판을 약 1시간에 깨도록 맞췄다 (`LaneData.PACE` 3, `NEST_MULT` 0.6, `CH1_BUG` 0.5)
  - 후퇴 단추를 없앴다
  - 결과창을 짧게 했다
  - 배속 표시를 "1x / 3x / 20x"로 바꿨다
  - 스킬 이름 띠를 가운데 정렬했다
- 글자 다듬기 (0.1.279):
  - Jua에서 밭과 발이 같아 보여서 구역 이름을 바꿨다 (풀밭 → 초원, 꽃밭 → 꽃동산)
  - 테두리 두께는 `IdleUi.outline_for(fs)` 한 곳에서 정한다
- 나중에 할 일:
  - 20x 배속은 시험용이다. 내놓기 전에 빼고 1x·3x만 남긴다
  - 자동 소환은 사용자가 나중에 없앨 예정이다 (`docs/redesign-lane.md` 끝의 계획)
  - 미룬 기능: 끝없는 길, 업적·칭호, 주말 우두머리 잔치, 3장
  - 받침이 또렷한 무료 폰트로 바꿀지는 아직 정하지 않았다. 새로 내려받아야 하니 사용자 승인이 먼저다
