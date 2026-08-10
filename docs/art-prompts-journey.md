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
| **J** | 주인공 턴어라운드 | ✅ |
| **K** | 고향집 마당 소품 6종 (장독대·빨랫줄·펌프·장작·대야·연장) | ⭐ 마당이 휑하다 |
| **L** | 줍는 것 8종 (감·조약돌·들꽃·솔방울·도토리·깃털·조개·유리) | ⭐⭐ 게임에 줍는 게 없다 |
| **M** | 윤슬 바닷가 소품 6종 (파라솔·좌판·그물·부표·아이스박스·우체통) | |
| **N** | 배낭 속 물건 6종 (쿼메라·배낭·엽서·수첩·쿼이스크림·쿼원) | |

### 받은 것 (2026-08-09)

A~N **전부 완료** →
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


---

## 12. K장 — 고향집 마당 소품 ⭐

마당에 아무것도 없어서 휑하다. **시골집 마당에 실제로 있는 것들**만 넣는다.

```
(1절 머리말 + 이어서)

Create a 3x2 grid of six rural Korean farmyard objects, seen from a 3/4
overhead game camera. Scale reference: a small animal character is 3 units tall.

1. A cluster of five dark brown earthenware jars of different sizes standing
   on a low stone platform, about 2.4 units tall. Rounded bellied pots with
   wide flat lids.
2. A clothesline strung between two simple wooden posts, with two plain
   cloths hanging and drying, about 3 units tall
3. An old hand water pump on a small concrete base, with a metal bucket
   beside it, about 2.4 units tall
4. A neat stack of chopped firewood logs, seen end-on, about 1.6 units tall
5. A round rubber washtub, pale pink, with a scrubbing board leaning inside,
   about 1 unit tall
6. A shovel and a hoe leaning together against nothing, handles crossed,
   about 2.2 units tall

Each object separate on the magenta background, clear gaps, none cropped.
```

## 13. L장 — 줍는 것 ⭐⭐

**게임에서 제일 필요한 것.** 지금 주울 수 있는 게 하나도 없다.
사진 소재이자 선물거리다 (`redesign-journey.md` 5절 — "그곳에서 주운 것 건네기").

**아주 작게 그려야 한다.** 발밑에 떨어져 있는 것이라 캐릭터 발보다 작다.

```
(1절 머리말 + 이어서)

Create a 4x2 grid of eight SMALL collectible objects lying on the ground,
seen from a 3/4 overhead game camera, as if dropped at your feet.

Scale reference: a small animal character is 3 units tall. Every object here
is UNDER 1 unit — they are tiny things you bend down to pick up. Draw each
one large and clear in its cell, but keep their proportions consistent with
each other (a persimmon is bigger than an acorn).

1. A single ripe orange persimmon with a small green calyx
2. One smooth grey river pebble
3. A tiny bunch of three small wild flowers, white and coral
4. A brown pine cone
5. A single acorn with its cap
6. A soft white feather lying flat
7. A small spiral seashell, pale cream
8. A rounded piece of frosted sea glass, soft teal

Each object separate on the magenta background, clear gaps, none cropped.
No hands, no containers, no ground shadow shapes larger than the object.
```

## 14. M장 — 윤슬 바닷가 소품

```
(1절 머리말 + 이어서)

Create a 3x2 grid of six seaside village objects, seen from a 3/4 overhead
game camera. Scale reference: a small animal character is 3 units tall.

1. A large beach parasol, coral and cream stripes, open, about 3.4 units tall
2. A small market stall — a folding table under a short awning with empty
   woven baskets on it, about 2.6 units tall
3. A fishing net bundled in a loose heap with two cork floats, 1.6 units tall
4. A round orange buoy with a rope loop, about 1.4 units tall
5. A blue plastic icebox with the lid closed, about 1.2 units tall
6. A red postbox on a single post, rounded top, no text or markings on it,
   about 2.4 units tall

Each object separate on the magenta background, clear gaps, none cropped.
```

## 15. N장 — 배낭 속 물건

화면 아이콘으로도 쓴다. 그래서 **정면에서 또렷하게** 그린다.

