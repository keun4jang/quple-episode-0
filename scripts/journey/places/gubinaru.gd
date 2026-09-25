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
ggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggggggggggggggg
ggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggggggggggggggg
gggggggggggggggggggggggggggsswwwwwwwwwwssgggggggggggggggggggggg
gggggggggggggggggggggggggggggswwwwwwwwwwwsggggggggggggggggggggg
gggggggggggggggggggggggggggggswwwwwwwwwwwsggggggggggggggggggggg
ggggggggggggggggggggggggggggggsswwwwwwwwwwssggggggggggggggggggg
gggggggggggggggggggggggggggggggggsswwwwwwwwwwssgggggggggggggggg
gggggggggggggggggggggggggggggggggsswwwwwwwwwwssgggggggggggggggg
gggggggggggggggggggggggggggggggggggswwwwwwwwwwwsggggggggggggggg
ggggggggggggggggggggggggggggggggggggsswwwwwwwwwwssggggggggggggg
ggggggggggggggggggggggggggggggggggggsswwwwwwwwwwssggggggggggggg
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggg
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggg
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggg
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgggggggggg
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgggggggggg
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgggggggggg
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgggggggggg
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgeeeeeeeee
gggggggggggggggggggggggggggggggggggggggsswwwsssswwwssgeeeeeeeee
gggggggggggggggggggggggggggggggggggggggsswwwwddwwwwddddddeeeeee
gggggggggggggggggggggggggggggggggggggggssddddddddddddddddeeeeee
gggggggggggggggggggggggggggggggggggggggssddddddddddddddddeeeeee
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwddddddeeeeeee
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwddddddeeeeeee
ggggggggggggggggggggggggggggggggggggggswwwwwwwwwwwddddddeeeeeee
ggggggggggggggggggggggggggggggggggggsswwwwwwwwwwssggggeeeeeeeee
gggggggggggggggggggggggggggggggggggswwwwwwwwwwwsggggggeeeeeeeee
gggggggggggggggggggggggggggggggggggswwwwwwwwwwwsggggggeeeeeeeee
gggggggggggggggggggggggggggggggggsswwwwwwwwwwssgggggggeeeeeeeee
ggggggggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggggggggg
ggggggggggggggggggggggggggggggggswwwwwwwwwwwsgggggggggggggggggg
gggggggggggggggggggggggggggggswwwwwwwwwwwsggggggggggggggggggggg
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
		[59, 22, "shop", true],          # 카피바라 가게
		[56, 19, "guesthouse", true],    # 쉼터
		[60, 23, "signpost", false],
		[51, 26, "mailbox", true],
		# 건물 밑동. 마당에서 안 가려지는 곳은 y15 와 y17~19 뿐이다.
		[56, 23, "flower-pots", false],
		[54, 26, "flower-pots", false],
		[56, 28, "bench", true],
		[54, 29, "firewood", false],
		[60, 28, "jars", true],
		[59, 29, "jars", true],

		# ── 데크 (사람이 만든 것 — 줄을 맞춘다) ─────────────────────
		# **막지 않는다.** 강 건너 모래톱으로 가는 길이 다리 어귀
		# 바로 이 자리를 살짝 스치는 완만한 대각선을 타는데, 걷는 몸이
		# 가로등 모서리에 1px 미만 차로 걸려 그 자리에서 멈췄다(실측으로
		# 확인) - 옮겨서 피해도 다리로 몰리는 길목 특성상 다른 자리에서
		# 같은 사고가 되풀이됐다. 자리는 그대로 두고 막지만 않는다 -
		# 밑동 가는 기둥이라 몸을 슬쩍 스쳐도 크게 안 어색하다.
		[39, 20, "street-lamp", false],   # 다리 서쪽 어귀
		# 데크 등 둘. 같은 칸줄(x34)에 세워 판자길 어귀를 양쪽에서 낀다.
		# (37,13)에 뒀더니 가게 그림에 62%가 먹혔다 — 가게가 x37.4까지 온다.
		[51, 20, "street-lamp", true],
		[51, 25, "street-lamp", true],
		[53, 25, "bench", true],         # 굽이를 보고 앉는 자리
		[50, 25, "net", false],

		# ── 강 한복판 모래톱 ────────────────────────────────────────
		[44, 14, "beach-grass", false],
		[47, 16, "beach-grass", false],
		[45, 19, "pebbles", false],

		# ── 강물 ────────────────────────────────────────────────────
		# 부표는 물길 한복판을 따라 내려간다(19→24→27). 굽이를 눈으로 읽게.
		[33, 2, "buoy", false],
		[36, 5, "buoy", false],
		[41, 8, "buoy", false],
		[42, 26, "buoy", false],
		# 아래 굽이 여울의 바위 둘
		[35, 31, "boulder", false],
		[32, 32, "boulder", false],

		# ── 동안 전망 자리 (갈매기가 서 있는 곳) ────────────────────
		[45, 4, "fence", true],          # 난간 셋 — 한 줄로
		[47, 4, "fence", true],
		[48, 4, "fence", true],
		[47, 5, "bench", true],
		# ── 둔치 모래톱 쉼터 (갈매기의 자리)
		[48, 10, "bench", true],
		[50, 4, "pebbles", false],
		[56, 8, "beach-grass", false],

		# ── 동안 숲 (오른쪽 가장자리를 두른다) ──────────────────────
		[57, 8, "pine", true],
		[60, 11, "pine", true],
		[60, 14, "tree", true],
		[59, 16, "shrub", false],

		# ── 남동 숲 (오른쪽 아래 귀퉁이) ────────────────────────────
		# 소나무를 마당 쪽(36,21)에 두면 장작(36,19)을 통째로 삼킨다 —
		# 나무는 네 칸 높이라 두 줄 아래에서도 위를 다 덮는다. 서쪽으로 뺐다.
		[47, 32, "pine", true],
		[50, 31, "tree", true],
		[53, 28, "shrub", false],

		# ── 서안: 서북 솔숲 (왼쪽 위 귀퉁이) ────────────────────────
		[3, 2, "shrub", false],
		[2, 5, "pine", true],
		[5, 8, "pine", true],
		[9, 7, "pine", true],

		# ── 서안: 참나무 그늘 (도토리 떨어진 자리 곁) ───────────────
		[14, 7, "tree", true],
		[18, 11, "tree", true],
		[20, 14, "shrub", false],

		# ── 서안: 북쪽 강가 갯풀, 첫 무리 ───────────────────────────
		[24, 2, "beach-grass", false],
		[26, 4, "pebbles", false],
		[23, 5, "beach-grass", false],

		# ── 서안: 북쪽 강가 갯풀, 둘째 무리 ─────────────────────────
		[32, 10, "beach-grass", false],
		[30, 11, "pebbles", false],
		[33, 13, "beach-grass", false],

		# ── 서안: 바깥 굽이 바위 (물살이 부딪는 쪽) ─────────────────
		[35, 16, "boulder", true],
		[36, 19, "boulder", true],
		[33, 20, "pebbles", false],

		# ── 서안: 그물 손질터 ───────────────────────────────────────
		[35, 26, "reception", true],
		[33, 25, "firewood", false],
		[32, 28, "net", false],

		# ── 서안: 남서 숲 (왼쪽 아래 귀퉁이) ────────────────────────
		[9, 26, "shrub", false],
		[6, 29, "tree", true],
		[12, 31, "pine", true],
		[3, 32, "pine", true],

		# ── 서안: 남쪽 강가 갯풀 ────────────────────────────────────
		[24, 31, "beach-grass", false],
		[21, 32, "beach-grass", false],
		[27, 32, "pebbles", false],
		# ── 1.5배로 넓히며 줄지어 선 소품 사이 틈을 메운 것
		[46, 4, "fence", true],
	]


