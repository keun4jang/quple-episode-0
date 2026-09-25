extends Place
## 볕뉘. 옛 도시.
##
## 낮은 기와지붕과 능. 윤슬이 파랗고 열려 있으면 여기는 **돌바닥이고 낮다.**
## 바다가 없는 대신 하늘이 넓다.
##
## 한때 44칸이었다. 폰으로 걸어 보니 넓기만 하고 **허전했다** — 걸어도
## 걸어도 빈 바닥이라 마을이 아니라 벌판이었다. 35칸으로 좁히고 그만큼
## 소품을 채웠다. 3배 줌에서 지도 밖이 드러나지 않는 한계가 34칸이라
## 그 바로 위에 세웠다.
##
## 바닥도 가로 띠로 층층이 갈라져 있었다. 모래·돌·풀이 곧은 줄로
## 지도를 가로지르면 마을이 아니라 줄무늬로 보인다. 이제 능 앞 박석은
## 둥글게 퍼지고, 돌길 가장자리는 풀이 삐져나와 들쭉날쭉하고,
## 아랫마당의 흙과 박석마당은 덩어리로 앉아 있다.

func place_name() -> String:
	return "볕뉘"


func _init() -> void:
	legend = {
		"c": "slate-path",     # 옛 돌길
		"s": "stone-slab",     # 능 앞 박석
		"t": "granite-step",   # 능으로 오르는 섬돌
		"b": "cobble",         # 아랫마당 박석
		"g": "grass",          # 잔디 무덤
		".": "dry-grass",
		"d": "dirt",
	}


## 35 x 21.
##
## 가운데 위가 능이다. 잔디 언덕에 박석이 둥글게 깔리고, 돌길에서
## 섬돌 넉 장(t)이 그리로 오른다. 돌길은 가로로 지나가되 **가장자리가
## 곧지 않다** — 풀이 길로 삐져나오고 흙이 만처럼 파고든다.
## 아래는 흙마당과 박석마당 두 덩어리.
func ground_map() -> String:
	return """
......ggggggggggggggggggggggggggggggggg..............
......ggggggggggggggggggggggggggggggggg..............
.....ggggggggggggggggggggggggggggggggggggggg.........
...gggggg......gggggggggggggggggggggggggggggggg......
...gggggg......gggggggggggggggggggggggggggggggg......
gg...ggg.........gggggggggggggggggggggggggggg........
ggg.........gggggggggggggggggggggggggggggg.........gg
ggg.........gggggggggggggggggggggggggggggg.........gg
ggggg......gggggggggggggssssssggggggggggg.......ggggg
ggg......ggggggggggggssssssssssssggggggggggg.........
ggg......ggggggggggggssssssssssssggggggggggg.........
........ggggggggggssssssssssssssssssgggggg...........
...ccccc......ggggggsssssssssssssssggg...cccc........
...ccccc......ggggggsssssssssssssssggg...cccc........
...cccccccccccccc.ggggg.tttttt...cccccccccccccc......
ccccccccccccccccccgggcccccccccccccccccccccccccccddddd
ccccccccccccccccccgggcccccccccccccccccccccccccccddddd
cccccccccccccccccccccccccccccccccccccccccccccccdddddd
ccccccccccccdddddccccgggggccccccccccccccccccccccddddd
ccccccccccccdddddccccgggggccccccccccccccccccccccddddd
ccccccccccc.dddddddddggggggccccccccccccccbbbbbb......
........gddddddddddddddgggggggggbbbbbbbbbbbbbbb......
........gddddddddddddddgggggggggbbbbbbbbbbbbbbb......
......ggdddddddddddddgggggggggbbbbbbbbbbbbbbg........
gg......gdddddddddddggggggggggggbbbbbbbbbbgg.......gg
gg......gdddddddddddggggggggggggbbbbbbbbbbgg.......gg
.....ggggggdddddddgggggggggggggggbbbbbbbbgggg........
ggg........gdddddggggggggggggggggggbbbbggg........ggg
ggg........gdddddggggggggggggggggggbbbbggg........ggg
.........gggggggggggg........gggggggggggg............
......gggggggggggg........gggggggggggg.........gggggg
......gggggggggggg........gggggggggggg.........gggggg
"""


