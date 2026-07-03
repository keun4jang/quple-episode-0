#!/usr/bin/env python3
"""스플래시 아트 생성/최적화 도구 가용성 체크."""
import subprocess, urllib.request, importlib, os
def has(c): return subprocess.call(["which",c],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)==0
def up(url):
    try: urllib.request.urlopen(url,timeout=3); return True
    except: return False
print("=== 스플래시 아트 도구 체크 ===\n[로컬 AI 생성기]")
comfy=os.environ.get("COMFYUI_URL","http://127.0.0.1:8188")
sd=os.environ.get("SD_WEBUI_URL","http://127.0.0.1:7860")
print(f"  ComfyUI  ({comfy}): {'RUNNING' if up(comfy) else 'down'}")
print(f"  SD WebUI ({sd}/sdapi/v1/sd-models): {'RUNNING' if up(sd+'/sdapi/v1/sd-models') else 'down'}")
print("[Python 모듈]")
for m in ("PIL","requests","cairosvg"):
    try: importlib.import_module(m); print(f"  ✔ {m}")
    except: print(f"  ✘ {m}")
print("[이미지 CLI]")
for c in ("cwebp","convert","magick","pngquant"): print(f"  {'✔' if has(c) else '✘'} {c}")
print("[환경변수]")
print(f"  SPLASH_ART_URL = {os.environ.get('SPLASH_ART_URL','(unset)')}")
print("\n권장 경로:")
if up(sd+'/sdapi/v1/sd-models'): print("  → SD WebUI 감지: python3 tools/splash/generate-splash-art-sdwebui.py")
elif up(comfy): print("  → ComfyUI 감지: (workflow 필요)")
else: print("  → 로컬 생성기 없음. 외부 no-text 포스터 URL을 import:")
print("     SPLASH_ART_URL='<no-text 포스터 URL>' python3 tools/splash/import-splash-art.py")
