#!/usr/bin/env python3
"""
퀴카 커플 HERO DIORAMA 렌더러 v1.0
캐릭터 + 미니월드 행성을 하나의 장면으로 통합 렌더 (공유 조명, 접지 그림자).
기존 render-quica-mascots.py의 빌드 함수 재사용.
Usage: python3 tools/mascot/render-quica-hero-diorama.py
출력: assets/mascots/quica-hero-diorama.png/.webp/@2x, closeup, thumbnail-test, contact-sheet, previews
"""
import bpy, math, os

HERE=os.path.dirname(os.path.abspath(__file__))
MOD=os.path.join(HERE,"render-quica-mascots.py")
OUT=os.path.normpath(os.path.join(HERE,"..","..","assets","mascots"))
os.makedirs(OUT,exist_ok=True)
def P(n): return os.path.join(OUT,n)

# import build funcs from mascots module
_src=open(MOD).read().replace("\nmain()\n","\n")
G={"__file__":MOD}
exec(_src,G)
M=G["M"]; sph=G["sph"]; box=G["box"]; tor=G["tor"]; cyl=G["cyl"]; C=G["C"]
reset=G["reset"]; build_leader=G["build_leader"]; build_partner=G["build_partner"]
setup_lights=G["setup_lights"]; h2c=G["h2c"]

def cone(name,loc,r,h,mat,rot=None):
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=r,radius2=0,depth=h,location=loc)
    o=bpy.context.active_object; o.name=name
    if rot:o.rotation_euler=rot
    bpy.ops.object.shade_smooth(); o.data.materials.append(mat); return o

def shift(objs,dx=0,dy=0,dz=0):
    for o in objs: o.location.x+=dx;o.location.y+=dy;o.location.z+=dz

