class_name Items
extends RefCounted
## 마을 선반 — 값이 없는 가게.
##
## 가게 건물과 간판은 그대로 두되(윤슬가게·빵집·귤가게), **경제는 안
## 만든다.** `CLAUDE.md` 에 "돈벌이 압박을 만들지 않는다" 고 못 박아
## 두었고, 값을 붙이는 순간 모으고 아끼고 비교하는 게임이 된다.
##
## 그래서 사고파는 대신 이렇게 한다:
##
##   들어간다 · 살펴본다 · 여행에서 한 일 때문에 새 물건이 놓인다 ·
##   하나를 챙긴다 · 나중에 다른 인연에게 보여 준다
##
## 지키는 선:
## - **값·잔액·재고·품절·기간 한정이 없다.** 이 파일에 `price` 같은
##   낱말이 아예 없어야 한다 (테스트가 검사한다)
## - **수집품을 쓰지 않는다.** 보여 주기만 한다 — 개수가 줄지 않는다
## - **조건을 채우면 언제든 받는다.** 하나를 골랐다고 다른 게 잠기지
##   않고, 마을을 떠났다 와도 그대로 있다
## - 먹거리는 배낭에 안 넣는다. 그 자리에서 맛보고 기록만 남긴다 —
##   며칠째 안 녹는 아이스크림을 배낭에 이고 다니지 않는다

## 마을마다 선반 셋. 시스템은 하나고 **데이터만 마을별**이다.
##
## food  : 오늘의 먹거리. 골라서 그 자리에서 맛본다 (배낭에 안 들어간다)
## keep  : 이 마을 물건. 조건을 채우면 선반에 놓이고, 챙기면 배낭에 남는다
## show  : 기억 선반. 주운 것을 보여 주면 이야기가 열린다 (안 없어진다)
const SHELF := {
	"윤슬": {
		"owner": "가게 할머니",
		"hello": [
			["천천히 둘러봐.", "살 것도 없지만 볼 건 있어."],
			["여행하다 뭐 주웠거든,", "저기 선반에 올려놔 봐."],
		],
		"food": [
			{"id": "f-icecream", "name": "아이스크림", "icon": "i-icecream",
				"line": "차가운 게 혀에서 천천히 녹는다.",
				"memory": "가게에서 아이스크림을 하나 먹었다."},
			{"id": "f-tea", "name": "따뜻한 차", "icon": "i-tea",
				"line": "김이 안경도 없는 얼굴로 올라온다.",
				"memory": "가게에서 따뜻한 차를 한 잔 마셨다."},
		],
		"keep": [
			{"id": "k-marble", "name": "유리구슬", "icon": "i-marble",
				# 숨은 자취를 다 찾아야 선반에 놓인다. 값이 아니라
				# **여행에서 한 일**이 조건이다.
				"need": {"quest": "윤슬:샛길:자취"},
				"locked": "빛나는 자취를 다 찾으면 할머니가 꺼내 준다고 했다.",
				"desc": "윤슬의 저녁 바다를 닮은 구슬.",
				"got": ["저녁 바다를 닮은 구슬이야.",
					"이번 여행을 기억하고 싶으면 가져가."],
				"memory": "윤슬가게에서 유리구슬을 챙겼다."},
		],
		"show": [
			{"id": "p-shell", "lines": [
				"조개를 올려놓았다. 할머니가 잠깐 들여다본다.",
				"이런 건 백사장에 널렸는데,", "줍는 사람은 드물어."]},
			{"id": "p-seaglass", "lines": [
				"바다유리를 올려놓았다. 할머니가 창가로 들어 비춰 본다.",
				"오래 굴러야 이렇게 돼.", "급한 사람은 못 찾아."]},
			{"id": "p-seaweed", "lines": [
				"미역을 올려놓았다. 할머니가 손끝으로 두께를 가늠해 본다.",
				"물때를 잘 맞춰 걷었네.", "다음 물때엔 또 다를 거야."]},
			{"id": "p-conch", "lines": [
				"소라를 올려놓았다. 할머니가 귀에 대 보라며 웃는다.",
				"파도 소리가 들린다지.", "실은 그냥 빈 껍데기 소리야."]},
		],
	},
}


static func has(village: String) -> bool:
	return SHELF.has(village)


static func of(village: String) -> Dictionary:
	return SHELF.get(village, {})


## 그 마을 물건을 받을 수 있게 됐나. 조건은 **여행에서 한 일**이다.
static func unlocked(village: String, item: Dictionary) -> bool:
	var need: Dictionary = item.get("need", {})
	if need.has("quest"):
		# 샛길·매듭 열쇠는 `Quests` 가 판정한다
		var key := String(need["quest"])
		if key.contains("샛길"):
			return Quests.side_done(village, key)
		return JourneyState.quest_done(key)
	if need.has("found"):
		return JourneyState.count(String(need["found"])) > 0
	if need.has("heart"):
		var h: Array = need["heart"]
		return JourneyState.heart(String(h[0])) >= int(h[1])
	return true


## 이미 챙겼나. 챙긴 것은 배낭에 그대로 있다 — 따로 세는 곳을 안 만든다.
static func kept(item: Dictionary) -> bool:
	return JourneyState.count(String(item["id"])) > 0


## 이미 맛봤나. 먹거리는 배낭에 안 들어가므로 표시로만 남긴다.
static func tasted(village: String, item: Dictionary) -> bool:
	return JourneyState.quest_done("%s:맛봄:%s" % [village, item["id"]])


## 이미 보여 줬나.
static func shown(village: String, id: String) -> bool:
	return JourneyState.quest_done("%s:보여줌:%s" % [village, id])


## 지금 이 마을 선반에 볼 것이 남았나. 가게에 들어갈 이유가 되는지를
## 이 하나로 판단한다 (문 앞 버튼 글씨를 바꾸는 데 쓴다).
static func something_new(village: String) -> bool:
	if not has(village):
		return false
	var d := of(village)
	for f in d.get("food", []):
		if not tasted(village, f):
			return true
	for k in d.get("keep", []):
		if unlocked(village, k) and not kept(k):
			return true
	for s in d.get("show", []):
		if JourneyState.count(String(s["id"])) > 0 \
				and not shown(village, String(s["id"])):
			return true
	return false
