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
....gggggggggggggggggggggg.........
...gggggggggggggggggggggggggg......
..gggg....ggggggggggggggggggggg....
g..gg......ggggggggggggggggggg.....
gg......gggggggggggggggggggg......g
ggg....gggggggggssssggggggg.....ggg
gg....ggggggggssssssssggggggg......
.....gggggggssssssssssssgggg.......
..ccc....ggggssssssssssgg..ccc.....
..ccccccccc.ggg.tttt..ccccccccc....
ccccccccccccggccccccccccccccccccddd
cccccccccccccccccccccccccccccccdddd
ccccccccdddcccgggcccccccccccccccddd
ccccccc.ddddddggggcccccccccbbbb....
.....gdddddddddggggggbbbbbbbbbb....
....gdddddddddggggggbbbbbbbbbg.....
g....gdddddddggggggggbbbbbbbg.....g
...ggggdddddggggggggggbbbbbggg.....
gg.....gdddggggggggggggbbbgg.....gg
......gggggggg.....gggggggg........
....gggggggg.....gggggggg......gggg
"""


## 덩어리로 놓는다. 하나씩 흩뿌리면 채워도 여전히 허전하다 —
## 소나무 셋이 모여 숲 가장자리가 되고, 항아리 넷이 모여 장독대가 된다.
##
## 막는 소품의 콜라이더는 가로로 그림 폭의 70% 만큼 퍼진다.
## 소나무·나무·가게·쿼스텔은 세 칸을 먹으니 길목에는 안 둔다.
## 돌길 한복판(y10~12)은 비워 둔다 — 걸을 자리가 있어야 마을이다.
func props() -> Array:
	return [
		# ── 능을 두른 숲. 지도 가장자리를 막아 세상이 끊겨 보이지 않게 한다
		[1, 2, "pine", true],
		[4, 0, "tree", true],
		[7, 2, "pine", true],
		[2, 4, "tree", true],
		[10, 1, "tree", true],
		[16, 1, "tree", true],
		[25, 1, "pine", true],
		[29, 3, "tree", true],
		[33, 1, "pine", true],
		[32, 5, "pine", true],
		[30, 7, "tree", true],
		[27, 6, "shrub", false],
		[20, 2, "shrub", false],

		# ── 능. 낮은 봉분과 그 앞 박석
		[13, 3, "boulder", true],
		[22, 3, "boulder", true],
		[17, 4, "boulder", true],
		[20, 5, "flower-pots", false],
		[12, 8, "boulder", true],
		[23, 8, "boulder", true],
		# 능을 두른 낮은 울. 세로로만 서니 위아래로는 막지 않는다 —
		# 섬돌(x16~19)로 오르는 길은 늘 열려 있다.
		[11, 5, "fence", true],
		[11, 6, "fence", true],
		[11, 7, "fence", true],
		[24, 5, "fence", true],
		[24, 6, "fence", true],
		[24, 7, "fence", true],

		# ── 돌길 북쪽. 낮은 기와지붕이 늘어선 쪽
		[4, 9, "guesthouse", true],
		[8, 9, "shop", true],
		[11, 9, "mailbox", true],
		[14, 9, "street-lamp", true],
		[21, 9, "street-lamp", true],
		[23, 9, "stall", true],
		[24, 9, "stall", true],
		[27, 9, "shop", true],
		[31, 9, "jars", true],

		# ── 돌길 남쪽. 살림이 나와 앉은 쪽
		[2, 13, "jars", true],
		[3, 13, "jars", true],
		[5, 13, "flower-pots", false],
		[9, 13, "washtub", true],
		[12, 13, "firewood", true],
		[19, 13, "stall", true],
		[20, 13, "stall", true],
		[23, 13, "bench", true],
		[25, 13, "street-lamp", true],
		[29, 13, "fence", true],
		[30, 13, "fence", true],

		# ── 아랫마당. 흙마당에는 밭과 펌프, 박석마당에는 장독대
		[7, 15, "clothesline", true],
		[10, 15, "pump", true],
		[7, 17, "home-garden", false],
		[10, 17, "home-garden", false],
		[12, 16, "jars", true],
		[13, 16, "jars", true],
		[22, 15, "bench", true],
		[25, 15, "clothesline", true],
		[23, 17, "jars", true],
		[24, 17, "jars", true],
		[27, 17, "shrub", false],

		# ── 아래 가장자리
		[0, 17, "tree", true],
		[3, 19, "pine", true],
		[16, 19, "tree", true],
		[8, 20, "shrub", false],
		[31, 16, "pine", true],
		[33, 19, "tree", true],
		[28, 20, "shrub", false],

		# ── 쿼스 서는 자리. 표지판은 안 막는다 — 그 위로 걸어가도 된다
		[32, 12, "bench", true],
		[33, 10, "signpost", false],
	]


func pickups() -> Array:
	return [
		[3, 3, "p-pinecone"],
		[18, 6, "p-flower"],
		[27, 4, "p-acorn"],
		[7, 16, "p-pebble"],
		[26, 16, "p-acorn"],
		[11, 19, "p-pebble"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(17, 11)


func sleep_tile() -> Vector2i:
	return Vector2i(4, 10)


func depart_tile() -> Vector2i:
	return Vector2i(33, 11)


func wanderer_tile() -> Vector2i:
	return Vector2i(21, 11)


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	put_folk(Vector2i(9, 10), "seal", "쿼빵집 아주머니", "ju_seal", [
		["갓 구운 쿼빵 있어요.", "식기 전에 드세요."],
		["여긴 다들 천천히 걸어요.", "급할 게 없거든."],
		["저 능은 천 년쯤 됐대요.", "…라고들 하죠."],
		["오늘은 좀 앉았다 가요."],
		["또 오면 알아볼게요."],
	], Vector2.DOWN)

	put_folk(Vector2i(20, 7), "seagull", "능 지키는 아이", "ju_kid", [
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
		"나 여기 어제 왔는데요.",
	])
