extends Place
## 잿마루 — 쿼카컴퍼니가 있는 잿빛 도시. 두 번 온다 (`docs/redesign-dream.md` 2절).
##
## **처음**은 프롤로그 - 야근하다 책상에 엎드려 잠든 뒤, 눈을 뜨니 사무실이
## 어딘가 이상하다. 여기가 꿈결의 입구다. 동료도 경비 아저씨도 먼저 떨어진
## 사람들이다. 걸어 나오면서 걷기·말 걸기를 배우고, 정류장에서 첫 구역을 고른다.
##
## **두 번째**는 끝판 - 꽃눈벌 보스를 쓰러뜨리면 꿈이 금 가고, 정류장에
## "잿마루 타워" 가 나타난다(`Quests.TOWER`). 같은 사무실이 거꾸로 선 회사가
## 되어 회사 몬스터로 가득하고, 꼭대기에 야근 대마왕이 있다(`tower()`).
##
## **회사를 악당으로 만들지 않는다.** 대마왕은 누구 한 사람이 아니라
## 떨어진 사람들의 "야근하는 마음" 이 뭉친 것이다.

func place_name() -> String:
	return "잿마루"


## 화면에는 **"사무실"** 로 보여 준다.
##
## 잿마루는 회사가 선 잿빛 도시 이름인데, 처음 잡은 사람에게 그 말은
## 아무 뜻이 아니다 — 지금 서 있는 데가 어디인지부터 알아야 한다.
## 저장 열쇠(`place_name()`)는 "잿마루" 그대로 둔다. 바꾸면 지난
## 세이브의 퀘스트 표시("잿마루:본:창밖")가 통째로 어긋난다.
func display_name() -> String:
	return "꿈속 잿마루 타워" if tower() else "꿈속 사무실"


## 끝판인가 - 꽃눈벌 보스를 쓰러뜨려 꿈이 금 간 뒤다.
func tower() -> bool:
	return Battle.boss_down(String(Quests.ORDER[-1]))


## 타워에서만 싸운다. 프롤로그의 사무실은 싸움이 없다.
func shades() -> Array:
	return Battle.tower_spawns() if tower() else []


func _init() -> void:
	legend = {
		"o": "office-carpet",  # 30층 사무실 바닥. 실내다
		"l": "lobby-marble",   # 엘리베이터 앞과 1층 로비. 같은 대리석이다
		"n": "granite-step",   # 로비에서 거리로 내려가는 층계
		"c": "cobble",         # 회사 앞 인도
		"a": "asphalt",        # 새벽 찻길. 잿빛 도시니까 아스팔트다
		"g": "grass",          # 인도 옆 화단
		".": "granite-step",   # 찻길 갓길. 주황 흙이라 이 잿빛 도시에서
		                       # 혼자 따뜻한 해변 띠처럼 보였다
	}


## 위가 사무실, 가운데가 로비, 아래가 회사 앞. 걸어 내려오면 나간다.
##
## **가로줄로 층층이 자르지 않는다.** 예전에는 44칸을 곧게 가로지르는
## 띠 세 개였고, 그러면 마을이 아니라 줄무늬로 보였다. 지금은
## 엘리베이터 앞 대리석이 카펫 속으로 혀처럼 파고들고, 층계는 로비
## 양옆에서 시작해 가운데로 내려오며, 인도와 찻길은 서로 물려 있다.
## 어디에도 곧은 선이 한 줄로 지나가지 않는다.
##
## 가로 35칸. 3배로 당겨 봐도 지도 밖 회색이 안 드러나는 가장 좁은 폭
## 언저리다 (34칸이 한계). 좁혀야 걸어 다닐 맛이 난다.
func ground_map() -> String:
	return """
ooooooooooooooooooooooooooooooooooo
ooooooooooooooooooooooooooooooooooo
ooooooooooooooooooooooooooooooooooo
ooooooooooooooolllllooooooooooooooo
oooooooooooooollllllloooooooooooooo
oooooooooooooollllllloooooooooooooo
ooooooooooolllllllllllllooooooooooo
ooooooolllllllllllllllllllllooooooo
ooolllllllllllllllllllllllllllllooo
lllllllllllllllllllllllllllllllllll
lllllllnnnnnnnllllllllnnnnnnnllllll
nnnnnnnnnnnnlllllllllllnnnnnnnnnnnn
ccccccccccccnnnnnnnnnnncccccccccccc
gggccccccccccccnnnnncccccccccccgggg
ggggccccccccccaaaaaaaccccccccccgggg
ggccccccccaaaaaaaaaaaaaaaccccccgggg
ccccccaaaaaaaaaaaaaaaaaaaaaaacccggg
....aaaaaaaaaaaaaaaaaaaaaaaaaaa....
.......aaaaaaaaaaaaaaaaaaaaa.......
"""


