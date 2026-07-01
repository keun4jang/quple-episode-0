# 퀴카 커플 마스코트 스타일 가이드 v2.0

> Blender 3D 기반 마스코트 파이프라인 기준 문서

---

## 1. 캐릭터 개요

**그룹명:** 퀴카 커플 (Quika Couple)
**세계관:** 퀴풀 힐링 여행 모바일 캐주얼 게임의 메인 IP
**스타일:** Soft 3D Clay Toy Mascot — 모바일 게임 상업 IP 수준

---

## 2. 캐릭터 프로필

### 캐릭터 A: 퀴카 리더

| 항목 | 내용 |
|---|---|
| **이름** | 퀴카 리더 (Quika Leader) |
| **파일 ID** | `quica-leader` |
| **역할** | 여행을 이끄는 호기심 많은 리더 |
| **성격** | 밝고 활발함, 새로운 것에 도전적 |
| **컬러** | 따뜻한 캐러멜 브라운 |
| **대표 소품** | 초록 여행 캡, 행성 배지, 백팩, 카메라 |
| **대표 자세** | 앞으로 나온 자신감 있는 직립, 한 손 카메라 |

**컬러 팔레트 A:**

| 부위 | HEX | RGB |
|---|---|---|
| 몸 기본 | `#B9783C` | 185, 120, 60 |
| 몸 하이라이트 | `#C98845` | 201, 136, 69 |
| 몸 그림자 | `#A86532` | 168, 101, 50 |
| 배/muzzle | `#FFE8BD` | 255, 232, 189 |
| 귀 안쪽 | `#F5AFA8` | 245, 175, 168 |
| 볼터치 | `#FF8FA3` | 255, 143, 163 |
| 캡 | `#1F8F4A` | 31, 143, 74 |
| 배지 | `#FFE57A` | 255, 229, 122 |
| 백팩 | `#3A7AC8` | 58, 122, 200 |
| 카메라 | `#1F2636` | 31, 38, 54 |
| 눈 | `#2A1A12` | 42, 26, 18 |
| 눈 홍채 | `#5A321D` | 90, 50, 29 |

---

### 캐릭터 B: 퀴카 파트너

| 항목 | 내용 |
|---|---|
| **이름** | 퀴카 파트너 (Quika Partner) |
| **파일 ID** | `quica-partner` |
| **역할** | 여행을 기록하는 다정한 파트너 |
| **성격** | 부드럽고 사랑스러움, 세심하고 따뜻함 |
| **컬러** | 허니 크림 베이지 |
| **대표 소품** | 핑크 스카프, 크로스백, 여행 티켓, 별 키링 |
| **대표 자세** | 부드럽고 다정한 자세, 한 손 티켓 |

**컬러 팔레트 B:**

| 부위 | HEX | RGB |
|---|---|---|
| 몸 기본 | `#D8A85C` | 216, 168, 92 |
| 몸 하이라이트 | `#E5BF78` | 229, 191, 120 |
| 몸 그림자 | `#C9934B` | 201, 147, 75 |
| 배/muzzle | `#FFF1D0` | 255, 241, 208 |
| 귀 안쪽 | `#F5AFA8` | 245, 175, 168 |
| 볼터치 | `#FF8FA3` | 255, 143, 163 |
| 스카프 | `#F05E9B` | 240, 94, 155 |
| 스카프 밝은 | `#FF8BBC` | 255, 139, 188 |
| 크로스백 | `#B17A3E` | 177, 122, 62 |
| 티켓 | `#FFFAE0` | 255, 250, 224 |
| 눈 | `#2A1A12` | 42, 26, 18 |
| 눈 홍채 | `#5A321D` | 90, 50, 29 |

---

## 3. 공통 외형 규칙

### 반드시 포함해야 할 요소

**얼굴:**
- 둥근 귀 (외이 + 내이 복숭아색)
- 눈 흰자 레이어
- 홍채 (갈색 계열)
- 동공 (짙은 갈색/검정)
- 눈 하이라이트 2개 이상 (크기 다르게)
- 작은 검은 코 + 코 하이라이트
- 크림색 muzzle 영역
- 부드러운 미소
- 볼터치 (반투명)

**몸:**
- 달걀형 몸통
- 배 밝은 크림 패치
- 팔 (둥근 끝부분)
- 다리
- 발 (약간 납작한 원형)
- 발바닥 밝은 패치
- 짧은 꼬리

**재질 (3D):**
- Roughness: 0.70~0.80
- 약간의 Subsurface Scattering (clay/skin 느낌)
- 은은한 Specular
- 부드러운 Area Light 조명

---

## 4. 소품 배치 규칙