## 덩어리로 놓는다. 하나씩 흩뿌리면 채워도 여전히 허전하다 —
## 소나무 셋이 모여 숲 가장자리가 되고, 항아리 넷이 모여 장독대가 된다.
##
## 막는 소품의 콜라이더는 가로로 그림 폭의 70% 만큼 퍼진다.
## 소나무·나무·가게·호스텔은 세 칸을 먹으니 길목에는 안 둔다.
## 돌길 한복판(y10~12)은 비워 둔다 — 걸을 자리가 있어야 마을이다.
func props() -> Array:
	return [
		# 능. 이 마을 이름이 "능 앞 마을" 인데 봉분이 없었다 — 잔디 언덕에
		# 박석만 깔려 있어서 무엇을 보러 온 곳인지 알 수가 없었다.
		[24, 10, "burial-mound", true],
		# ── 능을 두른 숲. 지도 가장자리를 막아 세상이 끊겨 보이지 않게 한다
		[2, 4, "pine", true],
		[6, 1, "tree", true],
		[11, 4, "pine", true],
		[3, 7, "tree", true],
		[15, 2, "tree", true],
		[24, 2, "tree", true],
		[38, 2, "pine", true],
		[44, 5, "tree", true],
		[50, 2, "pine", true],
		[48, 8, "pine", true],
		[45, 11, "tree", true],
		[41, 8, "shrub", false],
		[30, 4, "shrub", false],

		# ── 능. 낮은 봉분과 그 앞 박석
		[20, 5, "boulder", true],
		[33, 5, "boulder", true],
		[26, 7, "boulder", true],
		[30, 8, "flower-pots", false],
		[18, 13, "boulder", true],
		[33, 14, "boulder", true],
		# 능을 두른 낮은 울. 세로로만 서니 위아래로는 막지 않는다 —
		# 섬돌(x16~19)로 오르는 길은 늘 열려 있다.
		[17, 8, "fence", true],
		[17, 10, "fence", true],
		[17, 11, "fence", true],
		[36, 8, "fence", true],
		[36, 10, "fence", true],
		[35, 10, "fence", true],

		# ── 돌길 북쪽. 낮은 기와지붕이 늘어선 쪽
		[6, 14, "guesthouse", true],
		[12, 14, "shop", true],
		[17, 14, "mailbox", true],
		[21, 14, "street-lamp", true],
		[32, 14, "street-lamp", true],
		[35, 14, "stall", true],
		[36, 14, "stall", true],
		[41, 14, "shop", true],
		[47, 14, "jars", true],

		# ── 돌길 남쪽. 살림이 나와 앉은 쪽
		[3, 20, "jars", true],
		[5, 20, "jars", true],
		[8, 20, "flower-pots", false],
		[14, 20, "washtub", true],
		[18, 20, "firewood", true],
		[29, 20, "stall", true],
		[30, 20, "stall", true],
		[35, 20, "bench", true],
		[38, 20, "street-lamp", true],
		[44, 20, "fence", true],
		[45, 20, "fence", true],

		# ── 아랫마당. 흙마당에는 밭과 펌프, 박석마당에는 장독대
		[11, 23, "clothesline", true],
		[15, 23, "pump", true],
		[11, 26, "home-garden", false],
		[15, 26, "home-garden", false],
		[18, 25, "jars", true],
		[20, 25, "jars", true],
		[33, 23, "bench", true],
		[38, 23, "clothesline", true],
		[35, 26, "jars", true],
		[36, 26, "jars", true],
		[41, 26, "shrub", false],

		# ── 아래 가장자리
		[0, 26, "tree", true],
		[5, 29, "pine", true],
		[24, 29, "tree", true],
		[12, 31, "shrub", false],
		[47, 25, "pine", true],
		[50, 29, "tree", true],
		[42, 31, "shrub", false],

		# ── 버스 서는 자리. 표지판은 안 막는다 — 그 위로 걸어가도 된다
		[48, 19, "bench", true],
		[50, 16, "signpost", false],
		# ── 흙마당 생활터 (볕뉘:흙마당 장면) — 빨래·장작이 있어야 산다
		[18, 28, "bench", true],
		[12, 23, "washtub", false],
		[11, 26, "firewood", true],
		[20, 23, "jars", true],
		# ── 두 가게 사이 장터 — 아주머니 낮 자리(10,12) 곁
		[35, 19, "stall", true],
		[38, 20, "flower-pots", false],
		[32, 20, "jars", true],
		# ── 감나무 밭으로 들어가는 자리 ───────────────────────────
		[29, 28, "shrub", false],
		# ── 1.5배로 넓히며 줄지어 선 소품 사이 틈을 메운 것
		[17, 9, "fence", true],
		[36, 9, "fence", true],
		[4, 20, "jars", true],
		[19, 25, "jars", true],
		[20, 24, "jars", true],
	]


