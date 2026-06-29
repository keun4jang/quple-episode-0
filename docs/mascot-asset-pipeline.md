# 퀴풀 마스코트 에셋 파이프라인

## 현재 파이프라인

### 1. 자동 생성 (코드 기반)
```bash
python3 scratchpad/gen_mascot_svg.py
```
- SVG 생성 → cairosvg로 PNG 변환
- 출력: `assets/mascots/`

### 2. 에셋 경로
```
assets/mascots/
  quika-leader.svg          # 벡터 원본 (편집 가능)
  quika-partner.svg         # 벡터 원본
  quika-couple-hero.svg     # 커플 합본 벡터
  quika-leader.png          # 800px PNG
  quika-partner.png         # 800px PNG
  quika-couple-hero.png     # 1600px 커플 PNG
  mascot-manifest.json      # 에셋 메타데이터
assets/splash/
  splash-poster-no-text.png # 스플래시 배경 (캐릭터 포함)
```

---

## AI 이미지 생성 프롬프트

로컬 ComfyUI, Stable Diffusion WebUI, Forge 등이 설치되면 아래 프롬프트를 사용해라.

### 캐릭터 커플 (투명 배경)

**Positive:**
```
Two adorable quokka-like bear couple mascots for a premium Korean mobile casual healing travel game, full body, front 3/4 view, transparent background, warm caramel and honey cream fur, round ears with peach inner ears, big glossy black-brown eyes with multiple highlights, small shiny black noses, soft cream muzzle, rosy cheeks, cute smiling expressions, rounded soft 3D clay toy style, mascot-quality commercial game characters, one character wearing a green travel cap with a small planet badge, blue backpack on back, camera hanging at chest level, the other wearing a soft pink scarf around the neck (NOT covering the mouth), cozy crossbody tan bag on side, holding a small travel ticket, cute couple pose facing slightly toward each other, friendly memorable silhouette, warm cinematic lighting, soft global illumination, clean shape language, high detail but not cluttered, polished mobile game IP character design
```

**Negative:**
```
text, logo, watermark, letters, Korean letters, creepy, scary, alien antenna, insect antenna, deformed face, bad eyes, crossed eyes, extra limbs, extra fingers, realistic animal fur, aggressive animal, low quality, blurry, flat icon, cheap vector, cropped head, cropped feet, harsh shadows, messy details, uncanny, props covering face, scarf covering mouth, strap crossing face
```

**설정:**
- 모델: SDXL / Pony Diffusion / Animagine
- 해상도: 1024×1280 (세로)
- Steps: 35
- CFG: 6.5
- Sampler: DPM++ 2M Karras

---

### 리더 단독 (캐릭터 A)

**Positive:**
```
Single adorable quokka-like bear mascot, full body, front view, transparent background, warm caramel brown fur, round ears with peach inner ears, big glossy eyes with highlights, cream muzzle, orange-pink cheeks, green travel cap with planet badge, blue backpack visible on side, small camera hanging at chest level from shoulder strap, confident friendly pose, soft 3D clay toy mascot style, premium mobile game character
```

---

### 파트너 단독 (캐릭터 B)

**Positive:**
```
Single adorable quokka-like bear mascot, full body, front view, transparent background, honey cream fur lighter than companion, round ears with peach inner ears, big glossy eyes with highlights, cream muzzle, pink cheeks, soft pink scarf around neck (visible below chin, not covering face), tan crossbody bag, holding a small travel ticket, gentle sweet pose, head slightly tilted, soft 3D clay toy mascot style, premium mobile game character
```

---

### 스플래시 포스터 배경

**Positive:**
```
Vertical 9:16 premium mobile casual game title splash illustration, no text, no logo, no characters, empty top 25% area for title UI overlay, empty bottom 35% area for button UI overlay, center shows a tiny floating world diorama planet, blue ocean with gradient, green grass islands, small Korean palace-style building, N Seoul Tower inspired landmark, tiny forest clusters, soft clouds, pastel galaxy sky, dreamy stars, small cute planets, magical sparkles, healing travel adventure mood, soft 3D clay toy diorama render, high-end commercial game art, cinematic warm lighting, pastel blue lavender peach mint color palette
```

---

## SVG 직접 편집 가이드

캐릭터 SVG는 Inkscape, Figma, Illustrator에서 열어 편집 가능.

### 그라디언트 ID 목록 (quika-leader.svg)
| ID | 설명 |
|---|---|
| `bodyGrad_a` | 몸통 radial gradient |
| `headGrad_a` | 머리 radial gradient |
| `bellyGrad_a` | 배 linear gradient |
| `earGrad_a` | 귀 gradient |
| `capGrad` | 모자 linear gradient |
| `backpackGrad` | 백팩 linear gradient |
| `camGrad` | 카메라 gradient |

### 그라디언트 ID 목록 (quika-partner.svg)
| ID | 설명 |
|---|---|
| `bodyGrad_b` | 몸통 radial gradient |
| `headGrad_b` | 머리 radial gradient |
| `bellyGrad_b` | 배 linear gradient |
| `scarfGrad` | 스카프 gradient |
| `bagGrad` | 가방 gradient |

---

## PNG 최적화

```bash
# pngquant로 압축 (설치 필요)
pngquant --quality=85-95 assets/mascots/*.png

# cwebp로 WebP 변환 (설치 필요)
cwebp -q 90 assets/mascots/quika-couple-hero.png -o assets/mascots/quika-couple-hero.webp
```

---

## Godot 연동

현재 Godot 씬에서 캐릭터 사용 방법:

```gdscript
# 스플래시에서 포스터로 로드
var abs_path = ProjectSettings.globalize_path("res://assets/splash/splash-poster-no-text.png")
var img = Image.load_from_file(abs_path)
if img:
    var tex = ImageTexture.create_from_image(img)
    poster_rect.texture = tex
```

향후 인게임 캐릭터 스프라이트 연동:
```gdscript
# 개별 마스코트 에셋
var leader_tex = load("res://assets/mascots/quika-leader.png")
var partner_tex = load("res://assets/mascots/quika-partner.png")
```

---

## 버전 관리

| 버전 | 날짜 | 변경 내용 |
|---|---|---|
| v1.0 | 2026-06 | PIL 기반 초기 생성 |
| v2.0 | 2026-06 | PIL 캐릭터 디테일 강화 (40+ shapes) |
| v3.0 | 2026-06 | SVG 기반 재설계 (50+ shapes, cairosvg) |
