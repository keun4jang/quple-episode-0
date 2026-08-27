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
		# ── 빵집 앞 꽃마당 (장면) — 좌판·화분·장독이 마당을 만든다
		[10, 8, "stall", true],
		[4, 8, "flower-pots", false],
		[10, 4, "jars", true],
		# ── 남쪽 물소리 데크 곁 쉼터
		[16, 19, "bench", true],
		[22, 18, "beach-grass", false],
		[9, 15, "bench", true],
		# ── 동쪽 ────────────────────────────────────────────────────
		[32, 10, "signpost", false],
		[31, 10, "mailbox", true],
		[28, 7, "street-lamp", true],
		[28, 15, "flower-pots", false],
		# ── 데크 곁 안내 ────────────────────────────────────────────
		[19, 3, "street-lamp", true],
		# ── 연밭 그늘로 슬쩍 들어가는 자리 ───────────────────────────
		[5, 20, "shrub", false],
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

func wanderer_tile() -> Vector2i:
	return Vector2i(24, 4)



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
	}, {
		# 게스트하우스 뒤 풀숲 사이로 슬쩍 들어가는 자리. 문이 아니라
		# "들어가는 자리" 라 `enter_key` 를 따로 준다.
		"tile": Vector2i(4, 20),
		"scene": "res://scenes/journey/interiors/ShadeSpot.tscn",
		"label": "연밭 그늘로 들어가기", "enter_key": "연밭그늘",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 빵집 차림. 연못가 작은 빵집을 지킨다.
	put_folk(Vector2i(8, 4), "capybara-b", "연못가 빵집 아주머니", "cap_bangul", [
		["빵 냄새 맡고 왔어요?", "많이는 안 팔아요."],
		["비가 지난 뒤에도 냄새는 남아요.", "그게 좋아서 계속 굽어요."],
		["연못은 늘 저래요.", "잔잔했다 또 흔들렸다."],
		["연못 한 바퀴 돌고 가요."],
		["빵 냄새 나면 또 들러요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 연못 데크 높은 안내판 자리.
	put_folk(Vector2i(16, 3), "seagull", "안내판의 갈매기", "ba_gull", [
		["연못은 밤에 별을 담아요."],
		["데크를 한 바퀴 돌면 다 보여요.", "서두를 것 없어요."],
		["오늘은 물이 참 잔잔하네요."],
		["물소리 들으면서 한 바퀴 어때요?"],
		["연못에 별 뜨면 생각날 거예요."],
	], Vector2.DOWN, false, {
		# 아침엔 안내판 곁, 낮엔 동쪽 마당, 저녁엔 남쪽 데크 —
		# 연못을 하루에 걸쳐 반 바퀴 돈다.
		"아침": Vector2i(16, 3),
		"낮": Vector2i(28, 8),
		"저녁": Vector2i(17, 16),
	})

	# 개구리 — 선택형 서브 NPC. 남쪽 물가, 붙박이.
	put_folk(Vector2i(19, 19), "frog", "물가의 개구리", "ba_frog", [
		["…"],
		["말이 적어도 연못은 알아듣는 것 같아요."],
		["오늘도 여기 있었어요.", "연못은 늘 알아채더라고요."],
	], Vector2.UP, false, {})

	# 여행자. 다른 마을에서 만났던 그 너구리를 여기서 다시 만난다 —
	# 재회는 1탄에서 끝나지 않는다 (`JourneyState.WANDERER_STOPS`).
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["나는 아무 계획 없이 다녀요.", "그게 편하더라고."],
		["여긴 이틀만 있다 갈 거예요.", "다음은 아직 안 정했고."],
		["같이 노을 보러 갈래요?"],
		["그럼 또 어디선가.", "…진짜로 또 만나겠죠?"],
	], [
		"연못이 조용해서 하루 더 있었어요.",
	])


## 못가 — 물기 어린 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(0.96, 1.00, 0.98)
