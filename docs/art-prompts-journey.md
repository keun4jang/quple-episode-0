# 제미나이 프롬프트 — 첫 여행지 (바닷가 마을)

> `docs/redesign-journey.md` 13절의 **최소 버전**에 필요한 그림.
> 여행지 한 곳(숙소·마을길·바닷가) + 인연 셋 + **고향집** + 쿼카컴퍼니.
> 이야기는 `docs/story-journey.md`.

## 0. 먼저 읽을 것

### 왜 몰아서 받나

낱장으로 18개를 받으면 **화풍이 전부 따로 논다.** 선 굵기도, 색감도, 그림자 방향도
매번 달라진다. 탑다운 게임은 그것들이 한 화면에 동시에 보이므로 바로 티가 난다.

그래서 **한 장에 여러 개를 격자로 몰아 받는다.** 같은 생성 안에서는 화풍이 유지된다.
자르는 건 내가 한다 (PIL, 무료).

### 일곱 장

| | 무엇 | 우선순위 |
|---|---|---|
| **A** | 바닥 5종 (풀·모래·흙길·돌바닥·바다) | ⭐ 제일 먼저 |
| **B** | 건물 3종 (숙소·가게·등대) | ⭐ |
| **C** | 자연물 6종 (나무·바위·풀숲) | |
| **D** | 소품 6종 (벤치·가로등·표지판·화분·담장·부두) | |
| **E** | 인연 3명 (붙박이 2 · 여행자 1) | ⭐ |
| **F** | 쿼카컴퍼니 (사무실·로비·회사 앞) | 프롤로그용 |
| **G** | 고향집 (집·마당·가족 3명) | ⭐⭐ 제일 중요 |
| **H** | 가족 3명 턴어라운드 (앞·옆·뒤) | ⭐ 걷기용 |
| **I** | 인연 3명 턴어라운드 (앞·옆·뒤) | ⭐ 걷기용 |

### 받은 것 (2026-08-09)

A · E · G-1 · G-2 · G-3 · H · I 완료 →
`assets/source/journey/` 에 원본, `assets/tiles/` `assets/sprites/` 에 변환본.

**걷기 프레임은 제미나이에 안 시킨다.** 프레임마다 얼굴이 달라져서 이어 붙이면
캐릭터가 출렁인다. **정지 자세 세 방향만 받고** 걷기는 `import-journey-art.py`
가 만든다 — 24px 에서 걷기는 몸이 1px 뜨고 다리가 1px 엇갈리는 게 전부다.

H·I 는 3열을 요청했는데 6열로 나왔다. 쓸 열은 코드에 적어 두었다 —
H 는 1·2·3, I 는 1·3·6 이 제일 또렷하다.

**A · B · E 만 있어도 걸어 다니는 화면이 나온다.** C · D · F 는 나중에 줘도 된다.

**G(고향집)는 우선순위가 제일 높다.** `docs/story-journey.md` 8절대로
고향집을 먼저 만들어 이 게임이 뭉클한지부터 볼 것이기 때문이다.

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

**아래 블록을 일곱 장 전부의 맨 앞에 그대로 붙여 주세요.** 이게 화풍을 묶어 줍니다.

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


---

## 10. F장 — 쿼카컴퍼니 (프롤로그)

> `docs/story-journey.md` 3절. 밤 11시 사무실에서 걸어 나오는 장면.
>
> **톤이 중요합니다.** 무섭거나 우울한 회사가 아닙니다. 그냥 **내 자리가 아니었던 곳**
> 입니다. 악당스러운 연출(붉은 조명, 감옥 같은 구도)을 넣지 말아 주세요.

