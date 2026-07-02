#!/usr/bin/env python3
"""
퀴카 커플 3D 마스코트 렌더러 v6.0 - FACE-FORWARD
bpy 5.0.1 (pip) / Cycles CPU

좌표계 규약 (엄격):
  - 캐릭터 정면 = -Y 방향
  - 카메라 = -Y 쪽(캐릭터 앞)에 위치, Track-To로 얼굴 응시
  - 모든 얼굴 요소(눈/코/입/볼/muzzle)는 머리의 -Y 표면에 배치
  - 렌더 후 얼굴 가시성 자동 검수 (흰자/동공/볼터치 픽셀 카운트)

Usage: python3 tools/mascot/render-quica-mascots.py
"""
import bpy, math, os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR    = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "..", "assets", "mascots"))
os.makedirs(OUT_DIR, exist_ok=True)
def P(n): return os.path.join(OUT_DIR, n)

def h2c(h):
    h=h.lstrip("#"); return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))

C = dict(
    A_fur=h2c("#B47338"), A_hi=h2c("#CE8C4E"), A_sh=h2c("#8A551F"),
    B_fur=h2c("#D6A24E"), B_hi=h2c("#E8BE72"), B_sh=h2c("#B07C34"),
    belly=h2c("#FFE8BD"), muzzle=h2c("#FFF0D5"), ear_in=h2c("#F5AFA8"),
    cheek=h2c("#FF8FA3"),
    eye_w=h2c("#FBFAF7"), eye_ir=h2c("#4A2A16"), eye_pu=h2c("#160A04"),
    eye_h=h2c("#FFFFFF"), eye_h2=h2c("#CFE6FF"),
    brow=h2c("#7A4A26"),
    nose=h2c("#221008"), mouth=h2c("#7A3418"), nose_hi=h2c("#8A5C46"),
    cap=h2c("#218F4E"), cap_dk=h2c("#166034"), cap_hi=h2c("#49B66C"),
    cap_band=h2c("#1A7A42"), badge=h2c("#FFE57A"), badge_dk=h2c("#E0B840"),
    bp=h2c("#3A7AC8"), bp_dk=h2c("#2A5898"), bp_hi=h2c("#66A6E6"),
    cam=h2c("#1F2636"), cam_ln=h2c("#0D1322"), cam_hi=h2c("#7488B8"),
    strap=h2c("#2A5888"),
    scarf=h2c("#F05E9B"), scarf_dk=h2c("#C0307A"), scarf_hi=h2c("#FF91C2"),
    bag=h2c("#B17A3E"), bag_dk=h2c("#845A28"), bag_hi=h2c("#D89858"),
    buckle=h2c("#E8C868"),
    ticket=h2c("#FFF8D8"), tick_l=h2c("#D0A848"), star=h2c("#FFD840"),
    map_c=h2c("#EAD9B0"), map_l=h2c("#B08850"),
)

def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)

def M(name,col,rough=0.82,spec=0.10,sub=0.0,alpha=1.0,bump=0.0,emit=0.0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; b=nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1.0)
    b.inputs["Roughness"].default_value=rough
    b.inputs["Specular IOR Level"].default_value=spec
    if emit>0:
        b.inputs["Emission Color"].default_value=(*col,1.0)
        b.inputs["Emission Strength"].default_value=emit
    if sub>0:
        b.inputs["Subsurface Weight"].default_value=sub
        b.inputs["Subsurface Radius"].default_value=(0.10,0.07,0.05)
    if alpha<1.0:
        b.inputs["Alpha"].default_value=alpha; m.blend_method="BLEND"
    if bump>0:  # subtle clay noise bump
        tex=nt.nodes.new("ShaderNodeTexNoise"); tex.inputs["Scale"].default_value=18.0
        bmp=nt.nodes.new("ShaderNodeBump"); bmp.inputs["Strength"].default_value=bump
        nt.links.new(tex.outputs["Fac"], bmp.inputs["Height"])
        nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
    return m

def _finish(o,mat,smooth=True,subsurf=2):
    if smooth: bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    if subsurf>0:
        s=o.modifiers.new("S","SUBSURF"); s.levels=subsurf; s.render_levels=subsurf+1