func pickups() -> Array:
	return [
		[44, 16, "p-pebble"],      # 모래톱
		[45, 17, "p-pebble"],
		[12, 14, "p-flower"],
		[15, 10, "p-acorn"],
		# (35,4) 는 영영 못 줍는 자리였다 — 바로 위 (35,3) 에 선 갈매기가
		# 제 칸과 **아랫칸까지** 막는다(`Place._block_folk_tiles`). 줍는
		# 거리가 12px 라 한 칸(16px) 옆에 서서는 안 닿는다. 그래서 이 마을은
		# 다섯 개를 다 못 주웠고, "떨어진 것 다 줍기" 가 안 끝나
		# **방울못부터 그 뒤 2탄 전체가 안 열렸다.** 한 칸 아래로 내린다.
		[53, 8, "p-feather"],
	]


func spawn_tile() -> Vector2i:
	return Vector2i(15, 16)


## 호스텔 문 앞. 호스텔은 여섯 칸 높이(96px)라 마당 아래에 세우면
## 가게·표지판·정류장을 통째로 덮는다. 마당 위쪽에 세우고 문 앞은
## 그 아랫줄이다.
func sleep_tile() -> Vector2i:
	return Vector2i(54, 20)


func depart_tile() -> Vector2i:
	return Vector2i(60, 23)

