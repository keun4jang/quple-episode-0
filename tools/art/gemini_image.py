#!/usr/bin/env python3
"""제미나이로 그림을 받아 assets/source/lane/ 에 저장한다 (쿼카 군단 그림 다시 받기).

    GEMINI_API_KEY=... python3 tools/art/gemini_image.py bg1          # 하나
    python3 tools/art/gemini_image.py first                          # 먼저 받을 3장 (bg1 fortnest quokkaA)
    python3 tools/art/gemini_image.py all                            # 전부
    python3 tools/art/gemini_image.py --list

키는 환경 변수 GEMINI_API_KEY 에서만 읽는다 (파일에 적지 않는다).
프롬프트는 tools/art/lane_prompts.py, 설명은 docs/art-prompts-lane.md.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lane_prompts  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "assets", "source", "lane")
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")
URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"


def generate(key: str, prompt: str, aspect: str) -> bytes:
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect}},
    }
    req = urllib.request.Request(URL % MODEL, data=json.dumps(body).encode("utf-8"), method="POST",
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.loads(r.read().decode("utf-8"))
    for cand in data.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])
    raise RuntimeError("그림이 안 왔다: %s" % json.dumps(data)[:400])


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] == "--list":
        for k, v in lane_prompts.JOBS.items():
            print("%-10s %-5s %s" % (k, v["aspect"], v["title"]))
        return
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key:
        raise SystemExit("GEMINI_API_KEY 가 없다 - 클라우드 환경 설정의 비밀값(환경 변수)으로 넣어 주세요")
    ids = list(lane_prompts.JOBS) if args[0] == "all" else (lane_prompts.FIRST if args[0] == "first" else args)
    os.makedirs(OUT, exist_ok=True)
    for jid in ids:
        job = lane_prompts.JOBS[jid]
        for attempt in range(3):
            try:
                png = generate(key, lane_prompts.prompt(jid), job["aspect"])
                path = os.path.join(OUT, "%s.png" % jid)
                with open(path, "wb") as f:
                    f.write(png)
                print("✓ %s → %s (%d KB)" % (jid, path, len(png) // 1024))
                break
            except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as e:
                msg = e.read().decode("utf-8", "replace")[:300] if isinstance(e, urllib.error.HTTPError) else str(e)
                print("✗ %s (%d번째): %s" % (jid, attempt + 1, msg))
                time.sleep(4 * (attempt + 1))


if __name__ == "__main__":
    main()
