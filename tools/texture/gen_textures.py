#!/usr/bin/env python3
"""쿼플 표면 텍스처 생성기 — 흑백 디테일 맵 + 노멀 맵.

지금 씬의 물체는 전부 텍스처 없는 단색이다. 표면에 정보가 0이라
아무리 색을 잘 맞춰도 플라스틱 장난감처럼 보인다.

그렇다고 컬러 텍스처를 씌우면 지금까지 맞춰 온 파스텔 팔레트가 통째로 무너진다.
(색 설계는 scripts/systems/mood_palette.gd 와 scripts/travel/palette.gd 에 있고,
 쿼카 스카프색인 산호 #FF6F61 계열을 배경에서 금지하는 규칙까지 걸려 있다.)

그래서 색은 건드리지 않고 결만 만든다. 표면마다 두 장을 굽는다.

  <이름>_d.png   디테일. 흑백. 평균 0.5. 기존 albedo 색에 곱한다.
                 0.5 가 "손대지 않음" 이다. 그러니 곱하는 쪽에서 2배 해야 한다.
                   albedo *= detail * 2.0
                 그냥 곱하면 물체가 통째로 절반 어두워지면서 파스텔 팔레트가 무너진다.
                 표준편차 0.038 이면 실제 밝기 편차는 ±7.6% 라는 뜻이다.
  <이름>_n.png   노멀. 디테일과 **같은 높이 맵**에서 소벨로 뽑는다.
                 빛이 요철에 걸리게 만드는 쪽이라, 사실 이쪽이 절반 이상을 한다.

세 가지를 지킨다.

  1. 세기는 아주 약하게. 힐링 게임이다. 결이 눈에 띄면 그 시점에 과한 것이다.
     "자세히 보면 결이 있다" 수준이지 "무늬가 보인다" 가 아니다.
     그래서 디테일 맵의 표준편차를 0.06 아래로 묶어 둔다(한도는 0.10).
  2. 타일링. 이 게임의 물체는 BoxMesh/CylinderMesh 를 크기만 바꿔 쓰기 때문에
     삼중평면(triplanar) 으로 월드 좌표에 물릴 거고, 그러면 이음매가 반드시 드러난다.
     노이즈 격자 인덱스를 전부 모듈러로 감아서 상하좌우가 이어지게 만들었다.
     만든 뒤 --check 가 굴려서(roll) 실제로 이어지는지 숫자로 잰다.
  3. 결정적. randf 대신 고정 시드 정수 해시를 쓴다. 두 번 돌리면 같은 바이트가 나온다.
     prop_kit.gd 가 위치를 시드로 쓰는 것과 같은 이유다 — 실행할 때마다 달라지면
     테스트가 흔들린다.

의존성은 PIL 하나다. numpy 는 쓰지 않는다. 이 저장소는 외부 다운로드를 금지하고
있고, 실제로 이 컨테이너에도 numpy 가 없다. tools/icon/gen_icon.py 와 같은 발자국을
유지하는 편이 새 클론에서 안전하다. 무거운 보간은 PIL 대신 직접 짠 루프가 도는데,
512px 아홉 장이라 몇 초면 끝난다.

사용법:
    python3 tools/texture/gen_textures.py                    # assets/textures 에 굽기
    python3 tools/texture/gen_textures.py --check            # 통계·이음매만 다시 재기
    python3 tools/texture/gen_textures.py --preview /tmp/p   # 눈으로 볼 미리보기 PNG

Godot 쪽에서 쓸 때 (참고):
    mat.detail_enabled 가 아니라 albedo 에 곱하는 쪽이 목적이므로
    triplanar 를 켜고 uv1_scale 로 월드 밀도를 맞춘다.
      mat.uv1_triplanar = true
      mat.uv1_scale = Vector3(0.35, 0.35, 0.35)   # 1 타일 ≈ 2.8m
      mat.normal_enabled = true ; mat.normal_scale = 0.6
"""

import argparse
import math
import os

from PIL import Image, ImageDraw

# ── 기본값 ──────────────────────────────────────────────────────────────

SEED = 20260806          # 고정 시드. 바꾸면 결과물이 전부 달라진다.
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures")

# 노멀 맵이 바라보는 조명 방향(미리보기 전용). 왼쪽 위에서 비스듬히.
PREVIEW_LIGHT = (-0.42, 0.48, 0.77)


# ── 결정적 난수 ─────────────────────────────────────────────────────────
#
# random 모듈을 쓰지 않는다. 파이썬 버전에 따라 수열이 달라질 여지를 남기고 싶지 않다.
# 정수 몇 개를 섞어 [0,1) 을 뱉는 해시면 충분하고, 격자 좌표를 그대로 키로 쓸 수 있어서
# "인덱스를 모듈러로 감으면 타일링" 이 공짜로 따라온다.

