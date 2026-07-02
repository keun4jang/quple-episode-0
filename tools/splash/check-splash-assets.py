#!/usr/bin/env python3
"""스플래시 에셋 존재/치수 검수. Usage: python3 tools/splash/check-splash-assets.py"""
import os, sys
try: from PIL import Image
except: Image=None
ROOT=os.path.normpath(os.path.join(os.path.dirname(__file__),"..",".."))
SP=os.path.join(ROOT,"assets","splash")
NEED=[("splash-poster-no-text.png",1080,1920),("splash-poster-no-text.webp",1080,1920),
      ("splash-poster-no-text@2x.webp",1440,2560),("splash-art-manifest.json",None,None)]
ok=True
for fn,w,h in NEED:
    p=os.path.join(SP,fn); e=os.path.exists(p)
    line=f"  {'✔' if e else '✘'} {fn}"
    if e and w and Image:
        iw,ih=Image.open(p).size
        good = iw==w and ih==h
        line+=f"  {iw}x{ih} {'OK' if good else f'EXPECTED {w}x{h}'}"
        ok=ok and good
    ok=ok and e
    print(line)
mascot=os.path.join(ROOT,"assets","mascots","quica-couple-splash.png")
print(f"  {'✔' if os.path.exists(mascot) else '✘'} mascot couple: {mascot}")
print("\n결과:", "ALL OK" if ok else "MISSING/MISMATCH")
sys.exit(0 if ok else 1)
