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

## 남은 것
1. **캐릭터 동작 그림 - 서로 다른 그림 3장 이상** (사용자 요청: 한 장을 움직이지 말 것)
   - 시험 결과: 밑그림 위 자세 바꾸기 ✗ (자세 그대로) · 한 장 6칸 △ (가끔) · OpenPose ✗ (모습이 칸마다 바뀜)
   - 다음 시도: ① 2등신 비율 막대 인형 ② IP-Adapter 로 모습 고정 (새 모델 - 허락 받고) ③ 부위(머리·몸·팔·다리) 나눠 칸마다 다른 자세
2. 진화한 모습 24종 (지금은 옛 코드 그림)
3. 마법·거대 쿼카 발밑 흙 조금 남음
