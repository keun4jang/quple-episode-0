class_name Rewards
extends RefCounted
## 할 일을 마치면 받는 것 (`docs/items-rewards.md` 3절).
##
## 여태 할 일을 마치면 "다 했어요!" 한 번이 전부였다 — 받는 것이 없으니
## 다음 마을이 열리는 것 말고는 할 이유가 없었다. 이제 **줄마다 받는 것이
## 있다.** 목록에서 미리 보이고, 마치면 그 자리에서 손에 들어온다.
##
## 상태를 안 갖는다. 받았다는 표시는 `quest_flags` 의 `보상:마을:열쇠` 에
## 남기고, 무엇을 받는지는 여기 표에서 그때그때 다시 찾는다.
##
## 나누는 기준은 **그 일의 무게**다:
##   가벼운 일(인사·가게·줍기·잠)      → 먹을 것 · 경험 6
##   무게 있는 일(방문+사진·마을만의 것·이야기 완결) → 기념품 · 경험 12
##   마을 하나를 다 돌기               → 여행 도장 · 경험 20

const XP_LIGHT := 6
const XP_KEEP := 12
const XP_VILLAGE := 20

## 마을마다: 인사 보상 둘(그 마을 먹을 것), 방문+사진 기념품, 그 마을만의 것
## 기념품, 도장. 윤슬은 매듭·샛길이라 `SPECIAL` 에서 줄마다 적는다.
const VILLAGE := {
	"윤슬": {"snacks": ["b-fishcake", "b-gimbap"], "visit": "", "local": "",
		"stamp": "st-yunseul"},
	"볕뉘": {"snacks": ["b-redbean-bread", "b-garaetteok"], "visit": "k-roof-tile",
		"local": "k-clay-bell", "stamp": "st-byeotnwi"},
	"가풀재": {"snacks": ["b-noodle", "b-potato"], "visit": "k-ridge-stone",
		"local": "k-anchor", "stamp": "st-gapuljae"},
	"하늬섬": {"snacks": ["b-citrus-bread", "b-citrus-juice"], "visit": "k-basket",
		"local": "k-pinwheel", "stamp": "st-hanuiseom"},
	"굽이나루": {"snacks": ["b-corn", "b-plum-tea"], "visit": "k-oar",
		"local": "k-river-stone", "stamp": "st-gubinaru"},
	"방울못": {"snacks": ["b-cream-bread", "b-lotus-tea"], "visit": "k-lotus-leaf",
		"local": "k-wind-chime", "stamp": "st-bangulmot"},
	"갈밭머리": {"snacks": ["b-chestnut", "b-sujeonggwa"], "visit": "k-reed-flute",
		"local": "k-nest", "stamp": "st-galbatmeori"},
	"솔은재": {"snacks": ["b-acorn-jelly", "b-pine-tea"], "visit": "k-gold-cone",
		"local": "k-pine-sachet", "stamp": "st-soleunjae"},
	"꽃눈벌": {"snacks": ["b-hwajeon", "b-strawberry"], "visit": "k-petal-jar",
		"local": "k-scarecrow", "stamp": "st-kkonnunbeol"},
}

## 어느 마을에서나 같은 모양인 가벼운 일. 어디서나 나는 것을 준다.
const COMMON := {
	"door:가게": "b-riceball",
	"door:등대안": "b-sikhye",
	"door:능입구": "b-sikhye",
	"pickup:": "b-sweetpotato",
	"sleep:": "b-barleytea",
}

## 줄마다 손으로 적는 곳 — 윤슬(매듭·샛길), 잿마루, 고향.
const SPECIAL := {
	"윤슬": {
		"윤슬:매듭:1": "b-fishcake",
		"윤슬:매듭:2": "b-gimbap",
		# 이야기의 끝. "빛은 한 번에 보이지 않는다" 를 손에 쥐여 준다.
		"윤슬:매듭:3": "k-lens",
		"윤슬:샛길:가게": "b-riceball",
		"윤슬:샛길:등대안": "b-sikhye",
		"윤슬:샛길:부두": "k-rope",
		"윤슬:샛길:고르기": "b-yakgwa",
		"윤슬:샛길:자취": "b-honeycake",
		"윤슬:샛길:채집": "b-sweetpotato",
	},
	"잿마루": {
		"talk:coworker": "b-cookie",
		"prop:창밖": "b-candy",
		# 사원증을 넣고 나면 목걸이 줄만 남는다.
		"prop:반납함": "k-lanyard",
		"talk:guard": "b-yakgwa",
		"prop:회사 앞": "b-sweetpotato",
		"depart:": "k-ticket",
	},
	"고향": {
		"talk:mom": "b-lunchbox",
		"talk:dad": "b-apple",
		"talk:sibling": "b-candy",
		"prop:평상": "k-family-photo",
	},
}

