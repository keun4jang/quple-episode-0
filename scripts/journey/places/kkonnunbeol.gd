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


func props() -> Array:
	return [
		# ── 가운데 사거리 쉼터 ────────────────────────────────────────
		[18, 9, "shop", true],
		[30, 9, "guesthouse", true],
		[1, 9, "signpost", false],
		[2, 9, "mailbox", true],
		# ── 밭 사이 꽃눈나무 줄(그냥 tree 재사용) ───────────────────
		[6, 2, "tree", true],
		[33, 2, "tree", true],
		[6, 17, "tree", true],
		[33, 17, "tree", true],
		[19, 2, "tree", true],
		[19, 17, "tree", true],
		# ── 밭 둘레 낮은 울타리 ──────────────────────────────────────
		[9, 5, "fence", false],
		[16, 5, "fence", false],
		[29, 5, "fence", false],
		[9, 12, "fence", false],
		[29, 12, "fence", false],
		[16, 12, "fence", false],
		# ── 도랑 곁 ────────────────────────────────────────────────
		[20, 9, "street-lamp", true],
	]


func pickups() -> Array:
	# **소품·인연과 같은 칸에 놓지 않는다.** 줍는 거리가 12px 라 한 칸
	# 옆에 서서는 안 닿는다 — 막힌 칸에 놓으면 영영 못 줍는다. 인연은
	# 제 칸과 아랫칸을 둘 다 막는다는 것도 같이 본다.
	return [
		[6, 4, "p-flower"],        # (6,3) 은 (6,2) 갈매기의 아랫칸이었다
		[33, 3, "p-flower"],
		[6, 18, "p-flower"],       # (6,17) 은 나무와 같은 칸이었다
		[33, 18, "p-flower"],      # (33,17) 도 마찬가지
		[20, 10, "p-flower"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(13, 19)


func sleep_tile() -> Vector2i:
	return Vector2i(30, 9)


func depart_tile() -> Vector2i:
	return Vector2i(13, 18)


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
	put_folk(Vector2i(18, 9), "capybara-b", "밭머리 쉼터 아주머니", "cap_kkot", [
		["꽃눈 필 때가 젤 바빠요."],
		["밭이 아홉 뙈기예요.", "그래도 길 잃을 일은 없어요."],
		["도랑에 꽃잎 뜨는 거 봤어요?", "그거 보러 오는 사람도 있어요."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN, false, {})

	# 갈매기 — 밭머리 꽃눈나무 아래, 먼 곳을 본다.
	put_folk(Vector2i(6, 2), "seagull", "꽃눈나무의 갈매기", "kk_gull", [
		["여긴 물이 없는데도 자꾸 와요."],
		["밭 사이 도랑까지 가 봤어요?", "거기 꽃잎이 모여요."],
		["오늘은 바람이 꽃냄새를 실어 오네요."],
		["같이 좀 걸어요."],
		["또 만나요."],
	], Vector2.DOWN, false, {})

	# 까치 — 선택형 서브 NPC. "소식 전하는 새" 역할, 필수 아님.
	put_folk(Vector2i(20, 17), "magpie", "밭머리의 까치", "kk_magpie", [
		["…"],
		["큰 소식은 없어요.", "꽃눈이 하나 열렸을 뿐이에요."],
		["또 왔네요.", "그 나무, 아직 그대로예요."],
	], Vector2.UP, false, {})
