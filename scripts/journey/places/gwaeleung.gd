extends Place
## 🌊 쿼릉. 첫 여행지.
##
## 바다와 등대와 백사장. `docs/world-quo.md` 4절 — 1탄의 첫 곳이다.
## 고향과 정반대로 만든다. 고향이 갈색이고 조용하면 여기는 **파랗고
## 열려 있다.** 첫 5분에 "떠나왔다"가 느껴져야 한다.
##
## 여기서 만나는 셋 중 **너구리는 여행자**다. 다음 여행지에서 다시 만난다 —
## 그 재회가 이 게임의 심장이다.

func place_name() -> String:
	return "쿼릉"


func _init() -> void:
	legend = {
		"w": "water",       # 바다
		"s": "sand",        # 백사장
		"c": "cobble",      # 마을길
		"d": "deck",        # 부두 판자
		"g": "grass",       # 언덕
		".": "dry-grass",   # 모래와 풀 사이
	}


## 위가 바다, 아래가 마을. 걸어 내려오면 마을, 올라가면 바다다.
func ground_map() -> String:
	return """
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwddddwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwddddwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwddddwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwddddwwwwwwwwwwwwwwwwwwwwww
ssssssssssssssssssddddssssssssssssssssssssss
ssssssssssssssssssssssssssssssssssssssssssss
ssssssssssssssssssssssssssssssssssssssssssss
ssssssssssssssssssssssssssssssssssssssssssss
............................................
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc
............................................
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# 바다 쪽 — 등대가 제일 멀리 보인다
		[36, 5, "lighthouse", true],
		[16, 6, "dock", false],      # 부두 옆에 널린 판자
		[23, 7, "dock", false],
		[16, 7, "buoy", false],
		[27, 8, "net", false],
		[30, 8, "icebox", false],
		[6, 7, "parasol", false],
		[9, 8, "beach-grass", false],
		[13, 8, "beach-grass", false],

		# 마을길 — 숙소와 가게
		[8, 13, "guesthouse", true],
		[22, 12, "shop", true],
		[30, 13, "stall", true],
		[16, 14, "street-lamp", true],
		[35, 14, "mailbox", true],
		[27, 14, "bench", true],
		[12, 14, "flower-pots", true],

		# 언덕 쪽
		[5, 18, "pine", true],
		[38, 18, "pine", true],
		[20, 18, "tree", true],
		[31, 19, "shrub", false],
		[10, 19, "boulder", true],
	]


func pickups() -> Array:
	return [
		[24, 8, "p-shell"],        # 백사장
		[33, 8, "p-shell"],
		[11, 7, "p-seaglass"],
		[19, 9, "p-pebble"],
		[6, 18, "p-pinecone"],     # 언덕
		[25, 19, "p-flower"],
	]


## 마을길 한가운데. 위로 가면 바다, 아래로 가면 언덕이다.
func spawn_tile() -> Vector2i:
	return Vector2i(20, 13)


## 쿼스텔 문 앞. 여기서 자면 다음 날이다.
func sleep_tile() -> Vector2i:
	return Vector2i(8, 14)


## 마을 끝 쿼스 정류장.
func depart_tile() -> Vector2i:
	return Vector2i(40, 13)


func wanderer_tile() -> Vector2i:
	# (28,13) 은 좌판(30,13) 콜라이더에 걸려 설 수 없는 칸이었다.
	# 말은 걸렸지만 너구리가 좌판을 뚫고 서 있었다.
	return Vector2i(26, 13)


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 붙박이 둘
	put_folk(Vector2i(22, 14), "seal", "가게 할머니", "seal", [
		["어서 와요. 처음 보는 얼굴이네.", "쿼이스크림 하나 들고 가."],
		["오늘은 바람이 좀 차지.", "감기 조심하고."],
		["자네 고향은 어디라 했지?", "…아, 산 쪽이랬나."],
		["이거 가져가. 값은 됐어.", "다음에 또 오면 되지."],
		["또 올 거지?", "…그럼 됐어."],
	], Vector2.DOWN)

	put_folk(Vector2i(19, 7), "seagull", "갈매기 소년", "seagull", [
		["아저씨 여기 사람 아니죠?", "걷는 게 딱 티나요."],
		["저 등대까지 가 봤어요?", "생각보다 안 멀어요."],
		["나는 여기서 나고 자랐는데,", "가끔 저 배가 어디 가나 궁금해요."],
		["오늘은 같이 좀 걸어요."],
		["언젠가 나도 나가 볼래요.", "그때 어디서 만나면 아는 척해요."],
	], Vector2.LEFT)

	# 여행자. 다음 여행지에서 다시 만난다 — 1탄의 심장
	# (`docs/world-quo.md` 4절)
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["나는 아무 계획 없이 다녀요.", "그게 편하더라고."],
		["여긴 이틀만 있다 갈 거예요.", "다음은 아직 안 정했고."],
		["같이 노을 보러 갈래요?"],
		["그럼 또 어디선가.", "…진짜로 또 만나겠죠?"],
	], [
		"바다가 좋아서 돌아왔어요.",
	])
