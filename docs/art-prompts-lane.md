# 제미나이 프롬프트 — 쿼카 군단 그림 다시 받기

> 만든 사람 의견 (2026-10-25): "내가 생각한 퀄리티는 이 정도인데 우리 건 너무 화질구지 픽셀아트야."
> 참고로 보여 준 그림은 따뜻한 농장 RPG 풍의 **촘촘하고 명암이 풍부한 픽셀 아트**였다.
> 코드로만 그려서는 거기까지 못 간다. 그래서 제미나이로 그림을 받아 게임에 맞게 바꿔 넣는다.

## 0. 어떻게 주고받나

**자동으로 (권장)**: 클라우드 환경에 `GEMINI_API_KEY` 를 넣어 두면 내가 직접 받는다.
`python3 tools/art/gemini_image.py first` (먼저 3장) / `all` (전부). 프롬프트는 `tools/art/lane_prompts.py` -
이 문서와 같은 내용이다. 받은 원본은 `assets/source/lane/<id>.png`.

**손으로**: 아래처럼 직접 받아 대화에 올려도 된다.

1. 아래 프롬프트를 **머리말 + 각 장 본문** 순서로 붙여 넣어 그림을 받는다.
2. 받은 그림을 이 대화에 올리면서 **몇 번 그림인지** 적어 준다 (예: "배경 1", "쿼카 A").
3. 내가 자르고 → 픽셀 격자에 맞추고 → 색을 정리해서 게임에 넣는다.
   - 지금 그림은 화면 3점이 한 픽셀이다. 새 그림은 **2점이 한 픽셀**이라 1.5배 촘촘하다.
   - 걷기·공격 동작은 제미나이에게 시키지 않는다. 프레임마다 얼굴이 달라져 출렁인다.
     **서 있는 앞모습 하나만** 받고, 움직임은 게임이 만든다 (지금도 늘림·눌림·덤벼들기는 코드다).

### 먼저 3장만

전부 받기 전에 **이 3장으로 화풍이 맞는지부터** 본다. 게임에 넣어 보여 드리고, 괜찮으면 나머지를 받는다.

| 순서 | 그림 | 왜 |
|---|---|---|
| 1 | **배경 1 — 풀밭** | 화면에서 제일 넓다. 퀄리티 차이가 제일 크게 보이는 곳 |
| 2 | **성·둥지** | 길 위아래 끝 |
| 3 | **쿼카 A — 기본 쿼카 8종** | 매 판 보는 얼굴 |

### 전체 목록 (21장)

| 묶음 | 장 수 | 내용 |
|---|---|---|
| 배경 | 10 | 구역마다 하나 (세로 화면) |
| 성·둥지 | 1 | 우리 성 + 벌레 둥지 |
| 쿼카 A·B | 2 | 기본 쿼카 8종 / 진화한 쿼카 8종 |
| 동물 A~D | 4 | 동물 친구 16종 (8종씩) / 진화한 모습 16종 (8종씩) |
| 벌레 A~D | 4 | 졸개 벌레 16종 (8종씩) / 우두머리 10종 (5종씩) |

### 확인해 주실 것

제미나이로 만든 그림의 **상업적 사용 가능 여부**는 쓰시는 요금제 약관을 확인해 주세요.
나중에 출시하려면 필요합니다.

---

## 1. 모든 프롬프트 맨 앞에 붙일 머리말

```
High-quality cozy pixel art for a mobile game, in the style of modern indie
farm RPGs (Stardew Valley-like): detailed, richly shaded, warm and inviting.

STYLE RULES — follow all of them:
- Crisp pixel art with clean pixel edges. No blur, no soft airbrush, no
  photo-realism, no 3D render look.
- Rich but gentle colors: warm greens, soft cherry-blossom pinks, lavender
  accents, honey and cream highlights. Nothing neon, nothing gritty.
- Every surface has texture and 3-4 tones of shading (grass blades, wood
  grain, stone cracks, leaf clusters). Small details everywhere.
- Light comes from the upper-left. Shadows fall to the lower-right.
- No text, no letters, no numbers, no UI, no watermark, no logo.
```

캐릭터·물건 시트(성·둥지, 쿼카, 동물, 벌레)는 머리말 **뒤에 이것도** 붙인다:

```
- Each object stands alone on a plain solid MAGENTA background (#FF00FF).
  The magenta must be pure and flat — no gradient, no shadow on it, no glow.
- Objects must NOT touch or overlap. Leave wide magenta gaps between them.
- No ground shadow under the objects.
```

---

## 2. 배경 10장 (세로 화면)

**모든 배경이 같은 구도여야 한다** — 게임이 그 위에 성·둥지·캐릭터를 같은 자리에 올린다.

