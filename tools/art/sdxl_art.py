#!/usr/bin/env python3
"""SDXL + 픽셀아트 LoRA 로 쿼카 군단 그림을 만든다 (내 컴퓨터의 NVIDIA 그래픽카드, 무료).

    .sdenv/Scripts/python tools/art/sdxl_art.py bg1 --n 4            # 배경 1 을 네 장 (골라 쓴다)
    .sdenv/Scripts/python tools/art/sdxl_art.py bg1 --init layout     # 길 밑그림 위에 그린다 (구도 고정)

모델 (처음 한 번 허깅페이스에서 받는다, 약 7GB, 셋 다 상업 사용 가능한 OpenRAIL++ 계열):
  stabilityai/stable-diffusion-xl-base-1.0 · madebyollin/sdxl-vae-fp16-fix · nerijs/pixel-art-xl (LoRA)
결과: assets/source/lane/<id>_<n>.png (원본) - 게임에 넣는 건 import_lane_art.py 가 한다.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "source", "lane")

BASE = "stabilityai/stable-diffusion-xl-base-1.0"
VAE = "madebyollin/sdxl-vae-fp16-fix"
LORA = "nerijs/pixel-art-xl"

STYLE = ("pixel art, 16-bit cozy farm rpg game art, stardew valley style, richly detailed, soft warm lighting, "
         "crisp pixels, vibrant but gentle colors")
NEG = ("people, person, human, character, animal, flat, simple, minimalist, empty, blurry, smooth, painting, photo, 3d render, text, watermark, logo, signature, ugly, deformed, "
       "dark, horror, jpeg artifacts, noise")

## id: (prompt, width, height)  - SDXL 이 잘 그리는 크기 (픽셀 수 약 100만)
JOBS = {
    "bg1": ("top-down view of a straight dirt road going from the bottom to the top through a sunny spring meadow, "
            "green grass with clover and tiny white and pink flowers, cherry blossom trees on both sides, "
            "low wooden fences, hay bales, mushrooms, " + STYLE, 768, 1344),
    "bg2": ("top-down view of a straight dirt road going from the bottom to the top through a gentle marsh after "
            "rain, small clear puddles, a pond with lily pads, reeds and cattails, wet stones, a small wooden plank "
            "bridge at the side, " + STYLE, 768, 1344),
    "bg3": ("top-down view of a straight dirt road going from the bottom to the top through a huge flower garden, "
            "rows of tulips, daisies and lavender on both sides, beehive boxes, a watering can, butterflies, "
            + STYLE, 768, 1344),
    "bg4": ("top-down view of a straight dirt road going from the bottom to the top through a cozy oak forest, big "
            "oak trees with round leafy crowns, fallen acorns and leaves, ferns, a mossy log, dappled sunlight, "
            + STYLE, 768, 1344),
    "bg5": ("top-down view of a straight stone path going from the bottom to the top through a mossy cave, rocky "
            "walls with glowing purple crystals, hanging roots, small lanterns, soft cobwebs in corners, cute not "
            "scary, cool lavender light, " + STYLE, 768, 1344),
    "bg6": ("top-down view of a straight dirt road going from the bottom to the top over a cute junkyard hill, "
            "piles of old wooden crates, tin cans, a broken wheelbarrow, bottle caps and buttons, grass growing "
            "through, warm late afternoon light, charming not dirty, " + STYLE, 768, 1344),
    "bg7": ("top-down view of a straight dirt road going from the bottom to the top through a meadow at night, "
            "deep blue and violet starry sky with a big moon, fireflies glowing in tall grass, glowing lanterns "
            "along the road, silver moonlight, " + STYLE, 768, 1344),
    "bg8": ("top-down view of a straight dirt path going from the bottom to the top through an underground "
            "burrow village, earth walls with tiny round doors and windows, roots, glowing mushrooms, small "
            "ladders, wooden supports, warm lamp light, " + STYLE, 768, 1344),
    "bg9": ("top-down view of a straight path going from the bottom to the top across a giant kitchen floor seen "
            "from a tiny animal, huge checkered tiles, a dropped spoon, a sugar cube, crumbs, spilled milk, warm "
            "indoor light, " + STYLE, 768, 1344),
    "bg10": ("top-down view of a straight stone walkway going from the bottom to the top through an old sewer "
             "tunnel, stone brick walls, glowing green water channels on both sides, pipes, little grates, soft "
             "purple mist, spooky but cute, " + STYLE, 768, 1344),
    # 물건은 단색 마젠타 위에 하나만 - import_lane_art.py 가 마젠타를 빼서 투명하게 만든다
    "fort": ("a single cute small wooden fortress game sprite, front view, a row of wooden palisade logs with "
             "pointed tops, a small wooden watchtower in the middle with a red tiled roof, a round window and a "
             "tiny pink flag, isolated on a plain solid magenta background, centered, " + STYLE, 1024, 768),
    "nest": ("a single bug nest game sprite, a big round brown dirt mound with lumps of earth, roots and pebbles, "
             "three dark tunnel holes with small glowing red eyes, cute and mischievous, isolated on a plain solid "
             "magenta background, centered, " + STYLE, 1024, 768),
}


## 캐릭터 - 하나씩 따로 그린다 (한 장에 여럿이면 크기·모양이 들쭉날쭉). 앞모습, 서 있는 자세, 마젠타 바탕.
QUOKKA = ("a cute chibi quokka, small round marsupial, warm caramel brown fur, cream belly and muzzle, small round "
          "ears with pink insides, shiny black eyes, rosy cheeks, smiling")
CHARS = {
    "q_tiny": "little " + QUOKKA + ", a tiny green leaf sprout on its head",
    "q_shield": QUOKKA + ", wearing a round grey metal helmet, holding a big round golden shield",
    "q_spear": QUOKKA + ", wearing a red headband, holding a long spear",
    "q_hammer": QUOKKA + ", wearing a yellow hard hat, holding a big wooden mallet",
    "q_runner": QUOKKA + ", wearing a blue headband and red sneakers, sporty",
    "q_sling": QUOKKA + ", wearing a green cap, holding a wooden slingshot",
    "q_mage": QUOKKA + ", wearing a tall purple wizard hat, holding a staff with a star on top",
    "q_giant": "big bulky strong " + QUOKKA + ", wearing a brown helmet with two small horns, holding a heavy club",
}
ANIMALS = {
    "chick": "a tiny round yellow chick with a piece of eggshell on its head",
    "hedgehog": "a cute brown hedgehog with a crown of spikes and a cream face",
    "squirrel": "a cute orange squirrel with a big bushy tail, holding an acorn",
    "frog": "a cute green frog wearing a leaf hat, big friendly eyes",
    "rabbit": "a cute white rabbit with long ears with pink insides, holding a carrot",
    "duck": "a cute white duck wearing a little blue sailor hat and collar",
    "mole": "a cute dark grey mole with big claws, wearing a miner helmet with a lamp",
    "sheep": "a cute fluffy white wool sheep with a dark face",
    "turtle": "a cute light green turtle with a dark green shell, standing",
    "penguin": "a cute navy and white penguin wearing a red scarf",
    "owl": "a cute brown owl wearing round glasses, wise",
    "panda": "a cute sturdy panda holding a bamboo stick",
    "otter": "a cute brown otter holding a pink clam shell",
    "tiger": "a cute strong orange striped tiger cub with a golden claw gauntlet",
    "polar": "a cute big white polar bear wearing an icy blue scarf",
    "eagle": "a cute brown eagle with a white head, large wings and aviator goggles",
}
for _k, _d in ANIMALS.items():
    CHARS["a_" + _k] = "chibi " + _d
BUGS = {
    "ant": "red-brown ant", "caterpillar": "green segmented caterpillar", "mosquito": "thin mosquito",
    "fly": "shiny blue-green fly", "bee": "yellow and black bee with small wings", "ladybug": "red ladybug with black dots",
    "termite": "pale cream termite", "cricket": "brown cricket with long legs", "moth": "moth with dusty lavender wings",
    "spider": "purple spider with eight legs", "centipede": "orange centipede with many legs",
    "stag": "dark stag beetle with big jaws", "wasp": "orange and black wasp with a stinger",
    "pillbug": "grey armored pill bug", "molecricket": "brown mole cricket with digging claws",
    "roach": "glossy brown cockroach",
    "queen_ant": "giant red ant insect boss with six legs and antennae, wearing a tiny crown, an insect not a human",
    "mosquito_king": "giant mosquito insect boss with thin wings and a long needle nose, wearing a tiny crown, an insect "
                     "not a human",
    "hornet": "giant armored hornet boss with angry eyebrows", "rhino": "rhino beetle boss with a huge horn",
    "tarantula": "fuzzy purple tarantula king boss wearing a crown", "fly_king": "giant shiny green housefly insect boss with big red compound eyes and "
    "wings, wearing a tiny crown, an insect not a human",
    "moth_queen": "giant fluffy moth insect boss with big glowing patterned wings and antennae, wearing a tiny tiara, "
                  "an insect not a human",
    "cricket_king": "mole cricket king boss with digging claws and a crown",
    "centipede_king": "armored centipede emperor boss", "roach_king": "cockroach overlord boss wearing a cape and crown",
}
## 진화한 모습 (LaneData.EVOLVED_NAME) - 원래 설명에 더 멋진 차림을 얹는다. 모습은 IP-Adapter 가 원래 그림에서 가져온다.
EVOLVED = {
    "q_tiny": "brave, wearing a small red cape and a tiny silver helmet with a leaf",
    "q_shield": "wearing shining full silver plate armor, holding a huge golden tower shield",
    "q_spear": "wearing light blue armor, holding a spear crackling with yellow lightning",
    "q_hammer": "a blacksmith wearing a leather apron, holding a giant glowing orange forge hammer",
    "q_runner": "wearing a flowing blue scarf and winged sneakers, wind swirls",
    "q_sling": "a master archer wearing a green hood and cape, holding a golden slingshot",
    "q_mage": "an archmage in a starry dark purple robe and tall hat, holding a staff with a glowing crystal",
    "q_giant": "a huge chubby quokka with small round ears and a short narrow snout, wearing grey stone armor with green moss, holding a giant stone club",
    "a_chick": "a brave chick captain with a big red rooster comb on its head and a tiny red cape",
    "a_hedgehog": "with shining steel spikes and a metal armor plate",
    "a_squirrel": "a squirrel with small round ears and a huge curly bushy tail, holding a big shining golden acorn",
    "a_frog": "a frog prince wearing a small golden crown and a red cape",
    "a_rabbit": "with lightning bolt marks on its fur and yellow sneakers, holding a carrot",
    "a_duck": "a duck sea captain wearing a navy captain hat and coat",
    "a_mole": "wearing a miner helmet and a vest covered with sparkling gems, holding a gem pickaxe",
    "a_sheep": "with fluffy cloud-like light blue wool, floating little clouds around",
    "a_turtle": "with a pink coral and seashell decorated shell",
    "a_penguin": "wearing an icy blue crystal armor and a white scarf",
    "a_owl": "a sage owl wearing a starry blue wizard hat and round glasses, holding a book",
    "a_panda": "a kung fu panda wearing a red martial arts vest and headband",
    "a_otter": "holding a big round shiny white pearl ball with both paws, wearing a white pearl necklace",
    "a_tiger": "a thunder tiger with glowing blue lightning stripes and golden claw gauntlets",
    "a_polar": "wearing a shimmering aurora colored green and purple scarf and ice armor",
    "a_eagle": "a sun eagle with golden glowing wings and a golden crest",
}
for _k, _d in EVOLVED.items():
    CHARS["e_" + _k] = _d + ", " + CHARS[_k]   # 새 차림을 앞에 - 77토큰 뒤는 잘린다
for _k, _d in BUGS.items():
    CHARS["b_" + _k] = "a cute but mischievous chubby cartoon " + _d + ", big eyes, sly grin"
for _k, _d in CHARS.items():
    JOBS[_k] = ("a single game character sprite, " + _d + ", front view, standing, full body, feet visible, "
                "large in frame, isolated on a plain flat solid magenta background, no shadow, no ground, centered, "
                + STYLE, 1024, 1024)


def load_pipe(img2img: bool):
    import torch
    from diffusers import AutoencoderKL, StableDiffusionXLImg2ImgPipeline, StableDiffusionXLPipeline
    vae = AutoencoderKL.from_pretrained(VAE, torch_dtype=torch.float16)
    cls = StableDiffusionXLImg2ImgPipeline if img2img else StableDiffusionXLPipeline
    pipe = cls.from_pretrained(BASE, vae=vae, torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
    pipe.load_lora_weights(LORA)
    pipe.enable_model_cpu_offload()       # 12GB 카드에서 넉넉하게
    return pipe


## 동작 그림 - 서 있는 그림을 밑그림으로 깔고 자세만 바꿔 그린다 (얼굴·옷이 그대로 남게).
POSES = {
    "walk1": "walking, left foot stepping forward, right foot back, mid stride",
    "walk2": "walking, right foot stepping forward, left foot back, mid stride",
    "atk1": "preparing to attack, leaning back, raising its weapon or paw high above the head",
    "atk2": "attacking, lunging forward, swinging its weapon or paw down hard, action pose",
    "atk3": "after attacking, weapon or paw lowered in front, follow-through pose",
}


def make_frames(char: str, src: str, strength: float, seed: int) -> None:
    """한 캐릭터의 동작 그림 5장 → assets/source/lane/frames/<char>_<pose>.png"""
    import torch
    from PIL import Image
    pipe = make_frames.pipe = getattr(make_frames, "pipe", None) or load_pipe(True)
    desc = CHARS[char]
    out = os.path.join(OUT, "frames")
    os.makedirs(out, exist_ok=True)
    init = Image.open(src).convert("RGB").resize((1024, 1024))
    for pose, words in POSES.items():
        g = torch.Generator("cuda").manual_seed(seed)
        prompt = ("a single game character sprite, " + desc + ", " + words + ", full body, isolated on a plain flat "
                  "solid magenta background, no shadow, " + STYLE)
        img = pipe(prompt=prompt, negative_prompt=NEG + ", multiple characters, ground, shadow, frame, panel",
                   image=init, strength=strength, num_inference_steps=30, guidance_scale=7.0, generator=g,
                   cross_attention_kwargs={"scale": 0.6}).images[0]
        p = os.path.join(out, "%s_%s.png" % (char, pose))
        img.save(p)
        print("ok", p)
        sys.stdout.flush()


def make_sheet(char: str, n: int, seed: int) -> None:
    """한 장에 같은 캐릭터의 동작 여섯 칸 (걷기 셋 + 공격 셋) - 한 번에 그려야 얼굴·옷이 서로 맞는다.
    → assets/source/lane/sheets/<char>_<k>.png  (자르기는 import_lane_art.py anim)"""
    import torch
    pipe = make_sheet.pipe = getattr(make_sheet, "pipe", None) or load_pipe(False)
    out = os.path.join(OUT, "sheets")
    os.makedirs(out, exist_ok=True)
    prompt = ("pixel art game sprite sheet, six animation frames of the same " + CHARS[char] + ", in one horizontal "
              "row, evenly spaced, all facing the viewer, frames 1 to 3 walking cycle with legs moving, frames 4 to 6 "
              "attack animation: wind up, strike, follow through, identical character in every frame, isolated on a "
              "plain flat solid magenta background, " + STYLE)
    for k in range(n):
        g = torch.Generator("cuda").manual_seed(seed + k)
        img = pipe(prompt=prompt, negative_prompt=NEG + ", ground, shadow, frame, panel, border, text",
                   width=1536, height=640, num_inference_steps=30, guidance_scale=7.0, generator=g,
                   cross_attention_kwargs={"scale": 0.6}).images[0]
        p = os.path.join(out, "%s_%d.png" % (char, k))
        img.save(p)
        print("ok", p)
        sys.stdout.flush()


CONTROLNET = "thibaud/controlnet-openpose-sdxl-1.0"
POSE_DIR = os.path.join(OUT, "poses")


def make_posed(char: str, src: str, strength: float, cscale: float, seed: int, poses: list) -> None:
    """자세 지정(ControlNet OpenPose) + 서 있는 그림을 밑그림으로 → 같은 캐릭터가 그 자세를 한 그림.
    → assets/source/lane/posed/<char>_<자세>.png"""
    import torch
    from diffusers import AutoencoderKL, ControlNetModel, StableDiffusionXLControlNetImg2ImgPipeline
    from PIL import Image
    pipe = getattr(make_posed, "pipe", None)
    if pipe is None:
        cn = ControlNetModel.from_pretrained(CONTROLNET, torch_dtype=torch.float16)
        vae = AutoencoderKL.from_pretrained(VAE, torch_dtype=torch.float16)
        pipe = StableDiffusionXLControlNetImg2ImgPipeline.from_pretrained(
            BASE, controlnet=cn, vae=vae, torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
        pipe.load_lora_weights(LORA)
        pipe.enable_model_cpu_offload()
        make_posed.pipe = pipe
    out = os.path.join(OUT, "posed")
    os.makedirs(out, exist_ok=True)
    init = Image.open(src).convert("RGB").resize((1024, 1024))
    for ps in poses:
        ctrl = Image.open(os.path.join(POSE_DIR, ps + ".png")).convert("RGB")
        g = torch.Generator("cuda").manual_seed(seed)
        prompt = ("a single game character sprite, " + CHARS[char] + ", " + POSES.get(ps, "standing") +
                  ", full body, isolated on a plain flat solid grey background, no shadow, " + STYLE)
        img = pipe(prompt=prompt, negative_prompt=NEG + ", multiple characters, ground, shadow, frame, panel",
                   image=init, control_image=ctrl, strength=strength, controlnet_conditioning_scale=cscale,
                   num_inference_steps=30, guidance_scale=7.0, generator=g,
                   cross_attention_kwargs={"scale": 0.6}).images[0]
        p = os.path.join(out, "%s_%s.png" % (char, ps))
        img.save(p)
        print("ok", p)
        sys.stdout.flush()


def make_regen(char: str, ref: str, n: int, seed: int, ip_scale: float, poses: list) -> None:
    """동작마다 새로 생성한다: 자세 지정(OpenPose) + 모습 고정(IP-Adapter, 서 있는 그림을 참고).
    픽셀아트 LoRA 는 끈다 - 켜면 자세보다 화풍을 따른다. 픽셀 느낌은 import 가 입힌다.
    → assets/source/lane/regen/<char>_<자세>_<k>.png"""
    import torch
    from diffusers import AutoencoderKL, ControlNetModel, StableDiffusionXLControlNetPipeline
    from PIL import Image
    pipe = getattr(make_regen, "pipe", None)
    if pipe is None:
        cn = ControlNetModel.from_pretrained(CONTROLNET, torch_dtype=torch.float16)
        vae = AutoencoderKL.from_pretrained(VAE, torch_dtype=torch.float16)
        pipe = StableDiffusionXLControlNetPipeline.from_pretrained(
            BASE, controlnet=cn, vae=vae, torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
        pipe.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter_sdxl_vit-h.safetensors",
                             image_encoder_folder="models/image_encoder")
        pipe.enable_model_cpu_offload()
        make_regen.pipe = pipe
    pipe.set_ip_adapter_scale(ip_scale)
    out = os.path.join(OUT, "regen")
    os.makedirs(out, exist_ok=True)
    refimg = Image.open(ref).convert("RGB").resize((1024, 1024))
    for ps in poses:
        ctrl = Image.open(os.path.join(POSE_DIR, ps + ".png")).convert("RGB")
        for k in range(n):
            g = torch.Generator("cuda").manual_seed(seed + k)
            prompt = ("cute chibi game character, " + CHARS[char] + ", " + POSES.get(ps, "standing") +
                      ", full body, front view, plain flat grey background, pixel art style, clean shapes")
            img = pipe(prompt=prompt, negative_prompt=NEG + ", multiple characters, ground, shadow, frame, panel",
                       image=ctrl, ip_adapter_image=refimg, controlnet_conditioning_scale=1.0,
                       num_inference_steps=30, guidance_scale=6.0, generator=g, width=1024, height=1024).images[0]
            p = os.path.join(out, "%s_%s_%d.png" % (char, ps, k))
            img.save(p)
            print("ok", p)
            sys.stdout.flush()


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "regen":
        # regen <n> <ip세기> <char>=<서 있는 그림> ...   (환경 변수 REGEN_SEED · REGEN_POSES="atk2,walk1" 로 한 칸만 다시)
        seed = int(os.environ.get("REGEN_SEED", "5556"))
        poses = os.environ.get("REGEN_POSES", "stand,walk1,walk2,atk1,atk2,atk3").split(",")
        for pair in sys.argv[4:]:
            c, s = pair.split("=", 1)
            make_regen(c, s, int(sys.argv[2]), seed, float(sys.argv[3]), poses)
        return
    if len(sys.argv) > 1 and sys.argv[1] == "pose":
        # pose <strength> <cn세기> <char>=<원본> ...   (자세 6개 전부)
        for pair in sys.argv[4:]:
            c, s = pair.split("=", 1)
            make_posed(c, s, float(sys.argv[2]), float(sys.argv[3]), 4321,
                       ["walk1", "walk2", "atk1", "atk2", "atk3"])
        return
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        # sheet <n> <char> ...
        for c in sys.argv[3:]:
            make_sheet(c, int(sys.argv[2]), 2000)
        return
    if len(sys.argv) > 1 and sys.argv[1] == "frames":
        # frames <strength> <char>=<원본> ...
        st = float(sys.argv[2])
        for pair in sys.argv[3:]:
            c, s = pair.split("=", 1)
            make_frames(c, s, st, 1234)
        return
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--init", default="", help="밑그림 PNG (img2img) - 'layout' 이면 assets/source/lane/<id>_layout.png")
    ap.add_argument("--strength", type=float, default=0.72)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--lora", type=float, default=0.9, help="픽셀아트 LoRA 세기 - 낮을수록 픽셀이 잘고 그림이 부드럽다")
    ap.add_argument("--tag", default="", help="결과 파일 이름 앞에 붙일 말")
    a = ap.parse_args()
    import torch
    from PIL import Image
    os.makedirs(OUT, exist_ok=True)
    pipe = load_pipe(bool(a.init))
    for jid in a.ids:
        prompt, w, h = JOBS[jid]
        for k in range(a.n):
            seed = a.seed if a.seed >= 0 else int.from_bytes(os.urandom(4), "little")
            g = torch.Generator("cuda").manual_seed(seed + k)
            neg = NEG + (", ground, floor, shadow, platform, base, grass, plants, rocks, multiple characters, "
                         "character sheet, frame, border, panel, square, circle, glow, spotlight, vignette, halo" if w == h else "")
            kw = dict(prompt=prompt, negative_prompt=neg, num_inference_steps=a.steps, guidance_scale=6.5,
                      generator=g, cross_attention_kwargs={"scale": a.lora})
            if a.init:
                path = os.path.join(OUT, "%s_layout.png" % jid) if a.init == "layout" else a.init
                kw["image"] = Image.open(path).convert("RGB").resize((w, h))
                kw["strength"] = a.strength
            else:
                kw["width"], kw["height"] = w, h
            img = pipe(**kw).images[0]
            p = os.path.join(OUT, "%s%s_%d.png" % (a.tag, jid, k))
            img.save(p)
            print("ok", p, "seed", seed + k)
            sys.stdout.flush()


if __name__ == "__main__":
    main()