def _h01(*key: int) -> float:
	x = 0x9E3779B1
	for k in key:
		x = ((x ^ (int(k) & 0xFFFFFFFF)) * 0x85EBCA6B) & 0xFFFFFFFF
		x ^= x >> 13
		x = (x * 0xC2B2AE35) & 0xFFFFFFFF
		x ^= x >> 16
	return x / 4294967296.0


# ── 버퍼 도구 ───────────────────────────────────────────────────────────
#
# 값은 전부 float 리스트 하나(길이 w*h)로 들고 다닌다. 클래스를 만들 만큼 크지 않다.

def _smooth(t: float) -> float:
	# 스무스스텝. 격자 값 사이를 이걸로 이어야 셀 경계에 각이 안 선다.
	return t * t * (3.0 - 2.0 * t)


def noise(w: int, h: int, cx: int, cy: int, salt: int) -> list:
	"""cx x cy 격자의 값 노이즈.

	격자 인덱스를 cx, cy 로 나눈 나머지로 읽기 때문에 좌우/상하가 저절로 이어진다.
	cx 와 cy 를 다르게 주면 한쪽으로 늘어난 결이 된다 — 금속 브러시와 나무 섬유가 그걸 쓴다.
	"""
	g = [[_h01(SEED, salt, gx, gy) for gx in range(cx)] for gy in range(cy)]
	# x 방향 가중치는 모든 행에서 같으므로 한 번만 구해 둔다.
	xi0 = [0] * w
	xi1 = [0] * w
	xft = [0.0] * w
	for x in range(w):
		u = x * cx / w
		i0 = int(u)
		xi0[x] = i0 % cx
		xi1[x] = (i0 + 1) % cx
		xft[x] = _smooth(u - i0)
	out = [0.0] * (w * h)
	for y in range(h):
		v = y * cy / h
		j0 = int(v)
		f = _smooth(v - j0)
		r0 = g[j0 % cy]
		r1 = g[(j0 + 1) % cy]
		base = y * w
		for x in range(w):
			a = xi0[x]
			b = xi1[x]
			t = xft[x]
			v0 = r0[a] + (r0[b] - r0[a]) * t
			v1 = r1[a] + (r1[b] - r1[a]) * t
			out[base + x] = v0 + (v1 - v0) * f
	return out


def fbm(w: int, h: int, cells: int, octaves: int, gain: float, salt: int,
		aspect: float = 1.0) -> list:
	"""옥타브를 겹친 노이즈. 큰 얼룩부터 잔 알갱이까지 한 장에 담는다.

	aspect 는 x 격자 배율이다. 1 이 아니면 결이 한쪽으로 늘어난다.
	"""
	out = [0.0] * (w * h)
	amp = 1.0
	total = 0.0
	for o in range(octaves):
		cy = cells << o
		cx = max(2, int(round(cy * aspect)))
		if cx > w // 2 or cy > h // 2:
			break
		layer = noise(w, h, cx, cy, salt * 977 + o)
		for i in range(w * h):
			out[i] += layer[i] * amp
		total += amp
		amp *= gain
	if total > 0.0:
		inv = 1.0 / total
		for i in range(w * h):
			out[i] *= inv
	return out


def _transpose(buf: list, w: int, h: int) -> list:
	out = [0.0] * (w * h)
	for y in range(h):
		row = buf[y * w:(y + 1) * w]
		for x in range(w):
			out[x * h + y] = row[x]
	return out


def _box_h(buf: list, w: int, h: int, r: int) -> list:
	"""가로 박스 블러. 양끝을 감아서 처리해야 블러가 이음매를 깨지 않는다."""
	out = [0.0] * (w * h)
	inv = 1.0 / (2 * r + 1)
	for y in range(h):
		row = buf[y * w:(y + 1) * w]
		s = 0.0
		for i in range(-r, r + 1):
			s += row[i % w]
		base = y * w
		for x in range(w):
			out[base + x] = s * inv
			s += row[(x + r + 1) % w] - row[(x - r) % w]
	return out


def blur(buf: list, w: int, h: int, r: int, passes: int = 2) -> list:
	"""박스 블러를 두 번 겹쳐 가우시안 흉내. 뭉게구름 같은 잎사귀 덩어리에 쓴다."""
	if r < 1:
		return list(buf)
	out = list(buf)
	for _ in range(passes):
		out = _box_h(out, w, h, r)
		out = _transpose(_box_h(_transpose(out, w, h), h, w, r), h, w)
	return out


def zscore(buf: list) -> list:
	"""평균 0, 표준편차 1 로 맞춘다.

	층을 섞기 전에 전부 이걸 통과시킨다. 그래야 아래 mix 의 가중치가
	"이 층이 최종 결에 얼마나 기여하는가" 를 그대로 뜻하게 된다.
	"""
	n = len(buf)
	m = sum(buf) / n
	var = sum((v - m) * (v - m) for v in buf) / n
	sd = math.sqrt(var) if var > 1e-12 else 1.0
	inv = 1.0 / sd
	return [(v - m) * inv for v in buf]


