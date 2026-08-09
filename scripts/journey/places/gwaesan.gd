extends Place
## ⚓ 쿼산. 비탈진 항구.
##
## 바다는 쿼릉과 같지만 **가파르고 좁다.** 쿼릉이 넓게 열려 있다면
## 여기는 골목이 층층이 겹친다. 같은 바다도 마을에 따라 다르다.

func place_name() -> String:
	return "쿼산"


func _init() -> void:
	legend = {
		"w": "water",
		"d": "deck",         # 부두
		"c": "cobble",       # 비탈 골목
		"s": "stone-slab",   # 계단참
		"g": "grass",
		".": "dry-grass",
	}


func ground_map() -> String:
	return """
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
ddddddddddddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddd
ssssssssssssssssssssssssssssssssssssssssssss
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
ssssssssssssssssssssssssssssssssssssssssssss
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
ssssssssssssssssssssssssssssssssssssssssssss
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
............................................
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# 부두
		[6, 4, "buoy", false],
		[13, 4, "net", false],
		[19, 4, "icebox", false],
		[26, 4, "net", false],
		[33, 4, "buoy", false],
		[38, 3, "lighthouse", true],

		# 층층이 겹친 골목
		[8, 7, "shop", true],
		[24, 7, "guesthouse", true],
		[15, 10, "stall", true],
		[31, 10, "shop", true],
		[5, 13, "guesthouse", true],
		[36, 13, "stall", true],
		[20, 9, "street-lamp", true],
		[12, 12, "street-lamp", true],
		[28, 13, "bench", true],
		[3, 10, "jars", true],
		[40, 9, "mailbox", true],
		[17, 13, "flower-pots", true],

		[7, 16, "pine", true],
		[34, 16, "tree", true],
		[22, 17, "boulder", true],
	]


func pickups() -> Array:
	return [
		[10, 4, "p-shell"],
		[29, 4, "p-seaglass"],
		[21, 12, "p-pebble"],
		[38, 16, "p-pinecone"],
		[14, 16, "p-flower"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(20, 12)


func sleep_tile() -> Vector2i:
	return Vector2i(24, 8)


func depart_tile() -> Vector2i:
	return Vector2i(2, 13)


func wanderer_tile() -> Vector2i:
	return Vector2i(26, 12)


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	put_folk(Vector2i(15, 11), "seal", "쿼면집 아저씨", "san_seal", [
		["앉아요. 국물부터 한 술 떠 봐."],
		["이 동네는 계단이 많아서.", "다리 아프지."],
		["나도 젊을 땐 배를 탔어요."],
		["오늘은 국물 더 줄게."],
		["또 와요. 알아볼 테니."],
	], Vector2.DOWN)

	put_folk(Vector2i(31, 5), "seagull", "부두 청년", "san_gull", [
		["배 들어오는 거 보러 왔어요?"],
		["저기 등대까지 자전거로 십 분."],
		["여기 노을은 계단에서 봐야 해요."],
		["같이 올라가 볼래요?"],
		["조심히 가요."],
	], Vector2.LEFT)

	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["계단이 많아서 다리가 아파요."],
		["여기 국수 먹어 봤어요?"],
		["같이 노을 볼래요?"],
		["그럼 또 어디선가."],
	], [
		"나 계단 오르다 죽는 줄 알았어요.",
	])
