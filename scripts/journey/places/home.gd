extends Place
## 고향. 이 게임에서 이름이 없는 유일한 곳.
##
## `docs/story-journey.md` 5절. 작아야 한다 — 마당에 서면 집도 밭도 감나무도
## 한눈에 들어와야 하고, 끝에서 끝까지 스무 걸음이면 된다.
##
## 여기에는 **지어낸 낱말이 하나도 안 나온다.** 고향은 있는 말로만 쓴다.
## 가게도 상표도 없는 곳이라 붙일 게 없고, 그래서 다른 데보다 조용하다.

func place_name() -> String:
	return "고향"


func _init() -> void:
	legend = {
		"g": "grass",         # 바깥 풀밭
		".": "dry-grass",     # 마당과 풀밭 사이, 밟혀서 누런 데
		"y": "clay-earth",    # 마당. 비질한 황토
		"s": "stone-slab",    # 집 앞 디딤돌
		"f": "tilled-soil",   # 밭고랑
	}


## 산과 밭 사이의 낮은 집, 마당, 감나무 한 그루, 평상. 35 x 22.
##
## 한때 44칸이었다. 폰으로 걸어 보니 **넓기만 하고 허전했다** — 고향인데
## 마당 끝이 안 보이고, 걸어도 걸어도 빈 흙바닥이었다. 35칸으로 좁혔다.
## 3배 줌에서 지도 밖 회색이 드러나지 않는 한계가 34칸이라 그 바로 위다.
##
## 바닥도 예전엔 곧은 네모였다. 마당이 자로 잰 듯한 직사각형이면 마당이
## 아니라 운동장이다. 이제 **마당은 둥글고 가장자리가 들쭉날쭉하다** —
## 누런 풀이 황토로 삐져들고, 집 뒤로는 풀이 한 칸 파고들었고,
## 마당 남쪽 끝은 혀처럼 밭 쪽으로 흘러내린다. 밭고랑도 네모가 아니다.
func ground_map() -> String:
	return """
ggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggg
ggggggggggg.....ggggggg....gggggggg
ggggg......ggg.........gggg....gggg
ggg........gg.............gg.....gg
gg.....yyyyyyyy...yyyyyyyyyy....ggg
gg....yyyyyyyyyy.yyyyyyyyyyy....ggg
g...yyyyyyyyyyyyyyyyyyyyyyyyy...ggg
g....yyyyyyyyyyyysssyyyyyyyyy...ggg
g...yyyyyyyyyyyyysssyyyyyyyyyy..ggg
g..yyyyyyyyyyyyyyyyyyyyyyyyyyy..ggg
g....yyyyyyyyyyyyyyyyyyyyyyyyy...gg
gg..yyyyyyyyyyyyyyyyyyyyyyyy....ggg
gg.....yyyyyyyyyyyyyyyyyyyyy....ggg
gg.......yyyyyyyyyyyyyyy.......gggg
ggg........yyyyyyyyy...........gggg
gg...........yyy...............gggg
gg...fffffff..........g........gggg
gg..fffffffff............gg......gg
ggg..ffffffff...g..........ggg...gg
gggg.........gg...........ggg...ggg
ggggggggggggggggggggggggggggggggggg
"""