func pickups() -> Array:
	return [
		[8, 5, "p-pinecone"],
		[27, 10, "p-flower"],
		[41, 7, "p-acorn"],
		[8, 25, "p-pebble"],
		[39, 25, "p-acorn"],
		[17, 29, "p-pebble"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(26, 17)


func sleep_tile() -> Vector2i:
	return Vector2i(6, 16)


func depart_tile() -> Vector2i:
	return Vector2i(50, 17)


func wanderer_tile() -> Vector2i:
	return Vector2i(32, 16)


## 능(16,6) 한 바퀴 — 울타리 안쪽 박석까지 들어와 봤는지만 본다.
func quest_zones() -> Array:
	return [
		["볕뉘:능", Vector2i(24, 10), 64.0],
		# 남서쪽 흙마당. 돌길에서 한 층 내려온 살림 골목이다.
		["볕뉘:흙마당", Vector2i(15, 25), 44.0],
	]


## 가게 둘(8,9)·(27,9) 문 앞. 둘 다 한 칸만 막으니 문 앞은 아랫줄이다.
func doors() -> Array:
	return [
		{"tile": Vector2i(12, 16),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		{"tile": Vector2i(41, 16),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 능 밑동(16,6) 바로 앞. 안쪽길 서브맵으로 이어진다.
		# **들어서는 것만으로 퀘스트가 끝나면 안 된다** — 볕 드는 자리까지
		# 걸어야 진짜 "안쪽길을 돌았다" 는 뜻이 되므로, 완료 표시는
		# 안쪽(`TombPathInterior.quest_zones()`)에서 남긴다. 여기 문의
		# `enter_key` 는 그 표시와 겹치면 안 되니 다른 이름을 쓴다.
		{"tile": Vector2i(24, 11),
			"scene": "res://scenes/journey/interiors/TombPathInterior.tscn",
			"label": "안쪽길 들어가기", "enter_key": "능입구"},
		# 아랫마당 텃밭 너머, 옛 감나무 밭으로 슬쩍 들어가는 자리.
		{"tile": Vector2i(27, 28),
			"scene": "res://scenes/journey/interiors/GatherGround.tscn",
			"label": "감나무 밭으로 들어가기", "enter_key": "감나무밭"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	put_folk(Vector2i(15, 19), "seal", "빵집 아주머니", "ju_seal", [
		["갓 구운 빵 있어요.", "식기 전에 드세요."],
		["여긴 다들 천천히 걸어요.", "급할 게 없거든."],
		["저 능은 천 년쯤 됐대요.", "…라고들 하죠."],
		["빵 식는 동안만 앉았다 가요."],
		["냄새 나면 또 들어와요."],
	], Vector2.DOWN, false, {
		# 아침: 가게 문 바로 앞. 문을 열고 김 나는 빵을 내놓는 중이다.
		"아침": Vector2i(11, 19),
		# 낮: 가게 옆 돌길. 오가는 사람에게 빵을 판다.
		"낮": Vector2i(15, 19),
		# 저녁: 가로등 곁 벤치. "앉았다 가요" 하던 사람이 하루 끝엔 본인이 앉는다.
		"저녁": Vector2i(36, 20),
	})

	put_folk(Vector2i(30, 11), "seagull", "능 지키는 아이", "ju_kid", [
		["여기 앉아 있으면 바람 소리만 나요."],
		["아저씨는 어디서 왔어요?"],
		["나는 여기 말고 가 본 데가 없어요."],
		["언젠가 나도 걸어서 나가 볼래요."],
		["잘 가요. 다음에 또 얘기해요."],
	], Vector2.LEFT, false, {
		# 아침: 우체통 앞. 여기밖에 모르는 아이가 바깥에서 온 것부터 살핀다.
		"아침": Vector2i(17, 16),
		# 낮: 능 앞 박석. 제 자리를 지키며 바람 소리를 듣는다.
		"낮": Vector2i(30, 11),
		# 저녁: 펌프 곁 흙마당. 해가 지면 집 마당으로 돌아간다.
		"저녁": Vector2i(29, 13),
	})

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
		"나 여기 어제 왔는데요.",
	])


## 볕 — 노랗게 데워진 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(1.00, 0.99, 0.93)

## 가게가 둘이다. 아랫것이 본래의  가게, (27, 9) 것은 찻집이다.
func sign_of(prop_name: String, at: Vector2i = Vector2i.ZERO) -> String:
	if prop_name == "shop" and at == Vector2i(41, 14):
		return "찻집"
	return super(prop_name, at)
