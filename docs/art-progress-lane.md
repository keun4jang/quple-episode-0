# 쿼카 군단 그림 작업 - 진행 기록 (2026-10-26)

대화 원본: `C:\Users\rmsdu\.claude\projects\C--Projects-quqle-episode-0-happy-game\69fa4ac5-9b86-4faf-8112-709dcdf60c84.jsonl`

## 환경 (사용자 윈도우 컴퓨터)
- 그래픽카드 RTX 3060 12GB · 파이썬 가상환경 `.sdenv` (torch cu124, diffusers, peft, scipy)
- 그림 모델: SDXL base + sdxl-vae-fp16-fix + pixel-art-xl LoRA + controlnet-openpose-sdxl (허깅페이스 캐시)
- Godot 4.3: `C:\Tools\godot43\Godot_v4.3-stable_win64_console.exe`
- 배포: `powershell -File tools\publish-update.ps1 0.1.X "메모"` (파일은 BOM 있는 UTF-8 이어야 한다)

## 도구 (`tools/art/`)
| 파일 | 하는 일 |
|---|---|
| `sdxl_art.py` | 그림 생성. `<id> --n N` · 배경은 `--init layout --strength 0.94 --lora 0.5` · `pose`·`sheet`·`frames` 는 동작 시험 |
| `make_layout.py` | 배경 밑그림 (길 자리 고정, 높이 18%~82%) |
| `import_lane_art.py` | `bg N 원본` → lane-bg-N.png (폭 360칸) · `unit/bug 이름 원본 폭` → 4x3 시트 · `sprite` |
| `poses.py` | OpenPose 막대 인형 6개 (사람 비율 - 2등신에 안 맞는다) |
| `animate_sheets.py` | (다른 세션) 한 장을 비틀어 걷기·공격 칸 - 0.1.254 에 들어감 |

## 끝난 것 (0.1.253 까지 배포)
- 배경 10구역 · 성 · 둥지 · 쿼카 8 · 동물 16 · 벌레 16 · 우두머리 10 - 전부 SDXL 그림
- 게임: `lane-bg-N` 이 있으면 화면에 2배로 깐다, 새 시트(`lane-unit-*`·`lane-bug-*`)는 픽셀 한 칸 = 2점

## 캐릭터 동작 (0.1.256) - 칸마다 새로 생성
- 한 장 비틀기(0.1.254)·부위별 재배치(0.1.255)는 사용자가 거부 - "움직임 하나하나 다시 생성"
- 방법: `sdxl_art.py regen 1 0.6 <char>=<서있는그림> ...` - ControlNet OpenPose(2등신 막대 인형, `poses.py`)
  + IP-Adapter(`h94/IP-Adapter` sdxl vit-h, 사용자 승인)로 모습 고정, LoRA 끔, seed 5556
- 자세 6장(stand·walk1·walk2·atk1·atk2·atk3) → `import_lane_art.py regen unit-<id>|bug-<id> <char>` 로 4x3 시트
- 50종 300장 완료 (`assets/source/lane/regen/`). 작은 장식(병아리 달걀 모자 등)이 빠지기도 한다

## 진화한 모습 24종 (0.1.257)
- `sdxl_art.py` 의 `EVOLVED` (이름은 `LaneData.EVOLVED_NAME`) → `CHARS["e_<char>"]` (새 차림을 앞에 - 77토큰 뒤는 잘린다)
- ① 서 있는 그림: `sdxl_art.py e_<char> --init regen/<char>_stand_0.png --strength 0.82 --seed 777 --tag EV_`
  (거북이만 0.75 · seed 902) ② `regen 1 0.6 e_<char>=EV_e_<char>_0.png` ③ `import_lane_art.py regen unit-<id>-2 e_<char>`
  (진화 시트는 기본 시트보다 15% 크게)

## 손본 것 (0.1.258)
- 몸 키 표 `import_lane_art.BODY_H` - 거대 72 · 마법 50 · 방패 50→52 · 거북 50 (옛 시트 키가 이름과 안 맞았다)
- 한 칸만 다시: `REGEN_SEED=8300 REGEN_POSES=atk3 sdxl_art.py regen 3 ...` → 고른 것을 `_0` 으로 복사
- 진화 병아리(꼬꼬 대장)·수달은 밑그림 없이 새로 그림 (`EVX_` 후보), 다람쥐는 다람쥐 생김새를 앞에 적어 다시
- 거대 쿼카 내려침 칸은 색만 서 있는 그림에 맞춤 (평균·표준편차)

## 아트 검토 (0.1.259)
- 폰트에 없던 ★ ✦ ▶ ✓ ● (25곳)가 폰에서 네모로 뜨고 있었다 → `tools/pixel/make-symbol-font.py` 로 다섯 기호만
  직접 그린 `assets/fonts/QuokkaSymbols.ttf` 를 테마 대체 폰트 맨 뒤에 붙임. `check-font-glyphs.py` 도 함께 읽는다
- 작은 벌레(칸 키 40 이하)는 3배로 그린다 (`LaneData.sheet_px`) - 2배로는 쿼카의 절반도 안 됐다. 판정은 그대로
- 뽑기 그림: 8.8배 → 380점 안에 드는 정수 배율 (`lane_gacha.SHOW_BIG`)
- 출전 카드: 초상 54→72 (2배 미만은 부드럽게), 이름 19, 쿨타임은 값 자리에 "0.9초", 진화 이름 줄임 고침
- 자동 켜짐 = 분홍 버튼, 역할 "범위" 색 호박→산호, 설정 창 버전 글자 진하게
- 진화 거대 쿼카(곰 같던 것)를 쿼카 생김새를 앞에 적어 다시 (`EVGI_e_q_giant_2`)

## 공격이 닿게, 글자가 안 겹치게 (0.1.260)
- 근접(사거리 230 이하, 쏘는 공격 빼고)은 노린 상대 바로 앞까지 대각선으로 덤벼든다 (`_lunge_vec`).
  전투가 휘두름 이벤트에 `to`(노린 uid)를 실어 준다 - 그림 전용, 판정과 무관. 맞는 그림은 닿는 때(0.07초 뒤)에
- 하늘로 솟는 빛기둥(`pillar`)은 전투에서 모두 뺐다. 번개·얼음 스킬, 독수리 공격은 쓴 친구에게서 벌레에게로 날아간다
- 떠오르는 글자는 먼저 뜬 글자와 겹치면 위로 비켜 선다 (`IdleFx.text`). 스킬 띠가 뜨면 머리 위 스킬 이름은 안 띄운다.
  스킬 띠는 높이 40% (가운데 띠 30% 와 겹쳤다)

## 남은 것
- 없음. `animate_sheets.py` 는 더 쓰지 않는다
