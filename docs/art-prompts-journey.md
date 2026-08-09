# 제미나이 프롬프트 — 첫 여행지 (바닷가 마을)

> `docs/redesign-journey.md` 13절의 **최소 버전**에 필요한 그림.
> 여행지 한 곳(숙소·마을길·바닷가) + 인연 셋.

## 0. 먼저 읽을 것

### 왜 5장으로 몰아서 받나

낱장으로 18개를 받으면 **화풍이 전부 따로 논다.** 선 굵기도, 색감도, 그림자 방향도
매번 달라진다. 탑다운 게임은 그것들이 한 화면에 동시에 보이므로 바로 티가 난다.

그래서 **한 장에 여러 개를 격자로 몰아 받는다.** 같은 생성 안에서는 화풍이 유지된다.
자르는 건 내가 한다 (PIL, 무료).

### 다섯 장

| | 무엇 | 우선순위 |
|---|---|---|
| **A** | 바닥 5종 (풀·모래·흙길·돌바닥·바다) | ⭐ 제일 먼저 |
| **B** | 건물 3종 (숙소·가게·등대) | ⭐ |
| **C** | 자연물 6종 (나무·바위·풀숲) | |
| **D** | 소품 6종 (벤치·가로등·표지판·화분·담장·부두) | |
| **E** | 인연 3명 (붙박이 2 · 여행자 1) | ⭐ |

**A · B · E 만 있어도 걸어 다니는 화면이 나온다.** 나머지는 나중에 줘도 된다.

### 내가 할 일 (그림 받은 뒤)

1. 마젠타 배경을 투명으로 뺀다
2. 격자로 자른다
3. `tools/pixel/pixelize.py` 로 16px 격자에 맞춰 내린다
4. 팔레트를 기존 쿼카 색과 맞춘다
5. Godot 타일셋으로 만든다

즉 **픽셀로 안 그려 줘도 된다.** 오히려 매끈하게 그린 걸 주는 게 낫다 —
AI가 그린 "픽셀풍"은 픽셀 격자가 안 맞아서 쓸 수가 없다.

### 확인해 주실 것

제미나이로 만든 이미지의 **상업적 사용 가능 여부**는 쓰시는 요금제 약관을 확인해
주세요. 나중에 출시하려면 필요합니다.

---

## 1. 모든 프롬프트에 붙일 머리말

**아래 블록을 다섯 장 전부의 맨 앞에 그대로 붙여 주세요.** 이게 화풍을 묶어 줍니다.

```
A cozy top-down game art asset sheet, 3/4 overhead view (like Stardew Valley
camera angle), soft hand-painted style with clean readable shapes.

STYLE RULES — follow all of them:
- Warm, gentle color palette: soft coral, sage green, sandy beige, muted teal,
  warm brown. Nothing neon, nothing dark or gritty.
- Soft rounded forms. No harsh outlines, no heavy black linework.
- Light comes from the upper-left. All shadows fall to the lower-right.
- Flat, even lighting on each object. No dramatic highlights, no lens flare.
- Every object sits on a plain solid MAGENTA background (#FF00FF).
  The magenta must be pure and untouched — no gradient, no shadow bleeding
  onto it, no glow.
- Objects must NOT overlap or touch each other. Leave clear magenta gaps.
- No text, no letters, no numbers, no watermark, no logo anywhere.
- No people, no human characters.
- Do NOT render it as pixel art. Paint it smoothly — it will be converted
  to pixel art later.
```

---

## 2. A장 — 바닥 5종 ⭐

바닥은 **이어 붙여도 이음매가 안 보여야** 한다. 이게 제일 어려우니 따로 받는다.

```
(위 머리말을 먼저 붙이고, 이어서)

Create a 3x2 grid of six large square ground texture patches, each patch
512x512 pixels, arranged with clear magenta gaps between them.

Each patch must be a SEAMLESS TILING TEXTURE — the left edge must continue
into the right edge, and the top edge into the bottom edge, so it can be
repeated endlessly without visible seams. Keep the pattern even and calm;
avoid one big feature in the middle of a patch.

The six patches, in reading order:
1. Short green grass, summer, a few tiny scattered wildflowers
2. Pale beach sand, fine grain, very gentle ripples
3. Packed dirt path, warm brown, a few small pebbles
4. Old stone pavement, rounded cobblestones, weathered grey-beige
5. Shallow seawater, calm, soft teal, gentle light ripples
6. Wooden deck planks laid horizontally, warm sun-bleached timber

Viewed straight from directly above. No objects on the patches.
```

**받은 뒤 내가 할 일**: 512 → 16px 로 내리고, 이음매를 검사해 안 맞으면 손본다.

---

## 3. B장 — 건물 3종 ⭐

