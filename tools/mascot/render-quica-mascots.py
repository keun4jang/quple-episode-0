#!/usr/bin/env python3
"""
퀴카 커플 3D 마스코트 렌더러 v5.0
bpy 5.0.1 Python module 기반  (pip install bpy)
Usage: python3 tools/mascot/render-quica-mascots.py
"""
import bpy, math, os, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR    = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "..", "assets", "mascots"))
os.makedirs(OUT_DIR, exist_ok=True)

def P(n): return os.path.join(OUT_DIR, n)

def h2c(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16)/255 for i in (0,2,4))

C = dict(
    A_fur=h2c("#C08040"), A_hi=h2c("#D89858"), A_sh=h2c("#906028"),
    B_fur=h2c("#D8A85C"), B_hi=h2c("#E8C070"), B_sh=h2c("#B08038"),
    belly=h2c("#FFE8BD"), muzzle=h2c("#FFF0D5"), ear_in=h2c("#F5AFA8"),
    cheek=h2c("#FF7FA0"),
    eye_w=h2c("#F8F8F5"), eye_ir=h2c("#5A321D"), eye_pu=h2c("#1A0C05"),
    eye_h=h2c("#FFFFFF"), eye_h2=h2c("#C8E0FF"),
    nose=h2c("#201008"), mouth=h2c("#8A4020"), nose_hi=h2c("#7A5040"),
    cap=h2c("#2A8A48"), cap_dk=h2c("#1C6030"), cap_hi=h2c("#48B468"),
    badge=h2c("#FFE060"),
    bp=h2c("#3A7AC8"), bp_dk=h2c("#2A5898"), bp_hi=h2c("#60A0E0"),
    cam=h2c("#1E2432"), cam_ln=h2c("#080C18"), cam_hi=h2c("#6878A8"),
    strap=h2c("#2A5888"),
    scarf=h2c("#F05E9B"), scarf_dk=h2c("#C0307A"), scarf_hi=h2c("#FF9EC8"),
    bag=h2c("#B87840"), bag_dk=h2c("#885820"), bag_hi=h2c("#D89858"),
    ticket=h2c("#FFF8D8"), tick_l=h2c("#C8A040"), star=h2c("#FFD840"),
)

