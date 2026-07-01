#!/usr/bin/env python3
"""
퀴카 마스코트 파이프라인 도구 체크
Usage: python3 tools/mascot/check-mascot-tools.py
"""
import subprocess, sys, importlib, os, json

results = {}

def check(label, fn):
    try:
        v = fn()
        results[label] = {"ok": True, "value": v}
        print(f"  ✔  {label}: {v}")
    except Exception as e:
        results[label] = {"ok": False, "error": str(e)}
        print(f"  ✘  {label}: {e}")

print("=== 퀴카 마스코트 파이프라인 도구 체크 ===\n")

print("[Python 모듈]")
for mod in ["bpy", "PIL", "cairosvg", "numpy"]:
    check(mod, lambda m=mod: importlib.import_module(m).__version__)

print("\n[CLI 도구]")
for cmd in ["blender", "cwebp", "convert", "pngquant", "ffmpeg"]:
    check(cmd, lambda c=cmd: subprocess.check_output(["which", c]).decode().strip())

print("\n[로컬 서비스]")
import urllib.request
for url, label in [("http://127.0.0.1:8188/", "ComfyUI"), ("http://127.0.0.1:7860/", "SD WebUI")]:
    try:
        urllib.request.urlopen(url, timeout=3)
        results[label] = {"ok": True, "value": url}
        print(f"  ✔  {label}: {url}")
    except:
        results[label] = {"ok": False}
        print(f"  ✘  {label}: not running")

print("\n[에셋 파일]")
asset_dir = os.path.join(os.path.dirname(__file__), "../../assets/mascots")
for f in ["quica-leader-front.png", "quica-partner-front.png", "quica-couple-splash.png",
          "quica-leader.glb", "quica-partner.glb"]:
    p = os.path.join(asset_dir, f)
    exists = os.path.exists(p)
    size = os.path.getsize(p) if exists else 0
    results[f] = {"ok": exists, "size": size}
    mark = "✔" if exists else "✘"
    print(f"  {mark}  {f}" + (f"  ({size:,} bytes)" if exists else ""))

print("\n=== 결과 요약 ===")
ok_count = sum(1 for v in results.values() if v.get("ok"))
print(f"  통과: {ok_count}/{len(results)}")

has_bpy = results.get("bpy", {}).get("ok", False)
if has_bpy:
    print("\n  → bpy 사용 가능! 렌더 실행:")
    print("    python3 tools/mascot/render-quica-mascots.py")
else:
    print("\n  → bpy 없음. 설치:")
    print("    pip install bpy")

print()