# ── MINI WORLD PLANET (diorama) ─────────────────────────────────────────────
def build_planet(cz):
    """행성 top이 z=cz 근처. 캐릭터가 그 위에 섬."""
    o=[]
    R=2.05
    pcx,pcy,pcz=0,0,cz-R  # center below so top at cz
    ocean=M("pl_ocean",h2c("#3FA9E0"),rough=0.5,spec=0.25,sub=0.0)
    o.append(sph("planet",(pcx,pcy,pcz),(R,R,R),ocean,seg=64))
    # ocean darker deep ring (bottom)
    o.append(sph("planet_deep",(pcx,pcy,pcz-0.05),(R*0.99,R*0.99,R*0.99),
                 M("pl_deep",h2c("#2C7FC0"),rough=0.55),seg=48))
    grass=M("pl_grass",h2c("#6FCF63"),rough=0.8,sub=0.05)
    grass2=M("pl_grass2",h2c("#57B94E"),rough=0.82)
    sand=M("pl_sand",h2c("#EAD9A8"),rough=0.85)
    # grass islands (flattened caps on top hemisphere, front -Y)
    isl=[(-0.1,-0.15,1.55,0.55,1.25),(-1.05,0.25,0.95,0.4,0.9),
         (0.95,0.15,0.9,0.42,0.95),(0.15,1.0,1.0,0.4,0.85),(-0.6,-0.9,0.85,0.35,0.8)]
    for i,(ix,iy,sx,sz,sy) in enumerate(isl):
        # position on sphere top
        px=ix; py=iy; pz=cz-0.02 - (ix*ix+iy*iy)*0.14
        o.append(sph(f"isl{i}",(px,py,pz),(sx*0.62,sy*0.62,sz*0.30),
                     grass if i%2==0 else grass2,seg=32))
    # beach ring on main island
    o.append(sph("beach",(-0.1,-0.15,cz-0.05),(1.05,0.85,0.22),sand,seg=32))
    o.append(sph("isl_main",(-0.1,-0.2,cz+0.02),(0.95,0.78,0.30),grass,seg=40))
    # river/lake (small blue flat)
    o.append(sph("lake",(0.35,-0.35,cz+0.10),(0.28,0.20,0.10),
                 M("pl_lake",h2c("#5FC0EE"),rough=0.4,spec=0.4),seg=24))
    # trees (8+) — two-tone cones
    tcol=M("tree",h2c("#3E9E56"),rough=0.85); tcol2=M("tree2",h2c("#57B96A"),rough=0.85)
    trunk=M("trunk",h2c("#7A5232"),rough=0.9)
    tpos=[(-0.55,-0.45),(-0.35,-0.6),(-0.7,-0.25),(0.55,-0.35),(0.7,-0.15),
          (0.4,-0.55),(-0.15,-0.7),(0.15,-0.5),(-0.9,0.1),(0.9,0.05)]
    for i,(tx,ty) in enumerate(tpos):
        tz=cz+0.10-(tx*tx+ty*ty)*0.10
        o.append(cyl(f"trunk{i}",(tx,ty,tz),(0.03,0.03,0.10),(0,0,0),trunk))
        o.append(cone(f"tree{i}a",(tx,ty,tz+0.22),0.17,0.34,tcol if i%2 else tcol2))
        o.append(cone(f"tree{i}b",(tx,ty,tz+0.40),0.12,0.26,tcol2 if i%2 else tcol))
    # HANOK (Korean building) center-back
    hb=M("hanok_b",h2c("#E6D8BE"),rough=0.85); hr=M("hanok_r",h2c("#C0504A"),rough=0.7)
    hx,hy,hz=-0.1,0.35,cz+0.18
    o.append(box(f"hanok_body",(hx,hy,hz+0.10),(0.28,0.20,0.14),hb,bv=0.02))
    # roof (wide flattened wedge)
    o.append(box("hanok_roof",(hx,hy,hz+0.26),(0.40,0.30,0.05),hr,bv=0.03))
    o.append(box("hanok_roof2",(hx,hy,hz+0.32),(0.30,0.22,0.04),hr,bv=0.03))
    for cxp in (-0.16,-0.05,0.06,0.17):
        o.append(cyl(f"pillar{cxp}",(hx+cxp,hy-0.19,hz+0.06),(0.018,0.018,0.10),(0,0,0),
                     M("pillar",h2c("#9A6E44"),rough=0.85)))
    # TOWER (N Seoul inspired) right island
    tw=M("tower",h2c("#C8CCD6"),rough=0.5,spec=0.3)
    twx,twy,twz=0.95,0.1,cz+0.12
    o.append(cyl("tower_pole",(twx,twy,twz+0.35),(0.035,0.035,0.42),(0,0,0),tw))
    o.append(sph("tower_pod",(twx,twy,twz+0.78),(0.13,0.13,0.10),tw,seg=28))
    o.append(cyl("tower_spire",(twx,twy,twz+0.98),(0.012,0.012,0.16),(0,0,0),
                 M("spire",h2c("#E07070"),rough=0.6)))
    # ROCKET left island
    rk=M("rocket",h2c("#F2F2F5"),rough=0.5,spec=0.35); rkf=M("rfin",h2c("#E06B6B"),rough=0.6)
    rx,ry,rz=-1.0,0.2,cz+0.30
    o.append(sph("rocket_body",(rx,ry,rz+0.18),(0.10,0.10,0.26),rk,seg=28))
    o.append(cone("rocket_top",(rx,ry,rz+0.46),0.10,0.18,rkf))
    o.append(cone("rocket_finL",(rx-0.10,ry,rz-0.02),0.07,0.18,rkf,rot=(0,math.radians(20),0)))
    o.append(cone("rocket_finR",(rx+0.10,ry,rz-0.02),0.07,0.18,rkf,rot=(0,math.radians(-20),0)))
    o.append(sph("rocket_win",(rx,ry-0.09,rz+0.24),(0.045,0.03,0.045),
                 M("rwin",h2c("#7EC8F0"),rough=0.2,spec=0.6),seg=20))
    # CLOUDS floating (white, above planet, sides)
    cl=M("cloud",h2c("#FBFCFF"),rough=0.9,sub=0.1)
    for i,(cx,cy,cze,s) in enumerate([(-1.7,-0.6,cz+1.4,0.9),(1.75,-0.5,cz+1.1,0.8),(1.5,-0.7,cz+1.9,0.7)]):
        for dx in (-0.22,0,0.22):
            o.append(sph(f"cloud{i}_{dx}",(cx+dx*s,cy,cze),(0.20*s,0.14*s,0.14*s),cl,seg=24))
    return o

def contact_shadow(x,y,z):
    m=M("cshadow",(0.02,0.02,0.05),rough=1.0,alpha=0.5)
    return sph("cshadow",(x,y,z),(0.42,0.30,0.02),m,seg=24)

def add_cam(scale,loc,target):
    sc=bpy.context.scene
    cd=bpy.data.cameras.new("C");cd.type="ORTHO";cd.ortho_scale=scale
    co=bpy.data.objects.new("C",cd);co.location=loc;sc.collection.objects.link(co);sc.camera=co
    e=bpy.data.objects.new("T",None);e.location=target;sc.collection.objects.link(e)
    t=co.constraints.new("TRACK_TO");t.target=e;t.track_axis="TRACK_NEGATIVE_Z";t.up_axis="UP_Y"
    return co,e
def rm(co,e):
    bpy.data.objects.remove(co,do_unlink=True);bpy.data.objects.remove(e,do_unlink=True)
def rset(w,h,samp=110):
    sc=bpy.context.scene
    sc.render.engine="CYCLES";sc.cycles.device="CPU";sc.cycles.samples=samp
    sc.render.film_transparent=True
    sc.render.image_settings.file_format="PNG";sc.render.image_settings.color_mode="RGBA"
    sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.resolution_percentage=100
def render(fp):
    bpy.context.scene.render.filepath=fp;bpy.ops.render.render(write_still=True)
    print(f"  -> {os.path.basename(fp)} ({os.path.getsize(fp):,}B)")
def vis(show,hide):
    for o in show:o.hide_render=False;o.hide_viewport=False
    for o in hide:o.hide_render=True;o.hide_viewport=True