def mix(size: int, *parts) -> list:
	"""(가중치, 층) 들을 더한다. 층은 전부 zscore 를 통과한 상태여야 한다."""
	out = [0.0] * size
	for wgt, layer in parts:
		for i in range(size):
			out[i] += layer[i] * wgt
	return out


def curve(buf: list, power: float) -> list:
	"""0~1 값에 감마. 1 보다 크면 어두운 쪽이 넓어진다(얼룩이 성기게 진다)."""
	lo = min(buf)
	hi = max(buf)
	rng = (hi - lo) or 1.0
	return [(((v - lo) / rng) ** power) for v in buf]


def billow(buf: list) -> list:
	"""0~1 노이즈를 접어 뭉치게 만든다. 잎사귀 덩어리와 아스팔트 골재에 쓴다."""
	return [abs(v * 2.0 - 1.0) for v in buf]


# ── 표면별 높이 맵 ──────────────────────────────────────────────────────
#
# 전부 "높이 맵 한 장" 을 돌려준다. 디테일도 노멀도 여기서 파생된다.
# 두 장이 서로 다른 소스에서 나오면 밝은 자리와 튀어나온 자리가 어긋나서
# 표면이 오히려 더 가짜로 보인다.
#
# 구조적인 크기(타일 칸 수, 나무 나이테 수, 직조 올 수)는 절대값으로 둔다.
# 해상도를 올려도 월드에서 같은 자리에 같은 선이 있어야 하기 때문이다.
# 반대로 알갱이·섬유처럼 "안 보여야 정상인" 것은 픽셀 기준(n 비례)으로 둔다.

