extends Place
## 🌴 하늬섬. 섬.
##
## 검은 돌담과 바람. 작고, 다 안다. 1탄의 마지막 여행지다.
## 여기서는 **길이 하나뿐**이라 헤맬 수가 없다 — 섬이니까.
##
## ── 44칸에서 35칸으로 줄였다 ─────────────────────────────────────────
##
## 폰에서 해 보니 넓기만 하고 허전했다. 하늬섬은 **작아서** 좋은 곳인데
## 지도가 제일 넓었다. 말과 그림이 반대였던 셈이다.
## 가로를 35칸으로 줄이고 소품을 22개에서 54개로 늘렸다
## (100칸당 2.8개 → 8.6개).
## 34칸 밑으로는 못 내린다: 초광각 폰(1600px)에서 3배로 보면
## 1600 ÷ 16 ÷ 3 = 33.3칸이라 지도 밖 회색이 드러난다.
##
## ── 가로 띠를 깼다 ───────────────────────────────────────────────────
##
## 예전 지도는 물–모래–풀–흙–현무암이 **각각 한 줄씩 곧게 44칸을
## 가로질렀다.** 섬이 아니라 줄무늬였다. 지금은
##
## - 물가가 사방으로 굽이친다. 위아래가 좁고 가운데가 부른 **섬 꼴**이다
## - 현무암이 풀밭 위로 솟았다가(북쪽 언덕) 마을에서 다시 넓어진다
## - 마른풀이 모래와 풀 사이를 들쭉날쭉 오간다
##
## ── 길이 하나뿐이다 ──────────────────────────────────────────────────
##
## 흙길이 서쪽 나루(x2, y11~12)에서 시작해 마을을 지나 동쪽으로 빠진다.
## 그런데 **곧지 않다** — 나루에서 y12, 마을 앞에서 y10, 북쪽 언덕
## 아래에서 y7 까지 올라갔다가 다시 y11 로 내려간다. 한 줄기지만
## 굽이치므로 띠로 보이지 않는다. 길을 잃을 수 없다는 말은 그대로다.

func place_name() -> String:
	return "하늬섬"


func _init() -> void:
	legend = {
		"w": "water",
		"s": "sand",
		"g": "grass",
		"d": "dirt",        # 붉은 흙길. 섬을 가로지르는 하나뿐인 길
		".": "dry-grass",
		"c": "basalt",      # 검은 현무암. 이 섬의 색이다
	}


## 가로 35칸 × 세로 18칸.
## - 서쪽 x1~2, y11~12 가 **나루**다. 배는 여기로만 든다
## - 북쪽 x9~18, y4~8 은 현무암이 솟은 **언덕**
## - 동쪽 x28 은 등대가 선 **곶**
## - 가운데 x7~25, y10~14 가 **돌담 마을**
func ground_map() -> String:
	return """
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwwwwwwwssssssssssssswwwwwwwwwwwwwwwwwwww
wwwwwwwwwwwwwwssssssssssssssssssssssssswwwwwwwwwwwwww
wwwwwwwwwwwwwwssssssssssssssssssssssssswwwwwwwwwwwwww
wwwwwwwwsssssssssssssss.......ssssssssssssssswwwwwwww
wwwwwssssss....gggggggggggccccccgggggg....sssssswwwww
wwwwwssssss....gggggggggggccccccgggggg....sssssswwwww
wwwsssss...ggggccccccccccccccggggggg...gggggsssssswww
wwssss...gggggccccccccccccggggcccccggggggggg...ssssww
wwssss...gggggccccccccccccggggcccccggggggggg...ssssww
wwsss.ggggggggcccccccccggggggddddgggggcccccccccssswww
wwsssgggggggcccccccccdddddddddgggddddddggggg...swwwww
wwsssgggggggcccccccccdddddddddgggddddddggggg...swwwww
wwsssgggggggggggg.dddddddddddggggdddddddddddggggsssww
wwsggggggggddddddddddcccccccccccccccgggdddddddddddsww
wwsggggggggddddddddddcccccccccccccccgggdddddddddddsww
wwsdddddddddddgggccccccccccccgccccccgg...ggggdddddsww
wwsddddddddcccccccgggggccccgggcccccccccgggggggg.sswww
wwsddddddddcccccccgggggccccgggcccccccccgggggggg.sswww
wwwsss..ggggggccccgggggcccgggggggcccccggggggg..ssswww
wwwwwssss...ggggggggcccccccgggggggggggg...sssssswwwww
wwwwwssss...ggggggggcccccccgggggggggggg...sssssswwwww
wwwwwwwws........gggggggggggggggggg...ssssssswwwwwwww
wwwwwwwwwwww...sssss...ggggggg...sssssssswwwwwwwwwwww
wwwwwwwwwwww...sssss...ggggggg...sssssssswwwwwwwwwwww
wwwwwwwwwwwwwwwwwwssssssssssssssssswwwwwwwwwwwwwwwwww
"""


