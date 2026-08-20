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
ggggggggggggggggggggggggggswwwdwwwddddeeee
ggggggggggggggggggggggggggsdddddddddddeeee
gggggggggggggggggggggggggswwwwwwwddddeeeee
gggggggggggggggggggggggggswwwwwwwddddeeeee
ggggggggggggggggggggggggswwwwwwwsgggeeeeee
gggggggggggggggggggggggswwwwwwwsggggeeeeee
ggggggggggggggggggggggswwwwwwwsgggggeeeeee
gggggggggggggggggggggswwwwwwwsgggggggggggg
gggggggggggggggggggswwwwwwwsgggggggggggggg
"""


## 소품 61개 / 924칸 = 100칸당 6.6개.
##
## 열세 개뿐이라 휑했다. 개수보다 **놓인 꼴**이 문제였다 — 나무 한 그루,
## 바위 한 덩이가 넓은 둔치에 한 개씩 떨어져 있으면 아무리 늘려도
## 그냥 흩뿌린 것이다. 셋에서 다섯씩 묶고, 묶음 사이는 네 칸 넘게 비운다.
##
## 규칙 셋만 지켰다.
## - **사람이 만든 것은 줄을 맞춘다.** 난간 셋은 한 가로줄(y2), 데크 등
##   둘은 한 세로줄(x34), 부표는 물길 한복판을 따라 간다. 자연은 안 맞춘다 —
##   솔숲도 갯풀도 y 를 한두 칸씩 어긋내 깊이를 준다.
## - **바닥이 갈리는 선을 따라 심는다.** 갯풀과 조약돌은 강가 모래선을
##   따라가고, 바위는 물살이 부딪는 바깥 굽이에 모인다. 허공에 안 띄운다.
## - **가운데는 비운다.** 시작 자리(10,10)에서 데크(y14)까지 가로지르는
##   길은 뚫려 있고, 대신 지도 네 귀퉁이를 나무로 두른다.
##
## 스프라이트는 칸보다 훨씬 크다(나무 3.2칸, 소나무 4칸 높이). 아래
## 가운데가 기준이라 **위로** 자라므로, 소나무·나무는 y3 위로 못 올린다 —
## 꼭대기가 지도 밖으로 잘린다. 가로도 마찬가지라 x41 에는 폭 넓은 것을
## 안 둔다.
##
## 가게·쉼터·표지판·우체통은 문(39,15)·잠자리(39,17)·출발(40,15)이
## 그 좌표에 걸려 있어 못 옮긴다. 대신 밑동에 화분·평상·장독·장작을
## 붙여 땅에 앉힌다.
func props() -> Array:
	return [
		# ── 나루 마당 (동안) ────────────────────────────────────────
		# 붙박이 넷. 좌표 고정.
		[39, 14, "shop", true],          # 카피바라 가게
		[37, 12, "guesthouse", true],    # 쉼터
		[40, 15, "signpost", false],
		[34, 17, "mailbox", true],
		# 건물 밑동. 마당에서 안 가려지는 곳은 y15 와 y17~19 뿐이다.
		[37, 15, "flower-pots", false],
		[36, 17, "flower-pots", false],
		[37, 18, "bench", true],
		[36, 19, "firewood", false],
		[40, 18, "jars", true],
		[39, 19, "jars", true],

		# ── 데크 (사람이 만든 것 — 줄을 맞춘다) ─────────────────────
		[26, 13, "street-lamp", true],   # 다리 서쪽 어귀
		# 데크 등 둘. 같은 칸줄(x34)에 세워 판자길 어귀를 양쪽에서 낀다.
		# (37,13)에 뒀더니 가게 그림에 62%가 먹혔다 — 가게가 x37.4까지 온다.
		[34, 13, "street-lamp", true],
		[34, 16, "street-lamp", true],
		[35, 16, "bench", true],         # 굽이를 보고 앉는 자리
		[33, 16, "net", false],

		# ── 강 한복판 모래톱 ────────────────────────────────────────
		[29, 9, "beach-grass", false],
		[31, 10, "beach-grass", false],
		[30, 12, "pebbles", false],

		# ── 강물 ────────────────────────────────────────────────────
		# 부표는 물길 한복판을 따라 내려간다(19→24→27). 굽이를 눈으로 읽게.
		[22, 1, "buoy", false],
		[24, 3, "buoy", false],
		[27, 5, "buoy", false],
		[28, 17, "buoy", false],
		# 아래 굽이 여울의 바위 둘
		[23, 20, "boulder", false],
		[21, 21, "boulder", false],

		# ── 동안 전망 자리 (갈매기가 서 있는 곳) ────────────────────
		[30, 2, "fence", true],          # 난간 셋 — 한 줄로
		[31, 2, "fence", true],
		[32, 2, "fence", true],
		[31, 3, "bench", true],
		# ── 둔치 모래톱 쉼터 (갈매기의 자리)
		[32, 6, "bench", true],
		[33, 2, "pebbles", false],
		[37, 5, "beach-grass", false],

		# ── 동안 숲 (오른쪽 가장자리를 두른다) ──────────────────────
		[38, 5, "pine", true],
		[40, 7, "pine", true],
		[40, 9, "tree", true],
		[39, 10, "shrub", false],

		# ── 남동 숲 (오른쪽 아래 귀퉁이) ────────────────────────────
		# 소나무를 마당 쪽(36,21)에 두면 장작(36,19)을 통째로 삼킨다 —
		# 나무는 네 칸 높이라 두 줄 아래에서도 위를 다 덮는다. 서쪽으로 뺐다.
		[31, 21, "pine", true],
		[33, 20, "tree", true],
		[35, 18, "shrub", false],

		# ── 서안: 서북 솔숲 (왼쪽 위 귀퉁이) ────────────────────────
		[2, 1, "shrub", false],
		[1, 3, "pine", true],
		[3, 5, "pine", true],
		[6, 4, "pine", true],

		# ── 서안: 참나무 그늘 (도토리 떨어진 자리 곁) ───────────────
		[9, 4, "tree", true],
		[12, 7, "tree", true],
		[13, 9, "shrub", false],

		# ── 서안: 북쪽 강가 갯풀, 첫 무리 ───────────────────────────
		[16, 1, "beach-grass", false],
		[17, 2, "pebbles", false],
		[15, 3, "beach-grass", false],

		# ── 서안: 북쪽 강가 갯풀, 둘째 무리 ─────────────────────────
		[21, 6, "beach-grass", false],
		[20, 7, "pebbles", false],
		[22, 8, "beach-grass", false],

		# ── 서안: 바깥 굽이 바위 (물살이 부딪는 쪽) ─────────────────
		[23, 10, "boulder", true],
		[24, 12, "boulder", true],
		[22, 13, "pebbles", false],

		# ── 서안: 그물 손질터 ───────────────────────────────────────
		[23, 17, "reception", true],
		[22, 16, "firewood", false],
		[21, 18, "net", false],

		# ── 서안: 남서 숲 (왼쪽 아래 귀퉁이) ────────────────────────
		[6, 17, "shrub", false],
		[4, 19, "tree", true],
		[8, 20, "pine", true],
		[2, 21, "pine", true],

		# ── 서안: 남쪽 강가 갯풀 ────────────────────────────────────
		[16, 20, "beach-grass", false],
		[14, 21, "beach-grass", false],
		[18, 21, "pebbles", false],
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


## 호스텔 문 앞. 호스텔은 여섯 칸 높이(96px)라 마당 아래에 세우면
## 가게·표지판·정류장을 통째로 덮는다. 마당 위쪽에 세우고 문 앞은
## 그 아랫줄이다.
func sleep_tile() -> Vector2i:
	return Vector2i(36, 13)


func depart_tile() -> Vector2i:
	return Vector2i(40, 15)

func wanderer_tile() -> Vector2i:
	return Vector2i(14, 12)



## "강 굽이가 보이는 데크까지 가 보기" — 나루 데크 자체가 방문 지점이다.
func quest_zones() -> Array:
	return [
		["굽이나루:데크", Vector2i(36, 14), 56.0],
	]


func doors() -> Array:
	return [
		{"tile": Vector2i(39, 15),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 모래톱에서 강 안쪽으로 더 들어가는 샛길. **문이 아니라 길이다** —
		# 널 하나 건너 모래가 이어지는 자리다. `enter_key` 는 뜻이 없다.
		# 다 했다는 표시는 안쪽 자리에서 난다(`SidePathInterior`).
		{"tile": Vector2i(31, 11),
			"scene": "res://scenes/journey/interiors/SidePathInterior.tscn",
			"label": "모래톱 안쪽으로", "enter_key": "샛길입구"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 물범의 담수 버전. 조끼 차림, 나루 옆 가게를 지킨다.
	put_folk(Vector2i(33, 15), "capybara-a", "나루 가게 아저씨", "cap_guinaru", [
		["어서 와요. 강 여행은 또 다르지."],
		["강물이 굽어 도는 자리가 여기예요.", "서두를 것 없어요."],
		["길 묻는 손님한테도 늘 이렇게 말해요.", "천천히 가요."],
		["강 보면서 좀 쉬었다 가요."],
		["물소리 생각나면 또 와요."],
	], Vector2.DOWN, false, {}, "")

	# 갈매기 — 1탄과 같은 역할(높은 곳, 먼 곳을 동경). 여기선 강 굽이를 본다.
	put_folk(Vector2i(35, 3), "seagull", "둔치의 갈매기", "gu_gull", [
		["강도 바다처럼 넓어질 수 있대요."],
		["저 굽이까지 가 봤어요?", "데크에서 보면 더 잘 보여요."],
		["여긴 물살이 안 급해서 좋아요."],
		["데크 끝까지 같이 가 볼래요?"],
		["다음엔 더 먼 데서 만나요."],
	], Vector2.DOWN, false, {
		# 아침엔 난간에서 강을 내려다보고, 낮엔 모래톱에 내려앉고,
		# 저녁엔 데크에서 노을을 본다 — 하루가 흐르는 게 보인다.
		"아침": Vector2i(35, 3),
		"낮": Vector2i(24, 13),
		"저녁": Vector2i(33, 4),
	})

	# 수달 — 선택형 서브 NPC. 필수 퀘스트에 안 넣는다(강가 돌 위, 붙박이).
	put_folk(Vector2i(29, 12), "otter", "돌 위의 수달", "gu_otter", [
		["매끈한 돌 하나를 오래 들여다보고 있었어요."],
		["좋은 돌은 멀리 안 가도 물이 다듬어 줘요."],
		["또 왔네요.", "그 돌, 그대로 있어요."],
	], Vector2.DOWN, false, {})

	# 여행자. 다른 마을에서 만났던 그 너구리를 여기서 다시 만난다 —
	# 재회는 1탄에서 끝나지 않는다 (`JourneyState.WANDERER_STOPS`).
	put_wanderer("raccoon", "배낭 멘 너구리", "raccoon", [
		["어, 반가워요. 여행 중?", "나도요."],
		["나는 아무 계획 없이 다녀요.", "그게 편하더라고."],
		["여긴 이틀만 있다 갈 거예요.", "다음은 아직 안 정했고."],
		["같이 노을 보러 갈래요?"],
		["그럼 또 어디선가.", "…진짜로 또 만나겠죠?"],
	], [
		"강 따라 내려와 봤어요.",
	])


## 강가 — 싱싱한 초록. 같은 나무 그림이 마을마다 딴 빛을 띠게 한다 (`Place.FOLIAGE`).
func foliage_tint() -> Color:
	return Color(0.97, 1.00, 0.96)
