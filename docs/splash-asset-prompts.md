# 쿼플 0편 스플래시 포스터 에셋 생성 가이드

## 파일 경로
생성한 이미지를 아래 경로에 저장하면 메인 메뉴에 즉시 반영됩니다:

```
assets/splash/splash-poster-no-text.png
```

지원 포맷: `.png`, `.webp` (파일명은 반드시 `splash-poster-no-text`)

---

## 필수 사양
- 해상도: **1080 × 1920px** (세로형 모바일)
- 배경: 텍스트 없음 (로고, 버튼, 카피는 Godot에서 렌더링)
- 여백: 상단 300px / 하단 400px 는 반투명 또는 어두운 색으로 남겨 UI가 잘 보이도록
- 색상 팔레트: 딥 퍼플 (#0F0820) → 미드나잇 블루 → 소프트 핑크/라벤더

---

## Stable Diffusion / Flux 프롬프트

### 메인 프롬프트 (영문)
```
mobile game loading screen illustration, vertical poster 1080x1920,
cute couple of quokka marsupials standing on a tiny miniature planet earth,
nighttime starry sky, nebula clouds in deep purple and soft pink,
small cute landmarks on the globe (eiffel tower, korean hanok, pyramid),
retro japanese travel poster style, warm pastel colors,
the quokkas are wearing casual travel clothes, one has a camera,
NO TEXT, no UI elements, illustration art style,
soft rim lighting, dreamy atmosphere, indie game art,
color palette: deep navy, lavender, warm peach, mint green,
high quality, detailed, 2D illustration
```

### 네거티브 프롬프트
```
text, watermark, logo, UI, buttons, realistic photo, 3D render,
low quality, blurry, dark background only, adult content
```

### 추가 키워드 (스타일별)
- **지브리 풍**: `ghibli style, hand painted, watercolor`
- **플랫 일러스트**: `flat design, vector art, clean lines, bold shapes`
- **픽셀아트**: `pixel art, 16-bit, retro game sprite`

---

## ComfyUI 권장 설정
- Sampler: DPM++ 2M Karras
- Steps: 30–40
- CFG: 7.5
- Size: 1080×1920 (또는 540×960 후 upscale)
- Model: dreamshaper_8 / anything-v5 / counterfeit-v3

---

## 직접 그리기 (선택)
Krita, Aseprite, Procreate 등으로 위 컨셉에 맞게 제작 후 PNG 저장.

---

## 현재 상태
`assets/splash/splash-poster-no-text.png` 가 존재하지 않으면:
- Godot 메인 메뉴가 어두운 배경 + 안내 텍스트를 표시합니다
- 파일을 추가하면 다음 실행부터 포스터가 배경으로 자동 적용됩니다
- Godot 에디터에서 열려 있다면 프로젝트 재임포트 필요 없이 바로 반영됩니다
