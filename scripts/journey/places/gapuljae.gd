extends Place
## ⚓ 가풀재. 비탈진 항구.
##
## 바다는 윤슬과 같지만 **가파르고 좁다.** 윤슬이 넓게 열려 있다면
## 여기는 골목이 층층이 겹친다. 같은 바다도 마을에 따라 다르다.
##
## ── 44칸에서 35칸으로 줄였다 ─────────────────────────────────────────
##
## 폰에서 해 보니 넓기만 하고 허전했다. 가풀재는 **좁아야** 가풀재다 —
## 넓은 항구는 이미 윤슬이 하고 있다. 가로를 35칸으로 줄이고 소품을
## 세 배로 채웠다. 34칸 밑으로는 못 내린다: 초광각 폰(1600px)에서
## 3배로 보면 1600 ÷ 16 ÷ 3 = 33.3칸이라 지도 밖 회색이 드러난다.
##
## 그리고 **가로 띠를 깼다.** 예전 지도는 물–부두–돌–돌–풀이 각각 한 줄씩
## 곧게 44칸을 가로질러서, 항구가 아니라 줄무늬로 보였다.
## 지금은 왼쪽에 물이 파고든 만이 있고, 오른쪽은 현무암 곶이 솟아 있고,
## 층과 층 사이는 **축대가 어긋나게** 놓여 있다. 층계도 가로로 길게 깔지
## 않았다 — 그러면 그게 다시 띠가 된다. 두 칸 폭으로 네 군데만 세웠다.

func place_name() -> String:
	return "가풀재"


func _init() -> void:
	legend = {
		"w": "water",        # 바다
		"d": "deck",         # 부두 판자
		"b": "basalt",       # 물가에 드러난 검은 바위
		"s": "granite-step", # 층과 층 사이 계단참
		"c": "cobble",       # 골목 바닥
		"g": "grass",        # 비탈 위
		".": "dry-grass",    # 축대 위 마른 풀
	}


## 위가 바다, 아래로 갈수록 비탈이 높다. 가로 35칸 × 세로 20칸.
##
## - x14~18 은 바다로 나간 **부두**(판자). 끝까지 걸어 나갈 수 있다
## - x0~5 위쪽은 물이 파고든 **만**. 왼쪽 물가는 걸어서 못 돈다
## - x23~34 는 **현무암 곶**. 계단(s)이 비스듬히 올라가고 그 위에 등대가 선다
## - 골목은 세 층이다 (y7~8 / y10~12 / y14~16).
##   층과 층 사이는 **마른 풀 축대**인데, 한 줄로 곧게 긋지 않고
##   x0~4 는 y9, x7~13 은 y10, x14~19 는 y9 로 **어긋나게** 놓았다.
## - 층계(s)는 **두 칸 폭으로 세 줄씩** 세운다 — x5~6·x20~21 이 첫째와
##   둘째 층을, x2~3·x15~16 이 둘째와 셋째 층을 잇는다.
##   가로로 길게 깔면 계단이 아니라 또 하나의 띠로 보인다.
func ground_map() -> String:
	return """
wwwwwwwwwwwwwwdddwwwwwwwwwwwwbbbbbb
wwwwwwwwwwwwwwdddwwwwwwwwwwwbbbbbbb
wwwwwwwwwwwwbwdddddwwwwwwwwbbbbbbbb
wwwwwwwwwwdddddddddwwwwbbbsssbbbbbb
wwwwwwddddddddddddddddwbbsssbbbbbbb
wwbbbdddddddddddddddddddsssbbbbbbbb
wbbbbddddccccccccccccccssbbbbbbbbbb
bbcccccccccccccccccccccccssbbbbbbbb
bccccsscccccccccccccsscccccbbbbbbbb
.....ssccccccc......ss....cccbbbbbb
cccccss.......ccccccssccccccc.bbbbb
cccc..cccccccccccccccccccccc.gbbbbb
ccsscccccccccccssccccccccc...gggbbb
..ss.....ccccccss.....cccgggggggggg
ccsscccccccccccsscccccccccc.ggggggg
cccccccccc..ccccccccccc..gggggggggg
.cccccccc...ccccccc..gggggggggggggg
gg..cccc...gg..ccc..ggggggggggggggg
gggggg...ggggggggg..gggggggg...gggg
ggggggggggg...ggggggggggggggg..gggg
"""


