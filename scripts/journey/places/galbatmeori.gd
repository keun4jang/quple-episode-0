extends Place
## 🌾 갈밭머리. 2탄 "담수 3부작" 셋째. 강도 연못도 아니다 — **갈대
## 사이를 걷는 마을**이다. 길이 높낮이가 아니라 시야의 틈으로 나뉜다.
## 나무데크가 갈대밭을 가로지르고, 얕은 물길 둘이 남북에 있다.


func place_name() -> String:
	return "갈밭머리"


func _init() -> void:
	legend = {
		"w": "water",       # 얕은 물길
		"d": "deck",        # 나무데크
		"g": "grass",       # 빈터(가게·전망대 둘레)
		".": "dry-grass",   # 갈대. 걸어 지나갈 수 있다 — 막힌 미로가 아니다
	}


## 42x22. 가운데를 데크가 가로지르고(가로 y11, 세로 x20), 남북에
## 얕은 물길이 있다. 서쪽 빈터가 도착 자리, 동쪽 빈터가 카피바라 쉼터,
## 남쪽 빈터가 갈대 전망대다.
func ground_map() -> String:
	return """
..........................................
....g...............................g.....
..gggggwwwww......................ggggg...
..gggggwwwww......................ggggg...
.gggggggwwww........d............ggggggg..
..ggggg.............d.............ggggg...
..ggggg.............d.............ggggg...
....g...............d...............g.....
....................d.....................
..g.................d.....................
.ggg................d.....................
gggggddddddddddddddddddddddddddddddddddd..
.ggg................d.....................
..g.................d.....................
....................d.....................
....................g.....................
..................ggggg...................
..................ggggg.....wwwwww........
.................ggggggg....wwwwww........
..................ggggg.....wwwwww........
..................ggggg...................
....................g.....................
"""


func props() -> Array:
	return [
		# ── 서쪽 도착 빈터 ──────────────────────────────────────────
		[4, 2, "shrub", false],
		[4, 6, "shrub", false],
		[2, 11, "signpost", false],
		[3, 11, "mailbox", true],
		# ── 동쪽 카피바라 쉼터 ──────────────────────────────────────
		[36, 4, "shop", true],
		[38, 11, "guesthouse", true],
		[35, 3, "flower-pots", false],
		[38, 4, "fence", true],
		# ── 남쪽 전망대 ────────────────────────────────────────────
		[20, 16, "bench", true],
		[20, 20, "boulder", true],
		[24, 18, "beach-grass", false],
		[16, 18, "beach-grass", false],
		# ── 데크 곁 ────────────────────────────────────────────────
		[20, 4, "street-lamp", true],
	]


func pickups() -> Array:
	return [
		[6, 11, "p-flower"],
		[20, 8, "p-pebble"],
		[20, 14, "p-pebble"],
		[24, 2, "p-feather"],
		[16, 3, "p-feather"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(4, 4)


func sleep_tile() -> Vector2i:
	return Vector2i(38, 11)


func depart_tile() -> Vector2i:
	return Vector2i(2, 11)

func wanderer_tile() -> Vector2i:
	return Vector2i(8, 8)



## "갈대 사이로 보이는 하늘 사진 찍기" — 남쪽 전망대에서.
func quest_zones() -> Array:
	return [
		["갈밭머리:전망대", Vector2i(20, 18), 56.0],
		# 데크에서 벗어나 갈대 속으로 몇 걸음 들어가야 나오는 빈자리.
		# 이 마을은 길이 높낮이가 아니라 시야의 틈으로 나뉜다.
		["갈밭머리:빈자리", Vector2i(30, 7), 48.0],
	]


func doors() -> Array:
	return [{
		"tile": Vector2i(36, 5),
		"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
		"label": "가게 들어가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 스웨터 차림. 갈대밭 가장자리 쉼터를 지킨다.
	put_folk(Vector2i(36, 4), "capybara-c", "갈대밭 쉼터 할머니", "cap_galbat", [
		["바람이 세게 부는 날에도 여긴 이래요."],
		["말은 천천히 해도 돼요.", "여긴 서두를 데가 없어요."],
		["따뜻한 자리 하나는 늘 남겨 둬요."],
		["바람 소리 듣고 가요."],
		["갈대는 늘 여기 있어요. 또 와요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 갈대 전망대 근처, 높은 곳에서 하늘을 본다.
	put_folk(Vector2i(20, 4), "seagull", "전망대의 갈매기", "ga_gull", [
		["갈대 사이로 보면 하늘이 조각나 보여요."],
		["전망대까지 가 봤어요?", "남쪽으로 쭉 가면 나와요."],
		["오늘은 바람이 잔잔하네요."],
		["갈대 사이로 같이 걸을래요?"],
		["바람 불면 또 봐요."],
	], Vector2.DOWN, false, {})

	# 고라니 — 선택형 서브 NPC. 갈대 사이에 조용히 서 있는 붙박이.
	put_folk(Vector2i(24, 18), "deer", "갈대 사이의 고라니", "ga_deer", [
		["…"],
		["가까이 오라고 하지도, 도망가지도 않는다."],
		["또 왔구나.", "그래도 자리는 그대로다."],
	], Vector2.LEFT, false, {})

	# 여행자. 다른 마을에서 만났던 그 너구리를 여기서 다시 만난다 —
	# 재회는 1탄에서 끝나지 않는다 (`JourneyState.WANDERER_STOPS`).
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["나는 아무 계획 없이 다녀요.", "그게 편하더라고."],
		["여긴 이틀만 있다 갈 거예요.", "다음은 아직 안 정했고."],
		["같이 노을 보러 갈래요?"],
		["그럼 또 어디선가.", "…진짜로 또 만나겠죠?"],
	], [
		"갈대 소리가 좋아서 왔어요.",
	])
