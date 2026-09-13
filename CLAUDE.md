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

## AutoLoad 싱글톤 (project.godot 순서 중요)
- `Episode0State` — 13단계 스토리 상태머신
- `SaveManager` — ConfigFile 저장/불러오기 (스탯·퀘스트·처치기록 포함)
- `SceneTransition` — 페이드 전환 (go_to(path, style))
- `AudioManager` — 절차적 BGM/SFX (씬별 테마 4종, 외부 파일 없음)
- `PlayerStats` — 레벨/경험치/체력/마음력/화폐/인벤토리
- `ItemDB` — 아이템 정의 + 8×8 픽셀 아이콘, 사용 효과
- `QuestSystem` — 퀘스트 진행/보상 (kill·level·story·coins 조건)
- `BattleSystem` — 턴제 전투 로직 + 적/스킬 정의
- `GameUI` — HUD·가방·퀘스트·상점·전투 UI 생성 및 적 배치 (맵 수정 불필요)

## 전투 시스템 (그림자 감정)
현실에선 눈에 보이지 않는 부정적 감정이 형체를 얻어 나타난다. 쿼카는 마음의 힘으로 이를 걷어낸다.

**적** — 불안 / 욕심 / 불행 / 비교 / 번아웃 / 야근 귀신(보스)
- 맵을 떠다니다가 7m 안에 들어오면 쫓아오고, 닿으면 전투 시작 (`ShadowEnemy3D`)
- 전투 화면의 적은 12×12 픽셀 아트(`PixelArt`)로 그린다

**스킬** (레벨업으로 해금)
- LV1 웃어넘기기 / LV2 심호흡(회복) / LV3 여행 상상(적 약화) / LV4 응원 한마디(버프) / LV6 따뜻한 포옹(파트너 합류 시 위력 증가)

**화폐** — 반짝 조각(✦). 적 처치·퀘스트 보상으로 얻고 자판기(상점)에서 소비한다.

**연출** — 화면 플래시/흔들림, 데미지 숫자 팝업, 크리티컬, 처치 시 픽셀이 흩어지는 소멸 효과

**밸런스 (약점·경감·예고)**
- 일반 적 5종에 `weak` 필드(약점 스킬 id)가 있다. 약점 스킬 적중 시 1.6배(`WEAKNESS_MULT`) 피해 후
  적 턴 없이 즉시 넘어간다. 한 번 밝혀진 약점은 `weakness_found`에 전투 중 기억되어
  스킬 목록에 "◆약점" 표시가 붙는다(저장 데이터에도 포함).
- 피해 계산은 뺄셈 방어(`공격력 - 방어력`)가 아니라 비율 경감식
  `_mitigation(def) = 100 / (100 + def*8)` 을 공격력에 곱하는 방식이다.
- `BattleSystem.enemy_intent()` / `expected_enemy_damage()` 로 적의 다음 행동(일반 공격 예상 피해,
  보스는 4턴마다 강한 일격 예고)을 `BattleUI`의 `_intent_label`에 표시한다.

## UI 구조 (화면 상시 노출)
- 왼쪽 위: LV·체력·마음력·경험치 바 / 오른쪽 위: 반짝 조각
- 오른쪽 세로 버튼: 가방 · 퀘스트 · 상점 · 앨범 · 설정 (조이스틱과 겹치지 않게 배치)
- **가방에는 아이템만** 넣는다 — 퀘스트는 독립 메뉴로 분리
- 단축키: I=가방, Q=퀘스트, B=앨범, D=바람 노트(목표), F=사진

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
- ✅ 절차적 BGM/SFX (씬별 테마, 전투/클리어 효과음)
- ✅ 전투 시스템 (그림자 감정 6종, 스킬 5종, 레벨업)
- ✅ 아이템·화폐·상점·퀘스트 시스템
- ✅ 상시 노출 HUD + 메뉴 (가방/퀘스트/상점/앨범/설정)
- ✅ 전투 밸런스 조정 (약점 시스템, 비율 경감 방어식, 적 행동 예고)

## 다음 작업 후보
- 스킬 연출 강화 (스킬별 고유 이펙트)
- 그림자 감정 추가 (조급함, 외로움 등)
- 장비 아이템 (목도리·모자 등 상시 착용)
- Android 빌드 설정

## 검증 안 된 부분 (중요)
이 컨테이너에 Godot 실행 파일이 없어 **엔진 구동 테스트를 하지 못했다.**
전투/UI 시스템(약점·경감식·행동 예고 포함)은 코드 리뷰와 CI의 프로젝트 임포트 검사만
거친 상태이며, **실제로 플레이해본 적이 없다.** CI는 파싱 에러·씬 로딩 실패만 잡아내고
"재미있는가", "밸런스가 적절한가"는 검증하지 못하므로 에디터에서 직접 플레이해
체감을 확인해야 한다.

## CI 관련 주의사항
- `.github/workflows/godot-check.yml`은 `godot --headless --import --quit`로
  **프로젝트 전체를 한 번에 임포트**해 파싱 에러를 잡는다.
- `godot --check-only --script <파일>` 방식으로 스크립트를 하나씩 검사하는 방법은 쓰지 않는다.
  프로젝트 컨텍스트 밖에서 컴파일되어 오토로드 싱글턴(BattleSystem, AudioManager 등)과
  class_name(PixelArt) 참조를 못 찾아 멀쩡한 파일도 전부 실패로 뜬다.
- GDScript 정적 타입 추론 주의: `get_first_node_in_group()`/`get_node_or_null()` 결과를
  `:=`로 받으면 타입이 Node로 확정되어 `.global_position`, `.open()` 같은 호출이
  파싱 단계에서 실패한다. 이런 자리는 타입을 지정하지 않는 `var x = ...`를 쓴다.
