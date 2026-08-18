extends Place
## 🌼 꽃눈벌. 2탄 다섯째 — 담수 3부작·솔은재 다음, 처음으로 **밭**을
## 마을 골격으로 쓴다. 굽이도는 길 하나가 아니라, 밭 아홉 뙈기를
## 길 넷이 井자로 가르는 조각보 지형이다. 가운데 가로길엔 얕은
## 물도랑이 지난다.

func place_name() -> String:
	return "꽃눈벌"


func _init() -> void:
	legend = {
		"f": "tilled-soil",   # 밭 뙈기
		"d": "dirt",          # 井자 길
		"g": "grass",         # 길 모서리
		"w": "water",         # 가로길을 가로지르는 얕은 도랑
	}


## 38x20. 세로길 둘(x12-13, x25-26)과 가로길 둘(y8-9, y14-15)이
## 井자로 밭 아홉 뙈기를 가른다. 가로길 위쪽(y8)엔 도랑이 지난다.
func ground_map() -> String:
	return """
ggggggggggggddgggggggggggddggggggggggg
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
ddddddddddddddwwwwwwwwwwwddddddddddddd
dddddddddddddddddddddddddddddddddddddd
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
dddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddd
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
gfffffffffffddfffffffffffddfffffffffff
"""


## 井자가 골격이니 **소품도 井자를 따라 놓는다.** 뙈기 아홉의 한가운데는
## 비워 둔다 — 거기 심은 것은 작물이지 장식이 아니다. 사람이 만든 것
## (좌판·울타리·가로등·평상)은 길가에 줄을 맞추고, 나무와 덤불은 밭두렁
## 을 따라 어긋나게 선다. 그래야 격자가 보인다.
func props() -> Array:
	return [
		# ── 사거리 쉼터: 가게·쿼스텔과 그 발치 ───────────────────────
		# 건물은 발치에 잔 것들을 두어야 세상에 붙어 선다.
		[18, 9, "shop", true],
		[30, 9, "guesthouse", true],
		[16, 10, "flower-pots", false],
		[22, 10, "jars", false],
		[29, 10, "flower-pots", false],
		[33, 10, "bench", true],
		[35, 9, "firewood", true],
		[26, 8, "street-lamp", true],
		# ── 서쪽 한길 어귀: 표지판·우체통·좌판이 한 줄로 ─────────────
		# 사람이 만든 것은 줄을 맞춘다. 밑동이 모두 y=9 한 줄에 선다.
		[1, 9, "signpost", false],
		[2, 9, "mailbox", true],
		[5, 9, "stall", true],
		[8, 9, "stall", true],
		[11, 9, "bench", true],
		[12, 8, "street-lamp", true],
		# ── 도랑: 가게에 가려지지 않는 양 끝에만 ────────────────────
		# 물에 어울리는 것만 물 위에 둔다. 사진 자리(20,8)는 비워 둔다.
		[14, 8, "beach-grass", false],
		[15, 8, "pebbles", false],
		[21, 8, "beach-grass", false],
		[22, 8, "beach-grass", false],
		[24, 8, "boulder", true],
		# ── 북서 밭머리: 갈매기의 꽃눈나무 ──────────────────────────
		# 갈매기(6,2)가 나무 두 그루 사이에 서서 그늘에 든다.
		[2, 2, "tree", true],
		[6, 1, "tree", true],
		[4, 4, "shrub", false],
		[9, 3, "shrub", false],
		# ── 가게 뒤란 ───────────────────────────────────────────────
		[15, 4, "jars", false],
		[17, 3, "firewood", true],
		[19, 4, "tools", false],
		# ── 북동 밭머리 ─────────────────────────────────────────────
		[28, 2, "shrub", false],
		[31, 1, "tree", true],
		[35, 2, "tree", true],
		# ── 세로길 밭두렁 나무: 좌우를 번갈아 어긋나게 ──────────────
		[11, 6, "tree", true],
		[14, 12, "tree", true],
		[10, 17, "tree", true],
		[27, 12, "tree", true],
		[24, 17, "tree", true],
		# ── 아랫길: 울타리 셋씩 두 줄, 갈림목에 등 하나 ─────────────
		[4, 14, "fence", false],
		[6, 14, "fence", false],
		[8, 14, "fence", false],
		[26, 14, "street-lamp", true],
		[31, 14, "fence", false],
		[33, 14, "fence", false],
		[35, 14, "fence", false],
		# ── 남쪽 밭머리 (까치 곁) ───────────────────────────────────
		[3, 18, "tree", true],
		[17, 17, "pebbles", false],
		[19, 18, "shrub", false],
		[35, 17, "tree", true],
		# ── 샛길 어귀: 덤불 둘이 문(10,12)을 벌려 준다 ──────────────
		[9, 11, "shrub", false],
		[11, 12, "shrub", false],
		# ── 서쪽 밭 일자리 ──────────────────────────────────────────
		[3, 11, "jars", false],
		[5, 12, "tools", false],
		[4, 13, "pebbles", false],
	]


