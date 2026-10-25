"""쿼카 군단 그림 프롬프트 - docs/art-prompts-lane.md 와 같은 내용을 코드로. gemini_image.py 가 쓴다."""

HEAD = """High-quality cozy pixel art for a mobile game, in the style of modern indie
farm RPGs (Stardew Valley-like): detailed, richly shaded, warm and inviting.
STYLE RULES - follow all of them:
- Crisp pixel art with clean pixel edges. No blur, no soft airbrush, no photo-realism, no 3D render look.
- Rich but gentle colors: warm greens, soft cherry-blossom pinks, lavender accents, honey and cream highlights.
  Nothing neon, nothing gritty.
- Every surface has texture and 3-4 tones of shading (grass blades, wood grain, stone cracks, leaf clusters).
- Light comes from the upper-left. Shadows fall to the lower-right.
- No text, no letters, no numbers, no UI, no watermark, no logo.
"""

OBJ = """- Each object stands alone on a plain solid MAGENTA background (#FF00FF). The magenta must be pure and
  flat - no gradient, no shadow on it, no glow.
- Objects must NOT touch or overlap. Leave wide magenta gaps between them.
- No ground shadow under the objects.
"""

CHAR = """CHARACTER RULES:
- Cute chibi proportions: a big round head and a small body, about 2 heads tall.
- Every character faces the viewer (front view), standing, holding their item. Full body visible, feet included.
- All characters in the sheet are drawn at the same scale and the same camera angle.
- Arrange them in a grid of 4 columns x 2 rows, one character per cell, with wide magenta gaps.
"""

BG = """A tall vertical game background, portrait aspect ratio 9:16, seen from a 3/4 overhead camera.
COMPOSITION - keep exactly:
- A single dirt road runs straight down the middle of the picture. It is narrow and far near the top
  (about 1/5 of the image width) and wide and close near the bottom (about 2/3 of the image width).
- The road starts about 14% from the top edge and ends about 70% from the top edge. Keep the road surface
  plain and open - nothing standing on it - because characters will walk on it.
- The top 12% is sky and far scenery. The bottom 30% is simple ground (it will be covered by buttons).
- Both sides of the road are full of scenery details.
- Do NOT draw any castle, house, fort, nest, character or creature on the road.
THEME: """

THEMES = [
    "A sunny spring meadow. Soft green grass with clover and tiny white and pink flowers, a few cherry blossom "
    "trees with falling petals, low wooden fences, a small hay bale and a mushroom ring.",
    "A gentle marsh after rain. Small clear puddles and a pond with lily pads, reeds and cattails, wet stones, "
    "a tiny wooden plank bridge at the side, soft blue-green tones.",
    "A huge flower garden. Rows of tulips, daisies and lavender on both sides, a few beehive boxes, a watering "
    "can, butterflies, warm pink and lavender tones.",
    "A cozy oak forest. Big oak trees with thick trunks and round leafy crowns, fallen acorns and leaves, ferns, "
    "a mossy log, dappled sunlight.",
    "A mossy cave entrance area. Rocky walls with glowing purple crystals, hanging roots, soft cobwebs in the "
    "corners (cute, not scary), small lanterns, cool lavender tones.",
    "A cute junkyard hill. Piles of old crates, tin cans, a broken wheelbarrow, bottle caps and buttons, patches "
    "of grass growing through, warm late-afternoon light. Messy but charming, not dirty.",
    "A field at night. Deep blue and violet sky with stars and a big moon, fireflies glowing in the tall grass, "
    "a few glowing lanterns along the road, silver moonlight on the leaves.",
    "An underground burrow village. Earth walls with tiny round doors and windows, roots and glowing mushrooms, "
    "small ladders and wooden supports, warm lamp light.",
    "A giant kitchen floor seen from the size of a small animal. Huge checkered tiles, a dropped spoon, a sugar "
    "cube, crumbs and a puddle of spilled milk at the sides, warm indoor light. The road is a path across the tiles.",
    "A spooky but cute old sewer tunnel. Stone brick walls, green glowing water channels on both sides, pipes, "
    "little grates, soft purple mist. Keep it charming, not horror.",
]

