#!/usr/bin/env python3
"""이 컨테이너 안에서 그림 모델(SD-Turbo)을 직접 돌려 쿼카 군단 그림을 받는다 - API 키·비용 없음.

필요한 것: 네트워크에서 huggingface.co 허용 (모델 파일을 받는다).

    # 한 번만 (새 세션마다 - /tmp 는 사라진다)
    python3 -m venv /tmp/sdenv && /tmp/sdenv/bin/pip install stable-diffusion-cpp-python pillow
    # 받기 + 그리기
    /tmp/sdenv/bin/python tools/art/local_sd.py bg1            # 하나
    /tmp/sdenv/bin/python tools/art/local_sd.py first          # 먼저 3장
    /tmp/sdenv/bin/python tools/art/local_sd.py bg1 --n 4      # 같은 프롬프트로 4장 (고르기)

SD 계열은 프롬프트를 77토큰까지만 읽는다 - 제미나이용 긴 프롬프트(lane_prompts.py) 대신 짧은 SHORT 를 쓴다.
SD-Turbo 는 Stability AI Community License (연 매출 100만 달러 미만 무료 상업 사용).
"""
import os
import sys
import urllib.request

MODEL_URL = "https://huggingface.co/stabilityai/sd-turbo/resolve/main/sd_turbo.safetensors"
MODEL = "/tmp/sdmodels/sd_turbo.safetensors"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "source", "lane")

STYLE = "cozy detailed pixel art, stardew valley style, 16-bit, rich shading, warm colors, crisp pixels"
NEG = "blurry, photo, 3d render, text, watermark, logo, ugly, dark, horror"
SHORT = {
    "bg1": ("top-down view of a dirt road going straight up through a sunny spring meadow, cherry blossom trees, "
            "clover, tiny flowers, wooden fences, hay bale, " + STYLE, 512, 896),
    "fortnest": ("game sprite sheet on magenta background, left: cute wooden palisade fort with small watchtower "
                 "red roof and paw flag, right: round dirt mound bug nest with three holes and glowing red eyes, "
                 + STYLE, 896, 512),
    "quokkaA": ("character sprite sheet on magenta background, eight cute chibi quokka soldiers in a 4x2 grid, "
                "caramel brown fur, helmet, shield, spear, hammer, slingshot, wizard hat, front view, " + STYLE,
                896, 512),
}
FIRST = ["bg1", "fortnest", "quokkaA"]


def ensure_model() -> None:
    if os.path.exists(MODEL):
        return
    os.makedirs(os.path.dirname(MODEL), exist_ok=True)
    print("모델 받는 중 (몇 GB):", MODEL_URL)
    urllib.request.urlretrieve(MODEL_URL, MODEL + ".part")
    os.rename(MODEL + ".part", MODEL)


def main() -> None:
    args = sys.argv[1:]
    n = 1
    if "--n" in args:
        i = args.index("--n")
        n = int(args[i + 1])
        del args[i:i + 2]
    ids = FIRST if args == ["first"] else (list(SHORT) if args == ["all"] else args)
    ensure_model()
    from stable_diffusion_cpp import StableDiffusion
    sd = StableDiffusion(model_path=MODEL, n_threads=os.cpu_count() or 4)
    os.makedirs(OUT, exist_ok=True)
    for jid in ids:
        prompt, w, h = SHORT[jid]
        imgs = sd.generate_image(prompt=prompt, negative_prompt=NEG, width=w, height=h, sample_steps=4,
                                 cfg_scale=1.0, seed=-1, batch_count=n)
        for k, im in enumerate(imgs):
            path = os.path.join(OUT, "%s%s.png" % (jid, "" if n == 1 else "_%d" % k))
            im.save(path)
            print("✓", path)


if __name__ == "__main__":
    main()
