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
  player/       player_quokka_3d.gd (장비 3D 착용 표시 포함)
  characters/   partner_quokka_3d.gd
  ui/           menu_panel.gd(창 공통 틀) + bag_ui(인벤토리)·equip_ui·skill_ui·
                quest_ui·shop_ui·battle_ui·hud_ui·tutorial_ui 등
  systems/      episode0_state.gd, save_manager.gd, scene_transition.gd,
                interactable_3d.gd, photo_system.gd, audio_manager.gd
```

## AutoLoad 싱글톤 (project.godot 순서 중요)
- `Episode0State` — 13단계 스토리 상태머신
- `SaveManager` — ConfigFile 저장/불러오기 (스탯·퀘스트·처치기록 포함)
- `SceneTransition` — 페이드 전환 (go_to(path, style))
- `AudioManager` — 절차적 BGM/SFX (씬별 테마 4종, 외부 파일 없음)
- `PlayerStats` — 레벨/경험치/체력/마음력/화폐/인벤토리/장비
- `ItemDB` — 아이템 정의 + 8×8 픽셀 아이콘, 사용 효과 (consumable/equipment/story)
- `QuestSystem` — 퀘스트 진행/보상 (kill·level·story·coins 조건)
  - **퀘스트 설계 규칙**: 시간대·실시간 대기를 요구하는 조건("저녁까지 기다리기")은 만들지 않는다.
    순수 파밍(같은 행동 반복 수집)도 넣지 않는다. 스토리를 따라가면 자연스럽게 채워지는
    수준으로만 조건을 잡는다.
- `BattleSystem` — 턴제 전투 로직 + 적/스킬 정의
- `GameUI` — HUD·인벤토리·장비·스킬·퀘스트·상점·전투 UI 생성 및 적 배치 (맵 수정 불필요)

## 전투 시스템 (그림자 감정)
현실에선 눈에 보이지 않는 부정적 감정이 형체를 얻어 나타난다. 쿼카는 마음의 힘으로 이를 걷어낸다.

**적** — 불안 / 욕심 / 불행 / 비교 / 번아웃 / 조급함 / 외로움 / 미루기 / 강박 / 야근 귀신(보스)
- 맵을 떠다니다가 7m 안에 들어오면 쫓아오고, 닿으면 전투 시작 (`ShadowEnemy3D`)
- 전투 화면의 적은 12×12 픽셀 아트(`PixelArt`)로 그린다
- 맵별 배치는 `GameUI.SPAWN_TABLE`에서 관리한다 — 미루기(CompanyFront3D, 느리고 안 아프지만
  질기다), 외로움(CompanyLobby3D), 조급함(Office3D), 강박(BossDoorHallway3D, 일반 적 중 최고 공격력)

**스킬** (레벨업으로 해금)
- LV1 웃어넘기기 / LV2 심호흡(회복) / LV3 여행 상상(적 약화) / LV4 응원 한마디(버프) / LV6 따뜻한 포옹(파트너 합류 시 위력 증가)

**화폐** — 반짝 조각(✦). 적 처치·퀘스트 보상으로 얻고 자판기(상점)에서 소비한다.

**연출** — 화면 플래시/흔들림, 데미지 숫자 팝업, 크리티컬, 처치 시 픽셀이 흩어지는 소멸 효과
- **스킬별 고유 이펙트**: `BattleUI.SKILL_FX`에 스킬 id별로 파편 색·개수·크기·퍼짐 방향(사방으로
  터짐/위로 떠오름)·지속시간·피격 플래시 색을 정의한다. 웃어넘기기=노란 파편+연노랑 플래시,
  여행 상상=하늘색 파편이 천천히 떠오름+연보라 플래시, 따뜻한 포옹=크고 진한 분홍 파편,
  심호흡=민트색 파편이 플레이어 쪽에서 떠오름, 응원 한마디=금색 파편. `_play_skill_burst(id, on_enemy)`
  가 `_spawn_burst()`로 ColorRect 파편을 실제로 만들고 흩어지게 한다(외부 이미지 없이 픽셀 사각형).

**감정별 행동 패턴** — 적마다 싸우는 방식이 다르다. `ENEMIES`의 `pattern` 필드로 정의하고
`_enemy_plan(turn)`이 해석한다. **무작위가 아니라 턴 수만으로 결정**되므로 행동 예고와 실제가
항상 일치한다(`_enemy_turn()`과 `enemy_intent()`가 같은 함수를 쓴다).

| 적 | 패턴 | 행동 |
|---|---|---|
| 불안 | `multi` | 매 턴 약한 공격 2번 — 계속 재잘거린다 |
| 욕심 | `drain` | 3턴마다 마음력을 6 빨아간다 |
| 불행 | `weaken` | 3턴마다 마음의 힘을 3 꺾는다 (최대 공격력 절반까지만) |
| 비교 | `reflect` | 직전에 받은 피해의 35%를 그대로 되돌린다 (안 때렸으면 평범한 공격) |
| 번아웃 | `burst` | 2턴 늘어져 있다가 3턴째 2배로 터진다 |
| 외로움 | `lonely` | 혼자면 1.5배, **파트너가 곁에 있으면 0.5배** — 스토리와 연결된 패턴 |
| 조급함 | `escalate` | 턴마다 위력이 18%p씩 오른다 (최대 2.2배) — 오래 끌수록 위험 |
| 미루기 | `lazy` | 2턴에 한 번만 공격, 나머지는 미룬다 |
| 강박 | `multi` | 2턴마다 2연타 — "다시, 다시" 확인한다 |
| 야근 귀신 | `heavy` | 4턴마다 강한 일격 (기존과 동일) |

- 새 패턴을 만들려면 `_enemy_plan()`에 `match` 분기를 추가하고, 반환하는 `act`
  (`attack`/`rest`/`drain`/`weaken`/`reflect`)를 `_enemy_turn()`이 실행할 수 있게 한다.
  예고 문구도 `enemy_intent()`에 같이 넣어야 한다 — **예고와 실제 행동이 어긋나면 안 된다.**
- `drain`/`weaken`은 `status` 이벤트로 UI에 띄운다 (플레이어 쪽에 색깔 있는 뜨는 글자).

**밸런스 (약점·경감·예고)**
- 보스를 제외한 일반 적 전부에 `weak` 필드(약점 스킬 id)가 있다. 공격형 스킬 3종
  (웃어넘기기/여행 상상/따뜻한 포옹)에 3마리씩 고르게 분산돼 있다.
  약점 스킬 적중 시 1.6배(`WEAKNESS_MULT`) 피해 후
  적 턴 없이 즉시 넘어간다. 한 번 밝혀진 약점은 `weakness_found`에 전투 중 기억되어
  스킬 목록에 "◆약점" 표시가 붙는다(저장 데이터에도 포함).
- 피해 계산은 뺄셈 방어(`공격력 - 방어력`)가 아니라 비율 경감식
  `_mitigation(def) = 100 / (100 + def*8)` 을 공격력에 곱하는 방식이다.
- `BattleSystem.enemy_intent()` / `expected_enemy_damage()` 로 적의 다음 행동(일반 공격 예상 피해,
  보스는 4턴마다 강한 일격 예고)을 `BattleUI`의 `_intent_label`에 표시한다.
- **중요한 불변식**: `weak` 필드에는 반드시 `type: "attack"` 스킬만 지정한다. 회복/버프
  스킬(심호흡·응원 한마디)은 적에게 피해를 주지 않는데, 약점 판정에 걸리면 "피해 0 + 적 턴
  스킵"이 되어 그 스킬을 반복 사용하는 것만으로 무한 회복이 가능한 익스플로잇이 생긴다
  (`player_use_skill()`의 `hit_weakness`가 `skill.type == "attack"`을 함께 확인하도록 수정됨 —
  번아웃의 약점도 원래 심호흡이었다가 이 문제로 따뜻한 포옹으로, 비교는 응원 한마디에서
  웃어넘기기로 재배정했다).

## 장비 아이템 (상시 착용)
- `ItemDB`의 `kind: "equipment"` 아이템은 소모되지 않고 슬롯(`slot`)에 착용한다.
  슬롯은 4개(`hat` 머리 · `scarf` 목 · `gloves` 손 · `shoes` 발)이고,
  자리마다 기본/상위 장비가 하나씩 있다:
  - 머리: `hat` 털모자(마음력 최대치 +10, ✦65) / `travel_cap` 여행 모자(마음력 최대치 +6, 마음의 힘 +2, ✦140)
  - 목: `scarf` 포근한 목도리(방어 +4, ✦70) / `star_scarf` 별무늬 목도리(방어 +7, ✦150, 강박이 6% 드랍)
  - 손: `mittens` 벙어리장갑(마음의 힘 +3, ✦80, 번아웃이 10% 드랍) /
    `travel_gloves` 여행 장갑(마음의 힘 +5, 방어 +1, ✦160)
  - 발: `slippers` 푹신한 실내화(체력 최대치 +12, ✦75, 미루기가 10% 드랍) /
    `travel_shoes` 여행 운동화(체력 최대치 +20, 마음의 힘 +1, ✦170, 보스가 50% 드랍)
  - 상위 장비를 전부 착용하면 마음의 힘 +8, 방어 +8, 체력 +20, 마음력 +6 (총 ✦620어치)
- 같은 슬롯의 장비를 착용하면 기존 것이 자동으로 해제된다.
- `PlayerStats.equip_item(id)` / `unequip_slot(slot)` — 착용 시 `effect`가 스탯에 영구
  더해지고(같은 슬롯에 이미 장비가 있으면 자동으로 해제 후 교체), 해제하면 그만큼 다시 빠진다.
  전투 중/밖 상관없이 항상 적용된다(별도 버프 아님).
- 저장 데이터에는 장비 보너스가 이미 반영된 스탯 값이 그대로 저장되므로, 불러올 때
  `equipment` 딕셔너리는 표시용으로만 복원하고 효과를 다시 적용하지 않는다
  (`player_stats.gd`의 `from_dict()` 참고 — 다시 적용하면 중복 적용된다).
- **장비 창(EquipUI)**에서 슬롯별로 착용/해제한다. 인벤토리에는 장비가 들어가지 않는다.
  상점(자판기)에서도 구매 가능.
- **3D 착용 표시**: 착용한 장비는 `PlayerQuokka3D`에 실제 메시로 그려진다. 아이템의 `wear`
  필드(`color`/`accent`/`style`)를 읽어 슬롯별로 모양을 만든다:
  - 목 = TorusMesh 링 + 늘어뜨린 자락 (줄무늬 또는 별 장식)
  - 머리 = SphereMesh 크라운 + CylinderMesh 테두리 (+방울 또는 챙)
  - 손 = 손을 감싸는 SphereMesh + 손목 테두리 (양손 두 곳)
  - 발 = 발등 SphereMesh + BoxMesh 밑창 (+운동화면 끈) (양발 두 곳)
- 붙는 자리는 `_equip_roots`가 `{슬롯: [Node3D, ...]}`로 들고 있다. 손·발처럼 좌우 두 곳에
  붙는 슬롯이 있어서 슬롯마다 배열이다. 새 슬롯을 추가하면 여기에 자리를 등록하고
  `_build_worn()`에 `match` 분기를 하나 더 넣으면 된다.
- `PlayerStats.equipment_changed` 시그널이 오면 `_refresh_equipment()`가 메시를 다시 만든다 —
  착용/해제/불러오기 모두 즉시 반영된다. 파트너 쿼카에는 장비를 표시하지 않는다.

## UI 구조 (화면 상시 노출)
화면 왼쪽 위에 정보와 메뉴를 한데 모으고, 아래 절반은 조이스틱·상호작용 버튼 자리로 비워둔다.

```
(24,24)   스탯 패널 642px — LV · 체력 · 마음력 · 경험치        (766,24) 반짝 조각
(24,200)  메뉴 버튼 4×2 그리드 (150×124, 간격 14)
(24,486)  현재 목표
```

- **메뉴 7개는 전부 독립**이다. 한 창 안에 다른 기능을 넣지 않는다:
  인벤토리 · 장비 · 스킬 · 퀘스트 · 상점 · 앨범 · 설정
  - 인벤토리 = 소모품 + 중요 물품 (장비는 안 들어간다)
  - 장비 = 슬롯별 착용/해제 전용 창
  - 스킬 = 배운 스킬과 해금 예정 스킬 확인 (사용은 전투에서)
- **이름은 다른 게임에서 쓰는 일반적인 용어로 쓴다.** "배낭·사진첩·바람 노트" 같은
  감성적 명칭은 쓰지 않는다 — 처음 보는 사람이 바로 알아야 한다.
- **버튼 크기 근거**: 터치 최소 권장치가 Apple HIG 44pt / Material 48dp인데,
  1080폭 세로 화면은 대략 3배 밀도라 환산하면 132~144px이다. 그래서 150×124를 쓴다.
  이보다 작게 만들지 말 것. 간격도 14px 이상 유지한다 (`HudUI.BTN_SIZE`, `BTN_GAP`).
- 단축키: I=인벤토리, E=장비, K=스킬, Q=퀘스트, B=앨범, D=목표, F=사진

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
- **TutorialUI**: 첫 플레이 1회, 5단계 조작 안내(이동→상호작용→메뉴→전투→쓰러져도 괜찮음).
  언제든 "건너뛰기" 가능. 본 적 있는지는 `user://settings.cfg`의 `tutorial/seen`에 저장한다.
  첫 맵 `CompanyFront3D`에서 `maybe_show()`로 띄운다.
