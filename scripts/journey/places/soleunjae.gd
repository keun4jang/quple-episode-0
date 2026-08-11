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


func props() -> Array:
	return [
		# ── 중턱 쉼터 ─────────────────────────────────────────────────
		[27, 10, "shop", true],
		[30, 10, "guesthouse", true],
		[24, 11, "bench", true],
		[21, 10, "street-lamp", true],
		[29, 12, "jars", true],
		[21, 12, "flower-pots", false],
		# ── 정상 전망대 ──────────────────────────────────────────────
		[19, 3, "boulder", true],
		[21, 2, "boulder", true],
		[18, 4, "bench", true],
		# ── 고갯길 곁 소나무 (숲 가장자리) ──────────────────────────
		[12, 1, "pine", true],
		[28, 1, "tree", true],
		[10, 6, "pine", true],
		[33, 6, "tree", true],
		[8, 9, "pine", true],
		[35, 9, "pine", true],
		[9, 13, "tree", true],
		[34, 13, "pine", true],
		[10, 17, "pine", true],
		[31, 17, "tree", true],
		[13, 20, "pine", true],
		[27, 20, "pine", true],
		[15, 6, "shrub", false],
		[12, 12, "shrub", false],
		# ── 고개 어귀 ────────────────────────────────────────────────
		[23, 21, "signpost", false],
		[27, 21, "mailbox", true],
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


## "고갯마루 전망 바위까지 가 보기" — 정상 전망대.
func quest_zones() -> Array:
	return [["솔은재:전망", Vector2i(20, 2), 56.0]]


func doors() -> Array:
	return [{
		"tile": Vector2i(27, 11),
		"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
		"label": "가게 들어가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 스웨터 차림. 고개 중턱 쉼터를 지킨다.
	put_folk(Vector2i(27, 10), "capybara-c", "고개 쉼터 아저씨", "cap_sol", [
		["여기까지 올라오면 다리가 좀 뻐근하지."],
		["앉았다 가요.", "고개는 도망 안 가."],
		["서두르는 사람은 여기서 다 놓쳐요.", "천천히 봐야 보이는 게 있거든."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 정상 전망대, 먼 곳을 본다.
	put_folk(Vector2i(19, 3), "seagull", "전망대의 갈매기", "so_gull", [
		["여기서 보면 다 작아 보여요."],
		["고갯마루까지 가 봤어요?", "여기가 딱 거기예요."],
		["오늘은 멀리까지 다 보이네요."],
		["같이 좀 앉아 있을래요?"],
		["또 만나요."],
	], Vector2.DOWN, false, {})

	# 다람쥐 — 선택형 서브 NPC. 솔숲 사이, 붙박이.
	put_folk(Vector2i(15, 6), "squirrel", "솔숲의 다람쥐", "so_squirrel", [
		["…"],
		["모아 두는 건 서두르는 게 아니라,", "내일의 나를 챙기는 일이에요."],
		["또 왔어요?", "묻어 둔 솔방울은 아직 거기 있어요."],
	], Vector2.DOWN, false, {})
