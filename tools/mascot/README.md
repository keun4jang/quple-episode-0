# 쿼카 마스코트 툴킷

Blender bpy 기반 3D 마스코트 생성 파이프라인.

## 빠른 시작

```bash
# 1. 의존성 설치
pip install bpy Pillow

# 2. 환경 확인
python3 tools/mascot/check-mascot-tools.py

# 3. 3D 렌더 실행 (약 8~10분)
python3 tools/mascot/render-quica-mascots.py

# 4. 이미지 최적화 (WebP, 리사이즈)
python3 tools/mascot/optimize-mascot-assets.py
```

## 생성 파일

```
assets/mascots/
  quica-leader-front.png     # 리더 단독 2048x2048
  quica-partner-front.png    # 파트너 단독 2048x2048
  quica-couple-splash.png    # 커플 스플래시 2048x1536
  quica-couple-icon.png      # 아이콘 1024x1024
  quica-couple-splash.webp   # WebP 최적화
  mascot-manifest.json       # 에셋 메타데이터
```

## Godot 연동

`main_menu_3d.gd`의 `_inject_mascot_couple()` 함수가  
`quica-couple-splash.png`를 스플래시 화면에 자동 주입.

## 상세 문서

→ `docs/mascot-asset-pipeline.md`  
→ `docs/mascot-style-guide.md`