## 소품은 **덩어리로** 놓는다. 하나씩 흩뿌리면 넓기만 하고 허전하다.
## 책상 둘에 의자 둘이 모여 한 팀 자리가 되고, 화분 둘이 모여 로비
## 화단이 되고, 나무와 덤불이 모여 인도 화단이 된다.
##
## 대신 **길은 비워 둔다.** 제 자리(7,6)에서 층계를 지나 정류장(18,15)
## 까지 내려가는 길에는 막는 것을 하나도 두지 않았다.
func props() -> Array:
	return [
		# ── 30층 사무실 ────────────────────────────────────────────
		# 창밖으로 도시 불빛. 창은 안 막는다 — 벽에 붙어 있는 것이다
		[2, 1, "office-window", false],
		[8, 1, "office-window", false],
		[14, 1, "office-window", false],
		[20, 1, "office-window", false],
		[26, 1, "office-window", false, true],   # 바로 아래(26,2)가 "창밖" 자리다
		[32, 1, "office-window", false],
		[0, 4, "cabinet", true],
		# 왼쪽 팀 자리
		[3, 3, "desk", true],
		[4, 3, "desk", true],
		[3, 4, "office-chair", true],
		[4, 4, "office-chair", true],
		# 내 자리. 여기 의자 밑에서 일어난다
		[7, 4, "desk", true],
		[7, 5, "office-chair", true],
		[10, 3, "desk", true],
		[10, 4, "office-chair", true],
		[9, 6, "flower-pots", true],
		# 오른쪽 팀 자리
		[23, 3, "desk", true],
		[24, 3, "desk", true],
		[23, 4, "office-chair", true],
		[24, 4, "office-chair", true],
		[30, 3, "desk", true],
		[30, 4, "office-chair", true],
		[34, 4, "cabinet", true],
		[33, 6, "flower-pots", true],

		# ── 1층 로비 ───────────────────────────────────────────────
		[4, 10, "cabinet", true],
		[8, 9, "flower-pots", true],
		[9, 9, "flower-pots", true],
		[27, 9, "flower-pots", true],
		# 안내 데스크. 셋을 붙여 놓아야 카운터로 보인다
		[15, 10, "reception", true],
		[16, 10, "reception", true],
		[17, 10, "reception", true],
		[24, 10, "return-box", true, true],   # "반납함" 자리와 같은 칸
		# 층계참에 놓인 대기 의자
		[10, 11, "bench", true],
		[12, 11, "bench", true],
		[22, 11, "bench", true],

		# ── 회사 앞 새벽 거리 ──────────────────────────────────────
		[8, 12, "bench", true],
		[10, 12, "bench", true],
		# 왼쪽 화단
		[1, 13, "tree", true],
		[3, 14, "shrub", true],
		[4, 13, "street-lamp", true],
		[7, 13, "shrub", true],
		[12, 13, "mailbox", true],
		# 회사 앞 가로등. "회사 앞" 자리(13,13)가 올려다보는 것이다 -
		# 이게 없으면 빈 인도 한 칸에 이름표만 뜬다.
		[13, 12, "street-lamp", true],
		# 문 닫은 좌판 둘. 새벽이라 아무도 없다
		[23, 13, "stall", true],
		[25, 13, "stall", true],
		[28, 13, "street-lamp", true],
		# 오른쪽 화단
		[34, 13, "shrub", true],
		[33, 14, "pine", true],
		[31, 15, "shrub", true],
		[33, 16, "tree", true],
		# 정류장 언저리. 표지판은 안 막는다 — 그 위로 지나갈 수 있어야 한다
		[9, 15, "street-lamp", true],
		[20, 15, "signpost", false],
		[22, 15, "bench", true],
		[25, 15, "street-lamp", true],
		# 찻길 갓길. 지도 끝이 맨바닥이면 세상이 끊겨 보인다
		[0, 18, "fence", true],
		[1, 18, "fence", true],
		[2, 18, "fence", true],
		[32, 18, "fence", true],
		[33, 18, "fence", true],
		[34, 18, "fence", true],
	]


## 프롤로그에서는 아무것도 안 줍는다. 챙길 건 세 개뿐이었다.
func pickups() -> Array:
	return []


## 자리에 앉은 채로 시작한다. 바로 위가 내 의자와 책상이다.
func spawn_tile() -> Vector2i:
	return Vector2i(7, 6)


## 여기서는 못 잔다. 오늘은 집에 가는 날이 아니다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


## 회사 앞. 여기서 처음으로 어디 갈지 고른다. 바로 옆(20,15)에 표지판.
func depart_tile() -> Vector2i:
	return Vector2i(18, 15)


