extends Place
## 🌲 솔은재. 2탄 넷째 — "담수 3부작" 다음, 물을 벗어난 첫 마을이다.
## 소나무 고개. 굽이도는 고갯길을 올라 정상 전망대까지 간다.
##
## 1탄 넷을 다 둘러봐야 열린다(`Quests.ORDER`). 카피바라(물범의 담수
## 버전)를 고갯길 쉼터 지기로, 다람쥐를 선택형 서브 NPC로 처음 세운다.


func place_name() -> String:
	return "솔은재"


func _init() -> void:
	legend = {
		"d": "dirt",         # 고갯길
		"g": "grass",        # 솔숲
		".": "dry-grass",    # 길가
		"e": "clay-earth",   # 고개 중턱 쉼터 마당
		"s": "stone-slab",   # 정상 전망대 박석
	}


## 38x22. 고갯길이 아래에서 위로 완만히 굽이돈다. 중턱에 쉼터(카피바라
## 가게·호스텔), 꼭대기에 전망대가 있다.
func ground_map() -> String:
	return """
gggggggggggggggggggggggg..ddddddd..gggggggggggggggggggggg
gggggggggggggggggggggggg..ddddddd..gggggggggggggggggggggg
gggggggggggggggggggggggsssssssssssssggggggggggggggggggggg
ggggggggggggggggggggggggssssssssssssssggggggggggggggggggg
ggggggggggggggggggggggggssssssssssssssggggggggggggggggggg
ggggggggggggggggggggggggggsssssssssssssgggggggggggggggggg
gggggggggggggggggggggggggggssssssssssssssgggggggggggggggg
gggggggggggggggggggggggggggssssssssssssssgggggggggggggggg
gggggggggggggggggggggggggggggg..ddddddd..gggggggggggggggg
gggggggggggggggggggggggggggggggg.dddddddd.ggggggggggggggg
gggggggggggggggggggggggggggggggg.dddddddd.ggggggggggggggg
ggggggggggggggggggggggggggggggggg..ddddddd..ggggggggggggg
ggggggggggggggggggggggggggggggggg..ddddddd..ggggggggggggg
ggggggggggggggggggggggggggggggggg..ddddddd..ggggggggggggg
ggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeggggggggg
ggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeggggggggg
ggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeggggggggg
gggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeeggggggg
gggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeeggggggg
gggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeeggggggg
gggggggggggggggggggggggggggggggggeeeeeeeeeeeeeeeeeggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
gggggggggggggggggggggggggggggggggggg..ddddddd..gggggggggg
ggggggggggggggggggggggggggggggggggg.dddddddd.gggggggggggg
ggggggggggggggggggggggggggggggggggg.dddddddd.gggggggggggg
ggggggggggggggggggggggggggggggggggg.dddddddd.gggggggggggg
ggggggggggggggggggggggggggggggggg..ddddddd..ggggggggggggg
"""


