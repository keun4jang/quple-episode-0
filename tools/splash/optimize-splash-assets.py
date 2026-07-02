#!/usr/bin/env python3
"""PNG->WebP 변환 + 720/1440 리사이즈. sharp/cwebp 없으면 Pillow 사용."""
import os
from PIL import Image
ROOT=os.path.normpath(os.path.join(os.path.dirname(__file__),"..",".."))
SP=os.path.join(ROOT,"assets","splash")
src=os.path.join(SP,"splash-poster-no-text.png")
if not os.path.exists(src):
    print("run generate-splash-assets.py first"); raise SystemExit(1)
im=Image.open(src).convert("RGB")
im.save(os.path.join(SP,"splash-poster-no-text.webp"),"WEBP",quality=88,method=6)
im.resize((1440,2560),Image.LANCZOS).save(os.path.join(SP,"splash-poster-no-text@2x.webp"),"WEBP",quality=88,method=6)
im.resize((720,1280),Image.LANCZOS).save(os.path.join(SP,"splash-poster-no-text@720.webp"),"WEBP",quality=86,method=6)
print("optimized:")
for f in sorted(os.listdir(SP)):
    if f.startswith("splash-poster"): print(" ",f,f"{os.path.getsize(os.path.join(SP,f)):,}B")
