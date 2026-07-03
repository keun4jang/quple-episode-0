# 스플래시 아트 파이프라인 (포스터 우선 구조)

## 구조
```
Layer1  splash-poster-no-text.webp   ← 단일 고퀄 no-text 포스터 (full-cover)
Layer2  프레임 / vignette / sparkle   ← 코드
Layer3  "퀴풀" 3D 젤리 로고            ← 코드
Layer4  서브타이틀 / 하단 카피         ← 코드
Layer5  버튼 (CTA/이어하기/설정/종료)  ← 코드
```
캐릭터·디오라마·우주는 **포스터 이미지 한 장**에 포함. 코드는 UI만 담당.
Blender 렌더는 **debug/fallback 소스**로만 유지 (`QUPLE_DEBUG_HERO=1` 런타임 오버레이).

## 도구 우선순위 (자동)
```bash
python3 tools/splash/check-art-tools.py   # 환경 감지
```
1. **로컬 SD WebUI/Forge(:7860)** 실행 시:
   `python3 tools/splash/generate-splash-art-sdwebui.py --n 4` → 후보 생성 → 최적 선택 → import
2. **ComfyUI(:8188)** 실행 시: workflow 연동 (프롬프트는 splash-asset-prompts.md)
3. **외부 생성(Genspark 등)** 이미지가 있으면 URL/파일 import:
   ```bash
   SPLASH_ART_URL='https://.../no-text-poster.png' python3 tools/splash/import-splash-art.py
   # 또는
   python3 tools/splash/import-splash-art.py --file /path/poster.png
   ```
4. **생성기 없음(현재)**: 인터림 포스터 굽기 (우주 PIL + Blender 히어로 합성)
   ```bash
   python3 tools/mascot/render-quica-hero-diorama.py   # 히어로 소스(필요시)
   python3 tools/splash/compose-splash-poster.py       # 인터림 포스터 굽기
   ```

## 최적화
```bash
python3 tools/splash/optimize-splash-art.py   # WebP + @2x + mobile
```

## 프로덕션 교체 방법 (사용자용) ★
레퍼런스급 퀄리티를 원하면 **no-text** 세로 포스터(1080x1920 권장)를 준비해서:
- 방법 A: 파일을 그대로 `assets/splash/splash-poster-no-text.png` 에 덮어쓰기
- 방법 B: `python3 tools/splash/import-splash-art.py --file <파일>` (자동 리사이즈/WebP/manifest)
- 방법 C: `SPLASH_ART_URL='<URL>' python3 tools/splash/import-splash-art.py`

교체 즉시 Godot 스플래시가 새 포스터를 사용. 이미지에 **텍스트/로고가 없어야** 함(로고는 코드 렌더).

## 파일 슬롯
| 파일 | 역할 |
|---|---|
| `assets/splash/splash-poster-no-text.png/.webp` | **프로덕션 포스터 슬롯** |
| `assets/splash/splash-poster-no-text@2x.webp` | 고해상(1440x2560) |
| `assets/splash/splash-poster-mobile.webp` | 720x1280 |
| `assets/splash/source/splash-poster-original.png` | import 원본 보관 |
| `assets/splash/fallback-splash-poster.svg` | 포스터 없을 때 fallback(placeholder 명시) |
| `assets/mascots/quica-hero-diorama.png` | Blender debug/fallback 소스 |

## 현재 상태
- 로컬 AI 생성기: **없음** (ComfyUI/SD 모두 미실행)
- 현재 포스터: **인터림**(compose-splash-poster.py, Blender clay 캐릭터 합성) — manifest `isInterim:true`
- 권장: AI no-text 포스터로 교체 시 위 파이프라인 사용
