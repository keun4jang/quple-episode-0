extends Place
## 🌊 윤슬. 첫 여행지.
##
## 바다와 등대와 백사장. `docs/world-quo.md` 4절 — 1탄의 첫 곳이다.
## 고향과 정반대로 만든다. 고향이 갈색이고 조용하면 여기는 **파랗고
## 열려 있다.** 첫 5분에 "떠나왔다"가 느껴져야 한다.
##
## 여기서 만나는 셋 중 **너구리는 여행자**다. 다음 여행지에서 다시 만난다 —
## 그 재회가 이 게임의 심장이다.
##
## ── 44칸에서 35칸으로 줄였다 ─────────────────────────────────────────
##
## 폰에서 해 보니 넓기만 하고 허전했다. 넓은 것과 열려 있는 것은 다르다 —
## 열린 느낌은 **바다**가 만들지, 빈 백사장이 만드는 게 아니다.
## 그래서 가로를 35칸으로 줄이고 소품을 세 배로 채웠다.
## 34칸 밑으로는 못 내린다: 초광각 폰(1600px)에서 3배로 보면
## 1600 ÷ 16 ÷ 3 = 33.3칸이라 지도 밖 회색이 드러난다.
##
## 그리고 **가로 띠를 깼다.** 예전 지도는 물–모래–돌바닥–풀이 각각 한 줄씩
## 곧게 44칸을 가로질러서, 마을이 아니라 줄무늬로 보였다. 지금은
## 물가가 굽이치고(왼쪽에 만, 오른쪽에 등대곶), 모래와 돌바닥이 서로
## 이빨처럼 물리고, 마을 한가운데에 풀밭이 하나 들어와 있다.

func place_name() -> String:
	return "윤슬"


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
##
## 가로 35칸 × 세로 20칸.
## - 왼쪽 x6~9 에 물이 파고든 **만**이 있다
## - 오른쪽 x27~34 는 위로 솟은 **등대곶**이다
## - x14~16 은 바다로 나간 **부두**(판자). 끝까지 걸어 나갈 수 있다
## - x14~17 은 백사장을 가로질러 부두까지 가는 **돌길**이다
## - x6~9, y12~13 은 마을 한복판의 **풀밭**
func ground_map() -> String:
	return """
wwwwwwwwwwwwwwdddwwwwwwwwwwwwwsssww
wwwwwwwwwwwwwwdddwwwwwwwwwwwwssssss
wwwwwwwwwwwwwwdddwwwwwwwwwwssssssss
wwwwwwwwwwwwwwdddwwwwwwwwssssssssss
wwwsswwwwwwsssdddswwwwwssssssssssss
sssssswwwwsssssssssswwsssssssssssss
ssssssswwssssssssssssssssssssssssss
ssssssssssssssccccsssssssssssssssss
sssssssssssssccccccssssssssssssssss
sssscccccssssccccccsssscccccsssssss
cccccccccssssccccccccccccccccsssccc
ccccccccccccccccccccccc....cccccccc
ccccccggggccccccccccccc....cccccccc
ccccccggggccccccccccccccccccccccccc
cccccccccc.....ccccccccccccccccgggg
.....cccccgggggcccccc.....cccccgggg
ggggg.....ggggg......gggggcccccgggg
gggggggggggggggggggggggggg.....gggg
gggggggg....ggggggggggggggggggggggg
ggggggggg...ggggggggggggggggggggggg
"""