## 소품 54개 / 630칸 = 100칸당 8.6개.
##
## **덩어리로 놓는다.** 하나씩 흩뿌리면 아무리 많아도 허전하다 —
## 북쪽 언덕에 바위 여섯, 마을 서쪽에 장독대 셋, 시장에 좌판 셋,
## 남쪽 풀밭에 소나무 셋.
##
## 막는 소품의 콜라이더는 가로로 스프라이트 폭의 70% 만큼 퍼진다.
## 폭이 46px 를 넘는 것만 **세 칸**을 막는다 —
## 호스텔(59px) · 가게(48px) · 소나무(70px). 나머지는 한 칸이다.
## 그래서 큰 것은 **흙길 위에 두지 않는다.** 길이 하나뿐인 섬에서
## 그 하나를 막으면 나루로 못 간다.
func props() -> Array:
	return [
		# 돌담. 이 섬 이름이 "검은 돌담과 바람" 인데 정작 돌담이 없었다.
		# 밭과 길 사이에 낮게 두른다 — 바람을 막으려고 쌓은 것이다.
		[11, 14, "stone-wall", true],
		[18, 14, "stone-wall", true],
		[33, 22, "stone-wall", true],
		[38, 19, "stone-wall", true],
		[9, 20, "stone-wall", true],
		# ── 북쪽 백사장과 바다 ────────────────────────────────────────
		# 부표는 물 위에 뜬다. 물은 어차피 못 걷는 칸이라 막지 않는다.
		[15, 2, "buoy", false],
		[50, 13, "buoy", false],
		[12, 5, "parasol", false],
		[41, 5, "parasol", false],
		[18, 5, "beach-grass", false],
		[35, 5, "beach-grass", false],
		[29, 4, "beach-grass", false],
		[8, 7, "net", false],
		[44, 7, "net", false],
		[6, 8, "icebox", false],
		[45, 7, "washtub", false],

		# ── 북쪽 현무암 언덕 ──────────────────────────────────────────
		# 검은 돌담 대신 바위를 늘어놓는다. 여섯이 모여야 언덕이다.
		[17, 8, "boulder", true],
		[15, 10, "boulder", true],
		[20, 10, "boulder", true],
		[27, 7, "boulder", true],
		[32, 10, "boulder", true],
		[18, 11, "boulder", true],
		[23, 11, "pebbles", false],
		# ── 언덕 꼭대기 (하늬섬:언덕 장면 둘레)
		[24, 7, "boulder", true],
		[24, 13, "pebbles", false],

		# ── 동쪽 곶과 등대 ────────────────────────────────────────────
		# 등대는 96px(여섯 칸)짜리라 발을 6번 줄에 둬야 꼭대기가 바다에 걸린다.
		[42, 10, "lighthouse", true],
		[45, 10, "boulder", true],
		[44, 11, "beach-grass", false],

		# ── 돌담 마을 ─────────────────────────────────────────────────
		# 호스텔은 12번 줄 x9~11 을 막는다. 문 앞은 13번 줄이다.
		[15, 19, "guesthouse", true],
		[24, 19, "shop", true],
		[20, 17, "street-lamp", true],
		[11, 19, "bench", true],
		# 서쪽 살림골목 — 장독대·빨랫줄·펌프가 붙어 있어야 사람이 산다
		[12, 20, "jars", true],
		[14, 20, "jars", true],
		[12, 22, "jars", true],
		[15, 22, "clothesline", true],
		[18, 22, "pump", true],
		[11, 22, "firewood", false],
		[18, 22, "boulder", true],
		[29, 19, "bench", true],
		[32, 20, "flower-pots", false],
		# 시장. 좌판 셋이 모여야 장이다 — 두 줄로 오와 열을 맞춘다.
		[33, 19, "stall", true],
		[36, 19, "stall", true],
		[33, 20, "stall", true],
		[39, 19, "mailbox", true],
		[41, 20, "bench", true],
		[42, 17, "street-lamp", true],

		# ── 남쪽 풀밭 ─────────────────────────────────────────────────
		[21, 23, "pine", true],
		[27, 23, "pine", true],
		# **한 줄 위(y14)에 있었다.** 시장 좌판·돌담과 두 칸씩 떨어져
		# 있어서 따로는 다 트여 보였는데, 둘 다의 콜라이더가 그 사이
		# 칸(23,13)·(23,14)을 양쪽에서 갉아먹어 걷는 몸보다 좁은 틈만
		# 남기고, 결국 그 자리를 사방이 막힌 갇힌 웅덩이로 만들었다
		# (`_close_prop_gaps()` 가 잡아낸다). 다른 소나무 둘과 같은 줄로
		# 내려 시장과 한 칸 더 벌린다.
		[36, 23, "pine", true],
		[30, 22, "shrub", false],
		[26, 25, "shrub", false],
		[17, 25, "shrub", false],
		[14, 23, "beach-grass", false],
		[39, 23, "beach-grass", false],
		[20, 26, "dock", false],

		# ── 서쪽 나루 ─────────────────────────────────────────────────
		# 표지판은 떠나는 자리 (4,12) **바로 위**에 선다. 그리고
		# **막지 않는다** — 그 위로 걸어 지나갈 수 있어야 나루가 좁아
		# 보이지 않는다.
		[6, 17, "signpost", false],
		[2, 19, "dock", false],
		[3, 20, "boulder", true],
		[5, 16, "beach-grass", false],
		[8, 14, "pine", true],
		# ── 귤밭 뒤뜰로 들어가는 자리 ─────────────────────────────
		[45, 20, "flower-pots", false],
		# ── 1.5배로 넓히며 줄지어 선 소품 사이 틈을 메운 것
		[13, 20, "jars", true],
		[12, 21, "jars", true],
	]


