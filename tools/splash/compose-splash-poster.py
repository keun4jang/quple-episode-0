#!/usr/bin/env python3
"""
인터림 no-text 포스터 굽기: 파스텔 우주 배경 + Blender 히어로 디오라마를 하나의 이미지로 합성.
(로컬 AI 생성기가 없을 때의 최선 asset. 실제 AI no-text 포스터가 생기면 import-splash-art.py로 교체.)
Usage: python3 tools/splash/compose-splash-poster.py
"""
import os, sys, importlib.util
from PIL import Image, ImageDraw, ImageFilter

HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.normpath(os.path.join(HERE,"..",".."))
SP=os.path.join(ROOT,"assets","splash")
HERO=os.path.join(ROOT,"assets","mascots","quica-hero-diorama.png")

# import make_poster (cosmic bg) from generator
spec=importlib.util.spec_from_file_location("gen",os.path.join(HERE,"generate-splash-assets.py"))
gen=importlib.util.module_from_spec(spec); spec.loader.exec_module(gen)

W,H=1080,1920

def main():
    print("우주 배경 생성...")
    base=gen.make_poster(W,H).convert("RGBA")
    if not os.path.exists(HERO):
        print("ERROR: 히어로 에셋 없음. render-quica-hero-diorama.py 먼저 실행"); sys.exit(1)
    hero=Image.open(HERO).convert("RGBA")

    # scale hero to ~0.92 width
    tw=int(W*0.94); th=int(tw*hero.height/hero.width)
    hero=hero.resize((tw,th),Image.LANCZOS)

    # bottom alpha fade (lower 34%) so planet melts into cosmos (copy readability)
    fade_h=int(th*0.34)
    a=hero.split()[3].load()
    for y in range(th-fade_h,th):
        t=(y-(th-fade_h))/fade_h
        f=1.0-t*t
        for x in range(tw):
            a[x,y]=int(a[x,y]*f)

    # halo behind hero
    halo=gen.radial(int(tw*0.95),(255,238,200),0.42)
    hx=(W-halo.width)//2; hy=int(H*0.40)-halo.height//2
    base.alpha_composite(halo,(hx,hy))
    halo2=gen.radial(int(tw*0.7),(185,150,235),0.28)
    base.alpha_composite(halo2,((W-halo2.width)//2,int(H*0.46)-halo2.height//2))

    # composite hero (characters center ~y30-58%)
    px=(W-tw)//2; py=int(H*0.135)
    base.alpha_composite(hero,(px,py))

    # extra foreground sparkles for density
    import random; random.seed(77)
    d=ImageDraw.Draw(base)
    for _ in range(60):
        x=random.uniform(0,W); y=random.uniform(0,H*0.72); s=random.uniform(1,3)
        d.ellipse([x-s,y-s,x+s,y+s],fill=(255,250,235,random.randint(120,220)))
    for _ in range(8):
        x=random.uniform(60,W-60); y=random.uniform(40,H*0.6); r=random.uniform(5,10)
        base.alpha_composite(gen.radial(int(r*3),(255,245,220),0.5),(int(x-r*1.5),int(y-r*1.5)))
        d.line([x-r,y,x+r,y],fill=(255,250,235,200),width=2)
        d.line([x,y-r,x,y+r],fill=(255,250,235,200),width=2)

    out=base.convert("RGB")
    out.save(os.path.join(SP,"splash-poster-no-text.png"),"PNG")
    out.save(os.path.join(SP,"splash-poster-no-text.webp"),"WEBP",quality=90,method=6)
    out.resize((1440,2560),Image.LANCZOS).save(os.path.join(SP,"splash-poster-no-text@2x.webp"),"WEBP",quality=90,method=6)
    out.resize((720,1280),Image.LANCZOS).save(os.path.join(SP,"splash-poster-mobile.webp"),"WEBP",quality=88,method=6)
    print("구운 포스터 저장:")
    for f in sorted(os.listdir(SP)):
        if f.startswith("splash-poster"): print(f"  {f}  {os.path.getsize(os.path.join(SP,f)):,}B")

if __name__=="__main__": main()