## 소품 62개 / 700칸 = 100칸당 8.9개.
##
## **덩어리로 놓는다.** 하나씩 흩뿌리면 아무리 많아도 허전하다 —
## 등대곶에 바위 셋, 마을 왼쪽에 장독대 셋, 언덕에 소나무 무리.
##
## 막는 소품의 콜라이더는 가로로 스프라이트 폭의 70% 만큼 퍼진다.
## 쿼스텔(59px)·가게(48px)·소나무(70px)·나무(52px) 는 **세 칸**을 막는다.
## 그래서 큰 것은 길 위에 두지 않는다 —
## **12번 줄과 13번 줄이 마을을 가로지르는 큰길**이고, 여기가 뚫려 있어야
## 처음 서는 자리에서 쿼스텔로도 정류장으로도 갈 수 있다.
func props() -> Array:
	return [
		# ── 바다와 등대곶 ─────────────────────────────────────────────
		# 등대는 96px(여섯 칸)짜리라 발을 5번 줄에 둬야 꼭대기가 안 잘린다.
		[31, 5, "lighthouse", true],
		[28, 3, "boulder", true],
		[33, 2, "boulder", true],
		[26, 4, "boulder", true],
		[29, 2, "pebbles", false],
		[30, 4, "beach-grass", false],
		[32, 7, "beach-grass", false],
		# 부표는 물 위에 뜬다. 물은 어차피 못 걷는 칸이라 막지 않는다 —
		# 텅 빈 바다에 눈이 걸릴 것이 몇 개는 있어야 한다.
		[13, 2, "buoy", false],
		[17, 1, "buoy", false],
		[6, 3, "buoy", false],
		[21, 3, "buoy", false],
		# 부두 어귀
		[14, 5, "dock", false],
		[16, 5, "dock", false],
		[19, 5, "net", false],

		# ── 백사장 ────────────────────────────────────────────────────
		[3, 6, "parasol", false],
		[1, 8, "parasol", false],
		[0, 5, "beach-grass", false],
		[0, 7, "beach-grass", false],
		[2, 9, "beach-grass", false],
		[10, 7, "beach-grass", false],
		[11, 5, "beach-grass", false],
		[9, 8, "pebbles", false],
		[12, 6, "net", false],
		[21, 7, "pebbles", false],
		[24, 8, "firewood", false],
		[30, 8, "washtub", false],
		[29, 9, "icebox", false],
		# 백사장과 마을 사이 울타리. 두 칸만 세운다 —
		# 돌길(x15~18)은 비워 둬야 부두로 걸어 나갈 수 있다.
		[13, 9, "fence", true],
		[14, 9, "fence", true],

		# ── 마을 ──────────────────────────────────────────────────────
		[4, 11, "guesthouse", true],
		[24, 10, "shop", true],
		[15, 10, "flower-pots", false],
		[12, 11, "street-lamp", true],
		[20, 11, "bench", true],
		# 마을 한복판 풀밭. 나무 한 그루와 덤불.
		[8, 13, "tree", true],
		[6, 12, "shrub", false],
		# 왼쪽 살림골목 — 장독대·빨랫줄·펌프가 붙어 있어야 사람이 산다
		[1, 13, "jars", true],
		[2, 13, "jars", true],
		[1, 14, "jars", true],
		[3, 14, "clothesline", true],
		[5, 14, "pump", true],
		[11, 14, "boulder", true],
		[16, 14, "bench", true],
		[22, 14, "flower-pots", false],
		# 오른쪽 쿼장. 좌판 셋이 모여야 장이다.
		[27, 12, "stall", true],
		[29, 12, "stall", true],
		[28, 14, "stall", true],
		# 정류장 — 떠나는 자리 (32, 13) 둘레
		[31, 12, "bench", true],
		[33, 11, "street-lamp", true],
		[34, 12, "mailbox", true],
		# 표지판은 **막지 않는다.** 그 위로 걸어 지나갈 수 있어야
		# 정류장 앞이 좁아 보이지 않는다.
		[33, 13, "signpost", false],

		# ── 언덕 ──────────────────────────────────────────────────────
		[2, 17, "pine", true],
		[6, 19, "pine", true],
		[12, 18, "tree", true],
		[16, 19, "pine", true],
		[20, 18, "tree", true],
		[25, 19, "pine", true],
		[30, 18, "pine", true],
		[33, 17, "pine", true],
		[5, 16, "boulder", true],
		[9, 17, "shrub", false],
		[22, 17, "shrub", false],
	]