func pickups() -> Array:
	return [
		[20, 5, "p-shell"],        # 북쪽 백사장
		[38, 7, "p-seaglass"],
		[11, 10, "p-flower"],        # 언덕 서쪽
		[47, 14, "p-pebble"],       # 등대 아래
		[24, 22, "p-pinecone"],    # 마을 뒤
		[29, 25, "p-shell"],       # 남쪽 풀밭
	]


## 마을 한복판, 현무암 마당. 위로 가면 언덕, 서쪽으로 가면 나루다.
##
## **가게 그림 밖이어야 한다.** (17,10) 은 가게(16,12) 그림(67x64) 속이라
## 내리자마자 주인공이 통째로 안 보였다 — 가게 오른쪽 끝이 x18.6 칸이다.
func spawn_tile() -> Vector2i:
	return Vector2i(29, 16)


## 호스텔 문 앞. 호스텔이 12번 줄 x9~11 을 막으므로 문 앞은 13번 줄이다.
func sleep_tile() -> Vector2i:
	return Vector2i(15, 20)


## 서쪽 나루. 흙길의 끝이고, 바로 위 (4,11) 에 표지판이 서 있다.
func depart_tile() -> Vector2i:
	return Vector2i(6, 19)


## 마을 앞 풀밭. 길과 붙어 있어 지나가다 마주친다.
func wanderer_tile() -> Vector2i:
	return Vector2i(30, 16)