# ── scene reset ────────────────────────────────────────────────────────────────
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ── material ───────────────────────────────────────────────────────────────────
def M(name, col, rough=0.78, spec=0.12, sub=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value  = rough
    b.inputs["Specular IOR Level"].default_value = spec
    if sub > 0:
        b.inputs["Subsurface Weight"].default_value = sub
        b.inputs["Subsurface Radius"].default_value = (0.10, 0.07, 0.05)
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m

# ── primitives ─────────────────────────────────────────────────────────────────
def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o

def sph(name, loc, sc, mat, seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=seg, ring_count=int(seg*2//3))
    o = bpy.context.active_object
    o.name = name; o.scale = sc; o.location = loc
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    s = o.modifiers.new("S","SUBSURF"); s.levels=2; s.render_levels=3
    return o

def box(name, loc, sc, mat, bv=0.05):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name; o.scale = sc
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    b = o.modifiers.new("B","BEVEL"); b.width=bv; b.segments=4
    s = o.modifiers.new("S","SUBSURF"); s.levels=1; s.render_levels=2
    return o

def tor(name, loc, sc, rot, mat, maj=0.30, mn=0.07):
    bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot,
        major_radius=maj, minor_radius=mn, major_segments=48, minor_segments=16)
    o = bpy.context.active_object
    o.name = name; o.scale = sc
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o

def cyl(name, loc, sc, rot, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name; o.scale = sc
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    b = o.modifiers.new("B","BEVEL"); b.width=0.03; b.segments=3
    return o

# ── eye set ────────────────────────────────────────────────────────────────────
def eye_set(pfx, x, z, y_front, s=1.0):
    """Returns list of eye objects. y_front = depth toward camera (negative = toward cam)"""
    objs=[]
    ms = M(f"{pfx}esc",C["eye_w"],rough=0.05,spec=0.9)
    objs.append(sph(f"{pfx}sc",(x,y_front,z),(0.090,0.058,0.078),ms))
    mi = M(f"{pfx}ir",C["eye_ir"],rough=0.12,spec=0.7)
    objs.append(sph(f"{pfx}ir",(x,y_front-0.012,z),(0.068,0.044,0.065),mi))
    mp = M(f"{pfx}pu",C["eye_pu"],rough=0.05,spec=0.95)
    objs.append(sph(f"{pfx}pu",(x,y_front-0.025,z),(0.042,0.028,0.040),mp))
    mh = M(f"{pfx}h1",C["eye_h"],rough=0.0,spec=1.0)
    objs.append(sph(f"{pfx}h1",(x-0.024*s,y_front-0.032,z+0.022),(0.022,0.015,0.022),mh,seg=24))
    mh2= M(f"{pfx}h2",C["eye_h2"],rough=0.0,spec=1.0)
    objs.append(sph(f"{pfx}h2",(x+0.012*s,y_front-0.032,z-0.010),(0.012,0.008,0.012),mh2,seg=16))
    # cheek blush
    mck= M(f"{pfx}ck",C["cheek"],rough=0.9,spec=0.0,alpha=0.42)
    objs.append(sph(f"{pfx}ck",(x*1.38,y_front+0.016,z-0.048),(0.105,0.022,0.078),mck,seg=24))
    return objs

# ── ear pair ───────────────────────────────────────────────────────────────────
def ear_pair(pfx, hx, hz, hy, fur_c, ear_c):
    objs=[]
    mo = M(f"{pfx}eo",fur_c,rough=0.80,sub=0.04)
    mi = M(f"{pfx}ei",ear_c,rough=0.75,sub=0.06)
    for sx,tag in [(-1,"L"),(1,"R")]:
        ex = hx + sx*0.375
        eo = sph(f"{pfx}e{tag}o",(ex,hy+0.02,hz+0.30),(0.148,0.075,0.182),mo)
        objs.append(eo)
        ei = sph(f"{pfx}e{tag}i",(ex,hy-0.01,hz+0.31),(0.096,0.035,0.125),mi,seg=32)
        objs.append(ei)
    return objs

# ═══════════════════════════════════════════════════════════════════════════════
# LEADER (A)
# ═══════════════════════════════════════════════════════════════════════════════
def build_leader(ox=0.0):
    objs = []
    fur  = M("Af", C["A_fur"],  rough=0.80, sub=0.07)
    fur2 = M("Af2",C["A_hi"],   rough=0.78, sub=0.05)
    bly  = M("Ab", C["belly"],  rough=0.75, sub=0.08)
    mzl  = M("Am", C["muzzle"], rough=0.75, sub=0.10)

    # body
    objs.append(sph("Ab",(ox,0,0.40),(0.56,0.50,0.66),fur))
    objs.append(sph("Abl",(ox,-0.03,0.38),(0.38,0.30,0.50),bly))
    # head
    objs.append(sph("Ah",(ox,-0.01,1.12),(0.53,0.50,0.51),fur))
    # ears
    objs += ear_pair("A",ox,1.12,-0.01,C["A_fur"],C["ear_in"])
    # muzzle
    objs.append(sph("Amz",(ox,-0.445,1.06),(0.270,0.188,0.215),mzl))
    # nose
    mn=M("An",C["nose"],rough=0.30,spec=0.6)
    objs.append(sph("Ano",(ox,-0.528,1.108),(0.070,0.042,0.052),mn,seg=24))
    mnh=M("Anh",C["nose_hi"],rough=0.2,spec=0.8)
    objs.append(sph("Anh",(ox-0.022,-0.548,1.126),(0.025,0.016,0.018),mnh,seg=16))
    # mouth
    mm=M("Amou",C["mouth"],rough=0.6)
    for dx,rz in [(-0.084,0.40),(0.084,-0.40)]:
        mc=box("Amo",(ox+dx,-0.530,1.02),(0.018,0.013,0.034),mm,bv=0.012)
        mc.rotation_euler.z=rz; objs.append(mc)
    # eyes
    objs += eye_set("AL",ox-0.208,1.165,-0.360,s=1.0)
    objs += eye_set("AR",ox+0.208,1.165,-0.360,s=-1.0)
    # arms
    ma=M("Aarm",C["A_fur"],rough=0.80,sub=0.05)
    # left arm (hanging)
    la=sph("AaL",(ox-0.590,0,0.620),(0.225,0.205,0.362),ma)
    la.rotation_euler.z=math.radians(22); objs.append(la)
    objs.append(sph("AhL",(ox-0.690,0,0.330),(0.162,0.140,0.140),ma,seg=32))
    # right arm (raised — holding camera side)
    ra=sph("AaR",(ox+0.570,-0.04,0.660),(0.225,0.200,0.340),ma)
    ra.rotation_euler.z=math.radians(-28); objs.append(ra)
    objs.append(sph("AhR",(ox+0.740,-0.04,0.440),(0.155,0.138,0.138),ma,seg=32))
    # legs+feet
    ml=M("Aleg",C["A_fur"],rough=0.82,sub=0.04)
    mfp=M("Afp",C["belly"],rough=0.75)
    for sx in (-0.270, 0.270):
        tag="L" if sx<0 else "R"
        objs.append(sph(f"Alg{tag}",(ox+sx,0,0.100),(0.225,0.205,0.350),ml))
        objs.append(sph(f"Aft{tag}",(ox+sx*1.22,-0.100,-0.115),(0.290,0.185,0.165),ml))
        objs.append(sph(f"Afp{tag}",(ox+sx*1.22,-0.155,-0.150),(0.185,0.082,0.105),mfp,seg=32))
    # tail
    mt=M("Ata",C["A_fur"],rough=0.85)
    objs.append(sph("Ata",(ox,0.360,0.290),(0.185,0.152,0.152),mt,seg=24))

    # ── ACCESSORIES A ────────────────────────────────────────────────────────

    # Backpack
    mbp=M("Abp",C["bp"],rough=0.72,spec=0.08)
    mbpd=M("Abpd",C["bp_dk"],rough=0.76)
    objs.append(box("Abp",(ox-0.225,0.290,0.540),(0.205,0.148,0.295),mbp,bv=0.045))
    objs.append(box("Abpf",(ox-0.225,0.290+0.150,0.405),(0.168,0.025,0.130),mbpd,bv=0.022))
    mstr=M("Ast",C["strap"],rough=0.70)
    objs.append(box("Ast1",(ox-0.390,0.095,0.800),(0.030,0.030,0.145),mstr,bv=0.010))
    objs.append(box("Ast2",(ox-0.420,0.080,0.555),(0.030,0.028,0.120),mstr,bv=0.010))

    # Cap
    mcp=M("Acp",C["cap"],rough=0.75,spec=0.08)
    mcpd=M("Acpd",C["cap_dk"],rough=0.80)
    mcph=M("Acph",C["cap_hi"],rough=0.70)
    # dome
    dome=sph("Acdome",(ox+0.04,-0.06,1.570),(0.480,0.440,0.315),mcp)
    objs.append(dome)
    # brim
    objs.append(sph("Acbrim",(ox+0.04,-0.09,1.492),(0.600,0.520,0.065),mcpd))
    objs.append(sph("Acbrim2",(ox+0.04,-0.230,1.472),(0.330,0.250,0.048),mcpd))
    # cap highlight
    objs.append(sph("Achl",(ox-0.100,-0.100,1.588),(0.210,0.320,0.168),mcph))
    # planet badge
    mbd=M("Abd",C["badge"],rough=0.55,spec=0.30)
    objs.append(sph("Abd",(ox+0.080,-0.228,1.524),(0.075,0.045,0.075),mbd,seg=32))
    mbr=M("Abdr",C["badge"],rough=0.45,spec=0.35)
    objs.append(tor("Abdr",(ox+0.080,-0.228,1.524),(1,1,1),
                    (math.radians(90),0,0),mbr,maj=0.082,mn=0.013))

    # Camera body (chest right, below shoulder, NOT crossing face)
    mca=M("Aca",C["cam"],rough=0.45,spec=0.25)
    mcal=M("Acal",C["cam_ln"],rough=0.05,spec=0.95)
    mcah=M("Acah",C["cam_hi"],rough=0.05,spec=0.9)
    objs.append(box("Acam",(ox+0.520,-0.185,0.610),(0.165,0.105,0.115),mca,bv=0.026))
    objs.append(sph("Aclens",(ox+0.520,-0.286,0.610),(0.075,0.050,0.075),mcal,seg=32))
    objs.append(sph("Aclnsh",(ox+0.485,-0.302,0.634),(0.026,0.018,0.026),mcah,seg=20))
    # shutter button
    msb=M("Asb",C["cam_hi"],rough=0.3,spec=0.5)
    objs.append(sph("Asb",(ox+0.600,-0.188,0.682),(0.026,0.019,0.021),msb,seg=16))
    # Camera strap — short segments from right shoulder DOWN to camera, never touching face
    mcs=M("Acs",C["strap"],rough=0.68)
    objs.append(box("Acs1",(ox+0.390,-0.052,0.940),(0.030,0.024,0.128),mcs,bv=0.010))
    objs.append(box("Acs2",(ox+0.468,-0.095,0.788),(0.030,0.024,0.115),mcs,bv=0.010))
    objs.append(box("Acs3",(ox+0.510,-0.138,0.692),(0.030,0.024,0.072),mcs,bv=0.010))

    return objs


# ═══════════════════════════════════════════════════════════════════════════════
# PARTNER (B)
# ═══════════════════════════════════════════════════════════════════════════════
def build_partner(ox=0.0):
    objs = []
    fur  = M("Bf", C["B_fur"],  rough=0.80, sub=0.07)
    bly  = M("Bb", C["belly"],  rough=0.75, sub=0.08)
    mzl  = M("Bm", C["muzzle"], rough=0.75, sub=0.10)

    # body
    objs.append(sph("Bb",(ox,0,0.380),(0.535,0.468,0.635),fur))
    objs.append(sph("Bbl",(ox,-0.025,0.360),(0.360,0.285,0.480),bly))
    # head (tilted 6° for softer pose)
    head=sph("Bh",(ox+0.04,-0.01,1.110),(0.510,0.478,0.490),fur)
    head.rotation_euler=(0,math.radians(-6),0); objs.append(head)
    # ears
    objs += ear_pair("B",ox,1.105,-0.010,C["B_fur"],C["ear_in"])
    # muzzle
    objs.append(sph("Bmz",(ox+0.03,-0.428,1.038),(0.258,0.178,0.205),mzl))
    # nose
    mn=M("Bn",C["nose"],rough=0.30,spec=0.6)
    objs.append(sph("Bno",(ox+0.03,-0.510,1.086),(0.068,0.040,0.050),mn,seg=24))
    mnh=M("Bnh",C["nose_hi"],rough=0.2,spec=0.8)
    objs.append(sph("Bnh",(ox+0.008,-0.528,1.104),(0.024,0.015,0.017),mnh,seg=16))
    # mouth
    mm=M("Bmou",C["mouth"],rough=0.6)
    for dx,rz in [(-0.078,0.38),(0.098,-0.38)]:
        mc=box("Bmo",(ox+dx+0.03,-0.518,1.002),(0.017,0.012,0.032),mm,bv=0.011)
        mc.rotation_euler.z=rz; objs.append(mc)
    # eyes
    objs += eye_set("BL",ox-0.195,1.148,-0.348,s=1.0)
    objs += eye_set("BR",ox+0.218,1.148,-0.348,s=-1.0)
    # arms
    ma=M("Barm",C["B_fur"],rough=0.80,sub=0.05)
    # left arm raised (holding ticket)
    la=sph("BaL",(ox-0.565,0,0.740),(0.208,0.188,0.322),ma)
    la.rotation_euler.z=math.radians(38); objs.append(la)
    objs.append(sph("BhL",(ox-0.618,0,0.980),(0.148,0.128,0.128),ma,seg=32))
    # right arm (relaxed hang)
    ra=sph("BaR",(ox+0.548,0,0.580),(0.208,0.188,0.325),ma)
    ra.rotation_euler.z=math.radians(-20); objs.append(ra)
    objs.append(sph("BhR",(ox+0.638,0,0.340),(0.148,0.128,0.128),ma,seg=32))
    # legs+feet
    ml=M("Bleg",C["B_fur"],rough=0.82,sub=0.04)
    mfp=M("Bfp",C["belly"],rough=0.75)
    for sx in (-0.255, 0.255):
        tag="L" if sx<0 else "R"
        objs.append(sph(f"Blg{tag}",(ox+sx,0,0.090),(0.215,0.195,0.338),ml))
        objs.append(sph(f"Bft{tag}",(ox+sx*1.18,-0.092,-0.118),(0.278,0.175,0.158),ml))
        objs.append(sph(f"Bfp{tag}",(ox+sx*1.18,-0.145,-0.152),(0.178,0.078,0.100),mfp,seg=32))
    # tail
    mt=M("Bta",C["B_fur"],rough=0.85)
    objs.append(sph("Bta",(ox,0.340,0.280),(0.178,0.145,0.145),mt,seg=24))

    # ── ACCESSORIES B ────────────────────────────────────────────────────────

    # SCARF — V드레이프 (목에 감기고 두 끝이 앞으로 늘어짐, 입 절대 안 가림)
    msc =M("Bsc", C["scarf"],    rough=0.80, spec=0.05)
    mscd=M("Bscd",C["scarf_dk"], rough=0.82)
    msch=M("Bsch",C["scarf_hi"], rough=0.75)
    # Collar ring (neck level = z≈0.870)
    objs.append(tor("Bcol",(ox+0.02,0.02,0.870),(1.0,1.0,0.55),
                    (math.radians(84),0,0),msc,maj=0.305,mn=0.078))
    # Front cross knot
    objs.append(sph("Bkn1",(ox+0.02,-0.288,0.858),(0.125,0.072,0.104),mscd))
    objs.append(sph("Bkn2",(ox+0.02,-0.305,0.852),(0.095,0.052,0.080),msch))
    # Left tail (longer, diagonal left-down)
    for i,(dx,dy,dz,rx,rz) in enumerate([
        (-0.052,-0.295,0.800,-0.14,-0.12),
        (-0.100,-0.282,0.712,-0.18,-0.14),
        (-0.128,-0.262,0.618,-0.14,-0.10),
    ]):
        s=box(f"BscL{i}",(ox+dx,dy,dz),(0.062,0.048,0.088),
              msc if i%2==0 else mscd, bv=0.028)
        s.rotation_euler=(rx,0,rz); objs.append(s)
    # Right tail (shorter)
    for i,(dx,dy,dz,rx,rz) in enumerate([
        ( 0.088,-0.288,0.792,-0.13,0.11),
        ( 0.105,-0.270,0.695,-0.12,0.13),
    ]):
        s=box(f"BscR{i}",(ox+dx,dy,dz),(0.058,0.042,0.078),
              msc if i%2==0 else mscd, bv=0.025)
        s.rotation_euler=(rx,0,rz); objs.append(s)

    # Crossbody bag (right side)
    mbg =M("Bbg", C["bag"],    rough=0.75, spec=0.08)
    mbgd=M("Bbgd",C["bag_dk"], rough=0.78)
    mbgh=M("Bbgh",C["bag_hi"], rough=0.55, spec=0.25)
    objs.append(box("Bbag",(ox+0.540,0.065,0.440),(0.205,0.148,0.228),mbg,bv=0.042))
    # Flap
    objs.append(box("Bflap",(ox+0.540,0.065+0.148,0.508),(0.185,0.025,0.130),mbgd,bv=0.022))
    # Clasp
    objs.append(sph("Bclasp",(ox+0.540,0.214,0.508),(0.042,0.026,0.032),mbgh,seg=24))
    # Shoulder strap
    mss=M("Bss",C["bag_dk"],rough=0.70)
    for i,(dx,dz) in enumerate([(0.228,0.880),(0.368,0.700),(0.478,0.572)]):
        s=box(f"Bss{i}",(ox+dx,-0.040,dz),(0.030,0.024,0.105),mss,bv=0.010)
        s.rotation_euler.z=math.radians(-18+i*4); objs.append(s)
    # Star keyring
    mst=M("Bstar",C["star"],rough=0.45,spec=0.45)
    objs.append(sph("Bstar",(ox+0.475,0.188,0.322),(0.040,0.024,0.040),mst,seg=24))

    # Ticket (left hand, held up)
    mtk =M("Btk", C["ticket"], rough=0.85, spec=0.04)
    mtkl=M("Btkl",C["tick_l"], rough=0.80)
    tk=box("Btk",(ox-0.632,-0.065,1.030),(0.115,0.028,0.172),mtk,bv=0.016)
    tk.rotation_euler=(0,0,math.radians(-30)); objs.append(tk)
    for dz in (-0.042, 0.042):
        tl=box("Btkl",(ox-0.632,-0.086,1.030+dz),(0.088,0.030,0.014),mtkl,bv=0.005)
        tl.rotation_euler=(0,0,math.radians(-30)); objs.append(tl)

    return objs


# ── lighting ───────────────────────────────────────────────────────────────────
def setup_lights():
    sc=bpy.context.scene
    def add_area(name, energy, col, loc, rot, size=3.0):
        ld=bpy.data.lights.new(name,"AREA")
        ld.energy=energy; ld.color=col; ld.size=size
        lo=bpy.data.objects.new(name,ld)
        lo.location=loc; lo.rotation_euler=[math.radians(r) for r in rot]
        sc.collection.objects.link(lo)
        return lo
    add_area("Key",  950, (1.00,0.94,0.82), ( 4,-4, 6), (50,0, 45))
    add_area("Fill", 320, (0.72,0.82,1.00), (-4,-2, 4), (55,0,-40))
    add_area("Rim",  520, (1.00,0.96,0.88), ( 0, 6, 3), (30,0,  0))
    add_area("Bot",  130, (1.00,0.92,0.80), ( 0,-1,-2), (-60,0, 0))

# ── camera ─────────────────────────────────────────────────────────────────────
def add_cam(sc, scale, loc, rot):
    cd=bpy.data.cameras.new("C"); cd.type="ORTHO"; cd.ortho_scale=scale
    co=bpy.data.objects.new("C",cd)
    co.location=loc; co.rotation_euler=[math.radians(r) for r in rot]
    sc.collection.objects.link(co); sc.camera=co
    return co

def rm_cam(co):
    bpy.data.objects.remove(co,do_unlink=True)

# ── render settings ────────────────────────────────────────────────────────────
def rset(sc, w, h, samp=96):
    sc.render.engine="CYCLES"
    sc.cycles.device="CPU"
    sc.render.film_transparent=True
    sc.render.image_settings.file_format="PNG"
    sc.render.image_settings.color_mode="RGBA"
    sc.render.image_settings.color_depth="8"
    sc.render.resolution_x=w; sc.render.resolution_y=h
    sc.render.resolution_percentage=100
    sc.cycles.samples=samp

def render(fp):
    bpy.context.scene.render.filepath=fp
    bpy.ops.render.render(write_still=True)
    sz=os.path.getsize(fp) if os.path.exists(fp) else 0
    print(f"  → {os.path.basename(fp)}  ({sz:,} bytes)")

def vis(show, hide):
    for o in show: o.hide_render=False; o.hide_viewport=False
    for o in hide: o.hide_render=True;  o.hide_viewport=True

def shift(objs, dx=0, dy=0, dz=0):
    for o in objs: o.location.x+=dx; o.location.y+=dy; o.location.z+=dz

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    print("=== 퀴카 커플 3D 렌더러 v5.0 ===")
    reset()
    sc=bpy.context.scene

    # World (dark for transparent BG contrast)
    w=bpy.data.worlds.new("W"); w.use_nodes=True; sc.world=w
    bg=w.node_tree.nodes.get("Background")
    if bg: bg.inputs[0].default_value=(0.04,0.04,0.08,1)

    print("캐릭터 빌드...")
    la=build_leader(ox=0.0)
    pa=build_partner(ox=0.0)
    setup_lights()

    # ── 1. Leader only ─────────────────────────────────────────────────────────
    print("\n[1/4] Leader front...")
    vis(la, pa)
    rset(sc,2048,2048,samp=128)
    co=add_cam(sc,3.40,(0,-7,1.22),(83,0,0))
    render(P("quica-leader-front.png")); rm_cam(co)

    # ── 2. Partner only ────────────────────────────────────────────────────────
    print("\n[2/4] Partner front...")
    vis(pa, la)
    co=add_cam(sc,3.40,(0,-7,1.22),(83,0,0))
    render(P("quica-partner-front.png")); rm_cam(co)

    # ── 3. Couple splash ────────────────────────────────────────────────────────
    print("\n[3/4] Couple splash...")
    vis(la+pa, [])
    shift(la, dx=-1.22); shift(pa, dx=+1.22)
    rset(sc,2048,1536,samp=128)
    co=add_cam(sc,5.90,(0,-8,1.22),(83,0,0))
    render(P("quica-couple-splash.png")); rm_cam(co)
    shift(la, dx=+1.22); shift(pa, dx=-1.22)

    # ── 4. Icon (face close-up) ────────────────────────────────────────────────
    print("\n[4/4] Icon face close-up...")
    vis(la+pa, [])
    shift(la, dx=-0.88); shift(pa, dx=+0.88)
    rset(sc,1024,1024,samp=96)
    co=add_cam(sc,2.82,(0,-6,1.58),(85,0,0))
    render(P("quica-couple-icon.png")); rm_cam(co)
    shift(la, dx=+0.88); shift(pa, dx=-0.88)

    # ── WebP ────────────────────────────────────────────────────────────────────
    print("\nWebP 변환...")
    try:
        from PIL import Image as PILImage
        for src,dst in [("quica-couple-splash.png","quica-couple-splash.webp"),
                         ("quica-couple-icon.png","quica-couple-icon.webp"),
                         ("quica-leader-front.png","quica-leader-front.webp"),
                         ("quica-partner-front.png","quica-partner-front.webp")]:
            im=PILImage.open(P(src)).convert("RGBA")
            im.save(P(dst),"WEBP",quality=88,lossless=False,method=6)
            print(f"  {dst}: {os.path.getsize(P(dst)):,} bytes")
    except Exception as e:
        print(f"  WebP 실패: {e}")

    print("\n=== 완료 ===")
    for fn in ["quica-leader-front.png","quica-partner-front.png",
               "quica-couple-splash.png","quica-couple-icon.png"]:
        fp=P(fn)
        if os.path.exists(fp): print(f"  {fn}: {os.path.getsize(fp):,} bytes")

main()