```
(머리말 + 이어서)

A tall vertical game background, portrait aspect ratio 9:16
(for example 1080 x 1920 pixels), seen from a 3/4 overhead camera.

COMPOSITION — this is very important, keep it exactly:
- A single dirt road runs straight down the middle of the picture, from the
  top area to the bottom area. It is narrow and far away near the top
  (about 1/5 of the image width) and wide and close near the bottom
  (about 2/3 of the image width), like a road going into the distance.
- The road starts about 14% from the top edge and ends about 70% from the
  top edge. Keep the road surface itself plain and open — nothing standing
  on it — because characters will walk on it.
- The top 12% is sky and far scenery (hills, treetops).
- The bottom 30% is simple ground (it will be covered by buttons).
- Both sides of the road are full of scenery details: see THEME below.
- Do NOT draw any castle, house, fort, nest, character or creature on the
  road. Those are added by the game.

THEME: (아래 표에서 하나 골라 영어 문장을 붙인다)
```

| 번호 | 구역 | THEME 문장 |
|---|---|---|
| 1 | 풀밭 | `A sunny spring meadow. Soft green grass with clover and tiny white and pink flowers, a few cherry blossom trees with falling petals, low wooden fences, a small hay bale and a mushroom ring.` |
| 2 | 웅덩이 | `A gentle marsh after rain. Small clear puddles and a pond with lily pads, reeds and cattails, wet stones, a tiny wooden plank bridge at the side, soft blue-green tones.` |
| 3 | 꽃밭 | `A huge flower garden. Rows of tulips, daisies and lavender on both sides, a few beehive boxes, a watering can, butterflies, warm pink and lavender tones.` |
| 4 | 참나무 숲 | `A cozy oak forest. Big oak trees with thick trunks and round leafy crowns, fallen acorns and leaves, ferns, a mossy log, dappled sunlight.` |
| 5 | 거미 굴 | `A mossy cave entrance area. Rocky walls with glowing purple crystals, hanging roots, soft cobwebs in the corners (cute, not scary), small lanterns, cool lavender tones.` |
| 6 | 쓰레기 언덕 | `A cute junkyard hill. Piles of old crates, tin cans, a broken wheelbarrow, bottle caps and buttons, patches of grass growing through, warm late-afternoon light. Messy but charming, not dirty.` |
| 7 | 밤 들판 | `A field at night. Deep blue and violet sky with stars and a big moon, fireflies glowing in the tall grass, a few glowing lanterns along the road, silver moonlight on the leaves.` |
| 8 | 땅속 마을 | `An underground burrow village. Earth walls with tiny round doors and windows, roots and glowing mushrooms, small ladders and wooden supports, warm lamp light.` |
| 9 | 축축한 부엌 | `A giant kitchen floor seen from the size of a small animal. Huge checkered tiles, a dropped spoon, a sugar cube, crumbs and a puddle of spilled milk at the sides, warm indoor light. The road is a path across the tiles.` |
| 10 | 악몽 하수구 | `A spooky but cute old sewer tunnel. Stone brick walls, green glowing water channels on both sides, pipes, little grates, soft purple mist. Keep it charming, not horror.` |

---

## 3. 성·둥지 1장

```
(머리말 + 물건 규칙 + 이어서)

Two separate objects side by side on magenta, both seen from the same 3/4
overhead camera as the backgrounds:

1. LEFT — the heroes' little fortress, seen from the front: a curved row of
   wooden palisade logs with pointed tops, and in the middle a small wooden
   watchtower with a red tiled roof, a round window and a tiny flag with a
   paw print on top. Cute and sturdy. About as wide as it is tall.

2. RIGHT — the bugs' nest: a big round dirt mound with lumps of earth, roots
   and pebbles, three dark tunnel holes in its face with small glowing red
   eyes peeking out. Mischievous, not scary. About twice as wide as it is tall.
```

---

## 4. 캐릭터 시트 공통 규칙

캐릭터 시트에는 머리말 + 물건 규칙 뒤에 **이것을 또** 붙인다:

```
CHARACTER RULES:
- Cute chibi proportions: a big round head and a small body, about 2 heads tall.
- Every character faces the viewer (front view), standing, arms relaxed,
  holding their item. Full body visible, feet included.
- All characters in the sheet are drawn at the same scale and the same
  camera angle, as if they stand next to each other in the same game.
- Arrange them in a grid of 4 columns x 2 rows, one character per cell,
  with wide magenta gaps.
```

### 쿼카 A — 기본 쿼카 8종

```
(머리말 + 물건 규칙 + 캐릭터 규칙 + 이어서)

Eight quokka soldiers. A quokka is a small round marsupial with warm caramel
brown fur (#B8784F), a cream belly and muzzle, small round ears with pink
insides, a little dark nose, shiny black eyes and rosy cheeks, always smiling.

Reading order:
1. Little quokka — the smallest, a tiny green leaf sprout on its head.
2. Shield quokka — a round grey metal helmet and a big round golden shield.
3. Spear quokka — a red headband, holding a long spear.
4. Hammer quokka — a yellow hard hat, holding a big wooden mallet.
5. Runner quokka — a blue headband, red sneakers, in a running-ready pose.
6. Sling quokka — a green cap, holding a wooden slingshot.
7. Mage quokka — a tall purple wizard hat, holding a staff with a star on top.
8. Giant quokka — twice as big and bulky as the others, a brown helmet with
   two small horns, holding a heavy club.
```