## 덩어리로 놓는다. 하나씩 흩뿌리면 채워도 여전히 허전하다 —
## 항아리 넷이 모여야 장독대가 되고, 소나무와 나무가 줄지어야 산자락이 된다.
##
## 막는 소품의 콜라이더는 가로로 그림 폭의 70% 만큼 퍼진다. 소나무·나무·집은
## 세 칸을 먹으니 길목에는 안 둔다. **마당 한복판(x16~24)은 비워 둔다** —
## 시작 자리에서 디딤돌까지, 시작 자리에서 마을 어귀까지 곧게 뚫려 있다.
func props() -> Array:
	return [
		# ── 북쪽 산자락. 지도 위쪽을 나무로 막는다. 안 막으면 세상이 끊겨 보인다
		[1, 2, "pine", true],
		[5, 1, "tree", true],
		[9, 3, "pine", true],
		[13, 1, "tree", true],
		[17, 2, "pine", true],
		[21, 1, "tree", true],
		[25, 3, "pine", true],
		[29, 1, "tree", true],
		[33, 2, "pine", true],
		[3, 4, "boulder", true],
		[27, 3, "boulder", true],
		[7, 4, "shrub", false],
		[21, 3, "shrub", false],
		[30, 4, "shrub", false],

		# ── 집. 문이 디딤돌 바로 위에 오게 맞춘다 — 디딤돌은 x17~19
		[18, 7, "home-house", true],
		# 집 오른쪽 살림. 빨랫줄 · 펌프 · 대야 · 처마 밑 장작
		[21, 5, "clothesline", true],
		[23, 5, "clothesline", true],
		[22, 6, "pump", true],
		[23, 6, "washtub", false],
		[24, 7, "firewood", true],
		[25, 7, "firewood", true],
		# 장독대. 볕 드는 쪽. 넷이 모여야 장독대다
		[13, 5, "jars", true],
		[14, 5, "jars", true],
		[13, 6, "jars", true],
		[14, 6, "jars", true],

		# ── 서쪽. 감나무와 밭 가는 길목
		[2, 7, "tree", true],
		[5, 9, "shrub", false],
		[10, 9, "flower-pots", false],
		[1, 11, "pine", true],
		# 감나무. 뒤로 걸어 들어가면 가려진다
		[7, 12, "home-persimmon", true],
		[2, 14, "tree", true],
		[4, 16, "shrub", false],
		[1, 18, "pine", true],
		[3, 18, "tools", true],

		# ── 동쪽. 낮은 울과 평상
		[33, 6, "tree", true],
		[28, 8, "jars", true],
		[29, 8, "jars", true],
		[30, 8, "fence", true],
		[30, 9, "fence", true],
		[30, 10, "fence", true],
		[27, 10, "flower-pots", false],
		[28, 11, "flower-pots", false],
		[33, 11, "pine", true],
		# 평상. 엔딩에서 여기 앉는다
		[26, 12, "home-deck", false, true],   # 바로 아래(26,13)가 "평상" 자리다
		[25, 14, "bench", true],
		[32, 15, "tree", true],
		[31, 18, "pine", true],
		[34, 20, "shrub", false],

		# ── 남서쪽 밭. 고랑 넷이 모여 밭 한 뙈기가 된다
		[6, 17, "home-garden", false],
		[9, 17, "home-garden", false],
		[6, 19, "home-garden", false],
		[9, 19, "home-garden", false],
		[12, 16, "washtub", false],
		[9, 15, "pebbles", false],
		[13, 18, "firewood", true],
		[15, 19, "mailbox", true],
		[20, 16, "pebbles", false],

		# ── 마을 어귀. 여기서 떠난다.
		# 표지판은 **안 막는다** — 그 위로 걸어가도 되는 편이 낫다
		[17, 20, "signpost", false],
		[20, 20, "bench", true],
		[8, 20, "boulder", true],
		[22, 19, "shrub", false],
		[24, 20, "shrub", false],
		[11, 21, "shrub", false],
		[26, 21, "shrub", false],
		[6, 21, "pine", true],
		[29, 21, "tree", true],
	]


## 감나무 밑에 감이 떨어져 있고, 마당 구석에 이런저런 것이 있다.
##
## 여덟 개는 많다. **다섯 개만** 둔다 — 다 줍는 데 1분이면 되고,
## 다 주웠다는 느낌이 있어야 다음에 왔을 때 다른 게 반갑다.
func pickups() -> Array:
	return [
		[6, 13, "p-persimmon"],      # 감나무 밑
		[8, 14, "p-persimmon"],
		[28, 9, "p-flower"],         # 장독대 옆
		[21, 17, "p-pebble"],        # 마당 남쪽
		[10, 20, "p-acorn"],         # 밭 아래
	]


## 마당 한가운데, 집을 올려다보는 자리에서 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(18, 12)


## 집 문 앞. 디딤돌 위다.
func sleep_tile() -> Vector2i:
	return Vector2i(18, 9)


## 마을 어귀. 여기서 다시 떠난다. 바로 옆(x17)에 표지판이 서 있다.
func depart_tile() -> Vector2i:
	return Vector2i(18, 20)