## 소나무를 지도 양쪽 가장자리에 좌우 하나씩 6칸 간격으로 찍어 두었더니
## 숲이 아니라 **띄엄띄엄 선 기둥**으로 보였다. 나무 하나는 3칸이 넘게
## 넓어서, 6칸을 띄우면 서로 닿지도 겹치지도 않는 딱 그 간격이 된다.
##
## 그래서 **덩어리로 모은다.** 한 덩어리는 네댓 그루가 2칸씩 어긋나게
## 서서 우듬지가 서로 물리고, 덩어리와 덩어리 사이는 예닐곱 칸을 통째로
## 비운다. 마루(위)는 솔숲, 중턱 서쪽은 풀밭, 아래는 다시 솔숲이다.
## 소나무만 줄 세우지 않고 참나무·바위·덤불·조약돌을 섞어 키를 흩는다.
##
## 사람이 만든 것은 줄을 맞추고(벤치 두 짝, 가로등, 울짱), 자연은 안
## 맞춘다. 건물마다 발치에 두세 가지를 붙여(장독·화분·장작) 바닥에
## 앉힌다. 길과 문간, 주울 것 둘레는 비워 둔다.
func props() -> Array:
	return [
		# ── 정상 전망대: 전망 바위와 걸터앉는 자리 ───────────────────
		# 바위는 박석 바깥 테두리를 따라 어긋물리게, 벤치 두 짝은
		# 사람이 놓은 것이니 같은 줄(4행)에 맞춘다.
		[35, 4, "boulder", true],
		[36, 7, "boulder", true],
		[39, 7, "pebbles", false],
		[26, 7, "bench", true],
		[33, 7, "bench", true],
		# ── 북쪽 마루 솔숲 ───────────────────────────────────────────
		# 지도 위쪽을 한 덩어리로 덮는다. 전망대와 샛길 어귀(20,8)는
		# 숲에 난 틈으로 남기고, 다람쥐 자리(15,6)도 비워 둔다.
		[8, 2, "pine", true],
		[5, 4, "pine", true],
		[12, 5, "tree", true],
		[9, 10, "pine", true],
		[17, 4, "pine", true],
		[15, 8, "pine", true],
		[21, 5, "pine", true],
		[20, 11, "pine", true],
		[26, 13, "pine", true],
		[27, 17, "pine", true],
		# ── 중턱 풀밭의 외딴 나무 ────────────────────────────────────
		# 서쪽 비탈은 통째로 비운다. 대신 한가운데에 참나무 하나와
		# 바위·덤불·조약돌을 붙여 이정표를 세운다.
		[17, 20, "tree", true],
		[14, 23, "boulder", true],
		[20, 22, "shrub", false],
		[15, 25, "pebbles", false],
		# ── 마당 서쪽 어귀 ───────────────────────────────────────────
		[29, 20, "boulder", true],
		[30, 22, "shrub", false],
		# ── 남서 솔숲 ────────────────────────────────────────────────
		[5, 25, "pine", true],
		[6, 28, "pine", true],
		[3, 29, "pine", true],
		[5, 32, "pine", true],
		[11, 31, "tree", true],
		# ── 아랫길 왼쪽 솔숲 ─────────────────────────────────────────
		[21, 28, "pine", true],
		[24, 31, "pine", true],
		[27, 29, "pine", true],
		# ── 고개 어귀 ────────────────────────────────────────────────
		# 울짱 두 짝은 이어 붙여 한 줄로. 표지판·우체통은 그대로 둔다.
		[29, 32, "fence", true],
		[32, 32, "fence", true],
		[35, 32, "signpost", false],
		[41, 32, "mailbox", true],
		# ── 북동 솔숲 (호스텔 뒤쪽) ──────────────────────────────────
		[42, 2, "tree", true],
		[47, 4, "pine", true],
		[50, 2, "pine", true],
		[51, 7, "tree", true],
		[54, 10, "pine", true],
		# ── 중턱 쉼터 마당 ───────────────────────────────────────────
		# 가로등 둘은 마당 서쪽 모서리를 따라, 벤치 둘은 같은 세로줄에.
		# 장독·화분·장작은 가게와 호스텔 발치에 붙여 건물을 앉힌다.
		# 문간(27,11)과 잠자리(30,11)는 비워 둔다.
		[41, 16, "shop", true],
		[45, 16, "guesthouse", true],
		[32, 16, "street-lamp", true],
		[35, 17, "bench", true],
		[38, 17, "jars", true],
		[42, 17, "flower-pots", false],
		[44, 19, "jars", true],
		[48, 17, "firewood", true],
		[32, 20, "street-lamp", true],
		[35, 20, "bench", true],
		# ── 동남 솔숲 ────────────────────────────────────────────────
		[51, 22, "pine", true],
		[54, 25, "pine", true],
		[50, 28, "tree", true],
		[47, 31, "pine", true],
		[51, 32, "tree", true],
		# ── 길가 ─────────────────────────────────────────────────────
		[30, 8, "shrub", false],
		# ── 정상 전망대 둘레 (솔은재:전망 장면)
		[36, 8, "pebbles", false],
		[24, 8, "boulder", true],
		# ── 샛길 어귀 쉼터 (다람쥐의 자리)
		[21, 13, "boulder", true],
		[21, 19, "bench", true],
		# ── 솔밭 그늘로 들어가는 자리 (서쪽 비탈) ────────────────────
		[11, 19, "pebbles", false],
	]


