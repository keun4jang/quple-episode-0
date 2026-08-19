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
## 가게·쿼스텔), 꼭대기에 전망대가 있다.
func ground_map() -> String:
	return """
gggggggggggggggg.ddddd.ggggggggggggggg
gggggggggggggggsssssssssgggggggggggggg
ggggggggggggggggsssssssssggggggggggggg
gggggggggggggggggsssssssssgggggggggggg
ggggggggggggggggggsssssssssggggggggggg
gggggggggggggggggggg.ddddd.ggggggggggg
ggggggggggggggggggggg.ddddd.gggggggggg
gggggggggggggggggggggg.ddddd.ggggggggg
gggggggggggggggggggggg.ddddd.ggggggggg
gggggggggggggggggggggeeeeeeeeeeegggggg
gggggggggggggggggggggeeeeeeeeeeegggggg
ggggggggggggggggggggggeeeeeeeeeeeggggg
ggggggggggggggggggggggeeeeeeeeeeeggggg
ggggggggggggggggggggggeeeeeeeeeeeggggg
gggggggggggggggggggggggg.ddddd.ggggggg
gggggggggggggggggggggggg.ddddd.ggggggg
gggggggggggggggggggggggg.ddddd.ggggggg
gggggggggggggggggggggggg.ddddd.ggggggg
gggggggggggggggggggggggg.ddddd.ggggggg
ggggggggggggggggggggggg.ddddd.gggggggg
ggggggggggggggggggggggg.ddddd.gggggggg
gggggggggggggggggggggg.ddddd.ggggggggg
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
		[23, 2, "boulder", true],
		[24, 4, "boulder", true],
		[26, 4, "pebbles", false],
		[17, 4, "bench", true],
		[22, 4, "bench", true],
		# ── 북쪽 마루 솔숲 ───────────────────────────────────────────
		# 지도 위쪽을 한 덩어리로 덮는다. 전망대와 샛길 어귀(20,8)는
		# 숲에 난 틈으로 남기고, 다람쥐 자리(15,6)도 비워 둔다.
		[5, 1, "pine", true],
		[3, 2, "pine", true],
		[8, 3, "tree", true],
		[6, 6, "pine", true],
		[11, 2, "pine", true],
		[10, 5, "pine", true],
		[14, 3, "pine", true],
		[13, 7, "pine", true],
		[17, 8, "pine", true],
		[18, 11, "pine", true],
		# ── 중턱 풀밭의 외딴 나무 ────────────────────────────────────
		# 서쪽 비탈은 통째로 비운다. 대신 한가운데에 참나무 하나와
		# 바위·덤불·조약돌을 붙여 이정표를 세운다.
		[11, 13, "tree", true],
		[9, 15, "boulder", true],
		[13, 14, "shrub", false],
		[10, 16, "pebbles", false],
		# ── 마당 서쪽 어귀 ───────────────────────────────────────────
		[19, 13, "boulder", true],
		[20, 14, "shrub", false],
		# ── 남서 솔숲 ────────────────────────────────────────────────
		[3, 16, "pine", true],
		[4, 18, "pine", true],
		[2, 19, "pine", true],
		[3, 21, "pine", true],
		[7, 20, "tree", true],
		# ── 아랫길 왼쪽 솔숲 ─────────────────────────────────────────
		[14, 18, "pine", true],
		[16, 20, "pine", true],
		[18, 19, "pine", true],
		# ── 고개 어귀 ────────────────────────────────────────────────
		# 울짱 두 짝은 이어 붙여 한 줄로. 표지판·우체통은 그대로 둔다.
		[19, 21, "fence", true],
		[21, 21, "fence", true],
		[23, 21, "signpost", false],
		[27, 21, "mailbox", true],
		# ── 북동 솔숲 (쿼스텔 뒤쪽) ──────────────────────────────────
		[28, 1, "tree", true],
		[31, 2, "pine", true],
		[33, 1, "pine", true],
		[34, 4, "tree", true],
		[36, 6, "pine", true],
		# ── 중턱 쉼터 마당 ───────────────────────────────────────────
		# 가로등 둘은 마당 서쪽 모서리를 따라, 벤치 둘은 같은 세로줄에.
		# 장독·화분·장작은 가게와 쿼스텔 발치에 붙여 건물을 앉힌다.
		# 문간(27,11)과 잠자리(30,11)는 비워 둔다.
		[27, 10, "shop", true],
		[30, 10, "guesthouse", true],
		[21, 10, "street-lamp", true],
		[23, 11, "bench", true],
		[25, 11, "jars", true],
		[28, 11, "flower-pots", false],
		[29, 12, "jars", true],
		[32, 11, "firewood", true],
		[21, 13, "street-lamp", true],
		[23, 13, "bench", true],
		# ── 동남 솔숲 ────────────────────────────────────────────────
		[34, 14, "pine", true],
		[36, 16, "pine", true],
		[33, 18, "tree", true],
		[31, 20, "pine", true],
		[34, 21, "tree", true],
		# ── 길가 ─────────────────────────────────────────────────────
		[20, 5, "shrub", false],
		# ── 정상 전망대 둘레 (솔은재:전망 장면)
		[24, 5, "pebbles", false],
		[16, 5, "boulder", true],
		# ── 샛길 어귀 쉼터 (다람쥐의 자리)
		[14, 8, "boulder", true],
		[14, 12, "bench", true],
	]


func pickups() -> Array:
	return [
		[20, 3, "p-pinecone"],     # 전망대
		[19, 7, "p-pinecone"],     # 고갯길
		[26, 12, "p-acorn"],       # 쉼터
		[20, 16, "p-pinecone"],
		[24, 18, "p-acorn"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(25, 20)


func sleep_tile() -> Vector2i:
	return Vector2i(30, 11)


func depart_tile() -> Vector2i:
	return Vector2i(25, 21)

func wanderer_tile() -> Vector2i:
	return Vector2i(24, 12)



## "고갯마루 전망 바위까지 가 보기" — 정상 전망대.
func quest_zones() -> Array:
	return [["솔은재:전망", Vector2i(20, 2), 56.0]]


func doors() -> Array:
	return [
		{"tile": Vector2i(27, 11),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 고갯길에서 솔숲 쪽으로 빠지는 샛길. 다람쥐가 말하던 그 자리가
		# 이 안쪽 끝에 있다 — 마을에 두면 두 걸음이라 걷는 맛이 없었다.
		{"tile": Vector2i(20, 8),
			"scene": "res://scenes/journey/interiors/SidePathInterior.tscn",
			"label": "솔숲 사이로", "enter_key": "샛길입구"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 스웨터 차림. 고개 중턱 쉼터를 지킨다.
	put_folk(Vector2i(25, 13), "capybara-c", "고개 쉼터 아저씨", "cap_sol", [
		["여기까지 올라오면 다리가 좀 뻐근하지."],
		["앉았다 가요.", "고개는 도망 안 가."],
		["서두르는 사람은 여기서 다 놓쳐요.", "천천히 봐야 보이는 게 있거든."],
		["솔향 맡으면서 쉬었다 가요."],
		["고개는 어디 안 가요. 또 와요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 정상 전망대, 먼 곳을 본다.
	put_folk(Vector2i(18, 4), "seagull", "고갯마루의 갈매기", "so_gull", [
		["여기서 보면 다 작아 보여요."],
		["고갯마루까지 가 봤어요?", "여기가 딱 거기예요."],
		["오늘은 멀리까지 다 보이네요."],
		["같이 좀 앉아 있을래요?"],
		["고갯마루에서 또 봐요."],
	], Vector2.DOWN, false, {
		# 아침엔 전망대, 낮엔 쉼터 마당, 저녁엔 아랫길 — 고개를 오르내린다.
		"아침": Vector2i(18, 4),
		"낮": Vector2i(23, 10),
		"저녁": Vector2i(27, 18),
	})

	# 다람쥐 — 선택형 서브 NPC. 솔숲 사이, 붙박이.
	put_folk(Vector2i(15, 6), "squirrel", "솔숲의 다람쥐", "so_squirrel", [
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
