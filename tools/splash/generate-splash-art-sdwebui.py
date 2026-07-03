#!/usr/bin/env python3
"""
로컬 Stable Diffusion WebUI/Forge(:7860) txt2img로 no-text 포스터 후보 생성.
서버 없으면 프롬프트/설정만 출력. Usage: python3 tools/splash/generate-splash-art-sdwebui.py [--n 4]
"""
import os,sys,json,base64,argparse,urllib.request
ROOT=os.path.normpath(os.path.join(os.path.dirname(__file__),"..",".."))
SP=os.path.join(ROOT,"assets","splash","candidates"); os.makedirs(SP,exist_ok=True)
SD=os.environ.get("SD_WEBUI_URL","http://127.0.0.1:7860")
POS=("Vertical 9:16 premium mobile casual game title splash illustration, no text, no logo, "
 "two adorable quokka bear couple mascots traveling, warm caramel and honey cream fur, big glossy eyes, "
 "rosy cheeks, green travel cap, backpack, camera, pink scarf, crossbody bag, ticket, standing on a tiny "
 "floating world diorama planet, green grass islands, blue ocean, miniature Korean palace, N Seoul Tower, "
 "Eiffel-like tower, cute rocket, pastel galaxy sky, dreamy stars, glowing planets, magical sparkles, "
 "high-end 3D clay render, toy diorama, empty top and bottom for UI, pastel blue lavender peach mint cream palette")
NEG=("text, letters, Korean letters, logo, watermark, UI, button, low quality, blurry, flat vector, "
 "primitive shapes, simple blue ball, plain sphere, deformed face, extra limbs, creepy, gray background")
def up():
    try: urllib.request.urlopen(SD+"/sdapi/v1/sd-models",timeout=3); return True
    except: return False
def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--n",type=int,default=4); a=ap.parse_args()
    print("Positive:\n",POS,"\n\nNegative:\n",NEG,"\n")
    if not up():
        print(f"SD WebUI({SD}) 미실행 → 프롬프트만 출력. 서버 켜고 재실행하세요."); return
    payload={"prompt":POS,"negative_prompt":NEG,"width":1024,"height":1792,"steps":32,
             "cfg_scale":6,"sampler_name":"DPM++ 2M Karras","batch_size":1,"n_iter":a.n}
    req=urllib.request.Request(SD+"/sdapi/v1/txt2img",data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json"})
    print(f"{a.n}장 생성 중...")
    r=json.load(urllib.request.urlopen(req,timeout=600))
    for i,b in enumerate(r.get("images",[])):
        p=os.path.join(SP,f"candidate_{i}.png")
        open(p,"wb").write(base64.b64decode(b.split(",",1)[-1])); print("  저장:",p)
    print("후보 검토 후 import: python3 tools/splash/import-splash-art.py --file <best>.png")
if __name__=="__main__": main()
