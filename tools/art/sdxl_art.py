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
NEG = ("flat, simple, minimalist, empty, blurry, smooth, painting, photo, 3d render, text, watermark, logo, signature, ugly, deformed, "
       "dark, horror, jpeg artifacts, noise")

## id: (prompt, width, height)  - SDXL 이 잘 그리는 크기 (픽셀 수 약 100만)
JOBS = {
    "bg1": ("top-down view of a straight dirt road going from the bottom to the top through a sunny spring meadow, "
            "green grass with clover and tiny white and pink flowers, cherry blossom trees on both sides, "
            "low wooden fences, hay bales, mushrooms, " + STYLE, 768, 1344),
    # 물건은 단색 마젠타 위에 하나만 - import_lane_art.py 가 마젠타를 빼서 투명하게 만든다
    "fort": ("a single cute small wooden fortress game sprite, front view, a row of wooden palisade logs with "
             "pointed tops, a small wooden watchtower in the middle with a red tiled roof, a round window and a "
             "tiny pink flag, isolated on a plain solid magenta background, centered, " + STYLE, 1024, 768),
    "nest": ("a single bug nest game sprite, a big round brown dirt mound with lumps of earth, roots and pebbles, "
             "three dark tunnel holes with small glowing red eyes, cute and mischievous, isolated on a plain solid "
             "magenta background, centered, " + STYLE, 1024, 768),
}


def load_pipe(img2img: bool):
    import torch
    from diffusers import AutoencoderKL, StableDiffusionXLImg2ImgPipeline, StableDiffusionXLPipeline
    vae = AutoencoderKL.from_pretrained(VAE, torch_dtype=torch.float16)
    cls = StableDiffusionXLImg2ImgPipeline if img2img else StableDiffusionXLPipeline
    pipe = cls.from_pretrained(BASE, vae=vae, torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
    pipe.load_lora_weights(LORA)
    pipe.enable_model_cpu_offload()       # 12GB 카드에서 넉넉하게
    return pipe


def main() -> None:
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
            kw = dict(prompt=prompt, negative_prompt=NEG, num_inference_steps=a.steps, guidance_scale=6.5,
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
