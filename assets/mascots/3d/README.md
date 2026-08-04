# 쿼카 3D 모델

## quica-leader-rigged.glb

AI 생성 → 3D 변환된 **게임 즉시 사용 가능한** 리깅 캐릭터.

| 항목 | 값 |
|---|---|
| 포맷 | glTF 2.0 (GLB) — Godot / Unity / Unreal 바로 임포트 |
| 삼각형 | 37,694 |
| 본(뼈대) | 24개, 스킨 리깅 완료 |
| 애니메이션 | `Casual_Walk` (채널 72) |
| 텍스처 | baseColor + emissive |
| 파일 크기 | 6.1MB |

### 생성 방법 및 실측 비용

```
1) 캐릭터 레퍼런스 이미지 (A-포즈, 무배경)
   Higgsfield / nano_banana_pro, 2K, 1:1  →  2 크레딧
   결과: assets/splash/candidates/quokka_solo.png

2) 3D 변환 (Meshy image_to_3d)
   should_texture + enable_pbr + enable_rigging + enable_animation
   animation_action_id=30 (Casual_Walk), pose_mode=a-pose,
   target_polycount=20000, topology=quad, symmetry_mode=on
   →  38 크레딧

합계: 40 크레딧 / 캐릭터 1마리 (소요 약 8분)
```

### 애니메이션 추가 단가

같은 캐릭터에 다른 동작을 붙이려면 재변환이 필요하며 **38크레딧/동작**.
주요 클립 ID: idle `0` / 걷기 `30` / 달리기 `16` / 점프 `466` / 손흔들기 `28` / 춤 `64`
(전체 678종은 `animation_actions` 툴로 검색)

### Godot 런타임 로드

```gdscript
var doc := GLTFDocument.new()
var st := GLTFState.new()
doc.append_from_file(ProjectSettings.globalize_path("res://assets/mascots/3d/quica-leader-rigged.glb"), st)
add_child(doc.generate_scene(st))
```

### 주의

- 37,694 삼각형은 모바일 기준 다소 높음 → 배포 전 데시메이션 권장(1만 이하)
- 리깅은 **휴머노이드 스켈레톤** 기준이라 꼬리는 본이 없음(별도 처리 필요)
- 프로젝트 방향은 **2D 우선**. 이 GLB는 포인트 연출/검증용 레퍼런스