func on_built() -> void:
	JourneyState.here = place_name()

	# 평상. 여기 앉으면 모아 둔 엽서를 한 장씩 넘겨 본다
	# (`docs/story-journey.md` 6절) — 떠나서 만난 것들을, 떠나온 자리에서.
	put_spot(Vector2i(26, 13), "평상", _deck_lines())
	# 엄마는 마당에서 뭘 널고 있고, 아빠는 밭 옆에서 뭘 고치고 있고,
	# 동생은 평상에 앉아 있다. 셋이 흩어져 있어야 마당이 넓어 보인다.
	#
	# 대사는 마음 칸마다 다르다. 숫자는 안 보여 주고 **말투로만** 알린다
	# (`docs/redesign-journey.md` 5절).

	# 엄마의 첫마디는 **언제 왔느냐**에 따라 다르다
	# (`docs/story-journey.md` 5절). 벌이 아니라 그냥 다른 것이다.
	# `once` 를 따로 안 준다. 첫 만남에 그걸 쓰고 나면 말을 건 순간 마음이
	# 한 칸 올라 있어서, 0칸 대사를 **영영 못 듣는다.** 첫마디는 이미
	# 0칸 줄이 들고 있으니 그대로 두면 된다.
	#
	# 밥 하는 사람의 하루다 — 아침엔 장독대에서 국거리를 푸고(국 데워
	# 놨다는 그 국), 낮엔 마당에서 빨래를 널고, 저녁엔 펌프 옆 빨래통
	# 앞에서 하루를 헹군다.
	put_folk(Vector2i(14, 10), "mom", "엄마", "mom", [
		[_mom_greeting(), "…들어와서 밥부터 먹어."],
		["밥은 먹었니.", "국 데워 놨다."],
		["얼굴이 좀 폈네.", "천천히 있다 가."],
	], Vector2.DOWN, false,
		{"아침": Vector2i(15, 6), "낮": Vector2i(14, 10), "저녁": Vector2i(23, 7)})

	# 아침엔 밭고랑 한가운데(해 뜨면 밭부터), 낮엔 연장걸이 옆에서
	# 손잡이를 고치고, 저녁엔 평상 곁 벤치 옆에 선다 — "…다 됐다" 하고
	# 하루를 닫는 자리. 말은 없어도 자리는 하루 종일 옮겨 다닌다.
	put_folk(Vector2i(4, 17), "dad", "아빠", "dad", [
		["…왔냐."],
		["…어."],
		["이거 손잡이가 헐거워서.", "…다 됐다."],
	], Vector2.RIGHT, false,
		{"아침": Vector2i(8, 18), "낮": Vector2i(4, 17), "저녁": Vector2i(24, 14)})

	# 떠나고 싶은 아이의 하루다 — 아침엔 우체통 옆(엽서가 왔나 보러),
	# 낮엔 평상, 저녁엔 마을 어귀 벤치 옆에서 표지판 너머 길을 본다.
	# "나도 언젠가 그렇게 다녀 볼래" 가 서 있는 자리로도 보이게.
	put_folk(Vector2i(27, 13), "sibling", "동생", "sibling", [
		["어, 왔어?", "회사는 어쩌고?"],
		["요즘 뭐 하고 다녀?"],
		["나도 언젠가 그렇게 다녀 볼래."],
	], Vector2.LEFT, false,
		{"아침": Vector2i(16, 19), "낮": Vector2i(27, 13), "저녁": Vector2i(21, 20)})


## 늦게 올수록 첫마디가 달라진다.
func _mom_greeting() -> String:
	var been := JourneyState.places_visited()
	if been <= 2:
		return "어? 벌써 왔어? 회사는?"
	if been <= 8:
		return "얼굴 좋아졌네."
	return "…어디 갔다 이제 와."


## 평상에 앉으면 나오는 말. 엽서가 몇 장이냐에 따라 다르다.
##
## 엔딩을 따로 만들지 않았다. 이 게임에는 "끝"이 없고, 대신 **평상이
## 늘 거기 있다.** 언제 앉아도 지금까지의 여행을 넘겨 볼 수 있다.
func _deck_lines() -> Array:
	var cards := JourneyState.postcards
	if cards.is_empty():
		return [
			"평상에 앉았다.",
			"아직 아무한테서도 엽서가 안 왔다.",
			"…이제 막 떠났으니까.",
		]
	var out: Array = ["평상에 앉아 엽서를 꺼냈다."]
	for id in cards:
		out.append(JourneyState.postcard_text(id))
	out.append("혼자 떠났는데, 진짜 행복이 이만큼이었다.")
	return out