```
(머리말 + 이어서)

Create three separate buildings in a horizontal row, seen from a 3/4 overhead
game camera (you can see the roof and the front wall at the same time).

Scale reference: a small animal character in this world is about 3 units tall.
Use that to keep the buildings in proportion with each other.

1. A small seaside guesthouse, two stories, about 9 units tall.
   Warm cream plaster walls, terracotta tiled roof, a wooden door in the
   middle, two shuttered windows, a small hanging lantern by the door,
   and a flower box under one window.

2. A tiny corner shop, one story, about 6 units tall.
   Weathered blue-painted wood siding, a striped awning over the front
   (coral and cream stripes), a wide open display window with empty shelves,
   crates stacked beside the door.

3. A short lighthouse, about 12 units tall.
   White and soft-red horizontal bands, a small glass lantern room at the
   top with a simple railing, a little door at the base, sitting on a rough
   stone foundation.

Each building fully separated on the magenta background, not overlapping.
Show each building complete — do not crop any of them.
```

---

## 4. C장 — 자연물 6종

```
(머리말 + 이어서)

Create a 3x2 grid of six natural objects, seen from a 3/4 overhead game
camera. Scale reference: a small animal character is about 3 units tall.

1. A wind-bent pine tree, about 8 units tall, leaning slightly right
2. A round leafy tree with a thick trunk, about 7 units tall
3. A cluster of three tall beach grasses, about 2 units tall
4. A large weathered grey boulder, about 3 units wide
5. A group of four small rocks and pebbles scattered together
6. A low flowering shrub with small coral-pink blossoms, about 2 units tall

Each object separate on the magenta background, clear gaps between them,
none of them cropped.
```

---

## 5. D장 — 소품 6종

```
(머리말 + 이어서)

Create a 3x2 grid of six small village props, seen from a 3/4 overhead game
camera. Scale reference: a small animal character is about 3 units tall.

1. A weathered wooden bench facing the viewer, about 2 units tall
2. An old iron street lamp with a warm glass lantern, about 5 units tall
3. A wooden signpost with a blank empty board (NO text on it), 4 units tall
4. Three terracotta flower pots of different sizes with green plants
5. A short section of wooden picket fence, five posts wide, 2 units tall
6. A small wooden dock section extending toward the viewer, with two mooring
   posts, about 6 units long

Each object separate on the magenta background, clear gaps, none cropped.
```

---

## 6. E장 — 인연 3명 ⭐

**중요**: 쿼카 여행자(주인공)는 기존 3D 렌더 에셋을 픽셀로 내려 쓴다.
**여기서 만들 건 주인공이 아니라 여행지에서 만나는 셋**이다.

```
(머리말 + 이어서 — 단 "no people" 규칙은 그대로, 동물 캐릭터만)

Create three cute animal villager characters standing side by side, each
shown FACING THE VIEWER (front view), full body, standing straight with arms
relaxed at their sides.

Art direction: soft rounded chibi-like animal characters, gentle friendly
faces, simple clothing. Roughly 3 heads tall. They should feel like they
belong in the same cozy world as a small round quokka.

1. An elderly seal shopkeeper. Plump, silver-grey, wearing a faded blue
   apron and small round glasses. Warm, unhurried expression.

2. A young seagull. Slim, white and pale grey, wearing a yellow raincoat
   with the hood down and rolled-up sleeves. Bright, curious expression.

3. A raccoon traveler. Medium build, warm brown-grey, wearing a large
   backpack, a rolled sleeping mat on top, and a knitted scarf.
   Relaxed, easygoing expression. This one is a fellow traveler, not a
   villager — make the backpack clearly the biggest thing about them.

All three the same height in the image so their proportions can be compared.
Each fully separated on the magenta background. Front view only.
```

**받은 뒤 내가 할 일**: 정면 하나로 옆·뒤 방향과 걷기 프레임을 만든다
(픽셀로 내리면 세부가 단순해져서 가능하다).

---

## 7. 잘 안 나올 때

제미나이가 자주 어기는 것들이라, 아래를 프롬프트 끝에 덧붙이면 나아진다.

| 증상 | 덧붙일 말 |
|---|---|
| 배경이 마젠타가 아님 | `The background must be pure #FF00FF magenta, completely flat.` |
| 글자가 들어감 | `Absolutely no text, letters, numbers, or signage of any kind.` |
| 물체가 잘림 | `Every object must be fully visible with margin around it. Nothing cropped.` |
| 원근이 제각각 | `All objects must use the exact same 3/4 overhead camera angle.` |
| 픽셀풍으로 그림 | `Smooth painted illustration, NOT pixel art, NOT 8-bit style.` |
| 그림자가 사방으로 | `Every shadow falls to the lower-right. No exceptions.` |

**다시 뽑는 것보다 프롬프트를 고치는 게 빠릅니다.** 특히 마젠타 배경과 그림자 방향은
어긋나면 제가 손으로 고쳐야 해서 시간이 많이 듭니다.

## 8. 파일 이름

받으신 그대로 주셔도 됩니다. 다만 **어느 장인지만 알려 주세요** (A/B/C/D/E).
크기는 **가로 1536px 이상**이면 좋습니다 — 줄이는 건 되는데 늘리는 건 안 됩니다.

## 9. 다음

A · B · E 세 장만 오면 **걸어 다니는 화면**을 바로 만들 수 있습니다.
그동안 저는 이 그림들을 받아 자르고 16px 격자에 맞추는 도구
(`tools/pixel/import-journey-art.py`)를 미리 만들어 두겠습니다.