def sph(name,loc,sc,mat,seg=48,rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0,segments=seg,ring_count=int(seg*2//3))
    o=bpy.context.active_object; o.name=name; o.scale=sc; o.location=loc
    if rot: o.rotation_euler=rot
    _finish(o,mat); return o

def box(name,loc,sc,mat,bv=0.05,rot=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o=bpy.context.active_object; o.name=name; o.scale=sc
    if rot: o.rotation_euler=rot
    bpy.ops.object.shade_smooth(); o.data.materials.append(mat)
    b=o.modifiers.new("B","BEVEL"); b.width=bv; b.segments=4
    s=o.modifiers.new("S","SUBSURF"); s.levels=1; s.render_levels=2
    return o

def tor(name,loc,sc,rot,mat,maj=0.30,mn=0.07):
    bpy.ops.mesh.primitive_torus_add(location=loc,rotation=rot,
        major_radius=maj,minor_radius=mn,major_segments=48,minor_segments=18)
    o=bpy.context.active_object; o.name=name; o.scale=sc
    bpy.ops.object.shade_smooth(); o.data.materials.append(mat); return o

def cyl(name,loc,sc,rot,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,location=loc,rotation=rot)
    o=bpy.context.active_object; o.name=name; o.scale=sc
    bpy.ops.object.shade_smooth(); o.data.materials.append(mat)
    b=o.modifiers.new("B","BEVEL"); b.width=0.02; b.segments=3; return o

# ── FACE (front = -Y).  hy = head center Y (0), hz = head center Z ──────────────
def build_face(pfx, hx, hz, fur_c, is_leader):
    """모든 요소를 머리 -Y 표면에 배치. 리스트 반환."""
    o=[]
    # eye whites - 큰 납작 타원, 강하게 전면 돌출
    for sx,tag in [(-1,"L"),(1,"R")]:
        ex=hx+sx*0.185
        ms=M(f"{pfx}esc{tag}",C["eye_w"],rough=0.5,spec=0.2,emit=0.35)
        o.append(sph(f"{pfx}esc{tag}",(ex,-0.470,hz+0.055),(0.120,0.058,0.145),ms))
        # iris
        mi=M(f"{pfx}ir{tag}",C["eye_ir"],rough=0.14,spec=0.7)
        o.append(sph(f"{pfx}ir{tag}",(ex,-0.505,hz+0.040),(0.086,0.048,0.098),mi,seg=40))
        # pupil
        mp=M(f"{pfx}pu{tag}",C["eye_pu"],rough=0.85,spec=0.05)
        o.append(sph(f"{pfx}pu{tag}",(ex,-0.528,hz+0.030),(0.052,0.032,0.058),mp,seg=32))
        # big highlight
        mh=M(f"{pfx}h1{tag}",C["eye_h"],rough=0.0,spec=1.0,emit=0.8)
        o.append(sph(f"{pfx}h1{tag}",(ex-0.030*sx,-0.552,hz+0.080),(0.036,0.024,0.038),mh,seg=24))
        # small blue highlight
        mh2=M(f"{pfx}h2{tag}",C["eye_h2"],rough=0.0,spec=1.0)
        o.append(sph(f"{pfx}h2{tag}",(ex+0.020*sx,-0.545,hz-0.008),(0.016,0.011,0.016),mh2,seg=16))
        # upper lid shadow (thin dark arc above eye)
        mls=M(f"{pfx}lid{tag}",C["brow"],rough=0.8,alpha=0.5)
        o.append(sph(f"{pfx}lid{tag}",(ex,-0.452,hz+0.150),(0.120,0.030,0.038),mls))
        # brow
        mb=M(f"{pfx}brow{tag}",C["brow"],rough=0.85,alpha=0.75)
        o.append(sph(f"{pfx}brow{tag}",(ex,-0.430,hz+0.210),(0.100,0.028,0.030),mb,
                     rot=(0,math.radians(sx*8),0)))
        # cheek blush - 납작 핑크 디스크, 전면 돌출
        mck=M(f"{pfx}ck{tag}",C["cheek"],rough=0.9,spec=0.0,alpha=0.55)
        o.append(sph(f"{pfx}ck{tag}",(hx+sx*0.320,-0.410,hz-0.100),(0.078,0.022,0.058),mck,seg=24))
    # muzzle (크림, 눈보다 아래, 중앙)
    mmz=M(f"{pfx}mz",C["muzzle"],rough=0.78,sub=0.10)
    o.append(sph(f"{pfx}mz",(hx,-0.450,hz-0.155),(0.245,0.140,0.180),mmz))
    # nose
    mn=M(f"{pfx}no",C["nose"],rough=0.92,spec=0.0)
    o.append(sph(f"{pfx}no",(hx,-0.640,hz-0.090),(0.092,0.062,0.072),mn,seg=28))
    mnh=M(f"{pfx}noh",C["nose_hi"],rough=0.2,spec=0.85)
    o.append(sph(f"{pfx}noh",(hx-0.026,-0.672,hz-0.068),(0.028,0.018,0.020),mnh,seg=18))
    # mouth - curve (bezier w/ bevel) small smile
    mm=M(f"{pfx}mo",C["mouth"],rough=0.6)
    for dx,rz in [(-0.070,0.42),(0.070,-0.42)]:
        o.append(box(f"{pfx}mo",(hx+dx,-0.600,hz-0.210),(0.020,0.014,0.036),mm,bv=0.012,
                     rot=(0,0,rz)))
    # philtrum
    o.append(box(f"{pfx}ph",(hx,-0.615,hz-0.168),(0.010,0.010,0.026),mm,bv=0.004))
    return o

def build_ears(pfx,hx,hz,fur_c,ear_c):
    o=[]
    mo=M(f"{pfx}eo",fur_c,rough=0.82,sub=0.04)
    mi=M(f"{pfx}ei",ear_c,rough=0.75,sub=0.06)
    for sx,tag in [(-1,"L"),(1,"R")]:
        ex=hx+sx*0.375
        o.append(sph(f"{pfx}e{tag}o",(ex,0.02,hz+0.315),(0.150,0.080,0.185),mo,
                     rot=(0,math.radians(sx*10),0)))
        o.append(sph(f"{pfx}e{tag}i",(ex,-0.05,hz+0.320),(0.096,0.045,0.128),mi,seg=32,
                     rot=(0,math.radians(sx*10),0)))
    return o

def build_body(pfx,fur_c,belly_c,ox):
    """pear-shaped: 넓은 하체 + 좁은 가슴."""
    o=[]
    mf=M(f"{pfx}bd",fur_c,rough=0.82,sub=0.07,bump=0.06)
    mfs=M(f"{pfx}bds",fur_c,rough=0.85,sub=0.05)
    mb=M(f"{pfx}bl",belly_c,rough=0.75,sub=0.08)
    # lower (wide)
    o.append(sph(f"{pfx}bd_low",(ox,0,0.34),(0.58,0.50,0.50),mf))
    # upper chest (narrow) -> pear
    o.append(sph(f"{pfx}bd_up",(ox,-0.02,0.72),(0.46,0.42,0.42),mf))
    # belly gradient patch
    o.append(sph(f"{pfx}belly",(ox,-0.30,0.44),(0.34,0.20,0.44),mb))
    return o

def build_limbs(pfx,fur_c,belly_c,ox,left_pose,right_pose):
    """left_pose/right_pose: 'down'|'up'  (arm)."""
    o=[]
    ma=M(f"{pfx}arm",fur_c,rough=0.82,sub=0.05)
    mfp=M(f"{pfx}fp",belly_c,rough=0.75)
    ml=M(f"{pfx}leg",fur_c,rough=0.84,sub=0.04)
    # arms
    def arm(tag,sx,pose):
        if pose=="up":
            o.append(sph(f"{pfx}a{tag}",(ox+sx*0.55,-0.05,0.72),(0.20,0.18,0.33),ma,
                         rot=(0,0,math.radians(-sx*34))))
            hz=0.98; hy=-0.10
            hx=ox+sx*0.62
        else:
            o.append(sph(f"{pfx}a{tag}",(ox+sx*0.58,0,0.58),(0.21,0.19,0.35),ma,
                         rot=(0,0,math.radians(-sx*20))))
            hz=0.32; hy=-0.02; hx=ox+sx*0.70
        # hand + fingers
        o.append(sph(f"{pfx}h{tag}",(hx,hy,hz),(0.155,0.135,0.135),ma,seg=32))
        for i,fx in enumerate((-0.05,0,0.05)):
            o.append(sph(f"{pfx}fg{tag}{i}",(hx+fx,hy-0.10,hz-0.02),(0.045,0.045,0.05),ma,seg=16))
        return (hx,hy,hz)
    lh=arm("L",-1,left_pose)
    rh=arm("R", 1,right_pose)
    # legs+feet+toes
    for sx in (-0.27,0.27):
        tag="L" if sx<0 else "R"
        o.append(sph(f"{pfx}lg{tag}",(ox+sx,0,0.08),(0.22,0.20,0.34),ml))
        o.append(sph(f"{pfx}ft{tag}",(ox+sx*1.2,-0.16,-0.12),(0.29,0.20,0.17),ml))
        o.append(sph(f"{pfx}fp{tag}",(ox+sx*1.2,-0.26,-0.15),(0.19,0.09,0.11),mfp,seg=32))
        for i,tx in enumerate((-0.09,0,0.09)):
            o.append(sph(f"{pfx}toe{tag}{i}",(ox+sx*1.2+tx,-0.30,-0.14),(0.04,0.04,0.045),mfp,seg=14))
    # tail
    o.append(sph(f"{pfx}tail",(ox,0.40,0.30),(0.17,0.14,0.14),ml,seg=24))
    return o,lh,rh

# ═══ LEADER (A) ═══
def build_leader(ox=0.0):
    o=[]
    fur=C["A_fur"]
    o+=build_body("A",fur,C["belly"],ox)
    o+=build_limbs("A",fur,C["belly"],ox,"down","up")[0]
    # head (ellipsoid)
    mh=M("Ahead",fur,rough=0.80,sub=0.08,bump=0.05)
    o.append(sph("Ahead",(ox,0,1.12),(0.53,0.50,0.51),mh))
    o+=build_ears("A",ox,1.12,fur,C["ear_in"])
    o+=build_face("A",ox,1.12,fur,True)

    # ── CAP (crown+brim+band+badge+highlight) ──
    mcp=M("Acap",C["cap"],rough=0.72,spec=0.10,bump=0.04)
    mcd=M("Acapd",C["cap_dk"],rough=0.80)
    mch=M("Acaph",C["cap_hi"],rough=0.68)
    mbn=M("Acband",C["cap_band"],rough=0.78)
    # crown
    o.append(sph("Acrown",(ox+0.02,0.08,1.62),(0.45,0.43,0.30),mcp))
    # band (torus around base of crown)
    o.append(tor("Aband",(ox+0.02,0.04,1.42),(1.0,0.92,0.5),
                 (math.radians(90),0,0),mbn,maj=0.44,mn=0.045))  # band
    # brim (front, -Y) - flattened forward disc
    o.append(sph("Abrim",(ox+0.02,-0.40,1.42),(0.40,0.24,0.045),mcd,rot=(math.radians(-12),0,0)))
    # brim shadow underside
    o.append(sph("Abrimsh",(ox+0.02,-0.34,1.39),(0.36,0.18,0.03),mcd,rot=(math.radians(-12),0,0)))
    # highlight streak
    o.append(sph("Acaphl",(ox-0.16,-0.06,1.66),(0.15,0.22,0.13),mch))
    # planet badge on crown front
    mbd=M("Abadge",C["badge"],rough=0.5,spec=0.3)
    mbdd=M("Abadged",C["badge_dk"],rough=0.55)
    o.append(sph("Abadge",(ox+0.06,-0.34,1.46),(0.08,0.05,0.085),mbd,seg=32))
    o.append(tor("Abadger",(ox+0.06,-0.36,1.46),(1,1,0.6),
                 (math.radians(80),0,0),mbdd,maj=0.10,mn=0.014))

    # ── BACKPACK (뒤+옆) ──
    mbp=M("Abp",C["bp"],rough=0.72,spec=0.08,bump=0.05)
    mbpd=M("Abpd",C["bp_dk"],rough=0.76)
    mbph=M("Abph",C["bp_hi"],rough=0.68)
    o.append(box("Abp",(ox-0.22,0.34,0.56),(0.22,0.16,0.30),mbp,bv=0.05))
    o.append(box("Abpf",(ox-0.22,0.34-0.16,0.42),(0.17,0.03,0.13),mbpd,bv=0.02))  # pocket faces... keep
    o.append(box("Abphl",(ox-0.34,0.30,0.66),(0.05,0.05,0.14),mbph,bv=0.02))
    mstr=M("Astr",C["strap"],rough=0.7)
    o.append(box("Astr1",(ox-0.40,0.10,0.80),(0.032,0.03,0.15),mstr,bv=0.01,rot=(0,0,math.radians(-8))))
    o.append(box("Astr2",(ox+0.38,0.10,0.80),(0.032,0.03,0.15),mstr,bv=0.01,rot=(0,0,math.radians(8))))

    # ── CAMERA (가슴 앞, 얼굴 안가림 - 낮게) ──
    mca=M("Acam",C["cam"],rough=0.42,spec=0.28)
    mcl=M("Acaml",C["cam_ln"],rough=0.06,spec=0.95)
    mcah=M("Acamh",C["cam_hi"],rough=0.05,spec=0.9)
    o.append(box("Acam",(ox,-0.42,0.58),(0.19,0.11,0.13),mca,bv=0.03))
    o.append(sph("Acamlens",(ox,-0.56,0.58),(0.088,0.06,0.088),mcl,seg=36))
    o.append(tor("Acamring",(ox,-0.55,0.58),(1,1,1),(math.radians(90),0,0),mca,maj=0.10,mn=0.02))
    o.append(sph("Acamgh",(ox-0.035,-0.60,0.61),(0.028,0.02,0.028),mcah,seg=20))
    o.append(box("Acamflash",(ox-0.13,-0.50,0.66),(0.035,0.02,0.028),mcah,bv=0.008))
    o.append(sph("Acamshut",(ox+0.13,-0.46,0.70),(0.028,0.02,0.022),mcah,seg=16))
    # strap: 어깨→카메라, 얼굴(-Y 상단) 통과 안함 (가슴 옆으로만)
    mcs=M("Acs",C["strap"],rough=0.68)
    o.append(box("Acs1",(ox+0.30,-0.30,0.86),(0.03,0.024,0.16),mcs,bv=0.01,rot=(0,0,math.radians(22))))
    o.append(box("Acs2",(ox-0.30,-0.30,0.86),(0.03,0.024,0.16),mcs,bv=0.01,rot=(0,0,math.radians(-22))))

    # ── 지도 (왼손, 아래로) ──
    mmp=M("Amap",C["map_c"],rough=0.85)
    mmpl=M("Amapl",C["map_l"],rough=0.8)
    o.append(box("Amap",(ox-0.70,-0.10,0.30),(0.12,0.02,0.09),mmp,bv=0.01,rot=(math.radians(20),0,math.radians(-10))))
    return o

# ═══ PARTNER (B) ═══
def build_partner(ox=0.0):
    o=[]
    fur=C["B_fur"]
    o+=build_body("B",fur,C["belly"],ox)
    o+=build_limbs("B",fur,C["belly"],ox,"up","down")[0]
    # head (soft Z-tilt only, face stays -Y forward)
    mh=M("Bhead",fur,rough=0.80,sub=0.08,bump=0.05)
    head=sph("Bhead",(ox,0,1.11),(0.51,0.48,0.49),mh)
    head.rotation_euler=(0,0,math.radians(5))  # roll only, face still forward
    o.append(head)
    o+=build_ears("B",ox,1.11,fur,C["ear_in"])
    o+=build_face("B",ox,1.11,fur,False)

    # ── SCARF (목, knot+loop+2 tails, 입 안가림 z<0.90) ──
    msc=M("Bsc",C["scarf"],rough=0.80,spec=0.06,bump=0.04)
    mscd=M("Bscd",C["scarf_dk"],rough=0.82)
    msch=M("Bsch",C["scarf_hi"],rough=0.74)
    # loop around neck
    o.append(tor("Bscloop",(ox,-0.02,0.86),(1.0,0.95,0.6),
                 (math.radians(82),0,0),msc,maj=0.34,mn=0.115))
    # front knot
    o.append(sph("Bknot",(ox+0.03,-0.34,0.82),(0.12,0.09,0.11),mscd))
    o.append(sph("Bknot2",(ox+0.03,-0.38,0.81),(0.085,0.06,0.075),msch))
    # tail 1 (left, long)
    for i,(dx,dz,rz) in enumerate([(-0.02,0.72,-8),(-0.06,0.60,-12),(-0.08,0.48,-8)]):
        o.append(box(f"BtA{i}",(ox+dx,-0.32,dz),(0.065,0.05,0.09),
                     msc if i%2==0 else mscd,bv=0.028,rot=(math.radians(-10),0,math.radians(rz))))
    # tail 2 (right, short)
    for i,(dx,dz,rz) in enumerate([(0.10,0.70,10),(0.12,0.58,12)]):
        o.append(box(f"BtB{i}",(ox+dx,-0.32,dz),(0.06,0.045,0.08),
                     msc if i%2==0 else mscd,bv=0.025,rot=(math.radians(-8),0,math.radians(rz))))

    # ── CROSSBODY BAG (옆, strap+body+flap+buckle+star) ──
    mbg=M("Bbg",C["bag"],rough=0.75,spec=0.08,bump=0.05)
    mbgd=M("Bbgd",C["bag_dk"],rough=0.78)
    mbk=M("Bbk",C["buckle"],rough=0.4,spec=0.4)
    o.append(box("Bbag",(ox+0.52,-0.10,0.42),(0.20,0.15,0.22),mbg,bv=0.045))
    o.append(box("Bflap",(ox+0.52,-0.26,0.50),(0.19,0.03,0.12),mbgd,bv=0.02))
    o.append(box("Bbuckle",(ox+0.52,-0.30,0.44),(0.05,0.02,0.04),mbk,bv=0.01))
    # strap crossing chest (앞으로 대각선)
    mss=M("Bss",C["bag_dk"],rough=0.7)
    for i,(dx,dz,rz) in enumerate([(-0.20,0.86,28),(0.05,0.72,20),(0.30,0.58,10)]):
        o.append(box(f"Bss{i}",(ox+dx,-0.30,dz),(0.032,0.026,0.13),mss,bv=0.01,rot=(0,0,math.radians(rz))))
    # star keyring
    mst=M("Bstar",C["star"],rough=0.45,spec=0.45)
    o.append(sph("Bstar",(ox+0.44,-0.28,0.30),(0.05,0.03,0.05),mst,seg=20))

    # ── TICKET (오른팔이 down이므로... 파트너는 왼팔 up -> 왼손 티켓) ──
    mtk=M("Btk",C["ticket"],rough=0.85,spec=0.04)
    mtkl=M("Btkl",C["tick_l"],rough=0.8)
    tk=box("Btk",(ox-0.62,-0.20,0.98),(0.12,0.03,0.17),mtk,bv=0.016,rot=(0,0,math.radians(-26)))
    o.append(tk)
    for dz in (-0.05,0.03):
        o.append(box(f"Btkl{dz}",(ox-0.62,-0.235,0.98+dz),(0.09,0.032,0.014),mtkl,bv=0.005,
                     rot=(0,0,math.radians(-26))))
    return o

# ── lighting ──
def setup_lights():
    sc=bpy.context.scene
    def area(n,e,c,loc,rot,size=3.5):
        ld=bpy.data.lights.new(n,"AREA"); ld.energy=e; ld.color=c; ld.size=size
        lo=bpy.data.objects.new(n,ld); lo.location=loc
        lo.rotation_euler=[math.radians(r) for r in rot]
        sc.collection.objects.link(lo); return lo
    # Key from front-upper-left (in -Y region so it lights the FACE)
    area("Key", 1300,(1.00,0.94,0.82),(-3,-6, 5),(58,0,-28))
    area("Fill", 380,(0.74,0.83,1.00),( 4,-4, 3),(65,0, 40))
    area("Rim",  620,(1.00,0.96,0.88),( 0, 6, 4),(35,0,  0))
    area("FaceFill",470,(1.0,0.96,0.90),(0,-7,1.4),(90,0,0),size=4.5)  # direct face fill

def add_cam(scale,loc,target):
    sc=bpy.context.scene
    cd=bpy.data.cameras.new("C"); cd.type="ORTHO"; cd.ortho_scale=scale
    co=bpy.data.objects.new("C",cd); co.location=loc
    sc.collection.objects.link(co); sc.camera=co
    emp=bpy.data.objects.new("Tgt",None); emp.location=target
    sc.collection.objects.link(emp)
    tc=co.constraints.new("TRACK_TO"); tc.target=emp
    tc.track_axis="TRACK_NEGATIVE_Z"; tc.up_axis="UP_Y"
    return co,emp

def rm_cam(co,emp):
    bpy.data.objects.remove(co,do_unlink=True)
    bpy.data.objects.remove(emp,do_unlink=True)

def rset(w,h,samp=64):
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=samp
    sc.render.film_transparent=True
    sc.render.image_settings.file_format="PNG"
    sc.render.image_settings.color_mode="RGBA"
    sc.render.resolution_x=w; sc.render.resolution_y=h
    sc.render.resolution_percentage=100

def render(fp):
    bpy.context.scene.render.filepath=fp
    bpy.ops.render.render(write_still=True)
    print(f"  -> {os.path.basename(fp)} ({os.path.getsize(fp):,}B)")

def vis(show,hide):
    for o in show: o.hide_render=False; o.hide_viewport=False
    for o in hide: o.hide_render=True; o.hide_viewport=True

def shift(objs,dx=0,dy=0,dz=0):
    for o in objs: o.location.x+=dx; o.location.y+=dy; o.location.z+=dz

def export_glb(objs, fp):
    try:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            if o.type=="MESH": o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=fp, export_format="GLB",
            use_selection=True, export_apply=True)
        print(f"  GLB -> {os.path.basename(fp)} ({os.path.getsize(fp):,}B)")
    except Exception as e:
        print(f"  GLB 실패: {e}")

# ── FACE VISIBILITY VERIFIER ──
def verify_face(fp, label):
    try:
        from PIL import Image; import numpy as np
        arr=np.array(Image.open(fp).convert("RGBA"))
        a=arr[:,:,3]
        if (a>50).sum()<1000: 
            print(f"  [검수] {label}: 캐릭터 없음 FAIL"); return False
        rows=np.any(a>50,axis=1); cols=np.any(a>50,axis=0)
        rmin,rmax=np.where(rows)[0][[0,-1]]; cmin,cmax=np.where(cols)[0][[0,-1]]
        h=rmax-rmin
        face=arr[rmin:rmin+int(h*0.55),cmin:cmax]; fa=face[:,:,3]>100; rgb=face[:,:,:3]
        white=((rgb[:,:,0]>235)&(rgb[:,:,1]>235)&(rgb[:,:,2]>235)&fa).sum()
        dark=((rgb[:,:,0]<95)&(rgb[:,:,1]<70)&(rgb[:,:,2]<75)&fa).sum()
        pink=((rgb[:,:,0]>210)&(rgb[:,:,1]>120)&(rgb[:,:,1]<190)&(rgb[:,:,2]>140)&(rgb[:,:,2]<205)&fa).sum()
        ok = white>20 and dark>40 and pink>20
        print(f"  [검수] {label}: 눈highlight={white} 코/동공={dark} 볼={pink} -> {'PASS' if ok else 'FAIL'}")
        return ok
    except Exception as e:
        print(f"  [검수] {label}: 오류 {e}"); return False

def make_previews(src, base):
    """투명 src -> white/dark bg 프리뷰."""
    try:
        from PIL import Image
        im=Image.open(src).convert("RGBA")
        for bg,tag in [((248,244,236,255),"white"),((14,12,28,255),"dark")]:
            c=Image.new("RGBA",im.size,bg); c.paste(im,mask=im)
            c.convert("RGB").save(P(f"{base}-{tag}bg.png"))
    except Exception as e:
        print(f"  preview 실패: {e}")

def main():
    print("=== 퀴카 커플 v6.0 FACE-FORWARD ===")
    reset(); sc=bpy.context.scene
    w=bpy.data.worlds.new("W"); w.use_nodes=True; sc.world=w
    bg=w.node_tree.nodes.get("Background")
    if bg: bg.inputs[0].default_value=(0.05,0.05,0.09,1)
    print("빌드...")
    la=build_leader(0.0); pa=build_partner(0.0)
    setup_lights()

    results={}
    # 1 leader front
    print("[1] leader front"); vis(la,pa); rset(1600,1600,64)
    co,e=add_cam(2.9,(0,-8.5,1.16),(0,0,1.14)); render(P("quica-leader-front.png")); rm_cam(co,e)
    results["leader-front"]=verify_face(P("quica-leader-front.png"),"leader-front")
    # 2 partner front
    print("[2] partner front"); vis(pa,la)
    co,e=add_cam(2.9,(0,-8.5,1.15),(0,0,1.13)); render(P("quica-partner-front.png")); rm_cam(co,e)
    results["partner-front"]=verify_face(P("quica-partner-front.png"),"partner-front")
    # 3 leader 3/4
    print("[3] leader 3q"); vis(la,pa)
    co,e=add_cam(3.0,(-3.0,-7.5,1.25),(0,0,1.12)); render(P("quica-leader-3quarter.png")); rm_cam(co,e)
    # 4 partner 3/4
    print("[4] partner 3q"); vis(pa,la)
    co,e=add_cam(3.0,(3.0,-7.5,1.25),(0,0,1.12)); render(P("quica-partner-3quarter.png")); rm_cam(co,e)
    # 5 face closeup (both)
    print("[5] face closeup"); vis(la+pa,[]); shift(la,dx=-0.78); shift(pa,dx=0.78)
    rset(1200,1200,80)
    co,e=add_cam(2.6,(0,-8.5,1.22),(0,0,1.18)); render(P("quica-face-closeup.png")); rm_cam(co,e)
    results["closeup"]=verify_face(P("quica-face-closeup.png"),"closeup")
    shift(la,dx=0.78); shift(pa,dx=-0.78)
    # 6 couple splash
    print("[6] couple splash"); vis(la+pa,[]); shift(la,dx=-1.25); shift(pa,dx=1.25)
    rset(2048,1536,96)
    co,e=add_cam(5.8,(0,-9.5,1.05),(0,0,0.92)); render(P("quica-couple-splash.png")); rm_cam(co,e)
    results["couple"]=verify_face(P("quica-couple-splash.png"),"couple")
    # 7 icon
    print("[7] icon"); rset(512,512,80)
    co,e=add_cam(3.2,(0,-8.5,1.20),(0,0,1.12)); render(P("quica-couple-icon.png")); rm_cam(co,e)
    shift(la,dx=1.25); shift(pa,dx=-1.25)

    # GLB exports
    print("GLB export..."); vis(la,pa); export_glb(la,P("quica-leader.glb"))
    vis(pa,la); export_glb(pa,P("quica-partner.glb"))
    vis(la+pa,[]); export_glb(la+pa,P("quica-couple.glb"))

    # WebP + previews
    print("WebP/preview...")
    try:
        from PIL import Image
        for s,d in [("quica-couple-splash.png","quica-couple-splash.webp"),
                    ("quica-leader-front.png","quica-leader-front.webp"),
                    ("quica-partner-front.png","quica-partner-front.webp")]:
            Image.open(P(s)).convert("RGBA").save(P(d),"WEBP",quality=90,method=6)
    except Exception as e: print("webp",e)
    make_previews(P("quica-couple-splash.png"),"quica-couple-splash")
    make_previews(P("quica-leader-front.png"),"quica-leader")

    # contact sheet
    try:
        from PIL import Image, ImageDraw
        CELL=520; sheet=Image.new("RGBA",(CELL*3,CELL*2),(244,240,232,255))
        d=ImageDraw.Draw(sheet)
        items=[("quica-leader-front.png","Leader"),("quica-partner-front.png","Partner"),
               ("quica-face-closeup.png","Face"),("quica-leader-3quarter.png","Leader 3Q"),
               ("quica-partner-3quarter.png","Partner 3Q"),("quica-couple-splash.png","Couple")]
        for i,(fn,lb) in enumerate(items):
            c=i%3; r=i//3; p=P(fn)
            if os.path.exists(p):
                im=Image.open(p).convert("RGBA")
                bgc=Image.new("RGBA",im.size,(244,240,232,255)); bgc.paste(im,mask=im)
                bgc.thumbnail((CELL-16,CELL-16),Image.LANCZOS)
                sheet.paste(bgc,(c*CELL+(CELL-bgc.width)//2, r*CELL+(CELL-bgc.height)//2))
            d.rectangle([c*CELL,r*CELL,(c+1)*CELL-1,(r+1)*CELL-1],outline=(200,195,185,255),width=2)
            d.text((c*CELL+10,r*CELL+8),lb,fill=(80,70,60,255))
        sheet.save(P("quica-contact-sheet.png"))
        print(f"  contact-sheet ({os.path.getsize(P('quica-contact-sheet.png')):,}B)")
    except Exception as e: print("sheet",e)

    print("\n=== 검수 요약 ===")
    allok=True
    for k,v in results.items():
        print(f"  {k}: {'PASS' if v else 'FAIL'}"); allok=allok and v
    print(f"  전체: {'ALL PASS ✓' if allok else 'SOME FAILED ✗'}")

main()
