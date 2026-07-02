#!/usr/bin/env python3
"""
퀴풀 스플래시 포스터 배경 생성 (텍스트 없음)
파스텔 우주 은하 + 미니월드 디오라마. 상단/하단 UI 세이프존 확보.
Usage: python3 tools/splash/generate-splash-assets.py
출력: assets/splash/splash-poster-no-text.png/.webp (+ @2x)
"""
from PIL import Image, ImageDraw, ImageFilter
import math, os, random

random.seed(20260702)
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "splash"))
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def radial(size, col, a0=1.0):
    """soft radial glow RGBA tile."""
    img = Image.new("RGBA",(size,size),(0,0,0,0)); px=img.load(); c=size/2
    for y in range(size):
        for x in range(size):
            d=math.hypot(x-c,y-c)/c
            v=max(0.0,1.0-d); v=v*v
            px[x,y]=(col[0],col[1],col[2],int(255*v*a0))
    return img

def paste_glow(base, cx, cy, r, col, a=1.0):
    g=radial(max(8,int(r*2)), col, a)
    base.alpha_composite(g,(int(cx-r),int(cy-r)))

def make_poster(w,h):
    img=Image.new("RGBA",(w,h),(0,0,0,255))
    px=img.load()
    # 1) vertical pastel cosmic gradient
    top=(18,20,58); mid=(46,32,92); mid2=(74,54,120); low=(58,70,120); bot=(40,52,96)
    for y in range(h):
        t=y/h
        if t<0.32: c=lerp(top,mid,t/0.32)
        elif t<0.60: c=lerp(mid,mid2,(t-0.32)/0.28)
        elif t<0.82: c=lerp(mid2,low,(t-0.60)/0.22)
        else: c=lerp(low,bot,(t-0.82)/0.18)
        for x in range(w): px[x,y]=(c[0],c[1],c[2],255)
    # 2) nebula soft blobs (pastel lavender/pink/mint/sky)
    neb=[((0.22,0.30),380,(150,120,220)),((0.78,0.24),340,(230,150,190)),
         ((0.5,0.46),460,(120,150,220)),((0.16,0.66),300,(120,200,180)),
         ((0.84,0.7),320,(200,150,210)),((0.5,0.9),420,(120,160,200))]
    scale=w/1080.0
    for (fx,fy),r,col in neb:
        paste_glow(img, fx*w, fy*h, r*scale, col, 0.20)
    # 3) stars
    for _ in range(320):
        x=random.uniform(0,w); y=random.uniform(0,h)
        s=random.uniform(0.6,2.6)*scale
        b=random.uniform(0.5,1.0)
        col=random.choice([(255,255,255),(255,240,210),(210,225,255),(255,220,235)])
        d=ImageDraw.Draw(img)
        d.ellipse([x-s,y-s,x+s,y+s],fill=(col[0],col[1],col[2],int(230*b)))
    # bigger glowing stars w/ cross
    for _ in range(22):
        x=random.uniform(40,w-40); y=random.uniform(30,h*0.9)
        r=random.uniform(6,13)*scale
        paste_glow(img,x,y,r*2.4,(255,245,220),0.5)
        d=ImageDraw.Draw(img)
        d.line([x-r,y,x+r,y],fill=(255,250,235,220),width=max(1,int(1.5*scale)))
        d.line([x,y-r,x,y+r],fill=(255,250,235,220),width=max(1,int(1.5*scale)))
    # 4) small cute planets (upper region, safe from center)
    def planet(cx,cy,r,c1,c2,ring=None):
        sp=Image.new("RGBA",(int(r*4),int(r*4)),(0,0,0,0)); sd=ImageDraw.Draw(sp); C=r*2
        for yy in range(int(r*2)):
            t=yy/(r*2); c=lerp(c1,c2,t)
            sd.ellipse([C-r, C-r+yy, C+r, C-r+yy+1],fill=(c[0],c[1],c[2],255))
        m=Image.new("L",sp.size,0); md=ImageDraw.Draw(m); md.ellipse([C-r,C-r,C+r,C+r],fill=255)
        sp.putalpha(m)
        # highlight
        hd=ImageDraw.Draw(sp); hd.ellipse([C-r*0.5,C-r*0.6,C-r*0.05,C-r*0.15],fill=(255,255,255,60))
        img.alpha_composite(sp,(int(cx-C),int(cy-C)))
        if ring:
            rd=ImageDraw.Draw(img)
            rd.ellipse([cx-r*1.7,cy-r*0.5,cx+r*1.7,cy+r*0.5],outline=(ring[0],ring[1],ring[2],200),width=max(2,int(4*scale)))
    planet(w*0.20,h*0.15,34*scale,(255,200,150),(220,120,120))
    planet(w*0.83,h*0.12,26*scale,(160,220,210),(90,150,180))
    planet(w*0.86,h*0.42,40*scale,(210,180,240),(150,110,200),ring=(255,230,180))
    # shooting stars
    for (x0,y0,ln,ang) in [(w*0.3,h*0.1,120,20),(w*0.7,h*0.33,100,200)]:
        d=ImageDraw.Draw(img)
        x1=x0+ln*scale*math.cos(math.radians(ang)); y1=y0+ln*scale*math.sin(math.radians(ang))
        for i in range(int(ln*scale)):
            t=i/(ln*scale)
            xx=x0+(x1-x0)*t; yy=y0+(y1-y0)*t
            d.ellipse([xx-2,yy-2,xx+2,yy+2],fill=(255,250,235,int(200*(1-t))))
        paste_glow(img,x0,y0,18*scale,(255,250,235),0.6)

    # 5) 중앙 히어로 자리 (실제 캐릭터+행성은 hero-diorama 에셋이 담당) — 은은한 glow만
    paste_glow(img, w*0.5, h*0.46, 520*scale, (255,238,200), 0.30)
    paste_glow(img, w*0.5, h*0.52, 360*scale, (180,150,230), 0.20)
    # 6) vignette edges
    vg=Image.new("L",(w,h),0); vd=ImageDraw.Draw(vg)
    vd.ellipse([-w*0.25,-h*0.15,w*1.25,h*1.15],fill=255)
    vg=vg.filter(ImageFilter.GaussianBlur(160))
    dark=Image.new("RGBA",(w,h),(8,6,26,150))
    inv=Image.eval(vg,lambda a:255-a)
    dark.putalpha(inv)
    img.alpha_composite(dark)

    # subtle overall glow bloom pass
    bloom=img.filter(ImageFilter.GaussianBlur(6))
    img=Image.blend(img,bloom,0.12)
    return img.convert("RGB")

def main():
    print("포스터 생성 1080x1920...")
    base=make_poster(W,H)
    p_png=os.path.join(OUT,"splash-poster-no-text.png")
    base.save(p_png,"PNG")
    base.save(os.path.join(OUT,"splash-poster-no-text.webp"),"WEBP",quality=88,method=6)
    print(f"  {p_png} ({os.path.getsize(p_png):,}B)")
    # @2x
    print("포스터 @2x 1440x2560...")
    big=base.resize((1440,2560), Image.LANCZOS)
    big.save(os.path.join(OUT,"splash-poster-no-text@2x.webp"),"WEBP",quality=88,method=6)
    # 720 fallback
    small=base.resize((720,1280), Image.LANCZOS)
    small.save(os.path.join(OUT,"splash-poster-no-text@720.webp"),"WEBP",quality=86,method=6)
    print("완료")
    for f in os.listdir(OUT):
        print("  ",f, f"{os.path.getsize(os.path.join(OUT,f)):,}B")

if __name__=="__main__":
    main()
