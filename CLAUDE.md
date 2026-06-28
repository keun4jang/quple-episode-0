# 쿼플 0편: 퇴근 말고 출발 — 프로젝트 가이드

## 게임 소개
귀여운 쿼카 커플의 힐링 여행 게임. 늦은 밤 야근 중인 파트너를 구출해 함께 여행을 떠나는 스토리.
모바일 세로(1080×1920) 게임. 가상 조이스틱으로 조작.

## 핵심 제작 원칙 (반드시 지킬 것)
- **무료 제작만 가능** — 유료 에셋 절대 금지
- **Godot 기본 노드만 사용** — BoxMesh, SphereMesh, CapsuleMesh, StandardMaterial3D, Light3D 등
- **외부 이미지/모델/폰트/사운드 금지**
- **2D 방식 사용 금지** — 3D 전용
- **WASD 금지** — 화살표 키 + 가상 조이스틱
- **실존 브랜드 금지** — "쿼카전자" / "QUOKKA CORP" 만 사용
- **모든 답변은 한국어** — 파일명·변수명은 영어 유지

## 개발 환경
- Godot 4.6.3 (Forward Plus)
- 뷰포트: 1080×1920 (세로)
- GitHub: keun4jang/quple-episode-0
- 작업 브랜치: main

## 파일 구조
```
scenes/
  maps/         CompanyFront3D, CompanyLobby3D, Office3D, BossDoorHallway3D
  characters/   PlayerQuokka3D, PartnerQuokka3D
  ui/           DialogueBox, ChoiceBox, AlbumUI, WindNoteUI, ClearScreen, VirtualJoystick, KeyGuideUI
  systems/      SceneTransition
scripts/
  maps/         각 씬 스크립트 (_build_scene()으로 절차적 생성)
  characters/   player_quokka_3d.gd, partner_quokka_3d.gd
  ui/           각 UI 스크립트
  systems/      episode0_state.gd, save_manager.gd, scene_transition.gd,
                interactable_3d.gd, photo_system.gd, audio_manager.gd
```

## AutoLoad 싱글톤
- `Episode0State` — 13단계 스토리 상태머신
- `SaveManager` — ConfigFile 저장/불러오기
- `SceneTransition` — 페이드 전환 (go_to(path, style))
- `AudioManager` — 오디오 인터페이스 (파일 없음, 인터페이스만 완성)

## 스토리 흐름 (Episode0State.State)
```
START → ENTER_COMPANY → FIND_PARTNER → TALK_PARTNER → CHOICE_WAIT
→ EAVESDROP_BOSS → RETURN_TO_PARTNER → COLLECT_TRAVEL_ITEMS
→ RETURN_BADGE → PARTNER_JOINED → FIRST_PHOTO → ALBUM_CREATED → CLEAR
```

## 캐릭터 구조
- **PlayerQuokka3D**: CharacterBody3D, 화살표+조이스틱 이동, 절차적 걷기/idle 애니메이션
- **PartnerQuokka3D**: Node3D, 플레이어 팔로우, set_emotion("happy"/"nervous"/"excited") 지원
- 모든 메시는 `_build_meshes()`에서 SphereMesh/CapsuleMesh/BoxMesh로 생성
- 쿼카 색상: body=#B8784F, belly=#F3D5AD, eyes 3레이어(흰자+동공+하이라이트), 꼬리 있음

## UI 시스템
- **DialogueBox**: 타자기 효과, Space로 스킵
- **ChoiceBox**: 화살표키 선택, 금색 하이라이트
- **AlbumUI**: B키, 다중 사진 페이지(←→)
- **WindNoteUI**: D키, 현재 목표 표시
- **VirtualJoystick**: 왼쪽 하단 조이스틱 + 오른쪽 하단 상호작용 버튼(✦)
- **ClearScreen**: 클리어 화면, Space/Esc로 종료

## 씬 전환 스타일
```gdscript
SceneTransition.go_to("res://scenes/maps/씬이름.tscn", "hopeful")  # 흰빛
SceneTransition.go_to("res://scenes/maps/씬이름.tscn", "tense")    # 붉은빛
SceneTransition.go_to("res://scenes/maps/씬이름.tscn", "normal")   # 검정
```

## 카메라 설정 (세로 모드 최적화)
- CompanyFront3D: CAM_OFFSET = Vector3(0, 13, 9)
- Office3D: CAM_OFFSET = Vector3(0, 9, 6)
- CompanyLobby3D: CAM_OFFSET = Vector3(0, 10, 6)
- BossDoorHallway3D: CAM_OFFSET = Vector3(0, 8, 5)
- 모든 실내 씬: 천장(Ceiling) 메시 없음 (카메라가 위에서 내려다봄)

## 조명 원칙
- CompanyFront3D: 밤 외부, 달 + 가로등(SpotLight3D), 새벽 조명 연출
- Office3D: 파트너 책상 OmniLight + 천장 형광등 3개
- BossDoorHallway3D: 붉은 긴장 조명 + 문 아래 빛샘
- 모든 씬: WorldEnvironment에 glow_enabled + ssao_enabled

## 인터랙터블 시스템
interactable_3d.gd (Area3D 기반):
- `interact_text`: 힌트 텍스트
- `target_scene_path`: 씬 이동
- `item_id`: "camera" / "notebook" / "travel_bag" / "badge"
- 금색 구체 힌트가 위에서 bobbing

## 현재 진행 상황
- ✅ 4개 맵 씬 완성 (CompanyFront, Lobby, Office, BossDoorHallway)
- ✅ 캐릭터 완성 (눈 3레이어, 꼬리, 감정 시스템)
- ✅ UI 완성 (타자기, 앨범, 선택지)
- ✅ 모바일 세로 변환 (가상 조이스틱)
- ✅ Glow + SSAO 그래픽
- 🔧 오디오 미구현 (AudioManager 인터페이스만 있음)
- 🔧 메뉴 씬 미연결

## 다음 작업 후보
- BGM/SFX 추가 (Godot AudioStreamGenerator로 절차적 생성)
- 메인 메뉴 씬 추가
- 숨겨진 메모 시스템
- 손잡기 메카닉
- Android 빌드 설정