def main():
    print("=== HERO DIORAMA v1.0 ===")
    reset();sc=bpy.context.scene
    w=bpy.data.worlds.new("W");w.use_nodes=True;sc.world=w
    bg=w.node_tree.nodes.get("Background")
    if bg:bg.inputs[0].default_value=(0.05,0.05,0.09,1)

    FEET=0.0
    print("행성 빌드..."); planet=build_planet(FEET)
    print("캐릭터 빌드...")
    la=build_leader(0.0); pa=build_partner(0.0)
    # place couple on planet top, apart, upright
    shift(la, dx=-0.82, dz=FEET+0.12)
    shift(pa, dx= 0.82, dz=FEET+0.12)
    # contact shadows under feet
    cs1=contact_shadow(-0.82,-0.30,FEET+0.02)
    cs2=contact_shadow( 0.82,-0.30,FEET+0.02)
    setup_lights()

    allobj=planet+la+pa+[cs1,cs2]

    # HERO (portrait, transparent, 3/4-front)
    print("[1] hero diorama"); vis(allobj,[])
    rset(1600,2000,120)
    co,e=add_cam(5.4,(1.1,-10,1.7),(0,0,0.55)); render(P("quica-hero-diorama.png")); rm(co,e)

    # CLOSEUP (faces)
    print("[2] couple closeup"); rset(1200,1200,110)
    co,e=add_cam(3.0,(0.5,-10,1.7),(0,0,1.25)); render(P("quica-couple-closeup.png")); rm(co,e)

    # WebP + @2x + previews + thumbnails + contact sheet
    print("최적화/검수 이미지...")
    try:
        from PIL import Image
        hero=Image.open(P("quica-hero-diorama.png")).convert("RGBA")
        hero.convert("RGB").save(P("quica-hero-diorama.webp"),"WEBP",quality=90,method=6)
        hero.resize((hero.width*2//2, hero.height),Image.LANCZOS)  # keep
        hero2=hero.resize((min(2400,hero.width*3//2),min(3000,hero.height*3//2)),Image.LANCZOS)
        hero2.convert("RGB").save(P("quica-hero-diorama@2x.webp"),"WEBP",quality=90,method=6)
        # previews on dark / white
        for bgc,tag in [((14,12,30,255),"dark"),((246,242,234,255),"white")]:
            c=Image.new("RGBA",hero.size,bgc);c.paste(hero,mask=hero)
            c.convert("RGB").save(P(f"quica-hero-diorama-preview-{tag}.png"))
        # thumbnail test row 64/128/256
        row=Image.new("RGBA",(64+128+256+40,300),(245,240,232,255))
        x=8
        for s in (64,128,256):
            t=hero.resize((int(s*hero.width/hero.height),s),Image.LANCZOS)
            row.paste(t,(x,300-s-8),t); x+=t.width+8
        row.save(P("quica-thumbnail-test.png"))
        # contact sheet
        cw,ch=520,650; sheet=Image.new("RGBA",(cw*3,ch),(244,240,232,255))
        from PIL import ImageDraw; d=ImageDraw.Draw(sheet)
        items=[(P("quica-hero-diorama.png"),"Hero"),(P("quica-couple-closeup.png"),"Closeup"),
               (P("quica-hero-diorama-preview-dark.png"),"On Dark")]
        for i,(fp,lb) in enumerate(items):
            im=Image.open(fp).convert("RGBA")
            bgc=Image.new("RGBA",im.size,(244,240,232,255));bgc.paste(im,mask=im)
            bgc.thumbnail((cw-16,ch-40),Image.LANCZOS)
            sheet.paste(bgc,(i*cw+(cw-bgc.width)//2,30))
            d.rectangle([i*cw,0,(i+1)*cw-1,ch-1],outline=(200,195,185,255),width=2)
            d.text((i*cw+10,8),lb,fill=(80,70,60,255))
        sheet.save(P("quica-contact-sheet.png"))
        print("  thumbnails/contact-sheet/previews OK")
    except Exception as ex:
        print("  최적화 실패:",ex)

    # face verification on closeup
    try:
        from PIL import Image; import numpy as np
        arr=np.array(Image.open(P("quica-couple-closeup.png")).convert("RGBA"))
        a=arr[:,:,3];rows=np.any(a>50,axis=1);cols=np.any(a>50,axis=0)
        rmin,rmax=np.where(rows)[0][[0,-1]];cmin,cmax=np.where(cols)[0][[0,-1]]
        f=arr[rmin:rmin+int((rmax-rmin)*0.6),cmin:cmax];fa=f[:,:,3]>100;rgb=f[:,:,:3]
        white=((rgb[:,:,0]>235)&(rgb[:,:,1]>235)&(rgb[:,:,2]>235)&fa).sum()
        dark=((rgb[:,:,0]<95)&(rgb[:,:,1]<70)&(rgb[:,:,2]<75)&fa).sum()
        print(f"  [검수] closeup 눈={white} 코/동공={dark} -> {'PASS' if white>20 and dark>40 else 'CHECK'}")
    except Exception as ex: print("  검수 오류",ex)
    print("완료")

main()