func pickups() -> Array:
	return [
		[30, 5, "p-pinecone"],     # 전망대
		[29, 11, "p-pinecone"],     # 고갯길
		[39, 19, "p-acorn"],       # 쉼터
		[30, 25, "p-pinecone"],
		[36, 28, "p-acorn"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(38, 31)


func sleep_tile() -> Vector2i:
	return Vector2i(45, 17)


func depart_tile() -> Vector2i:
	return Vector2i(38, 32)

func wanderer_tile() -> Vector2i:
	return Vector2i(36, 19)



## "고갯마루 전망 바위까지 가 보기" — 정상 전망대.
func quest_zones() -> Array:
	return [["솔은재:전망", Vector2i(30, 4), 56.0]]


func doors() -> Array:
	return [
		{"tile": Vector2i(41, 17),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 고갯길에서 솔숲 쪽으로 빠지는 샛길. 다람쥐가 말하던 그 자리가
		# 이 안쪽 끝에 있다 — 마을에 두면 두 걸음이라 걷는 맛이 없었다.
		{"tile": Vector2i(30, 13),
			"scene": "res://scenes/journey/interiors/SidePathInterior.tscn",
			"label": "솔숲 사이로", "enter_key": "샛길입구"},
		# 서쪽 비탈, 솔숲이 유난히 그늘진 자리. 샛길과는 다른 문이니
		# `enter_key` 도 다르게 준다.
		{"tile": Vector2i(9, 17),
			"scene": "res://scenes/journey/interiors/GatherGround.tscn",
			"label": "솔밭 그늘로 들어가기", "enter_key": "솔밭그늘"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 스웨터 차림. 고개 중턱 쉼터를 지킨다.
	put_folk(Vector2i(38, 20), "capybara-c", "고개 쉼터 아저씨", "cap_sol", [
		["여기까지 올라오면 다리가 좀 뻐근하지."],
		["앉았다 가요.", "고개는 도망 안 가."],
		["서두르는 사람은 여기서 다 놓쳐요.", "천천히 봐야 보이는 게 있거든."],
		["솔향 맡으면서 쉬었다 가요."],
		["고개는 어디 안 가요. 또 와요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 정상 전망대, 먼 곳을 본다.
	put_folk(Vector2i(27, 7), "seagull", "고갯마루의 갈매기", "so_gull", [
		["여기서 보면 다 작아 보여요."],
		["고갯마루까지 가 봤어요?", "여기가 딱 거기예요."],
		["오늘은 멀리까지 다 보이네요."],
		["같이 좀 앉아 있을래요?"],
		["고갯마루에서 또 봐요."],
	], Vector2.DOWN, false, {
		# 아침엔 전망대, 낮엔 쉼터 마당, 저녁엔 아랫길 — 고개를 오르내린다.
		"아침": Vector2i(27, 7),
		"낮": Vector2i(35, 16),
		"저녁": Vector2i(41, 28),
	})

	# 다람쥐 — 선택형 서브 NPC. 솔숲 사이, 붙박이.
	put_folk(Vector2i(23, 10), "squirrel", "솔숲의 다람쥐", "so_squirrel", [
		["…"],
		["모아 두는 건 서두르는 게 아니라,", "내일의 나를 챙기는 일이에요."],
		["또 왔어요?", "묻어 둔 솔방울은 아직 거기 있어요."],
	], Vector2.DOWN, false, {})

	# 여행자. 다른 마을에서 만났던 그 너구리를 여기서 다시 만난다 —
	# 재회는 1탄에서 끝나지 않는다 (`JourneyState.WANDERER_STOPS`).
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["나는 아무 계획 없이 다녀요.", "그게 편하더라고."],
		["여긴 이틀만 있다 갈 거예요.", "다음은 아직 안 정했고."],
		["같이 노을 보러 갈래요?"],
		["그럼 또 어디선가.", "…진짜로 또 만나겠죠?"],
	], [
		"고개 넘다가 하루 쉬어 가요.",
	])


## 솔숲 — 깊고 어두운 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(0.93, 0.98, 0.95)
