extends Place
## 💧 방울못. 2탄 "담수 3부작" 둘째. 굽이나루가 **흐르는 물**이라면
## 방울못은 **고여 있는 물**이다 — 중앙에 둥근 연못 하나, 그걸 두르는
## 나무데크 순환길. 작고 포근하게, 2탄의 속도를 여기서 한 번 낮춘다.


func place_name() -> String:
	return "방울못"


func _init() -> void:
	legend = {
		"w": "water",       # 연못
		"d": "deck",        # 데크 순환길
		"g": "grass",       # 둘레 풀밭
		"e": "clay-earth",  # 빵집·쉼터·정류장 마당 — 풀밭과 갈라지는 자리
	}


## 38x22. 가운데 둥근 연못을 데크가 한 바퀴 두른다.
func ground_map() -> String:
	return """
gggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggg
geeeeeeeeeeggggggggggggggggggggggggggg
geeeeeeeeeeggggggggggggggggggggggggggg
geeeeeeeeeeggggggggggggggggggggggggggg
geeeeeeeeeeggggggdddddgggggggggggggggg
geeeeeeeeeeggggdddwwwdddgggggggggggggg
gggggggggggggddwwwwwwwwwddgeeeeeeeeegg
ggggggggggggddwwwwwwwwwwwddeeeeeeeeegg
ggggggggggggdwwwwwwwwwwwwwdeeeeeeeeegg
gggggggggggddwwwwwwwwwwwwwddeeeeeeeegg
gggggggggggdwwwwwwwwwwwwwwwdeeeeeeeegg
gggggggggggddwwwwwwwwwwwwwddeeeeeeeegg
ggggggggggggdwwwwwwwwwwwwwdeeeeeeeeegg
geeeeeeeeeegddwwwwwwwwwwwddggggggggggg
geeeeeeeeeeggddwwwwwwwwwddgggggggggggg
geeeeeeeeeeggggdddwwwdddgggggggggggggg
geeeeeeeeeeggggggdddddgggggggggggggggg
geeeeeeeeeeggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# ── 빵집 (서쪽) ─────────────────────────────────────────────
		[6, 4, "shop", true],
		[6, 17, "guesthouse", true],
		[2, 4, "flower-pots", false],
		[2, 17, "jars", true],
		[9, 7, "bench", true],
		[9, 15, "bench", true],
		# ── 동쪽 ────────────────────────────────────────────────────
		[32, 10, "signpost", false],
		[31, 10, "mailbox", true],
		[28, 7, "street-lamp", true],
		[28, 15, "flower-pots", false],
		# ── 데크 곁 안내 ────────────────────────────────────────────
		[19, 3, "street-lamp", true],
	]


func pickups() -> Array:
	return [
		[16, 6, "p-flower"],       # 연못 데크 위
		[22, 16, "p-pebble"],
		[10, 10, "p-flower"],      # 서쪽 둘레
		[27, 12, "p-acorn"],       # 동쪽 둘레
		[13, 8, "p-pebble"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(9, 10)


func sleep_tile() -> Vector2i:
	return Vector2i(6, 17)


func depart_tile() -> Vector2i:
	return Vector2i(32, 10)


## "물방울 무늬가 남은 연못 사진 찍기" — 데크를 한 바퀴 돌면 남쪽
## 다리께에서 연못이 가장 잘 보인다.
func quest_zones() -> Array:
	return [
		["방울못:데크", Vector2i(19, 17), 56.0],
		# 데크를 한 바퀴 돌면 닿는 북쪽 끝. 남쪽과 정반대라
		# 여기까지 와야 연못을 다 돈 것이 된다.
		["방울못:물소리", Vector2i(19, 5), 48.0],
	]


func doors() -> Array:
	return [{
		"tile": Vector2i(6, 5),
		"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
		"label": "가게 들어가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 빵집 차림. 연못가 작은 빵집을 지킨다.
	put_folk(Vector2i(6, 4), "capybara-b", "연못가 빵집 아주머니", "cap_bangul", [
		["빵 냄새 맡고 왔어요?", "많이는 안 팔아요."],
		["비가 지난 뒤에도 냄새는 남아요.", "그게 좋아서 계속 굽어요."],
		["연못은 늘 저래요.", "잔잔했다 또 흔들렸다."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 연못 데크 높은 안내판 자리.
	put_folk(Vector2i(19, 3), "seagull", "안내판의 갈매기", "ba_gull", [
		["연못은 밤에 별을 담아요."],
		["데크를 한 바퀴 돌면 다 보여요.", "서두를 것 없어요."],
		["오늘은 물이 참 잔잔하네요."],
		["같이 한 바퀴 돌래요?"],
		["또 만나요."],
	], Vector2.DOWN, false, {})

	# 개구리 — 선택형 서브 NPC. 남쪽 물가, 붙박이.
	put_folk(Vector2i(19, 19), "frog", "물가의 개구리", "ba_frog", [
		["…"],
		["말이 적어도 연못은 알아듣는 것 같아요."],
		["오늘도 여기 있었어요.", "연못은 늘 알아채더라고요."],
	], Vector2.UP, false, {})