```
(머리말 + 이어서 — 단 색 규칙만 아래로 바꿉니다)

OVERRIDE the palette rule for this sheet only: use muted desaturated colors —
cool grey, dim blue-grey, tired beige, with small warm points of light from
monitors and desk lamps. Still gentle, never harsh or scary.

Create a 3x2 grid of six office objects, seen from a 3/4 overhead game camera.
Scale reference: a small animal character is about 3 units tall.

1. An office desk with a monitor (screen glowing faint blue), a keyboard,
   and a paper cup, about 2 units tall
2. An office swivel chair, seen from behind, 2 units tall
3. A tall grey filing cabinet, 4 units tall
4. A row of three large office windows showing a night city view outside —
   small distant building lights on a dark blue sky
5. A reception desk with a small potted plant on it, 2 units tall
6. A wall-mounted return box with a narrow slot, like a mailbox,
   1 unit tall, mounted on a short section of wall

Each object separate on the magenta background, clear gaps, none cropped.
```

**한 장 더 (선택)** — 회사 건물 바깥 모습. 없어도 됩니다.

```
(머리말 + 이어서)

A single large office building seen from a 3/4 overhead game camera, at night.
About 30 units tall but shown from the street level so we mainly see the lower
three floors and the entrance. Plain grey-blue glass and concrete, a revolving
door at the base, a few lit windows scattered above. Calm and ordinary —
not intimidating, not dystopian. On magenta background, nothing cropped.
```

---

## 11. G장 — 고향집 ⭐⭐

> `docs/story-journey.md` 5절. **이 게임에서 제일 중요한 장소입니다.**
>
> 실제 지명은 안 씁니다. **이름 없는 시골** — 누구의 고향이든 될 수 있게.

### G-1. 집과 마당

```
(머리말 + 이어서)

Create four objects for a small rural family home, seen from a 3/4 overhead
game camera. Scale reference: a small animal character is about 3 units tall.

1. A small old countryside house, one story, about 7 units tall.
   Low tiled roof, warm weathered wood and pale plaster walls, a sliding
   paper door in the middle, one window with a soft warm light inside,
   and a low porch step in front. Humble and well-kept, not run-down.

2. A persimmon tree with a few orange fruits, about 8 units tall,
   slightly leaning.

3. A low wide wooden platform bench (a flat raised deck you can sit or lie
   on), about 1 unit tall and 4 units wide, seen from the 3/4 angle.

4. A small vegetable garden patch — neat rows of low green leafy vegetables
   in dark soil, about 5 units wide.

Each object separate on the magenta background, clear gaps, none cropped.
```

### G-2. 가족 3명

```
(머리말 + 이어서)

Create three quokka family characters standing side by side, each FACING THE
VIEWER (front view), full body, arms relaxed at their sides.

They must all clearly be quokkas — small round marsupials with a naturally
gentle upturned mouth, small rounded ears, plump body, short arms.
Soft rounded chibi style, roughly 3 heads tall.

1. Mother. Slightly plump, soft grey-brown fur, wearing a faded floral apron
   over simple clothes, hair pinned back. Calm face, warm but not smiling
   too widely.

2. Father. Sturdier build, darker brown fur, wearing a worn work jacket and
   a flat cap, holding nothing. Quiet, reserved expression.

3. Younger sibling. Smaller and slimmer, lighter fur, wearing a loose hoodie
   and shorts. Bright, direct, slightly cheeky expression.

All three the same height in the image so proportions can be compared.
Each fully separated on the magenta background. Front view only.
```

**받은 뒤 내가 할 일**: 정면 한 장으로 옆·뒤 방향과 걷기 프레임을 만듭니다.

### G-3. 마당 바닥 (선택)

```
(머리말 + 이어서)

Create a 2x2 grid of four SEAMLESS TILING ground texture patches, each
512x512 pixels, viewed straight from directly above, with magenta gaps
between them.

Each must tile seamlessly — left edge continues into right edge, top into
bottom. Keep the pattern even and calm.

1. Dry packed earth of a rural yard, warm pale brown, faint broom marks
2. Dark tilled farm soil in low parallel furrows
3. Coarse country grass, slightly yellowed, uneven
4. Flat grey stone slabs of an old stepping path
```
