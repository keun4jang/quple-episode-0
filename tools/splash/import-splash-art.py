#!/usr/bin/env python3
"""
외부 no-text 포스터 이미지를 스플래시 프로덕션 슬롯으로 import.
Usage:
  SPLASH_ART_URL='https://.../poster.png' python3 tools/splash/import-splash-art.py
  python3 tools/splash/import-splash-art.py --url 'https://.../poster.png'
  python3 tools/splash/import-splash-art.py --file /path/local.png

동작: 원본 저장 → 1080x1920/1440x2560/720x1280 WebP 생성 → PNG 갱신 → manifest 업데이트.
production 권장 = no-text 이미지. 텍스트 감지 시 경고만 남기고 저장은 진행.
"""
import os, sys, json, urllib.request, argparse
from PIL import Image

ROOT=os.path.normpath(os.path.join(os.path.dirname(__file__),"..",".."))
SP=os.path.join(ROOT,"assets","splash"); SRC=os.path.join(SP,"source")
os.makedirs(SRC,exist_ok=True)

def fetch(url,dst):
    req=urllib.request.Request(url,headers={"User-Agent":"quple-splash-import/1.0"})
    with urllib.request.urlopen(req,timeout=60) as r, open(dst,"wb") as f:
        f.write(r.read())

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--url",default=os.environ.get("SPLASH_ART_URL",""))
    ap.add_argument("--file",default="")
    a=ap.parse_args()
    orig=os.path.join(SRC,"splash-poster-original.png")
    if a.file:
        Image.open(a.file).convert("RGBA").save(orig,"PNG"); print(f"로컬 파일 로드: {a.file}")
    elif a.url:
        print(f"다운로드: {a.url}"); fetch(a.url,orig); print(f"  저장: {orig}")
    else:
        print("ERROR: --url 또는 --file 또는 SPLASH_ART_URL 필요"); sys.exit(1)

    im=Image.open(orig).convert("RGB")
    print(f"원본 크기: {im.size}")
    # portrait 9:16 center-crop-fit to 1080x1920
    def fit916(img,w,h):
        tw,th=w,h; iw,ih=img.size
        s=max(tw/iw,th/ih); nw,nh=int(iw*s),int(ih*s)
        img2=img.resize((nw,nh),Image.LANCZOS)
        x=(nw-tw)//2; y=(nh-th)//2
        return img2.crop((x,y,x+tw,y+th))
    base=fit916(im,1080,1920)
    base.save(os.path.join(SP,"splash-poster-no-text.png"),"PNG")
    base.save(os.path.join(SP,"splash-poster-no-text.webp"),"WEBP",quality=90,method=6)
    fit916(im,1440,2560).save(os.path.join(SP,"splash-poster-no-text@2x.webp"),"WEBP",quality=90,method=6)
    fit916(im,720,1280).save(os.path.join(SP,"splash-poster-mobile.webp"),"WEBP",quality=88,method=6)
    print("  생성: no-text.png/.webp, @2x.webp, mobile.webp")

    # manifest
    mp=os.path.join(SP,"splash-art-manifest.json")
    m=json.load(open(mp)) if os.path.exists(mp) else {}
    m.update({"source":"imported","importedFrom":a.url or a.file,"isInterim":False,
              "hasText":"UNKNOWN — 반드시 no-text 확인","focalPoint":[0.5,0.46],
              "poster":{"path":"res://assets/splash/splash-poster-no-text.png","width":1080,"height":1920}})
    json.dump(m,open(mp,"w"),ensure_ascii=False,indent=2)
    print("  manifest 업데이트")
    print("\n⚠ 이미지에 텍스트/로고가 있으면 production에 부적합. no-text 확인 권장.")
    print("완료. Godot 스플래시가 자동으로 새 포스터를 사용합니다.")

if __name__=="__main__": main()