FORTNEST = """Two separate objects side by side on magenta, 3/4 overhead camera:
1. LEFT - the heroes' little fortress, seen from the front: a curved row of wooden palisade logs with pointed
   tops, and in the middle a small wooden watchtower with a red tiled roof, a round window and a tiny flag with
   a paw print on top. Cute and sturdy. About as wide as it is tall.
2. RIGHT - the bugs' nest: a big round dirt mound with lumps of earth, roots and pebbles, three dark tunnel
   holes in its face with small glowing red eyes peeking out. Mischievous, not scary. About twice as wide as tall.
"""

QUOKKA = """A quokka is a small round marsupial with warm caramel brown fur (#B8784F), a cream belly and muzzle,
small round ears with pink insides, a little dark nose, shiny black eyes and rosy cheeks, always smiling.
"""

QUOKKA_A = QUOKKA + """Eight quokka soldiers. Reading order:
1. Little quokka - the smallest, a tiny green leaf sprout on its head.
2. Shield quokka - a round grey metal helmet and a big round golden shield.
3. Spear quokka - a red headband, holding a long spear.
4. Hammer quokka - a yellow hard hat, holding a big wooden mallet.
5. Runner quokka - a blue headband, red sneakers, in a running-ready pose.
6. Sling quokka - a green cap, holding a wooden slingshot.
7. Mage quokka - a tall purple wizard hat, holding a staff with a star on top.
8. Giant quokka - twice as big and bulky as the others, a brown helmet with two small horns, a heavy club.
"""

EVOLVED = """now EVOLVED: each is a bit bigger and looks stronger and proud, while staying cute. Every evolved one
wears a golden crown with three small points and a red gem, golden shoulder armor, a jeweled belt and a flowing
red cape, with a soft golden glow around the body. Their items are upgraded to gold and shine.
"""

QUOKKA_B = QUOKKA + "The same eight quokka soldiers, " + EVOLVED + """Reading order:
1. little quokka (leaf sprout) 2. shield quokka (helmet, golden shield) 3. spear quokka (spear with a lightning
tip) 4. hammer quokka (hard hat, golden mallet) 5. runner quokka (blue headband, red sneakers) 6. sling quokka
(green cap, golden slingshot) 7. mage quokka (purple wizard hat, glowing star staff) 8. giant quokka (horned
helmet, huge golden club) - still twice as big as the others.
"""

ANIMAL_A = """Eight animal friends who fight beside the quokkas. Reading order:
1. Chick - tiny round yellow chick with a piece of eggshell on its head.
2. Hedgehog - brown hedgehog with a crown of spikes, cream face.
3. Squirrel - orange squirrel with a big bushy tail, holding an acorn.
4. Frog - green frog with a leaf hat, big friendly eyes.
5. Rabbit - white rabbit with long ears with pink insides, holding a carrot.
6. Duck - white duck in a little blue sailor hat and collar.
7. Mole - dark grey-purple mole with big claws and a miner's helmet with a lamp.
8. Sheep - fluffy white wool sheep with a dark face.
"""

ANIMAL_B = """Eight more animal friends, rarer and more special. Reading order:
1. Turtle - light green turtle with a dark green shell.
2. Penguin - navy and white penguin wearing a red scarf.
3. Owl - brown owl with round glasses, wise look.
4. Panda - panda holding a bamboo stick, bigger and sturdy.
5. Otter - brown otter holding a pink clam shell.
6. Tiger - orange striped tiger cub with a golden claw gauntlet, bigger, legendary.
7. Polar bear - big white polar bear with an icy blue scarf, legendary, the biggest.
8. Eagle - brown eagle with a white head, large wings and aviator goggles, legendary.
"""