def build_concrete(n: int) -> list:
	"""건물 외벽·인도. 넓은 얼룩 + 미세한 알갱이."""
	# 큰 얼룩을 세게 주면 표면이 아니라 구름이 된다. 처음에 3칸 fbm 을 0.60 으로 넣었더니
	# 스웨이드 가죽처럼 뭉게뭉게 읽혔고, 2x2 로 붙였을 때 반복까지 눈에 띄었다.
	# 저주파를 눌러야 반복도 같이 죽는다.
	broad = zscore(fbm(n, n, 6, 5, 0.5, 11))             # 세월이 남긴 얼룩
	stain = zscore(blur(curve(noise(n, n, 9, 9, 12), 1.7), n, n, max(1, n // 128)))
	grain = zscore(noise(n, n, n // 2, n // 2, 13))       # 2px 알갱이
	fine = zscore(noise(n, n, n // 4, n // 4, 14))
	return mix(n * n, (0.30, broad), (0.26, stain), (0.44, grain), (0.34, fine))


def build_asphalt(n: int) -> list:
	"""도로. 콘크리트보다 알갱이가 굵고 성기다."""
	agg = zscore(billow(noise(n, n, n // 8, n // 8, 21)))   # 골재 덩어리
	chip = zscore(noise(n, n, n // 3, n // 3, 22))          # 잔돌
	grain = zscore(noise(n, n, n // 2, n // 2, 23))
	sweep = zscore(fbm(n, n, 3, 4, 0.5, 24))               # 포장이 누운 큰 굴곡
	return mix(n * n, (0.52, agg), (0.44, chip), (0.30, grain), (0.40, sweep))


def build_wood(n: int) -> list:
	"""나무 줄기·가구. 결 방향(가로)이 분명한 줄무늬."""
	rings = 13                                   # 나이테 수. 해상도와 무관하게 고정.
	warp = noise(n, n, 6, 3, 31)                 # 결을 살짝 휘게 하는 저주파
	sway = noise(n, n, 3, 2, 32)
	band = [0.0] * (n * n)
	for y in range(n):
		base = y * n
		v = y / n
		for x in range(n):
			i = base + x
			# 나이테는 y 방향으로 반복한다(결은 가로로 흐른다).
			# 정수 주기라 위아래가 그대로 이어진다.
			t = v * rings + (warp[i] - 0.5) * 0.55 + (sway[i] - 0.5) * 0.30
			s = 0.5 + 0.5 * math.sin(t * math.tau)
			# 제곱하면 어두운 줄이 좁고 또렷해지는데, 그러면 무늬목 시트가 된다.
			# 1.3 정도만 줘서 줄이 있다는 것만 알려 준다.
			band[i] = s ** 1.3
	fiber = zscore(noise(n, n, max(4, n // 24), n // 2, 33))   # 가로로 늘어난 섬유
	pore = zscore(noise(n, n, max(3, n // 40), n // 3, 34))
	return mix(n * n, (0.58, zscore(band)), (0.42, fiber), (0.26, pore))


def build_metal(n: int) -> list:
	"""가로등·기둥·실외기. 세로로 아주 미세한 브러시 자국만."""
	brush = zscore(noise(n, n, n // 2, max(2, n // 48), 41))   # x 촘촘, y 늘어남
	brush2 = zscore(noise(n, n, n // 3, max(2, n // 80), 42))
	dent = zscore(fbm(n, n, 4, 3, 0.45, 43))                   # 판이 아주 살짝 우는 정도
	return mix(n * n, (0.62, brush), (0.40, brush2), (0.30, dent))


def build_fabric(n: int) -> list:
	"""커튼·러그·소파. 씨실 날실이 교차하는 격자.

	칸마다 "위로 올라온 실" 을 갈아 끼우는 방식으로 짜면 칸 경계에서 밝기가 툭 끊긴다.
	이음매 검사에 바로 걸린다. 그래서 실을 한 올씩 세우고, 그 올이 지나가면서
	위아래로 넘실대게 만든다. 단면이 경계에서 0 으로 수렴하므로 어디서도 끊기지 않는다.
	올 수가 짝수라야 넘실거림의 주기까지 맞아떨어진다.
	"""
	# 올이 굵으면 천이 아니라 고무 미끄럼방지 매트가 된다. 20 올로 짰더니 딱 그랬다.
	# 32 올이면 256px 에서 한 올이 8px 이라 "천" 으로 읽히기 시작한다. 짝수라야
	# 위아래로 넘실대는 주기까지 맞아떨어진다.
	threads = 32
	p = n / threads
	weave = [0.0] * (n * n)
	for y in range(n):
		base = y * n
		v = y / p
		j = int(v)
		py = math.sin((v - j) * math.pi)          # 씨실 단면(둥근 봉)
		ay = 0.88 + 0.24 * _h01(SEED, 52, j)      # 올마다 굵기가 조금씩 다르다
		for x in range(n):
			u = x / p
			i = int(u)
			px = math.sin((u - i) * math.pi)      # 날실 단면
			ax = 0.88 + 0.24 * _h01(SEED, 51, i)
			# 날실은 y 를 따라, 씨실은 x 를 따라 위아래로 넘실댄다.
			# 이웃한 올끼리 반대 위상이라야 격자로 읽힌다.
			warp = px * ax * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(math.pi * (v + i))))
			weft = py * ay * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(math.pi * (u + j))))
			weave[base + x] = warp + weft
	lint = zscore(noise(n, n, n // 2, n // 2, 53))             # 보풀
	drape = zscore(fbm(n, n, 4, 3, 0.5, 54))                   # 천이 누운 큰 흐름
	return mix(n * n, (0.62, zscore(weave)), (0.30, lint), (0.42, drape))


def build_foliage(n: int) -> list:
	"""잎사귀 덩어리. 잎을 한 장씩 그리지 않는다 — 뭉게구름 같은 뭉침만."""
	# billow 는 접힌 자리가 골이 되어 대비가 세진다. 넉넉히 뭉개야 잎 덩어리가 되지,
	# 덜 뭉개면 군복 위장무늬가 된다. 그늘 층도 2칸이면 화면이 반반으로 갈려서 4칸으로 올렸다.
	clump = zscore(blur(billow(fbm(n, n, 5, 4, 0.62, 61)), n, n, max(2, n // 40)))
	leaf = zscore(blur(noise(n, n, n // 12, n // 12, 62), n, n, max(1, n // 128)))
	deep = zscore(fbm(n, n, 4, 3, 0.55, 63))                   # 덩어리 안쪽 그늘
	return mix(n * n, (0.70, clump), (0.30, leaf), (0.22, deep))


def build_tile(n: int) -> list:
	"""실내 바닥. 일정한 이음새 격자 + 칸마다 아주 옅은 색차."""
	cells = 4                                     # 한 변에 4칸. 절대값 고정.
	p = n / cells
	grout = max(1.6, n / 128.0)                   # 이음새 폭(px)
	bevel = grout * 2.6                           # 이음새 옆 모따기
	base = [0.0] * (n * n)
	for y in range(n):
		row = y * n
		gy = int(y / p)
		dy = min((y / p - gy) * p, (gy + 1) * p - y)
		for x in range(n):
			gx = int(x / p)
			dx = min((x / p - gx) * p, (gx + 1) * p - x)
			d = min(dx, dy)
			# 모따기로 부드럽게 내려간 뒤 바닥에서 한 번 더 좁게 파인다.
			# 두 항 모두 경계에서 값이 이어지게 스무스스텝으로 만들었다 — 계단이 생기면
			# 그 자리에서 노멀이 튀어 이음새가 형광등처럼 번쩍인다.
			v = _smooth(min(1.0, d / bevel)) - 0.35 * (1.0 - _smooth(min(1.0, d / grout)))
			# 칸마다 미세한 밝기 차. 같은 타일이 16칸 이어지면 인쇄물처럼 보인다.
			base[row + x] = v + (_h01(SEED, 71, gx, gy) - 0.5) * 0.10
	speck = zscore(noise(n, n, n // 2, n // 2, 72))
	wear = zscore(fbm(n, n, 3, 4, 0.5, 73))
	return mix(n * n, (1.00, zscore(base)), (0.16, speck), (0.26, wear))


def build_plaster(n: int) -> list:
	"""실내 벽. 아주 옅은 얼룩과 미장 자국. 여기가 제일 약해야 한다."""
	# 미장 자국을 세로로 길게 주면 벽이 아니라 물 흘러내린 자국이 된다.
	# 방향성을 반쯤 걷어내고 얼룩도 잘게 쪼갠다. 여기는 아홉 표면 중 제일 약해야 하는 곳이다.
	mottle = zscore(fbm(n, n, 5, 4, 0.5, 81))
	trowel = zscore(blur(noise(n, n, n // 6, max(4, n // 16), 82), n, n, max(1, n // 160)))
	tooth = zscore(noise(n, n, n // 2, n // 2, 83))
	return mix(n * n, (0.78, mottle), (0.22, trowel), (0.24, tooth))


def build_paper(n: int) -> list:
	"""포스터·간판. 섬유 결 + 아주 옅은 얼룩."""
	fx = zscore(noise(n, n, n // 2, max(4, n // 12), 91))
	fy = zscore(noise(n, n, max(4, n // 12), n // 2, 92))
	tooth = zscore(noise(n, n, n // 2, n // 2, 93))
	blot = zscore(fbm(n, n, 3, 3, 0.45, 94))
	return mix(n * n, (0.40, fx), (0.40, fy), (0.26, tooth), (0.30, blot))


# ── 표면 목록 ───────────────────────────────────────────────────────────
#
# (이름, 해상도, 디테일 표준편차, 노멀 세기, 설명)
#
# std 는 곱했을 때의 밝기 편차다. 0.04 면 albedo 가 ±4% 흔들린다는 뜻이고,
# 그 정도가 "자세히 보면 결이 있다" 의 실제 값이다. 한도는 0.10.
# bump 는 소벨 기울기 배율이다. 미리보기에서 평균 기울기 각도로 확인한다.

SURFACES = [
	("concrete", 512, 0.024, 0.22, build_concrete, "건물 외벽·인도"),
	("asphalt",  512, 0.030, 0.20, build_asphalt,  "도로"),
	("wood",     512, 0.026, 0.26, build_wood,     "나무 줄기·가구"),
	("metal",    256, 0.013, 0.10, build_metal,    "가로등·기둥·실외기"),
	("fabric",   256, 0.022, 0.16, build_fabric,   "커튼·러그·쿠션"),
	("foliage",  256, 0.021, 0.30, build_foliage,  "잎사귀 덩어리"),
	("tile",     256, 0.026, 0.26, build_tile,     "실내 바닥"),
	("plaster",  256, 0.015, 0.22, build_plaster,  "실내 벽"),
	("paper",    256, 0.018, 0.10, build_paper,    "포스터·간판"),
]

# 미리보기에 쓸 바탕색. 실제 씬에서 그 표면이 칠해져 있는 색을 그대로 가져왔다
# (company_front_3d.gd / office_3d.gd / souvenir_room_3d.gd).
# 결의 세기는 바탕색 위에서만 판단할 수 있다 — 흑백 원본만 띄워 놓고 보면
# 늘 "약해 보이는데" 로 끝나고, 어두운 아스팔트와 밝은 커튼은 같은 std 라도 다르게 읽힌다.
PREVIEW_PICKS = [
	("concrete", "#7F8790"),   # Sidewalk
	("asphalt",  "#3B3E46"),   # Road
	("wood",     "#8A6A4A"),   # TableTop
	("metal",    "#8A9099"),   # LampStem
	("fabric",   "#E3CDBE"),   # CurtainPanel
	("foliage",  "#72B48D"),   # Canopy
	("tile",     "#43566A"),   # office Floor
	("plaster",  "#4A5D74"),   # BackWall
	("paper",    "#F2EEE2"),   # InfoLine
]
PREVIEW_COLS = 3


# ── 굽기 ────────────────────────────────────────────────────────────────

def to_detail(height: list, std: float) -> list:
	"""높이 맵을 평균 0.5 의 디테일 맵으로.

	평균이 0.5 를 벗어나면 곱했을 때 물체 전체가 어두워지거나 밝아진다.
	그러면 색 설계가 통째로 틀어지므로 여기가 제일 중요하다.
	"""
	z = zscore(height)
	return [max(0.0, min(1.0, 0.5 + v * std)) for v in z]


def to_normal(height: list, n: int, bump: float) -> list:
	"""같은 높이 맵에서 소벨로 노멀을 뽑는다. (r, g, b) 튜플 리스트.

	Godot 은 OpenGL 규약(+Y 가 위)을 쓴다. 이미지의 y 는 아래로 늘어나므로
	세로 기울기의 부호를 뒤집어야 요철이 반대로 파이지 않는다.
	이웃을 감아서(wrap) 읽는 것도 잊으면 안 된다 — 가장자리에서만 노멀이 튄다.
	"""
	z = zscore(height)
	out = [(0.0, 0.0, 0.0)] * (n * n)
	for y in range(n):
		ym = ((y - 1) % n) * n
		y0 = y * n
		yp = ((y + 1) % n) * n
		for x in range(n):
			xm = (x - 1) % n
			xp = (x + 1) % n
			# 소벨 3x3
			gx = ((z[ym + xp] + 2.0 * z[y0 + xp] + z[yp + xp])
				- (z[ym + xm] + 2.0 * z[y0 + xm] + z[yp + xm])) * 0.125
			gy = ((z[yp + xm] + 2.0 * z[yp + x] + z[yp + xp])
				- (z[ym + xm] + 2.0 * z[ym + x] + z[ym + xp])) * 0.125
			nx = -gx * bump
			ny = gy * bump          # 이미지 y 는 아래로 → 부호 반전
			inv = 1.0 / math.sqrt(nx * nx + ny * ny + 1.0)
			out[y0 + x] = (nx * inv, ny * inv, inv)
	return out


def save_detail(path: str, buf: list, n: int) -> None:
	raw = bytes(max(0, min(255, int(v * 255.0 + 0.5))) for v in buf)
	Image.frombytes("L", (n, n), raw).save(path, optimize=True)


def save_normal(path: str, nrm: list, n: int) -> None:
	raw = bytearray(n * n * 3)
	i = 0
	for (r, g, b) in nrm:
		raw[i] = max(0, min(255, int(r * 127.5 + 128.0)))
		raw[i + 1] = max(0, min(255, int(g * 127.5 + 128.0)))
		raw[i + 2] = max(0, min(255, int(b * 127.5 + 128.0)))
		i += 3
	Image.frombytes("RGB", (n, n), bytes(raw)).save(path, optimize=True)


def load_channel(path: str, which: int = 0) -> tuple:
	"""저장된 PNG 를 0~1 float 리스트로 되읽는다. 8비트로 깎인 뒤의 진짜 값이다."""
	img = Image.open(path)
	w, h = img.size
	raw = img.tobytes()
	if img.mode == "L":
		vals = [v / 255.0 for v in raw]
	else:
		vals = [raw[i] / 255.0 for i in range(which, len(raw), 3)]
	return vals, w, h


# ── 검사 ────────────────────────────────────────────────────────────────

def stats(vals: list) -> tuple:
	n = len(vals)
	m = sum(vals) / n
	sd = math.sqrt(sum((v - m) * (v - m) for v in vals) / n)
	return m, sd, min(vals), max(vals)


def _gap_report(gaps: list) -> tuple:
	"""틈 세기 목록에서 마지막(감긴 자리) 것이 얼마나 튀는지.

	그냥 "이음매 차이 / 전체 평균 차이" 로 재면 안 된다. 타일 이음새나 직조 올처럼
	원래 경계가 있는 표면은 굴린 자리가 하필 그 경계에 걸리기만 해도 비율이 4배로 뛴다.
	실제로 처음에 그렇게 재서 멀쩡한 타일을 실패로 읽었다.

	그래서 모든 틈의 분포 안에서 감긴 자리가 몇 번째로 큰지, 표준편차로 몇 배 벗어났는지를 본다.
	1등이면서 z 가 크면 그건 진짜 이음매다.
	"""
	n = len(gaps)
	m = sum(gaps) / n
	sd = math.sqrt(sum((g - m) * (g - m) for g in gaps) / n) or 1e-9
	last = gaps[-1]
	rank = sum(1 for g in gaps if g >= last)      # 1 이면 제일 크다는 뜻
	return (last - m) / sd, rank, last * 255.0    # 마지막 값은 8비트 계단 수


def seam_check(vals: list, w: int, h: int) -> tuple:
	"""가로/세로로 감긴 자리의 (z, 순위) 를 돌려준다.

	가로 틈은 열 x 와 x+1 사이 차이의 세로 평균, 세로 틈은 그 반대.
	목록의 마지막 원소가 곧 감긴 자리(w-1 ↔ 0)다.
	"""
	gx = []
	for x in range(w):
		x2 = (x + 1) % w
		s = 0.0
		for y in range(h):
			row = y * w
			s += abs(vals[row + x2] - vals[row + x])
		gx.append(s / h)
	gy = []
	for y in range(h):
		r0 = y * w
		r1 = ((y + 1) % h) * w
		s = 0.0
		for x in range(w):
			s += abs(vals[r1 + x] - vals[r0 + x])
		gy.append(s / w)
	return _gap_report(gx), _gap_report(gy)


def tilt_degrees(nrm: list) -> float:
	"""노멀이 평면에서 평균 몇 도 기울었는지. 조명이 얼마나 걸릴지의 감각값."""
	s = 0.0
	for (_, _, b) in nrm:
		s += math.degrees(math.acos(max(-1.0, min(1.0, b))))
	return s / len(nrm)


def measure_dir(out: str) -> None:
	"""디스크에 저장된 결과물을 다시 읽어 잰다. 8비트로 깎인 뒤의 진짜 값이다."""
	total = 0
	bad = []
	# 이음 열은 z(분포에서 벗어난 정도) / 순위(1 이면 제일 큼) / 칸(8비트 계단 수).
	print("\n%-9s %-3s %5s %7s %8s %10s %6s %4s %5s %6s %4s %5s %9s" %
		("표면", "종류", "px", "평균", "표준편차", "범위",
		"가로z", "순위", "칸", "세로z", "순위", "칸", "용량"))
	print("-" * 104)
	for name, _size, _std, _bump, _fn, _desc in SURFACES:
		for kind in ("d", "n"):
			p = os.path.join(out, "%s_%s.png" % (name, kind))
			if not os.path.exists(p):
				continue
			size = os.path.getsize(p)
			total += size
			# 노멀은 가로 기울기가 R, 세로 기울기가 G 라 채널을 나눠 본다.
			vx, w, h = load_channel(p, 0)
			vy = vx if kind == "d" else load_channel(p, 1)[0]
			m, sd, lo, hi = stats(vx)
			(zx, rx, ax), _ = seam_check(vx, w, h)
			_, (zy, ry, ay) = seam_check(vy, w, h)
			flag = ""
			# z 만 보면 안 된다. 금속의 세로 기울기처럼 채널이 거의 평평하면
			# 8비트 한 칸의 1/3 짜리 차이도 z 10 으로 튄다. 눈에 보이려면 적어도
			# 한 칸(1/255) 은 벌어져야 하므로 절대 크기를 같이 건다.
			if ((abs(zx) > 3.0 and rx == 1 and ax > 1.0)
				or (abs(zy) > 3.0 and ry == 1 and ay > 1.0)):
				flag = "  <- 이음매 의심"
				bad.append("%s_%s" % (name, kind))
			if kind == "d" and sd > 0.10:
				flag += "  <- 대비 과함"
				bad.append("%s_%s" % (name, kind))
			print("%-9s %-3s %5d %7.4f %8.4f %10s %+6.2f %4d %5.2f %+6.2f %4d %5.2f %7.1fKB%s" %
				(name, kind, w, m, sd, "%.2f~%.2f" % (lo, hi),
				zx, rx, ax, zy, ry, ay, size / 1024.0, flag))
	print("-" * 100)
	print("합계 %.1f KB (%.2f MB) / 예산 2048 KB (2.00 MB)" % (total / 1024.0, total / 1048576.0))
	if total > 2 * 1024 * 1024:
		print("!! 용량 예산 초과")
	if bad:
		print("!! 확인 필요: %s" % ", ".join(bad))


# ── 미리보기 ────────────────────────────────────────────────────────────

def _shade(detail: str, normal: str, hexcol: str, tiles: int, boost: float = 1.0) -> Image.Image:
	"""실제로 화면에 나올 모습으로 그린다.

	albedo 색 x 디테일 x (노멀에 걸린 램버트). 숫자만 보면 늘 "약해 보이는데" 로 끝나서
	굽고 나면 이걸 한 번 띄워 보고 세기를 정한다. boost 는 이음매 볼 때만 쓴다.
	"""
	d = Image.open(detail).convert("L")
	nm = Image.open(normal).convert("RGB")
	n = d.size[0]
	base = tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
	lx, ly, lz = PREVIEW_LIGHT
	ln = math.sqrt(lx * lx + ly * ly + lz * lz)
	lx, ly, lz = lx / ln, ly / ln, lz / ln
	dd = d.tobytes()
	nn = nm.tobytes()
	px = bytearray(n * n * 3)
	for i in range(n * n):
		# 0.5 가 "그대로" 다. 그래서 2배 해서 곱한다 — 셰이더 쪽도 똑같이 해야 한다.
		det = 1.0 + (dd[i] / 255.0 - 0.5) * 2.0 * boost
		nx = (nn[i * 3] / 127.5 - 1.0) * boost
		ny = (nn[i * 3 + 1] / 127.5 - 1.0) * boost
		nz = nn[i * 3 + 2] / 127.5 - 1.0
		lam = (nx * lx + ny * ly + nz * lz) / lz    # 평평하면 1.0
		f = det * max(0.0, lam)
		for c in range(3):
			px[i * 3 + c] = max(0, min(255, int(base[c] * f)))
	one = Image.frombytes("RGB", (n, n), bytes(px))
	out = Image.new("RGB", (n * tiles, n * tiles))
	for ty in range(tiles):
		for tx in range(tiles):
			out.paste(one, (tx * n, ty * n))
	return out


def write_preview(out_dir: str, prefix: str) -> list:
	"""1) 있는 그대로 2x2, 2) 절반 굴린 뒤 6배 뻥튀기 — 두 장을 뽑는다."""
	made = []
	cell = 360

	def _sheet(panels: list, path: str) -> None:
		cols = PREVIEW_COLS
		rows = (len(panels) + cols - 1) // cols
		sheet = Image.new("RGB", (cell * cols, cell * rows), (18, 18, 22))
		for i, p in enumerate(panels):
			sheet.paste(p, ((i % cols) * cell, (i // cols) * cell))
		sheet.save(path)
		made.append(path)

	panels = []
	for name, hexcol in PREVIEW_PICKS:
		d = os.path.join(out_dir, "%s_d.png" % name)
		nm = os.path.join(out_dir, "%s_n.png" % name)
		img = _shade(d, nm, hexcol, 2).resize((cell, cell), Image.LANCZOS)
		dr = ImageDraw.Draw(img)
		dr.rectangle([0, 0, cell - 1, cell - 1], outline=(20, 20, 24))
		# 밝은 표면 위에서는 흰 글씨가 안 보인다. 라벨 뒤에 어두운 띠를 깐다.
		dr.rectangle([0, 0, cell - 1, 18], fill=(18, 18, 22))
		dr.text((8, 5), "%s  %s" % (name, hexcol), fill=(250, 250, 250))
		panels.append(img)
	_sheet(panels, prefix + "-real.png")

	# 이음매용. 절반 굴려서 원래의 상하좌우 끝이 화면 한가운데로 오게 만든다.
	# 여기서 십자선이 보이면 타일링 실패다. 대비를 6배로 올려 두었다.
	panels = []
	for name, _hexcol in PREVIEW_PICKS:
		d = Image.open(os.path.join(out_dir, "%s_d.png" % name))
		n = d.size[0]
		rolled = Image.new("L", (n, n))
		rolled.paste(d.crop((n // 2, n // 2, n, n)), (0, 0))
		rolled.paste(d.crop((0, n // 2, n // 2, n)), (n // 2, 0))
		rolled.paste(d.crop((n // 2, 0, n, n // 2)), (0, n // 2))
		rolled.paste(d.crop((0, 0, n // 2, n // 2)), (n // 2, n // 2))
		boosted = rolled.point(lambda v: max(0, min(255, int(128 + (v - 128) * 6))))
		img = boosted.convert("RGB").resize((cell, cell), Image.LANCZOS)
		dr = ImageDraw.Draw(img)
		dr.line([cell // 2, 0, cell // 2, cell - 1], fill=(120, 30, 30))
		dr.line([0, cell // 2, cell - 1, cell // 2], fill=(120, 30, 30))
		dr.text((8, 8), "%s  (roll 1/2, x6)" % name, fill=(255, 80, 80))
		panels.append(img)
	_sheet(panels, prefix + "-seam.png")
	return made


# ── 진입점 ──────────────────────────────────────────────────────────────

def main() -> None:
	ap = argparse.ArgumentParser(description="쿼플 표면 디테일/노멀 맵 생성기")
	ap.add_argument("--out", default=OUT_DIR, help="결과물 폴더")
	ap.add_argument("--only", default="", help="쉼표로 구분한 표면 이름만 굽기")
	ap.add_argument("--check", action="store_true", help="굽지 않고 이미 있는 것만 재기")
	ap.add_argument("--preview", default="", help="미리보기 PNG 경로 접두사")
	args = ap.parse_args()
	out = os.path.abspath(args.out)
	os.makedirs(out, exist_ok=True)

	if not args.check:
		want = set(s.strip() for s in args.only.split(",") if s.strip())
		for name, size, std, bump, fn, desc in SURFACES:
			if want and name not in want:
				continue
			height = fn(size)
			detail = to_detail(height, std)
			nrm = to_normal(height, size, bump)
			save_detail(os.path.join(out, "%s_d.png" % name), detail, size)
			save_normal(os.path.join(out, "%s_n.png" % name), nrm, size)
			m, sd, lo, hi = stats(detail)
			print("%-10s %3dpx  평균 %.4f  표준편차 %.4f  범위 %.3f~%.3f  "
				"노멀기울기 %.1f도  (%s)" % (name, size, m, sd, lo, hi, tilt_degrees(nrm), desc))

	measure_dir(out)

	if args.preview:
		for p in write_preview(out, os.path.abspath(args.preview)):
			print("미리보기: %s" % p)


if __name__ == "__main__":
	main()