| 규칙 | 설명 |
|---|---|
| 얼굴 미노출 | 소품이 눈/코/입/볼을 가리면 절대 안 됨 |
| 스카프 위치 | 목 아래 + 앞쪽에 V드레이프 — 입 절대 안 가림 |
| 카메라 스트랩 | 어깨→가슴 방향, 얼굴 통과 금지 |
| 모자 위치 | 귀 앞쪽 머리에 자연스럽게 |
| 티켓 위치 | 손에 들고 있는 형태 (세로 방향) |
| 소품 크기 | 64px에서도 식별 가능한 크기 |

---

## 5. 포즈 규칙

### 현재 기본 포즈 (idle)

| 캐릭터 | 자세 |
|---|---|
| A (리더) | 자신감 있는 직립, 약간 앞으로 기울기, 카메라 들기 |
| B (파트너) | 부드러운 직립, 약간 오른쪽 고개 기울기, 티켓 들기 |

### 렌더 포즈 목록

| 파일 | 설명 |
|---|---|
| `quica-leader-front.png` | A 단독, 정면 |
| `quica-partner-front.png` | B 단독, 정면 |
| `quica-couple-splash.png` | A+B 나란히, 스플래시용 |
| `quica-couple-icon.png` | A+B 얼굴 클로즈업, 아이콘용 |
| `quica-leader-3quarter.png` | A 3/4 뷰 |
| `quica-partner-3quarter.png` | B 3/4 뷰 |

---

## 6. 표정 규칙

기본 표정: 부드러운 미소 (happy-neutral)

### 추후 제작 예정 표정

| ID | 이름 | 눈 형태 | 입 | 볼 |
|---|---|---|---|---|
| `happy` | 기쁨 | 초승달형 | 크게 웃음 | 강화 |
| `excited` | 흥분 | 크게 뜨기 | 열린 입 | 강화 |
| `shy` | 수줍음 | 아래 시선 | 작은 미소 | 매우 강화 |
| `sad` | 슬픔 | 눈썹 처짐 | 처진 입 | 눈물 |
| `surprised` | 놀람 | 동그랗게 | O형 | 없음 |
| `wink` | 윙크 | 한쪽 윙크 | 미소 | 보통 |
| `sleepy` | 졸림 | 반쯤 감김 | 작은 O | 없음 |

---

## 7. 금지 요소

- ❌ 머리 위 안테나/더듬이 형태 털
- ❌ 날카로운 귀
- ❌ 무서운 사실적 동물 눈
- ❌ 기괴한/불안한 표정
- ❌ 너무 납작한 2D 벡터 아이콘 스타일
- ❌ 유료 폰트/에셋/외부 이미지
- ❌ 실존 브랜드 로고/텍스트
- ❌ 한글 텍스트 캐릭터 내부에 삽입
- ❌ 소품으로 얼굴 가림
- ❌ 카메라 스트랩 얼굴 통과

---

## 8. 사용 크기 가이드

| 용도 | 파일 | 최소 해상도 |
|---|---|---|
| 스플래시 히어로 | `quica-couple-splash.webp` | 1024px 이상 |
| 게임 내 NPC | 단독 PNG | 256px |
| 아이콘/프로필 | `quica-couple-icon.png` | 128px |
| 알림/뱃지 | 단독 PNG | 64px |

### 64px에서 식별 가능해야 할 요소

- A: 초록 캡 실루엣 + 둥근 귀
- B: 핑크 스카프 색상 + 둥근 귀

---

## 9. 스플래시 화면 적용 가이드

현재 Godot 4 기반:

```gdscript
# main_menu_3d.gd
const COUPLE_PATH := "res://assets/mascots/quica-couple-splash.png"

func _inject_couple_mascot() -> void:
    var abs_path = ProjectSettings.globalize_path(COUPLE_PATH)
    if FileAccess.file_exists(abs_path):
        var img = Image.load_from_file(abs_path)
        if img:
            var tex = ImageTexture.create_from_image(img)
            var rect = TextureRect.new()
            rect.texture = tex
            rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
            rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
            rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            ctrl.add_child(rect)
```

---

## 10. 추후 추가 예정 에셋

### 즉시 필요
- [ ] `quica-leader-happy.png` (게임 내 대화)
- [ ] `quica-partner-happy.png` (게임 내 대화)
- [ ] `quica-couple-photo.png` (사진 찍는 포즈)

### 중기 필요
- [ ] 걷기 애니메이션 GLB (4프레임)
- [ ] 표정 블렌드쉐이프 설정
- [ ] 앱 아이콘용 헤드샷 (512x512)

### 장기 필요
- [ ] 한복 버전 의상
- [ ] 해변 의상 버전
- [ ] Godot AnimationPlayer 연동 GLB

---

## 버전 히스토리

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1.0 | 2026-06 | PIL 기반 초기 생성 |
| v2.0 | 2026-06 | PIL 40+ shapes 강화 |
| v3.0 | 2026-06 | SVG 50+ shapes cairosvg |
| v4.0 | 2026-06 | SVG v4 스카프 V드레이프, 실루엣 차별화 |
| **v5.0** | **2026-06** | **Blender bpy 3D 파이프라인 구축** |
