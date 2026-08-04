# 쿼카 마스코트 에셋 파이프라인 v5.0

> Blender bpy 기반 3D 마스코트 파이프라인

---

## 1. 환경 요구사항

| 도구 | 버전 | 설치 |
|---|---|---|
| Python | 3.11+ | 기본 설치 |
| bpy | 5.0.1 | `pip install bpy` |
| Pillow | 10+ | `pip install Pillow` |

```bash
pip install bpy Pillow
```

---

## 2. 도구 확인

```bash
python3 tools/mascot/check-mascot-tools.py
```

---

## 3. 렌더 실행

```bash
python3 tools/mascot/render-quica-mascots.py
```

생성 파일:

| 파일 | 크기 | 설명 |
|---|---|---|
| `quica-leader-front.png` | 2048x2048 RGBA | 리더 단독 정면 |
| `quica-partner-front.png` | 2048x2048 RGBA | 파트너 단독 정면 |
| `quica-couple-splash.png` | 2048x1536 RGBA | 커플 스플래시 |
| `quica-couple-icon.png` | 1024x1024 RGBA | 아이콘 클로즈업 |
| `*.webp` | WebP | 최적화 버전 |

---

## 4. 품질 조정

`render-quica-mascots.py` - `rset()` 함수:

```python
sc.cycles.samples = 128   # 높일수록 품질↑ 시간↑
```

| samples | 시간 (2048px) |
|---|---|
| 32 | ~1분 (초안) |
| 128 | ~4분 (배포용) |
| 256 | ~8분 (고품질) |

---

## 5. Godot 적용

`main_menu_3d.gd`가 자동으로 로드:

```gdscript
const COUPLE_3D_PATH := "res://assets/mascots/quica-couple-splash.png"
```

파일 존재시 스플래시 화면 중앙 하단 자동 표시.

---

## 6. GLB Export (추후)

```python
bpy.ops.export_scene.gltf(
    filepath=P("quica-couple.glb"),
    export_format="GLB",
    export_apply=True,
)
```

---

## 7. 문제 해결

| 증상 | 해결 |
|---|---|
| `libEGL.so` 오류 | CYCLES 엔진 사용 (기본 설정됨) |
| 렌더가 검은색 | 카메라/조명 확인 |
| 투명 배경 안 됨 | `film_transparent=True` 확인 |
| WebP 실패 | `pip install Pillow` |

---

## 버전 히스토리

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1~4 | 2026-06 | PIL/SVG 기반 2D |
| **v5.0** | **2026-07** | **Blender bpy Cycles 3D 파이프라인** |