- **InventoryUI**(bag_ui.gd) / **EquipUI** / **SkillUI** / **QuestUI** / **ShopUI**:
  전부 `menu_panel.gd`를 상속하고 `panel_title()` + `_refresh_content()`만 구현한다.
  새 메뉴를 만들 때도 이 틀을 쓰고, `GameUI`에 인스턴스와 `open_panel()` 분기를 추가한다.
- **AlbumUI**: B키, 다중 사진 페이지(←→)
- **WindNoteUI**: D키, 현재 목표 표시 (HUD 목표 패널과 같은 내용)
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

## Android 빌드
저장소에 들어있는 설정 (이미 반영됨):
- `project.godot`
  - `window/handheld/orientation=1` — 세로 고정
  - `pointing/emulate_touch_from_mouse=true` — **중요**: `VirtualJoystick`은 `InputEventScreenTouch`
    /`ScreenDrag`만 처리하므로 이 설정이 없으면 데스크톱에서 마우스로 조이스틱을 못 움직인다
  - `renderer/rendering_method.mobile="mobile"` — 안드로이드는 Mobile 렌더러
  - `textures/vram_compression/import_etc2_astc=true` — 모바일 텍스처 압축
- `export_presets.cfg` — Android 프리셋 (APK, arm64-v8a + armeabi-v7a, 몰입 모드,
  패키지명 `com.quokkacorp.quple0`, 버전 0.1.0). 배포 전에 패키지명은 본인 도메인으로 바꿀 것.