```
(1절 머리말 + 이어서 — 단 카메라 각도만 아래로 바꾼다)

OVERRIDE the camera rule for this sheet: draw each object FLAT FROM THE
FRONT (like a clean inventory icon), not from a 3/4 overhead angle.

Create a 3x2 grid of six travel items. Keep them all roughly the same size
in the image so they read as a matching icon set.

1. A small vintage film camera with a brown leather strap
2. A canvas travel backpack, warm beige, with a rolled mat strapped on top
3. A blank postcard, cream, slightly worn corners, NO text or picture on it
4. A small pocket notebook, closed, with an elastic band around it
5. A soft-serve ice cream cone, pale cream swirl
6. A single round coin, warm brass, with a plain smooth face and NO markings,
   NO letters, NO numbers

Each object separate on the magenta background, clear gaps, none cropped.

---

# 두 번째 묶음 (2026-08-09)

여섯 팀이 화면을 훑고 나서 **정말로 그림이 있어야만 풀리는 것**만 추렸다.
코드로 되는 건 다 코드로 고쳤다. 여기 남은 셋은 그림 없이는 안 된다.

| 장 | 무엇 | 왜 |
|---|---|---|
| **O** ⭐⭐ | 메뉴 배경 (가로) | 지금 그림에 **쿼카가 둘**이고 글자가 구워져 있다 |
| **P** ⭐ | 스플래시 포스터 (세로) | 같은 문제 |
| **Q** ⭐ | 바닥 6종 | 여섯 곳이 **다 같은 색**이다. 사무실이 야외 타일이다 |

## 16. O장 — 메뉴 배경 ⭐⭐

**이 장은 앞의 머리말을 안 붙인다.** 탑다운 에셋이 아니라 한 장짜리
그림이고, 화풍도 다르다 (부드러운 3D 렌더 느낌).

### 왜 다시 받나

지금 `assets/splash/menu-bg-wide.png` 는 세 가지가 어긋난다.

1. **쿼카가 둘이다.** 접은 커플 컨셉 시절 그림이다. 지금 이 게임은
   혼자 떠나는 이야기다 (`CLAUDE.md`)
2. **"쿼카 커플의 힐링 여행" 이라는 글자가 그림에 구워져 있다.**
   로고와 문구는 코드로 얹으므로 배경에는 글자가 없어야 한다
3. **작은 행성과 토성이 떠 있다.** 우주는 나중 이야기고, 1탄은 국내다

```
A single cozy illustration for a mobile game title screen. Soft 3D-rendered
look — smooth clay-like surfaces, gentle rim light, shallow depth of field.
Warm and calm, like a children's picture book cover.

SUBJECT — exactly ONE character:
One quokka traveler, alone. Small and round, warm honey-brown fur, friendly
half-smile. Wearing a soft green cap, a small canvas backpack, and a film
camera on a strap around the neck. Standing, weight on one leg, looking out
toward the horizon — not at the viewer.

There must be only ONE animal in the entire image. No second character,
no companion, no crowd, no people.

SCENE — a quiet Korean coastal town at golden hour:
Behind the quokka, a gentle hillside with low tiled roofs, a small lighthouse
far off, a calm sea, and soft rolling clouds. Warm late-afternoon light,
long soft shadows. Grounded on real earth — NOT a floating tiny planet,
no outer space, no planets, no stars, no Saturn rings.

COMPOSITION — this is important:
- Landscape, aspect ratio about 2.36 : 1 (very wide).
- The quokka and all the interesting scenery sit in the LEFT 45% of the frame.
- The RIGHT 55% must stay calm and mostly empty — soft sky, distant haze,
  gentle gradient. Buttons will be drawn on top of that half, so nothing
  detailed or high-contrast can live there.
- Leave the TOP-CENTER area calm too — the logo goes there.

PALETTE: warm coral, sage green, sandy beige, muted teal, soft cream.
Nothing neon, nothing dark.

ABSOLUTELY NO TEXT. No letters, no words, no title, no signature,
no watermark, no logo, no UI elements, no buttons, no frame or border.
```

**크기**: 가로 **3168 x 1344** 이상이면 좋다 (쓰는 크기의 두 배).
못 맞추면 **가로가 세로의 두 배 이상**이기만 하면 된다.

**받은 뒤 내가 할 일**: `1584 x 672` 로 줄여
`assets/splash/menu-bg-wide.png` 를 갈아 끼운다. 코드는 안 고쳐도 된다.

## 17. P장 — 스플래시 포스터 ⭐

앱을 켤 때 잠깐 뜨는 세로 그림. **O장과 같은 그림의 세로 버전**이면
제일 좋다 — 같은 쿼카, 같은 시간대, 같은 색.

```
(O장 프롬프트를 그대로 쓰되, COMPOSITION 만 아래로 바꾼다)

COMPOSITION:
- Portrait, aspect ratio 9 : 16 (tall).
- The quokka stands in the lower-middle third, small in the frame.
- The upper half is open sky — calm, soft, uncluttered. The game logo will
  be drawn over it in code, so keep it simple there.
- Nothing important within 8% of any edge (phones crop differently).
```

**크기**: **1080 x 1920** 이상.

**받은 뒤 내가 할 일**: `assets/splash/splash-poster-no-text.png` 를
갈아 끼우거나 `python3 tools/splash/import-splash-art.py --file <파일>`.

## 18. Q장 — 바닥 6종 ⭐

**A장 머리말을 그대로 붙인다.** A장과 같은 규칙, 같은 화풍이다.

### 왜 필요한가

지금 바닥 타일이 열 장뿐이고, 여섯 곳이 그중 서너 장을 돌려 쓴다.
평균 색을 재 보면 여섯 곳이 **30/255 안쪽**에 다 몰려 있다 —
윤슬(바다)과 볕뉘(기와지붕)와 고향집이 화면만 봐서는 구별이 안 된다.

그리고 **잿마루(쿼카컴퍼니) 사무실이 야외 돌바닥**이다. 실내인데
바깥 돌판을 깔아 놨다.

```
(A장 머리말을 먼저 붙이고, 이어서)

