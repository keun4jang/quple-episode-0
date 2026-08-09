extends Place
## 🌴 쿼도. 섬.
##
## 검은 돌담과 바람. 작고, 다 안다. 1탄의 마지막 여행지다.
## 여기서는 **길이 하나뿐**이라 헤맬 수가 없다 — 섬이니까.

func place_name() -> String:
	return "쿼도"


func _init() -> void:
	legend = {
		"w": "water",
		"s": "sand",
		"g": "grass",
		"d": "dirt",        # 붉은 흙길
		".": "dry-grass",
		"c": "basalt",      # 검은 현무암. 이 섬의 색이다
	}


func ground_map() -> String:
	return """
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwsssssssssssssssssssssssssssssssssssswwww
wwsssssssssssssssssssssssssssssssssssssssswww
ws..........................................
w..gggggggggggggggggggggggggggggggggggggg..w
w.ggggggggggggggggggggggggggggggggggggggg..w
w.gggggggggddddddddddddddddddgggggggggggg..w
w.gggggggggddddddddddddddddddgggggggggggg..w
w.gggggggggddddddddddddddddddgggggggggggg..w
w.gggggggggggggggggggggggggggggggggggggg...w
w..ccccccccccccccccccccccccccccccccccc....ww
w..ccccccccccccccccccccccccccccccccccc....ww
w...gggggggggggggggggggggggggggggggg.....www
ws.....................................swwww
wwsssssssssssssssssssssssssssssssssssswwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
"""


func props() -> Array:
	return [
		# 검은 돌담 대신 바위를 늘어놓는다
		[6, 6, "boulder", true],
		[12, 6, "boulder", true],
		[30, 6, "boulder", true],
		[36, 6, "boulder", true],
		[9, 10, "boulder", true],
		[33, 10, "boulder", true],

		# 마을은 흙길 가운데
		[14, 9, "guesthouse", true],
		[25, 9, "shop", true],
		[20, 11, "stall", true],
		[31, 12, "bench", true],
		[10, 12, "street-lamp", true],
		[37, 12, "mailbox", true],
		[17, 12, "flower-pots", true],
		[27, 7, "jars", true],

		# 바람 맞는 나무
		[5, 13, "pine", true],
		[38, 13, "pine", true],
		[22, 13, "shrub", false],
		[8, 3, "parasol", false],
		[34, 3, "beach-grass", false],
		[16, 3, "beach-grass", false],
	]


func pickups() -> Array:
	return [
		[11, 3, "p-shell"],
		[28, 3, "p-seaglass"],
		[19, 14, "p-shell"],
		[7, 9, "p-flower"],
		[35, 9, "p-pebble"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(20, 12)


func sleep_tile() -> Vector2i:
	return Vector2i(14, 10)


func depart_tile() -> Vector2i:
	return Vector2i(3, 12)


func wanderer_tile() -> Vector2i:
	return Vector2i(24, 12)


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	put_folk(Vector2i(25, 10), "seal", "쿼귤 파는 할머니", "do_seal", [
		["쿼귤 하나 먹어 봐.", "여기 건 달아."],
		["바람이 세지? 늘 이래."],
		["섬은 작아서 하루면 다 봐요.", "그래도 사흘은 있어야 알지."],
		["오늘은 바람이 덜하네."],
		["가는 배 시간 놓치지 말고."],
	], Vector2.DOWN)

	put_folk(Vector2i(9, 12), "seagull", "자전거 탄 아이", "do_kid", [
		["섬 한 바퀴 십오 분이에요!"],
		["돌담 사이로 가면 더 빨라요."],
		["나는 여기서 태어났어요."],
		["같이 한 바퀴 돌래요?"],
		["또 놀러 와요."],
	], Vector2.RIGHT)

	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["섬은 처음이에요."],
		["여기 바람 소리가 좋네요."],
		["같이 돌담길 걸을래요?"],
		["그럼 또 어디선가."],
	], [
		"섬까지 따라온 건 아니죠?",
	])
