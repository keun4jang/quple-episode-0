extends Place
## 🏯 쿼주. 옛 도시.
##
## 낮은 기와지붕과 능. 쿼릉이 파랗고 열려 있으면 여기는 **돌바닥이고 낮다.**
## 바다가 없는 대신 하늘이 넓다.

func place_name() -> String:
	return "쿼주"


func _init() -> void:
	legend = {
		"c": "cobble",       # 옛 돌길
		"s": "stone-slab",   # 능 앞 박석
		"g": "grass",        # 잔디 무덤
		".": "dry-grass",
		"d": "dirt",
	}


func ground_map() -> String:
	return """
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
ggggggggggg......................gggggggggggg
ggggggggg....ssssssssssssssss....ggggggggggg
ggggggg......ssssssssssssssss......ggggggggg
ggggg........ssssssssssssssss........ggggggg
.............ssssssssssssssss.............gg
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
..........dddddddd..........................
ggggggggggddddddddgggggggggggggggggggggggggg
ggggggggggddddddddgggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# 능 언저리
		[8, 7, "tree", true],
		[34, 7, "tree", true],
		[20, 6, "boulder", true],
		[16, 8, "shrub", false],
		[27, 8, "shrub", false],

		# 돌길가 — 쿼체국과 빵집
		[7, 12, "guesthouse", true],
		[19, 11, "shop", true],
		[29, 12, "stall", true],
		[13, 13, "street-lamp", true],
		[35, 13, "mailbox", true],
		[24, 13, "bench", true],
		[33, 11, "jars", true],
		[3, 13, "flower-pots", true],

		# 아래 밭
		[12, 17, "home-garden", false],
		[15, 17, "home-garden", false],
		[38, 17, "pine", true],
		[5, 18, "pine", true],
	]


func pickups() -> Array:
	return [
		[22, 8, "p-acorn"],
		[10, 6, "p-pinecone"],
		[31, 7, "p-flower"],
		[26, 17, "p-pebble"],
		[6, 16, "p-acorn"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(21, 13)


func sleep_tile() -> Vector2i:
	return Vector2i(7, 13)


func depart_tile() -> Vector2i:
	return Vector2i(40, 12)


func wanderer_tile() -> Vector2i:
	return Vector2i(26, 12)


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	put_folk(Vector2i(19, 13), "seal", "쿼빵집 아주머니", "ju_seal", [
		["갓 구운 쿼빵 있어요.", "식기 전에 드세요."],
		["여긴 다들 천천히 걸어요.", "급할 게 없거든."],
		["저 능은 천 년쯤 됐대요.", "…라고들 하죠."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN)

	put_folk(Vector2i(31, 8), "seagull", "능 지키는 아이", "ju_kid", [
		["여기 앉아 있으면 바람 소리만 나요."],
		["아저씨는 어디서 왔어요?"],
		["나는 여기 말고 가 본 데가 없어요."],
		["언젠가 나도 걸어서 나가 볼래요."],
		["잘 가요. 다음에 또 얘기해요."],
	], Vector2.LEFT)

	_put_raccoon()


## 여행자는 여기 있을 수도, 없을 수도 있다.
func _put_raccoon() -> void:
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["여기 빵이 맛있대서 왔어요."],
		["돌바닥이 발에 좀 배기네요.", "그래도 좋다."],
		["같이 능 한 바퀴 돌래요?"],
		["그럼 또 어디선가."],
	], [
		"어? 너 여기 웬일이야?",
		"…아니 진짜로 또 만났네요.",
		"나 여기 어제 왔는데.",
		"우리 이쯤 되면 쿼플인가.",
	])