Create a 3x2 grid of six large square ground texture patches, each patch
512x512 pixels, arranged with clear magenta gaps between them.

Each patch must be a SEAMLESS TILING TEXTURE — the left edge must continue
into the right edge, and the top edge into the bottom edge, so it can be
repeated endlessly without visible seams. Keep the pattern even and calm;
avoid one big feature in the middle of a patch.

The six patches, in reading order:
1. Office carpet, flat low-pile, muted cool grey-blue, very fine even weave
2. Polished lobby floor, large pale marble squares, soft cool grey,
   thin darker grout lines
3. Dark volcanic basalt gravel, near-black charcoal grey with tiny warm
   flecks, dry and rough
4. Weathered granite steps, cool blue-grey stone, fine speckle,
   slightly damp look
5. Warm ochre clay earth, fine dry soil, faint rake lines, terracotta tone
6. Old dark-grey roof tiles seen from above, gentle repeating half-round
   ridges, matte slate colour

Viewed straight from directly above. No objects on the patches.
```

**이 여섯 장이 하는 일**

| 새 바닥 | 어디에 | 지금은 |
|---|---|---|
| 1 사무실 카펫 | 잿마루 30층 | 야외 돌판 |
| 2 로비 대리석 | 잿마루 로비 | 조약돌 |
| 3 검은 현무암 | 하늬섬 | 조약돌 (윤슬과 같은 색) |
| 4 화강암 계단 | 가풀재 | 조약돌 |
| 5 황토 | 고향집 마당 | 그냥 흙 |
| 6 기와 | 볕뉘 | 돌판 |

**받은 뒤 내가 할 일**: 16px 로 내리고 이음매를 검사한 뒤
`assets/tiles/` 에 넣고, 여행지 여섯 곳의 `legend` 를 갈아 끼운다.

## 19. 안 받아도 되는 것

물어보실 것 같아 미리 적는다. **아래는 그림이 필요 없다.**

- **노을** — 지금 낮과 밤 둘뿐인데, 색만 섞으면 되는 일이라 코드로 한다
- **가로등 불빛** — 그림 말고 코드로 동그란 빛을 그린다
- **캐릭터가 배경에 묻히는 것** — 발밑 그림자와 1px 테두리로 이미 고쳤다
  (갈매기가 갑판 위에서 명도차 1.02:1 이었다)
- **타일·소품·걷기 시트** — 코드가 부르는 파일 **전부 있다.** 없는 게 없다

---

# 세 번째 묶음 — R장 · 정면 교체 (2026-08-10)

만든 사람: **"지금 디자인들 방향이 45도인데 모든걸 정면으로 바꾸자."**

맞는 지적이다. 지금 건물들이 모서리를 앞에 두고 두 면이 보이게(45도)
그려져 있는데, 스타듀밸리를 비롯한 탑다운 게임은 **건물 정면 벽이
똑바로 보이고 지붕이 위에 얹힌** 시점을 쓴다. 화면의 다른 것들과
시점이 어긋나서 건물만 붕 떠 보인다.

## 바꿔야 하는 것 (45도로 그려진 것들)

**건물 넷** — `guesthouse`(쿼스텔) · `shop`(가게) · `stall`(좌판) ·
`home-house`(고향집). 그리고 `reception`(접수대) · `icebox` 도 기울어 있다.

**안 바꿔도 되는 것** — 나무·바위·가로등·표지판·울타리·부표·인물들처럼
좌우 대칭이거나 원래 정면인 것. `lighthouse` 도 원기둥이라 그대로 쓴다.

## R장 프롬프트 — 건물 4종 정면

**A장 머리말을 그대로 붙이고**, 이어서:

```
Create 4 building sprites for a top-down pixel-style game, arranged in a
row with clear magenta gaps between them.

CAMERA — this is the most important rule:
Straight-on FRONT view, like buildings in Stardew Valley. The front wall
faces the viewer squarely. The roof is visible as a band on top, tilted
slightly toward the viewer. NO corner view, NO 45-degree angle, NO side
wall visible, NO isometric perspective.

The 4 buildings:
1. A small cozy guesthouse: cream plaster walls, terracotta tiled roof,
   a wooden sign by the door, two windows with green shutters
2. A tiny village shop: pale teal wooden walls, striped awning over the
   window, a small display of goods in front
3. A market stall: simple wooden frame, striped fabric roof, produce
   laid out on the counter
4. A low country house: whitewashed walls, traditional Korean tiled
   roof (기와), a wooden porch, humble and warm

Each building roughly 400x400px on the magenta background.
```

## R-2장 — 실내 가구 2종 정면

```
(A장 머리말 + 이어서)

Create 2 furniture sprites, front view, magenta gaps between:
1. An office reception counter: straight-on front view, wood panel front,
   a small bell on top
2. A cooler box (icebox): straight-on front view, pale blue metal box
   with a lid

NO angled view. The front face is a flat rectangle facing the viewer.
```

## 받은 뒤 내가 할 일

`tools/pixel/import-journey-art.py` 에 R 시트를 등록해 자르고 16px 격자에
맞춘 뒤 같은 이름으로 갈아 끼운다 — 마을 파일은 안 고쳐도 된다.
