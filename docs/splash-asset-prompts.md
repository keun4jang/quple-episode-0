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