빌드하려면 (이 컨테이너·CI에서는 불가 — Godot 에디터와 Android SDK가 필요):
1. 에디터 → 편집기 설정 → Export → Android 에서 Android SDK 경로 지정
2. 내보내기 템플릿 설치 (에디터 → 프로젝트 → 내보내기 템플릿 관리)
3. 디버그 빌드는 에디터가 디버그 키스토어를 자동 생성한다. 릴리스는 직접 만든 키스토어 사용
4. **키스토어와 비밀번호는 절대 커밋하지 말 것** — `.gitignore`에 `*.keystore`, `*.jks`,
   `export_credentials.cfg`(Godot 4가 비밀번호를 저장하는 파일)를 등록해뒀다

알아둘 것:
- Mobile 렌더러는 **SSAO를 지원하지 않는다** (glow는 된다). 안드로이드에서는 씬의 SSAO 설정이
  무시되므로 PC보다 음영이 얕게 보인다.
- 런처 아이콘을 지정하지 않아 Godot 기본 아이콘이 쓰인다. 커스텀 아이콘은 이미지 파일이
  필요한데 "외부 이미지 금지" 원칙과 부딪히므로, 넣을지 여부는 별도 결정이 필요하다.

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
- ✅ 그림자 감정 2종 추가 (조급함·외로움) + 약점 판정 익스플로잇 수정
- ✅ 장비 아이템 (목도리·모자, 상시 착용, 가방에서 착용/해제)
- ✅ 스킬별 고유 이펙트 (파편 색·모양·플래시 색을 스킬마다 다르게)
- ✅ 그림자 감정 2종 추가 (미루기·강박) — 일반 적 9종 + 보스
- ✅ 장비 4종(슬롯당 기본/상위) + 3D 캐릭터에 실제 착용 표시
- ✅ Android 빌드 설정 (세로 고정, 터치, Mobile 렌더러, Android 내보내기 프리셋)
- ✅ UI 재설계 — 메뉴 7개 독립 분리(장비·스킬 창 신설), 왼쪽 위 그리드 배치, 명칭 일반화
- ✅ 단계별 초반 튜토리얼
- ✅ 파밍 퀘스트 제거 (반짝 조각 200개 삭제, 레벨 5→3, 불안 3→2마리)
- ✅ 장비 슬롯 4개로 확장 (머리·목·손·발, 장비 8종, 손발은 좌우 양쪽에 표시)
- ✅ 그림자 감정별 고유 행동 패턴 (연타·흡수·약화·반사·폭발·지연·가속 등 10종)

## 다음 작업 후보
- 실제 기기에서 APK 빌드·플레이 테스트 (지금까지 전부 미검증)
- 장비 세트 효과 (같은 계열 전부 착용 시 보너스)
- 상태이상 (일시적 약화·회복 불가 등)

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