func pickups() -> Array:
	# **소품·인연과 같은 칸에 놓지 않는다.** 줍는 거리가 12px 라 한 칸
	# 옆에 서서는 안 닿는다 — 막힌 칸에 놓으면 영영 못 줍는다. 인연은
	# 제 칸과 아랫칸을 둘 다 막는다는 것도 같이 본다.
	# 다섯 개 중 넷이 지도 네 모서리에, 전부 같은 꽃이었다 — 줍기가
	# 구경이 아니라 심부름이 됐다. 井자 안쪽 뙈기로 모으고 종류를 섞는다.
	return [
		[6, 4, "p-flower"],        # 북서 — 갈매기 곁
		[33, 3, "p-acorn"],        # 북동 — 꽃눈나무 아래
		[17, 10, "p-pebble"],      # 도랑 남쪽 길가
		[28, 16, "p-flower"],      # 남동 밭
		[20, 10, "p-flower"],      # 도랑 사진 자리 곁
	]


func spawn_tile() -> Vector2i:
	return Vector2i(13, 19)


func sleep_tile() -> Vector2i:
	return Vector2i(30, 9)


func depart_tile() -> Vector2i:
	return Vector2i(13, 18)

func wanderer_tile() -> Vector2i:
	return Vector2i(22, 9)



## "밭 사이 도랑에 꽃잎 뜬 모습 사진 찍기" — 가운데 도랑 자리.
func quest_zones() -> Array:
	return [
		["꽃눈벌:도랑", Vector2i(20, 8), 48.0],
	]


func doors() -> Array:
	return [
		{"tile": Vector2i(18, 10),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 밭과 밭 사이로 난 두렁길. 본 지도가 곧은 井자라, 안쪽은
		# 일부러 어긋나게 났다.
		{"tile": Vector2i(10, 12),
			"scene": "res://scenes/journey/interiors/SidePathInterior.tscn",
			"label": "밭 사이로", "enter_key": "샛길입구"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 빵집 차림. 사거리 쉼터를 지킨다.
	put_folk(Vector2i(21, 9), "capybara-b", "밭머리 쉼터 아주머니", "cap_kkot", [
		["꽃눈 필 때가 젤 바빠요."],
		["밭이 아홉 뙈기예요.", "그래도 길 잃을 일은 없어요."],
		["도랑에 꽃잎 뜨는 거 봤어요?", "그거 보러 오는 사람도 있어요."],
		["밭 구경하다 가요."],
		["꽃눈 열릴 때쯤 또 와요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 밭머리 꽃눈나무 아래, 먼 곳을 본다.
	put_folk(Vector2i(6, 2), "seagull", "꽃눈나무의 갈매기", "kk_gull", [
		["여긴 물이 없는데도 자꾸 와요."],
		["밭 사이 도랑까지 가 봤어요?", "거기 꽃잎이 모여요."],
		["오늘은 바람이 꽃냄새를 실어 오네요."],
		["밭둑 따라 같이 걸을래요?"],
		["꽃눈 필 때 또 봐요."],
	], Vector2.DOWN, false, {
		# 아침엔 꽃눈나무, 낮엔 도랑가, 저녁엔 남쪽 밭머리.
		"아침": Vector2i(6, 2),
		"낮": Vector2i(15, 9),
		"저녁": Vector2i(22, 18),
	})

	# 까치 — 선택형 서브 NPC. "소식 전하는 새" 역할, 필수 아님.
	put_folk(Vector2i(20, 17), "magpie", "밭머리의 까치", "kk_magpie", [
		["…"],
		["큰 소식은 없어요.", "꽃눈이 하나 열렸을 뿐이에요."],
		["또 왔네요.", "그 나무, 아직 그대로예요."],
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
		"꽃눈 핀다길래 와 봤어요.",
	])


## 꽃밭 — 분홍기 도는 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(1.00, 0.97, 0.95)