func wanderer_tile() -> Vector2i:
	return Vector2i(21, 19)



## "강 굽이가 보이는 데크까지 가 보기" — 나루 데크 자체가 방문 지점이다.
func quest_zones() -> Array:
	return [
		["굽이나루:데크", Vector2i(54, 22), 56.0],
	]


func doors() -> Array:
	return [
		{"tile": Vector2i(59, 23),
			"scene": "res://scenes/journey/interiors/ShopInterior.tscn",
			"label": "가게 들어가기"},
		# 모래톱에서 강 안쪽으로 더 들어가는 샛길. **문이 아니라 길이다** —
		# 널 하나 건너 모래가 이어지는 자리다. `enter_key` 는 뜻이 없다.
		# 다 했다는 표시는 안쪽 자리에서 난다(`SidePathInterior`).
		{"tile": Vector2i(47, 17),
			"scene": "res://scenes/journey/interiors/SidePathInterior.tscn",
			"label": "모래톱 안쪽으로", "enter_key": "샛길입구"},
	]


func on_built() -> void:
	JourneyState.here = place_name()
	JourneyState.visit(place_name())

	# 카피바라 — 물범의 담수 버전. 조끼 차림, 나루 옆 가게를 지킨다.
	put_folk(Vector2i(50, 23), "capybara-a", "나루 가게 아저씨", "cap_guinaru", [
		["어서 와요. 강 여행은 또 다르지."],
		["강물이 굽어 도는 자리가 여기예요.", "서두를 것 없어요."],
		["길 묻는 손님한테도 늘 이렇게 말해요.", "천천히 가요."],
		["강 보면서 좀 쉬었다 가요."],
		["물소리 생각나면 또 와요."],
	], Vector2.DOWN, false, {}, "")

	# 갈매기 — 1탄과 같은 역할(높은 곳, 먼 곳을 동경). 여기선 강 굽이를 본다.
	put_folk(Vector2i(53, 5), "seagull", "둔치의 갈매기", "gu_gull", [
		["강도 바다처럼 넓어질 수 있대요."],
		["저 굽이까지 가 봤어요?", "데크에서 보면 더 잘 보여요."],
		["여긴 물살이 안 급해서 좋아요."],
		["데크 끝까지 같이 가 볼래요?"],
		["다음엔 더 먼 데서 만나요."],
	], Vector2.DOWN, false, {
		# 아침엔 난간에서 강을 내려다보고, 낮엔 모래톱에 내려앉고,
		# 저녁엔 데크에서 노을을 본다 — 하루가 흐르는 게 보인다.
		"아침": Vector2i(53, 5),
		"낮": Vector2i(36, 20),
		"저녁": Vector2i(50, 7),
	})

	# 수달 — 선택형 서브 NPC. 필수 퀘스트에 안 넣는다(강가 돌 위, 붙박이).
	put_folk(Vector2i(44, 19), "otter", "돌 위의 수달", "gu_otter", [
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