## 소품 62개 / 700칸 = 100칸당 8.9개.
##
## **덩어리로 놓는다.** 하나씩 흩뿌리면 아무리 많아도 허전하다 —
## 부두에 어구가 모여 있고, 골목 어귀에 장독대가 셋, 능선에 솔숲.
##
## 막는 소품의 콜라이더는 가로로 스프라이트 폭의 70% 만큼 퍼진다.
## 쿼스텔(59px)·가게(48px)·소나무(70px)·나무(52px) 는 **세 칸**을 막는다.
## 그래서 큰 것은 층과 층을 잇는 길목에 두지 않는다 —
## 부두(y5)에서 첫째 층(y7~8), 둘째 층(y10~12) 으로 내려가는 길이
## 뚫려 있어야 처음 서는 자리에서 나루로도 쿼스텔로도 갈 수 있다.
func props() -> Array:
	return [
		# 축대. 계단은 놓였는데 층과 층 사이 높이차가 0 이라 아직 평지로
		# 읽혔다. 단 옆에 세워 "여기가 한 층 아래"라고 말해 준다.
		[4, 7, "retaining-wall", true],
		# ── 면집 앞 마당 (장면) — 좌판과 장독이 있어야 장사 중이다
		[21, 12, "stall", true],
		[17, 12, "jars", true],
		# ── 능선 쉼터 (가풀재:능선 장면 곁)
		[16, 18, "bench", true],
		[13, 18, "pebbles", false],
		[20, 17, "boulder", true],
		[10, 7, "retaining-wall", true],
		[24, 9, "retaining-wall", true],
		[29, 9, "retaining-wall", true],
		# ── 바다와 현무암 곶 ──────────────────────────────────────────
		# 등대는 96px(여섯 칸)짜리라 발을 5번 줄에 둬야 꼭대기가 안 잘린다.
		[30, 5, "lighthouse", true],
		[32, 3, "boulder", true],
		[27, 2, "boulder", true],
		[33, 7, "boulder", true],
		[31, 8, "pebbles", false],
		[34, 9, "pebbles", false],
		[34, 4, "beach-grass", false],
		[25, 6, "beach-grass", false],
		# 부표는 물 위에 뜬다. 물은 어차피 못 걷는 칸이라 막지 않는다 —
		# 텅 빈 바다에 눈이 걸릴 것이 몇 개는 있어야 한다.
		[11, 1, "buoy", false],
		[19, 1, "buoy", false],
		[6, 2, "buoy", false],
		[21, 3, "buoy", false],
		[3, 4, "buoy", false],

		# ── 부두 ──────────────────────────────────────────────────────
		[14, 3, "dock", false],
		[17, 3, "dock", false],
		[15, 1, "net", false],
		[12, 5, "net", false],
		[10, 4, "icebox", false],
		[16, 4, "icebox", false],
		[19, 4, "firewood", false],
		[21, 5, "washtub", false],
		# 나루 어귀. 떠나는 자리 (7,5) 바로 옆에 표지판이 선다.
		# **막지 않는다** — 그 위로 걸어 지나갈 수 있어야 나루가 안 좁다.
		[8, 5, "signpost", false],
		[5, 6, "jars", true],
		[6, 6, "jars", true],

		# ── 첫째 층: 쿼장 골목 ────────────────────────────────────────
		# 좌판은 한 칸씩 띄워 세운다. 붙여 놓으면 골목이 막힌다.
		[11, 7, "stall", true],
		[13, 7, "stall", true],
		[15, 7, "stall", true],
		# 가게는 세 칸(x17~19)을 막는다. 층계 머리(x20~21)를 비워 둔다.
		[18, 8, "shop", true],
		[9, 8, "street-lamp", true],
		[16, 8, "bench", true],
		[5, 7, "flower-pots", false],
		[3, 8, "jars", true],
		[4, 8, "jars", true],
		[2, 8, "washtub", false],
		[1, 9, "beach-grass", false],
		[23, 6, "net", false],
		[24, 6, "fence", true],

		# ── 둘째 층: 살림 골목 ────────────────────────────────────────
		# 장독대·빨랫줄·펌프가 붙어 있어야 사람이 산다.
		[0, 10, "boulder", true],
		[2, 11, "jars", true],
		[3, 11, "jars", true],
		[5, 12, "clothesline", true],
		[7, 12, "pump", true],
		[10, 12, "stall", true],
		[11, 10, "street-lamp", true],
		[14, 12, "bench", true],
		[16, 10, "flower-pots", false],
		[18, 12, "mailbox", true],
		[21, 12, "bench", true],
		[23, 10, "shop", true],
		# 쿼스텔은 비탈 끝에 앉아 항구를 내려다본다. 문 앞은 (26,12).
		[26, 11, "guesthouse", true],
		[29, 11, "shrub", false],

		# ── 셋째 층과 능선 ────────────────────────────────────────────
		[3, 15, "tools", false],
		[7, 14, "street-lamp", true],
		[16, 15, "bench", true],
		[13, 17, "boulder", true],
		[21, 16, "shrub", false],
		[32, 14, "tree", true],
		[4, 18, "pine", true],
		[9, 19, "pine", true],
		[17, 18, "pine", true],
		[24, 19, "tree", true],
		[30, 18, "pine", true],
	]


