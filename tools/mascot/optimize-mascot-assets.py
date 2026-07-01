#!/usr/bin/env python3
"""
퀴카 마스코트 에셋 최적화
- PNG 원본 보존
- WebP 생성 (cwebp 또는 Pillow)
- 1024px / 512px 다운스케일
- 투명 배경 유지

Usage: python3 tools/mascot/optimize-mascot-assets.py
"""
import os, sys, subprocess
from pathlib import Path

ASSET_DIR = Path(__file__).parent.parent.parent / "assets" / "mascots"
TARGETS = [
    ("quica-leader-front.png",   [("quica-leader-1024.png", 1024), ("quica-leader-512.png", 512)]),
    ("quica-partner-front.png",  [("quica-partner-1024.png", 1024), ("quica-partner-512.png", 512)]),
    ("quica-couple-splash.png",  [("quica-couple-splash-1024.png", 1024)]),
]

def has_cmd(cmd):
    return subprocess.call(["which", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

def png_to_webp_cwebp(src, dst, quality=90):
    subprocess.run(["cwebp", "-q", str(quality), "-lossless", str(src), "-o", str(dst)], check=True)

def png_to_webp_pillow(src, dst):
    from PIL import Image
    img = Image.open(src).convert("RGBA")
    img.save(dst, "WEBP", quality=90, lossless=False, method=6)

def resize_png(src, dst, max_px):
    from PIL import Image
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    scale = max_px / max(w, h)
    if scale >= 1.0:
        img.save(dst, "PNG")
        return
    new_w, new_h = int(w * scale), int(h * scale)
    img = img.resize((new_w, new_h), Image.LANCZOS)
    img.save(dst, "PNG")
    print(f"    → {new_w}x{new_h} saved")

def main():
    try:
        from PIL import Image
    except ImportError:
        print("ERROR: Pillow not installed. Run: pip install Pillow")
        sys.exit(1)

    cwebp_ok = has_cmd("cwebp")
    print(f"cwebp: {'available' if cwebp_ok else 'not found, using Pillow'}")
    print()

    for src_name, resizes in TARGETS:
        src = ASSET_DIR / src_name
        if not src.exists():
            print(f"SKIP (not found): {src_name}")
            continue

        print(f"Processing: {src_name}  ({src.stat().st_size:,} bytes)")

        # WebP
        webp_name = src_name.replace(".png", ".webp")
        webp_path = ASSET_DIR / webp_name
        try:
            if cwebp_ok:
                png_to_webp_cwebp(src, webp_path)
            else:
                png_to_webp_pillow(src, webp_path)
            print(f"    WebP: {webp_name}  ({webp_path.stat().st_size:,} bytes)")
        except Exception as e:
            print(f"    WebP ERROR: {e}")

        # Resized PNGs
        for out_name, px in resizes:
            out = ASSET_DIR / out_name
            try:
                resize_png(src, out, px)
                print(f"    Resize {px}px: {out_name}  ({out.stat().st_size:,} bytes)")
            except Exception as e:
                print(f"    Resize ERROR {px}px: {e}")

        print()

    print("Done.")

if __name__ == "__main__":
    main()