func pickups() -> Array:
	return [
		[24, 7, "p-shell"],        # 백사장
		[12, 7, "p-shell"],
		[6, 7, "p-seaglass"],
		[19, 8, "p-pebble"],
		[13, 17, "p-pinecone"],    # 언덕
		[20, 16, "p-flower"],
	]


## 마을길 한가운데. 위로 가면 바다, 아래로 가면 언덕이다.
func spawn_tile() -> Vector2i:
	return Vector2i(17, 12)


## 쿼스텔 문 앞. 여기서 자면 다음 날이다.
## 쿼스텔은 11번 줄 x3~5 를 막으므로 문 앞은 12번 줄이다.
func sleep_tile() -> Vector2i:
	return Vector2i(4, 12)


## 마을 끝 쿼스 정류장. 바로 옆 (33,13) 에 표지판이 서 있다.
func depart_tile() -> Vector2i:
	return Vector2i(32, 13)


func wanderer_tile() -> Vector2i:
	# 예전 (28,13) 은 좌판 콜라이더에 걸려 설 수 없는 칸이었다.
	# 말은 걸렸지만 너구리가 좌판을 뚫고 서 있었다. 큰길 위에 세운다.
	return Vector2i(21, 12)


## 가게(24,10) 문 앞. 가게는 한 칸만 막으므로 문 앞은 바로 아랫줄이다.
func doors() -> Array:
	return [{
		"tile": Vector2i(24, 11),
		"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
		"label": "가게 들어가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 붙박이 둘. 하루 시간표 — 아침 6~11 / 낮 11~17 / 저녁 17시~.
	# 낮 자리는 원래 서 있던 칸 그대로다. 자리만 바뀌어도 마을이 산다.
	put_folk(Vector2i(24, 11), "seal", "가게 할머니", "seal", [
		["어서 와요. 처음 보는 얼굴이네.", "쿼이스크림 하나 들고 가."],
		["오늘은 바람이 좀 차지.", "감기 조심하고."],
		["자네 고향은 어디라 했지?", "…아, 산 쪽이랬나."],
		["이거 가져가. 값은 됐어.", "다음에 또 오면 되지."],
		["또 올 거지?", "…그럼 됐어."],
	], Vector2.DOWN, false, {
		# 아침엔 살림골목 장독대 앞 — 가게 열기 전에 살림부터 돌본다.
		# 저녁엔 큰길 벤치(16,14) 곁에서 하루를 닫는다.
		# 잠자리 (4,12) 와는 세 칸 떨어져 있어 "잠" 표시를 안 가린다.
		"아침": Vector2i(1, 12),
		"낮": Vector2i(24, 11),
		"저녁": Vector2i(17, 14),
	})

	put_folk(Vector2i(18, 7), "seagull", "갈매기 소년", "seagull", [
		["아저씨 여기 사람 아니죠?", "걷는 게 딱 티 나요."],
		["저 등대까지 가 봤어요?", "생각보다 안 멀어요."],
		["나는 여기서 나고 자랐는데,", "가끔 저 배가 어디 가나 궁금해요."],
		["오늘은 같이 좀 걸어요."],
		["언젠가 나도 나가 볼래요.", "그때 어디서 만나면 아는 척해요."],
	], Vector2.LEFT, false, {
		# 배가 어디 가나 궁금한 아이 — 아침엔 부두 한가운데서 배를 본다.
		# 부두는 폭 세 칸(x14~16)이라 가운데를 막아도 양옆으로 지나간다.
		# 저녁엔 등대곶 끝 — "저 등대까지 가 봤어요?"의 그 등대 곁에서
		# 불 켜지는 걸 본다. 마을(스폰) 쪽에서 화면 밖일 만큼 멀어야
		# 시간표 이동이 눈앞 순간이동 없이 일어난다.
		"아침": Vector2i(15, 2),
		"낮": Vector2i(18, 7),
		"저녁": Vector2i(30, 2),
	})

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
