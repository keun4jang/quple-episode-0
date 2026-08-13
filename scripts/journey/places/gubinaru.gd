extends Place
## 🌊 굽이나루. 2탄 "담수 3부작"의 첫 곳 — `docs/quest-journey.md`,
## `docs/planning/content_brainstorm_plan.md` 참고.
##
## 1탄 넷을 다 둘러봐야 열린다(`Quests.ORDER`). 바다도 항구도 아니다 —
## **강이 굽어 도는 나루**다. 여기서 카피바라(물범의 담수 버전)를
## 처음 만난다.


func place_name() -> String:
	return "굽이나루"


func _init() -> void:
	legend = {
		"w": "water",       # 강
		"s": "sand",        # 모래톱·강가
		"g": "grass",       # 둔치
		"d": "deck",        # 나루 판자
		"e": "clay-earth",  # 나루 마당 — 오가는 발길에 다져진 흙바닥
	}


## 42x22. 강이 위에서 아래로 완만히 굽이돈다. 오른쪽(동안)에 나루가
## 있고, 강 한복판에 모래톱이 있다.
func ground_map() -> String:
	return """
gggggggggggggggggswwwwwwwsgggggggggggggggg
ggggggggggggggggggswwwwwwwsggggggggggggggg
gggggggggggggggggggswwwwwwwsgggggggggggggg
ggggggggggggggggggggswwwwwwwsggggggggggggg
ggggggggggggggggggggggswwwwwwwsggggggggggg
gggggggggggggggggggggggswwwwwwwsgggggggggg
ggggggggggggggggggggggggswwwwwwwsggggggggg
gggggggggggggggggggggggggswwwwwwwsgggggggg
gggggggggggggggggggggggggswwwwwwwsgggggggg
ggggggggggggggggggggggggggswwssswwsggggggg
ggggggggggggggggggggggggggswwssswwsggggggg
ggggggggggggggggggggggggggswwssswwsggggggg
ggggggggggggggggggggggggggswwssswwsgeeeeee
ggggggggggggggggggggggggggswwwwwwwddddeeee
ggggggggggggggggggggggggggswwwwwwwddddeeee
gggggggggggggggggggggggggswwwwwwwddddeeeee
gggggggggggggggggggggggggswwwwwwwddddeeeee
ggggggggggggggggggggggggswwwwwwwsgggeeeeee
gggggggggggggggggggggggswwwwwwwsggggeeeeee
ggggggggggggggggggggggswwwwwwwsgggggeeeeee
gggggggggggggggggggggswwwwwwwsgggggggggggg
gggggggggggggggggggswwwwwwwsgggggggggggggg
"""


func props() -> Array:
	return [
		# ── 나루 (동안) ──────────────────────────────────────────────
		[39, 14, "shop", true],          # 카피바라 가게
		[39, 17, "guesthouse", true],    # 쉼터
		[40, 15, "signpost", false],
		[38, 16, "mailbox", true],
		[36, 3, "street-lamp", true],
		# ── 강가 소품 (서안) ─────────────────────────────────────────
		[9, 9, "boulder", true],
		[7, 5, "pine", true],
		[3, 12, "tree", true],
		[20, 8, "reception", true],      # 그물 손질하는 좌판 자리(임시로 재사용)
		[15, 5, "net", false],
		[15, 3, "shrub", false],
		[13, 16, "shrub", false],
		[5, 18, "pine", true],
	]


func pickups() -> Array:
	return [
		[29, 10, "p-pebble"],      # 모래톱
		[30, 11, "p-pebble"],
		[8, 9, "p-flower"],
		[10, 6, "p-acorn"],
		# (35,4) 는 영영 못 줍는 자리였다 — 바로 위 (35,3) 에 선 갈매기가
		# 제 칸과 **아랫칸까지** 막는다(`Place._block_folk_tiles`). 줍는
		# 거리가 12px 라 한 칸(16px) 옆에 서서는 안 닿는다. 그래서 이 마을은
		# 다섯 개를 다 못 주웠고, "떨어진 것 다 줍기" 가 안 끝나
		# **방울못부터 그 뒤 2탄 전체가 안 열렸다.** 한 칸 아래로 내린다.
		[35, 5, "p-feather"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(10, 10)


func sleep_tile() -> Vector2i:
	return Vector2i(39, 17)


func depart_tile() -> Vector2i:
	return Vector2i(40, 15)


## "강 굽이가 보이는 데크까지 가 보기" — 나루 데크 자체가 방문 지점이다.
func quest_zones() -> Array:
	return [["굽이나루:데크", Vector2i(36, 14), 56.0]]


func doors() -> Array:
	return [{
		"tile": Vector2i(39, 15),
		"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
		"label": "가게 들어가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 물범의 담수 버전. 조끼 차림, 나루 옆 가게를 지킨다.
	put_folk(Vector2i(39, 14), "capybara-a", "나루 가게 아저씨", "cap_guinaru", [
		["어서 와요. 강 여행은 또 다르지."],
		["강물이 굽어 도는 자리가 여기예요.", "서두를 것 없어요."],
		["길 묻는 손님한테도 늘 이렇게 말해요.", "천천히 가요."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN, false, {}, "")

	# 갈매기 — 1탄과 같은 역할(높은 곳, 먼 곳을 동경). 여기선 강 굽이를 본다.
	put_folk(Vector2i(35, 3), "seagull", "둔치의 갈매기", "gu_gull", [
		["강도 바다처럼 넓어질 수 있대요."],
		["저 굽이까지 가 봤어요?", "데크에서 보면 더 잘 보여요."],
		["여긴 물살이 안 급해서 좋아요."],
		["오늘은 같이 좀 걸어요."],
		["또 만나요."],
	], Vector2.DOWN, false, {})

	# 수달 — 선택형 서브 NPC. 필수 퀘스트에 안 넣는다(강가 돌 위, 붙박이).
	put_folk(Vector2i(30, 9), "otter", "돌 위의 수달", "gu_otter", [
		["매끈한 돌 하나를 오래 들여다보고 있었어요."],
		["좋은 돌은 멀리 안 가도 물이 다듬어 줘요."],
		["또 왔네요.", "그 돌, 그대로 있어요."],
	], Vector2.DOWN, false, {})