func pickups() -> Array:
	return [
		[12, 4, "p-shell"],        # 부두
		[19, 5, "p-seaglass"],
		[32, 6, "p-shell"],        # 곶
		[8, 7, "p-pebble"],        # 골목
		[12, 15, "p-flower"],
		[24, 17, "p-pinecone"],    # 능선
	]


## 둘째 층 골목 한복판. 올라가면 부두, 내려가면 능선이다.
func spawn_tile() -> Vector2i:
	return Vector2i(14, 11)


## 쿼스텔 문 앞. 쿼스텔은 11번 줄 x25~27 을 막으므로 문 앞은 12번 줄이다.
func sleep_tile() -> Vector2i:
	return Vector2i(26, 12)


## 나루. 부두 서쪽 끝이고 바로 옆 (8,5) 에 표지판이 서 있다.
func depart_tile() -> Vector2i:
	return Vector2i(7, 5)


## 둘째 층 큰길. 좌판이나 벤치 콜라이더에 걸리지 않는 칸이어야
## 여행자가 물건을 뚫고 서 있지 않는다.
func wanderer_tile() -> Vector2i:
	return Vector2i(20, 11)


## "노을은 계단에서 봐야 해요" — 부두(1층)에서 능선(3층)까지 다 오른
## 사람만 닿는 자리다.
func quest_zones() -> Array:
	return [
		["가풀재:능선", Vector2i(16, 16), 56.0],
		# 부두 끝. 뒤돌아보면 세 층 골목이 다 보인다.
		["가풀재:부두끝", Vector2i(15, 1), 36.0],
	]


## 가게 둘(18,8)·(23,10) 문 앞. 둘 다 한 칸만 막으니 문 앞은 아랫줄이다.
func doors() -> Array:
	return [
		{"tile": Vector2i(18, 9),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		{"tile": Vector2i(23, 11),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 등대 밑동(30,5) 바로 앞.
		{"tile": Vector2i(30, 6),
			"scene": "res://scenes/journey/interiors/LighthouseInterior.tscn",
			"label": "등대 들어가기", "enter_key": "등대안"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 좌판 (13,7) 앞. 아저씨가 제 가게 앞에 서 있는 셈이다.
	put_folk(Vector2i(13, 8), "seal", "쿼면집 아저씨", "san_seal", [
		["앉아요. 국물부터 한 술 떠 봐."],
		["이 동네는 계단이 많아서.", "다리 아프지."],
		["나도 젊을 땐 배를 탔어요."],
		["오늘은 국물 더 줄게."],
		["또 와요. 알아볼 테니."],
	], Vector2.DOWN, false, {
		# 아침: 부두 얼음궤 (16,4) 옆. 젊을 때 배를 탔던 사람이라
		# 새벽 배가 부린 생선을 아직도 제 눈으로 고른다.
		"아침": Vector2i(15, 4),
		# 낮: 좌판 앞. 국물을 내며 손님을 받는다.
		"낮": Vector2i(13, 8),
		# 저녁: 좌판 옆 벤치 (16,8) 곁. "다리 아프지" 하던 사람이
		# 하루 끝엔 제 다리부터 쉰다.
		"저녁": Vector2i(15, 8),
	})

	put_folk(Vector2i(17, 4), "seagull", "부두 청년", "san_gull", [
		["배 들어오는 거 보러 왔어요?"],
		["저기 등대까지 자전거로 십 분."],
		["여기 노을은 계단에서 봐야 해요."],
		["같이 올라가 볼래요?"],
		["조심히 가요."],
	], Vector2.LEFT, false, {
		# 아침: 부두 한가운데. 배는 새벽에 들어온다 —
		# 들어오는 배를 보는 게 이 청년의 아침이다.
		"아침": Vector2i(13, 6),
		# 낮: 부두 어귀. 짐을 부리고 오가는 사람을 맞는다.
		"낮": Vector2i(17, 4),
		# 저녁: 등대로 오르는 곶 층계. "노을은 계단에서 봐야 해요"를
		# 본인이 매일 지키고 있다.
		"저녁": Vector2i(25, 5),
	})

	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["계단이 많아서 다리가 아파요."],
		["여기 국수 먹어 봤어요?"],
		["같이 노을 볼래요?"],
		["그럼 또 어디선가."],
	], [
		"나 계단 오르다 죽는 줄 알았어요.",
	])


## 고갯바람 — 서늘한 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(0.96, 0.99, 1.00)