BUG_RULE = """CHARACTER RULES:
- Cute but mischievous cartoon bugs, round and chubby, big eyes with a sly grin, facing the viewer.
- All drawn at the same scale and the same camera angle.
- Arrange them in a grid of 4 columns x 2 rows, one per cell, with wide magenta gaps.
"""

BOSS_RULE = """CHARACTER RULES:
- Cute but mischievous cartoon bug BOSSES, round and chubby, big eyes, facing the viewer, each wearing boss
  decorations (crown, cape or armor).
- All drawn at the same scale and the same camera angle.
- Arrange them in a single row of 5, one per cell, with wide magenta gaps.
"""

BUG_A = """Eight bugs. Reading order: 1 ant (red-brown) 2 caterpillar (green, segmented) 3 mosquito (thin, big
eyes) 4 fly (blue-green shiny) 5 bee (yellow and black, small wings) 6 ladybug (red shell, black dots)
7 termite (pale cream) 8 cricket (brown, long legs)."""
BUG_B = """Eight bugs. Reading order: 1 moth (dusty lavender wings) 2 spider (purple, eight legs) 3 centipede
(orange, many legs) 4 stag beetle (dark shell, big jaws) 5 wasp (orange and black, stinger) 6 pill bug (grey
armored) 7 mole cricket (brown, digging claws) 8 cockroach (glossy brown)."""
BOSS_C = """Five bosses. Reading order: 1 queen ant (crown, royal red) 2 mosquito king (crown, long needle)
3 giant hornet (armored, angry eyebrows) 4 rhino beetle (huge horn) 5 tarantula king (fuzzy purple, crown)."""
BOSS_D = """Five bosses. Reading order: 1 fly king (crown, shiny green eyes) 2 moth queen (glowing wing patterns,
tiara) 3 mole cricket king (digging claws, crown) 4 centipede emperor (long, armored) 5 cockroach overlord
(cape, crown, glossy)."""

JOBS = {}
for i, th in enumerate(THEMES):
    JOBS["bg%d" % (i + 1)] = {"title": "배경 %d" % (i + 1), "aspect": "9:16", "text": HEAD + BG + th}
JOBS["fortnest"] = {"title": "성·둥지", "aspect": "16:9", "text": HEAD + OBJ + FORTNEST}
JOBS["quokkaA"] = {"title": "쿼카 A (기본 8)", "aspect": "16:9", "text": HEAD + OBJ + CHAR + QUOKKA_A}
JOBS["quokkaB"] = {"title": "쿼카 B (진화 8)", "aspect": "16:9", "text": HEAD + OBJ + CHAR + QUOKKA_B}
JOBS["animalA"] = {"title": "동물 A", "aspect": "16:9", "text": HEAD + OBJ + CHAR + ANIMAL_A}
JOBS["animalB"] = {"title": "동물 B", "aspect": "16:9", "text": HEAD + OBJ + CHAR + ANIMAL_B}
JOBS["animalC"] = {"title": "동물 C (A 진화)", "aspect": "16:9",
                   "text": HEAD + OBJ + CHAR + "The same eight animal friends, " + EVOLVED + ANIMAL_A}
JOBS["animalD"] = {"title": "동물 D (B 진화)", "aspect": "16:9",
                   "text": HEAD + OBJ + CHAR + "The same eight animal friends, " + EVOLVED + ANIMAL_B}
JOBS["bugA"] = {"title": "벌레 A", "aspect": "16:9", "text": HEAD + OBJ + BUG_RULE + BUG_A}
JOBS["bugB"] = {"title": "벌레 B", "aspect": "16:9", "text": HEAD + OBJ + BUG_RULE + BUG_B}
JOBS["bossC"] = {"title": "우두머리 C", "aspect": "21:9", "text": HEAD + OBJ + BOSS_RULE + BOSS_C}
JOBS["bossD"] = {"title": "우두머리 D", "aspect": "21:9", "text": HEAD + OBJ + BOSS_RULE + BOSS_D}

FIRST = ["bg1", "fortnest", "quokkaA"]


def prompt(jid: str) -> str:
    return JOBS[jid]["text"]