## "섬 한 바퀴 십오 분이에요!" — 나루 반대편, 시장까지 건너와 봤는지.
## 길이 하나뿐인 섬이라 여기 닿았으면 한 바퀴 돈 것과 다름없다.
func quest_zones() -> Array:
	return [
		["하늬섬:한바퀴", Vector2i(36, 19), 56.0],
		# 북쪽 현무암 언덕 꼭대기. 섬에서 제일 높은 자리다.
		["하늬섬:언덕", Vector2i(20, 8), 44.0],
	]


## 가게(16,12) 문 앞. 한 칸만 막으니 문 앞은 바로 아랫줄이다.
func doors() -> Array:
	return [
		{"tile": Vector2i(24, 20),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 등대 밑동(28,6) 바로 앞.
		{"tile": Vector2i(42, 11),
			"scene": "res://scenes/journey/interiors/LighthouseInterior.tscn",
			"label": "등대 들어가기", "enter_key": "등대안"},
		# 시장 뒤편, 귤 파는 할머니 좌판 너머로 이어지는 뒤뜰.
		{"tile": Vector2i(44, 20),
			"scene": "res://scenes/journey/interiors/GatherGround.tscn",
			"label": "귤밭 뒤뜰로 들어가기", "enter_key": "귤밭"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 시장 좌판 앞
	put_folk(Vector2i(30, 19), "seal", "귤 파는 할머니", "do_seal", [
		["귤 하나 먹어 봐.", "여기 건 달아."],
		["바람이 세지? 늘 이래."],
		["섬은 작아서 하루면 다 봐요.", "그래도 사흘은 있어야 알지."],
		["오늘은 바람이 덜하네."],
		["가는 배 시간 놓치지 말고."],
	], Vector2.DOWN, false, {
		# 아침: 나루 부두 곁. 섬 물건은 다 첫 배로 온다 — "가는 배 시간"을
		# 꿰는 사람이 배가 부린 궤짝을 여기서 맞는다.
		# 떠나는 자리 (4,12) 와는 50px 떨어져 있어 "출발" 표시를 안 가린다.
		"아침": Vector2i(2, 17),
		# 낮: 시장 좌판 앞. 원래 서 있던 자리다.
		"낮": Vector2i(30, 19),
		# 저녁: 우체통과 벤치 사이. 좌판을 닫은 사람이 벤치 곁에서
		# 바다 쪽을 보며 하루를 닫는다.
		"저녁": Vector2i(39, 20),
	})

	# 하나뿐인 흙길 위. 자전거는 이 길로만 다닌다.
	put_folk(Vector2i(29, 13), "seagull", "자전거 탄 아이", "do_kid", [
		["섬 한 바퀴 십오 분이에요!"],
		["돌담 사이로 가면 더 빨라요."],
		["나는 여기서 태어났어요."],
		["같이 한 바퀴 돌래요?"],
		["또 놀러 와요."],
	], Vector2.DOWN, false, {
		# 아침: 북쪽 언덕 아래, 길이 제일 높이 오른 자리 (y7).
		# "십오 분" 한 바퀴는 여기서 시작한다 — 내리막부터니까.
		"아침": Vector2i(30, 11),
		# 낮: 마을 앞 흙길. 원래 서 있던 자리다.
		"낮": Vector2i(29, 13),
		# 저녁: 등대 아래 풀밭. 여기서 태어난 아이는 불 켜지는 걸
		# 다 보고도 또 본다.
		"저녁": Vector2i(39, 14),
	})

	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["섬은 처음이에요."],
		["여기 바람 소리가 좋네요."],
		["같이 돌담길 걸을래요?"],
		["그럼 또 어디선가."],
	], [
		"섬까지 따라온 건 아니죠?",
	])


## 하늬바람 — 가장 차가운 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(0.95, 0.99, 1.00)