### 쿼카 B — 진화한 쿼카 8종

```
(머리말 + 물건 규칙 + 캐릭터 규칙 + 이어서)

The same eight quokka soldiers as before, now EVOLVED: each is a bit bigger
and looks stronger and proud, while staying cute. Every evolved quokka wears
a golden crown with three small points and a red gem, golden shoulder armor,
a jeweled belt and a flowing red cape, with a soft golden glow around the body.
Their items are upgraded to gold and shine.

Reading order (same as before):
1. Brave little quokka (leaf sprout)  2. Iron-wall quokka (helmet, golden shield)
3. Lightning-spear quokka (red headband, spear with a lightning tip)
4. Blacksmith quokka (hard hat, golden mallet)  5. Gale quokka (blue headband, red sneakers)
6. Sharpshooter quokka (green cap, golden slingshot)
7. Archmage quokka (purple wizard hat, glowing star staff)
8. Mountain quokka (horned helmet, huge golden club) — still twice as big as the others.
```

### 동물 A — 동물 친구 1~8

```
(머리말 + 물건 규칙 + 캐릭터 규칙 + 이어서)

Eight animal friends who fight beside the quokkas. Reading order:
1. Chick — tiny round yellow chick with a piece of eggshell on its head.
2. Hedgehog — brown hedgehog with a crown of spikes, cream face.
3. Squirrel — orange squirrel with a big bushy tail, holding an acorn.
4. Frog — green frog with a leaf hat, big friendly eyes.
5. Rabbit — white rabbit with long ears with pink insides, holding a carrot.
6. Duck — white duck in a little blue sailor hat and collar.
7. Mole — dark grey-purple mole with big claws and a miner's helmet with a lamp.
8. Sheep — fluffy white wool sheep with a dark face.
```

### 동물 B — 동물 친구 9~16

```
(머리말 + 물건 규칙 + 캐릭터 규칙 + 이어서)

Eight more animal friends, a bit rarer and more special. Reading order:
1. Turtle — light green turtle with a dark green shell.
2. Penguin — navy and white penguin wearing a red scarf.
3. Owl — brown owl with round glasses, wise look.
4. Panda — panda holding a bamboo stick, bigger and sturdy.
5. Otter — brown otter holding a pink clam shell.
6. Tiger — orange striped tiger cub with a golden claw gauntlet, bigger, legendary.
7. Polar bear — big white polar bear with an icy blue scarf, legendary, the biggest.
8. Eagle — brown eagle with a white head, large wings and aviator goggles, legendary.
```

### 동물 C · D — 진화한 동물 친구

동물 A·B 를 **그대로** 다시 쓰되 맨 앞 문장만 이걸로 바꾼다:

```
The same eight animal friends as before, now EVOLVED: each is a bit bigger and
looks stronger and proud, while staying cute. Every evolved friend wears a
golden crown with three small points and a red gem, golden shoulder armor and
a flowing red cape, with a soft golden glow. Their items are upgraded to gold.
```

### 벌레 A · B — 졸개 벌레 16종

캐릭터 규칙 중 "chibi" 대신: `Cute but mischievous cartoon bugs, round and chubby, big eyes with a sly grin, facing the viewer.`

```
벌레 A: 1 ant (red-brown) · 2 caterpillar (green, segmented) · 3 mosquito (thin, big eyes)
        4 fly (blue-green shiny) · 5 bee (yellow and black, small wings)
        6 ladybug (red shell, black dots) · 7 termite (pale cream) · 8 cricket (brown, long legs)
벌레 B: 1 moth (dusty lavender wings) · 2 spider (purple, eight legs) · 3 centipede (orange, many legs)
        4 stag beetle (dark shell, big jaws) · 5 wasp (orange and black, stinger)
        6 pill bug (grey armored, curled a little) · 7 mole cricket (brown, digging claws)
        8 cockroach (glossy brown)
```

### 벌레 C · D — 우두머리 10종

캐릭터 규칙의 "4 columns x 2 rows" 를 **"5 in a single row"** 로 바꾸고, 각자 졸개보다 **세 배 크고** 왕관·망토·갑옷 같은 우두머리 장식을 단다:

```
벌레 C: 1 queen ant (crown, royal red) · 2 mosquito king (crown, long needle)
        3 giant hornet (armored, angry eyebrows) · 4 rhino beetle (huge horn)
        5 tarantula king (fuzzy purple, crown)
벌레 D: 1 fly king (crown, shiny green eyes) · 2 moth queen (glowing wing patterns, tiara)
        3 mole cricket king (digging claws, crown) · 4 centipede emperor (long, armored)
        5 cockroach overlord (cape, crown, glossy)
```
