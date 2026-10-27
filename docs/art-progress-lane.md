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

## 남은 것
- 없음. `animate_sheets.py` 는 더 쓰지 않는다