## 마을 하나를 다 돌았다는 칸의 열쇠.
const VILLAGE_KEY := "마을"


## 그 줄(열쇠)을 마치면 무엇을 받나. 없으면 "".
static func item_for(village: String, key: String) -> String:
	var sp: Dictionary = SPECIAL.get(village, {})
	if sp.has(key):
		return String(sp[key])
	var v: Dictionary = VILLAGE.get(village, {})
	if v.is_empty():
		return ""
	if key == VILLAGE_KEY:
		return String(v["stamp"])
	if COMMON.has(key):
		return String(COMMON[key])
	if key.begins_with("talk:"):
		var ids: Array = Quests.TALK_FOLK.get(village, [])
		var i := ids.find(key.substr(5))
		var snacks: Array = v["snacks"]
		return String(snacks[maxi(0, i) % snacks.size()])
	if key == "visit:" + String(Quests.VISIT_KEY.get(village, "")):
		return String(v["visit"])
	if Quests.LOCAL.has(village):
		var loc: Array = Quests.LOCAL[village]
		if key == "%s:%s" % [loc[0], loc[1]]:
			return String(v["local"])
	return ""


## 경험. 받는 것의 무게를 따른다.
static func xp_for(village: String, key: String) -> int:
	if key == VILLAGE_KEY:
		return XP_VILLAGE
	var k := Catalog.kind_of(item_for(village, key))
	if k == "keep" or k == "stamp":
		return XP_KEEP
	return XP_LIGHT


## 목록의 한 줄(`Quests.quest_list` 의 사전)에 붙는 보상.
static func for_row(village: String, row: Dictionary) -> Dictionary:
	var key := Quests.row_id(row)
	return {"item": item_for(village, key), "xp": xp_for(village, key)}


## 이 마을에서 받을 수 있는 것 전부. `[{key, label, item, xp, done, step}]`.
##
## **목록 줄과 똑같지 않다.** 매듭 마을(윤슬)의 이야기 줄은 단계마다
## 같은 줄이 모양만 바뀐다 - 줄 전체는 세 단계를 다 해야 "다 했다" 가
## 된다. 그러면 첫 두 단계는 보상 없이 지나간다. 그래서 여기서는 단계를
## 하나씩 따로 센다.
static func entries(village: String) -> Array:
	var out: Array = []
	if Quests.KNOT.has(village):
		var steps: Array = Quests.KNOT[village]["steps"]
		for i in steps.size():
			var st: Dictionary = steps[i]
			out.append(_entry(village, String(st["key"]), String(st["label"]),
				Quests.knot_step_done(village, i), true))
		for e in Quests.SIDE.get(village, []):
			out.append(_entry(village, String(e["key"]), String(e["label"]),
				Quests.side_done(village, String(e["key"])), false))
	else:
		for q in Quests.quest_list(village):
			out.append(_entry(village, Quests.row_id(q), String(q.get("label", "")),
				bool(q.get("done", false)), false))
	if VILLAGE.has(village):
		out.append(_entry(village, VILLAGE_KEY, "이 마을을 다 돌기",
			Quests.village_cleared(village), false))
	return out


static func _entry(village: String, key: String, label: String, done: bool,
		step: bool) -> Dictionary:
	return {"key": key, "label": label, "item": item_for(village, key),
		"xp": xp_for(village, key), "done": done, "step": step}


static func _flag(village: String, key: String) -> String:
	return "보상:%s:%s" % [village, key]


static func claimed(village: String, key: String) -> bool:
	return JourneyState.quest_done(_flag(village, key))


## 받는다. **두 번 받지 않는다.** 레벨이 오르면 그 사건들을 돌려준다.
##
## `quiet` 이면 얻은 것 카드를 안 띄운다 - 옛 세이브에 밀린 것을 한꺼번에
## 챙겨 줄 때 스무 장이 우르르 뜨지 않게.
static func claim(village: String, e: Dictionary, quiet := false) -> Array:
	var key := String(e.get("key", ""))
	if key == "" or claimed(village, key):
		return []
	JourneyState.mark_quest(_flag(village, key))
	var item := String(e.get("item", ""))
	if item != "" and Catalog.has(item):
		JourneyState.pick(item, 1, quiet)
	return Battle.gain_xp(int(e.get("xp", 0)))


## 마쳤는데 아직 안 받은 것들.
static func unclaimed(village: String) -> Array:
	var out: Array = []
	for e in entries(village):
		if bool(e["done"]) and not claimed(village, String(e["key"])):
			out.append(e)
	return out
