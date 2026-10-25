#!/usr/bin/env python3
"""이 컨테이너 안에서 그림 모델(SD-Turbo)을 직접 돌려 쿼카 군단 그림을 받는다 - API 키·비용 없음.

필요한 것: 네트워크에서 huggingface.co 허용 (모델 파일을 받는다).

    # 한 번만 (새 세션마다 - /tmp 는 사라진다)
    python3 -m venv /tmp/sdenv && /tmp/sdenv/bin/pip install stable-diffusion-cpp-python pillow
    # 받기 + 그리기
    /tmp/sdenv/bin/python tools/art/local_sd.py bg1            # 하나
    /tmp/sdenv/bin/python tools/art/local_sd.py first          # 먼저 3장
    /tmp/sdenv/bin/python tools/art/local_sd.py bg1 --n 4      # 같은 프롬프트로 4장 (고르기)

윈도우 + NVIDIA 그래픽카드 (C++ 컴파일러가 없어도 된다 - diffusers 로 돈다):
    python -m venv .sdenv
    .sdenv/Scripts/python -m pip install torch --index-url https://download.pytorch.org/whl/cu124
    .sdenv/Scripts/python -m pip install diffusers transformers accelerate safetensors pillow
    .sdenv/Scripts/python tools/art/local_sd.py first
stable_diffusion_cpp 가 없으면 저절로 diffusers 를 쓴다 (모델은 허깅페이스 캐시, fp16 약 2.5GB).

SD 계열은 프롬프트를 77토큰까지만 읽는다 - 제미나이용 긴 프롬프트(lane_prompts.py) 대신 짧은 SHORT 를 쓴다.
SD-Turbo 는 Stability AI Community License (연 매출 100만 달러 미만 무료 상업 사용).
"""
import os
import sys
import urllib.request

MODEL_URL = "https://huggingface.co/stabilityai/sd-turbo/resolve/main/sd_turbo.safetensors"
HF_REPO = "stabilityai/sd-turbo"
## 모델 파일 자리: SD_MODELS 환경 변수 > /tmp/sdmodels (리눅스 컨테이너) > ~/sdmodels (윈도우·맥)
MODEL_DIR = os.environ.get("SD_MODELS") or ("/tmp/sdmodels" if os.name == "posix" and os.path.isdir("/tmp")
                                            else os.path.join(os.path.expanduser("~"), "sdmodels"))
MODEL = os.path.join(MODEL_DIR, "sd_turbo.safetensors")
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


def _cpp_backend():
    """stable-diffusion.cpp (CPU, 리눅스 컨테이너). 없으면 None."""
    try:
        from stable_diffusion_cpp import StableDiffusion
    except ImportError:
        return None
    ensure_model()
    sd = StableDiffusion(model_path=MODEL, n_threads=os.cpu_count() or 4)
    return lambda prompt, w, h, n: sd.generate_image(prompt=prompt, negative_prompt=NEG, width=w, height=h,
                                                     sample_steps=4, cfg_scale=1.0, seed=-1, batch_count=n)


def _diffusers_backend():
    """diffusers + torch (NVIDIA 그래픽카드면 GPU, 없으면 CPU)."""
    import torch
    from diffusers import AutoPipelineForText2Image
    cuda = torch.cuda.is_available()
    print("diffusers 로 그린다 -", torch.cuda.get_device_name(0) if cuda else "CPU (느리다)")
    pipe = AutoPipelineForText2Image.from_pretrained(HF_REPO, torch_dtype=torch.float16 if cuda else torch.float32,
                                                     variant="fp16" if cuda else None)
    pipe = pipe.to("cuda" if cuda else "cpu")
    # SD-Turbo 는 가이던스 없이(cfg 0) 1~4걸음 - 부정 프롬프트는 가이던스가 있어야 먹으니 넣지 않는다
    return lambda prompt, w, h, n: pipe(prompt=prompt, width=w, height=h, num_inference_steps=4,
                                        guidance_scale=0.0, num_images_per_prompt=n).images


def main() -> None:
    args = sys.argv[1:]
    n = 1
    if "--n" in args:
        i = args.index("--n")
        n = int(args[i + 1])
        del args[i:i + 2]
    ids = FIRST if args == ["first"] else (list(SHORT) if args == ["all"] else args)
    gen = _cpp_backend() or _diffusers_backend()
    os.makedirs(OUT, exist_ok=True)
    for jid in ids:
        prompt, w, h = SHORT[jid]
        imgs = gen(prompt, w, h, n)
        for k, im in enumerate(imgs):
            path = os.path.join(OUT, "%s%s.png" % (jid, "" if n == 1 else "_%d" % k))
            im.save(path)
            print("✓", path)


if __name__ == "__main__":
    main()