func on_built() -> void:
	JourneyState.here = place_name()
	# 밤 11시에서 시작한다
	JourneyState.minutes = 23 * 60

	var t := tower()
	# 주고받는 말은 **누가 하는지 적어 준다.** 이름 하나만 찍혀 있으면
	# 혼잣말로 읽힌다 (`journey_say.gd` 의 `say()` 참고).
	put_folk(Vector2i(22, 5), "seagull", "옆자리 동료", "coworker", [
		[["옆자리 동료", "…부장님 목소리가 들려요. 위층에서."],
			["옆자리 동료", "\"내일 아침까지 부탁해요.\" 계속 저 말만 해요."]],
		[["옆자리 동료", "저 위에 있는 게 대마왕이래요. 조심해요."]],
	] if t else [
		[["옆자리 동료", "어, 일어났어요? 여기 꿈결이에요."], ["나", "…꿈결?"],
			["옆자리 동료", "야근하다 잠들면 오는 곳이요. 저도 방금 떨어졌어요."]],
		[["옆자리 동료", "밖에 나가면 몬스터가 있대요. 조심해요."]],
	], Vector2.DOWN, false, {
		# 아침엔 엘리베이터 앞 대리석 — 30층에 막 올라와 하루를 시작한다.
		# 프롤로그가 밤 11시(저녁 칸)에 시작하므로, 저녁 자리를 옮기면
		# 옆자리 장면 자체가 사라진다.
		"아침": Vector2i(17, 4),
		"낮": Vector2i(22, 5),
		"저녁": Vector2i(22, 5),
	})

	# 로비 경비 아저씨 - 꿈결 입구의 문지기. 쿼카의 대답 한 줄이 이 모험의
	# 시작이다.
	put_folk(Vector2i(18, 11), "seal", "경비 아저씨", "guard", [
		[["경비 아저씨", "여기가 꿈의 끝이야."],
			["경비 아저씨", "저 녀석만 쓰러뜨리면 다들 개운하게 깰 거야."]],
		[["경비 아저씨", "…무리하지 말고. 정류장으로 돌아가도 돼."]],
	] if t else [
		[["경비 아저씨", "왔구먼. 꿈결 입구에 온 걸 환영하네."],
			["나", "…저 그냥 잠깐 졸았는데요."],
			["경비 아저씨", "다들 그렇게 말하지. 정류장에서 첫 구역을 고르게."]],
		[["경비 아저씨", "문 밖은 모험이야. 조심히 가."]],
	], Vector2.RIGHT, false, {
		# 아침엔 바깥 층계 위에서 출근 행렬에 인사한다. 낮부터 밤까지는
		# 안내 데스크 옆 제자리 - 반납함 쪽을 보고 선 자리다.
		"아침": Vector2i(20, 12),
		"낮": Vector2i(18, 11),
		"저녁": Vector2i(18, 11),
	})

	# 창밖. 확대해야 보인다
	put_spot(Vector2i(26, 2), "창밖", [
		"하늘에서 결재 서류가 비처럼 내린다.",
		"멀리서 알람 소리가 들린다.",
		"…아침이 가까운 걸까.",
	] if t else [
		"창밖 도시 불빛이 네모나다. 픽셀처럼.",
		"하늘에 커다란 글자가 떠 있다. 꿈결 온라인.",
		"…어디로 가는 걸까.",
	])

	# 반납함. 사원증 대신 모험가 증표가 나온다
	put_spot(Vector2i(24, 10), "반납함", [
		"반납함이 서류로 꽉 찼다.",
		"…이제 넣을 것이 없다.",
	] if t else [
		"사원증을 넣었다.",
		"덜컹. 대신 반짝이는 증표가 튀어나왔다.",
		"꿈나그네 LV 1.",
	])

	# 정류장 (18,15) 과 겹치지 않게 인도 쪽으로 비켜 둔다.
	put_spot(Vector2i(13, 13), "회사 앞", [
		"정류장 너머로 돌아갈 수도 있다. 아직 준비가 덜 됐다면.",
	] if t else [
		"오늘은 퇴근이 아니라 모험이다.",
	])
	# 여기까지 왔으면 프롤로그를 본 것이다. 다음부터는 건너뛸 수 있다.
	# 이 표시가 없으면 메인화면의 "건너뛸까요" 가 영영 안 뜬다.
	SaveManager.mark_prologue_done()


## 여기는 거의 실내다 — 30층 사무실과 로비.
##
## 바깥 하늘빛(`Place.SKY`)을 그대로 곱히면 밤 11시에 시작하는 프롤로그
## 내내 **사무실까지 통째로 남색으로 죽는다.** 형광등 아래여야 한다.
## 살짝 눌린 따뜻한 톤까지만 간다 — 창밖 장면과 새벽 거리의 어둑함은
## 이 정도로도 충분히 읽힌다.
func sky_tint(_mins: float) -> Color:
	var n := JourneyState.night_amount()
	return Color(1, 1, 1).lerp(Color(0.93, 0.86, 0.74), n * 0.85)
