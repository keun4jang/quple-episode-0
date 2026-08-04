# 스플래시 에셋 생성 프롬프트 (로컬 AI 도구용)

로컬 ComfyUI(:8188) 또는 SD WebUI/Forge(:7860)가 실행 중일 때 사용.
없으면 `tools/splash/generate-splash-assets.py`(PIL)로 대체 생성. 대용량 모델 새로 다운로드 금지.

## A. 메인 포스터 배경 (텍스트 없음)
**Positive:** Vertical 9:16 premium Korean mobile casual game title splash illustration, no text, no logo,
empty top for title UI, empty bottom for buttons, tiny floating world diorama planet, green grass islands,
blue ocean, miniature Korean palace, N Seoul Tower inspired landmark, small rocket, pastel galaxy sky,
dreamy stars, soft nebula, glowing planets, healing travel mood, high-end 3D clay toy diorama render,
cinematic warm lighting, pastel blue lavender peach mint cream palette, volumetric glow, magical sparkles

**Negative:** text, letters, Korean letters, logo, watermark, UI, button, low quality, blurry, flat vector,
harsh shadows, horror, gray background, huge simple blue ball, cluttered

설정: SDXL 1024x1792, steps 28~40, CFG 5~7, DPM++ 2M Karras, 4장 생성 후 최적 선택 → 1080x1920 업스케일 → WebP

## B. 캐릭터 커플 (투명)
Two adorable quokka-like bear couple mascots, full body front 3/4, transparent background, warm tan/cream fur,
round ears, big glossy eyes, rosy cheeks, one green travel cap + backpack + camera, other pink scarf +
crossbody bag + ticket, 3D clay toy render, premium mascot. (현재는 Blender bpy 렌더로 대체 → `quica-couple-splash.png`)

## C. 미니 월드 디오라마 (투명)
Tiny floating world diorama planet, no characters, no text, blue ocean, green islands, Korean palace,
tower, rocket, palm trees, pastel 3D clay style. (현재 포스터에 내장 생성)

## D. 파스텔 우주 배경만
Vertical 9:16 pastel cosmic galaxy background, no text, dreamy blue lavender pink mint nebula, soft stars,
cute planets, gentle glow, empty safe zones top/bottom.

---

## 최종 포스터 프롬프트 (canonical, no-text)

**Positive:**
```
Vertical 9:16 premium mobile casual game title splash illustration, no text, no logo, no letters,
empty space at the top for Korean title UI, empty space at the bottom for game buttons, two adorable
quokka-like bear couple mascots traveling together, warm caramel and honey cream fur, round ears, big
glossy eyes, small black noses, soft cream muzzle, rosy cheeks, happy friendly expressions, cute travel
outfits, small backpacks, camera, scarf, travel pouch, ticket, standing on a tiny floating world diorama
planet, green grass island, blue ocean, small river, tiny forest, miniature Korean palace building, N
Seoul Tower inspired landmark, tiny Eiffel-like tower, small beach, palm trees, tiny houses, cute rocket,
pastel galaxy sky, dreamy stars, glowing planets, magical sparkles, healing travel adventure mood, premium
casual mobile game splash art, high-end 3D clay render, toy diorama, rounded shapes, cinematic warm
lighting, soft global illumination, polished commercial game art, detailed but clean composition, cute and
cozy, colorful pastel blue lavender peach mint cream palette, depth, volumetric glow, magical atmosphere
```

**Negative:**
```
text, letters, Korean letters, logo, watermark, signature, UI, button, menu, unreadable signs, bad
typography, low quality, blurry, flat vector, cheap 3D, primitive shapes, simple blue ball, plain sphere,
harsh shadows, horror, scary, creepy, realistic aggressive fur, deformed face, extra limbs, extra fingers,
bad eyes, crossed eyes, cropped head, cropped body, cluttered composition, muddy colors, gray background,
alien antenna, insect antenna
```

**설정:** 9:16, 1024x1792 또는 1080x1920, steps 28~40, CFG 5~7, 후보 4장+, seed 기록, WebP 변환.
텍스트가 포함된 후보는 폐기. 상단/하단 UI 세이프존 확인.

생성 후 적용: `python3 tools/splash/import-splash-art.py --file <best>.png`

---

## ★ 쿼카 해부학 (곰으로 나오는 것 방지 — 필수)

AI에 "quokka"만 쓰면 십중팔구 **곰**이 나온다. 아래를 프롬프트에 명시할 것:

| 부위 | 반드시 명시 | 나오면 안 되는 것 |
|---|---|---|
| 주둥이 | tapered elongated snout, narrows to a tiny black nose | 짧고 납작한 곰 주둥이 |
| 입 | famous quokka smile, mouth corners curving upward, tiny front teeth | 무표정 |
| 귀 | small rounded ears set **low and wide on the sides** of the head | 머리 위 큰 곰 귀 |
| 수염 | fine whiskers | 없음 |
| 다리 | strong kangaroo-like hind legs, large hind feet, small front paws at chest | 곰 사지 |
| 꼬리 | thick tapering tail like a small kangaroo | 짧고 둥근 꼬리 |
| 분류 | "small Australian macropod, like a tiny kangaroo or wallaby — NOT a bear" | — |

**Negative에 반드시 포함:** `bear, teddy bear, round bear ears on top of the head, short flat bear snout, dog, cat, hamster, mouse`

검증된 결과: `assets/splash/candidates/q_d.png` (채택), `q_b.png`
