class_name Quests
extends RefCounted
## 마을 퀘스트를 다 마쳤는지 셈한다. 상태를 안 갖는다 — `JourneyState`
## 에 이미 있는 기록에서 그때그때 다시 계산한다(`docs/quest-journey.md` 8절).
##
## 여기서 "정답"을 새로 안 만든다. 대화는 마음 칸, 줍기는 `taken`, 사진은
## `photos`, 나머지(가게·잠·방문)는 `Place`가 그때그때 남긴 `quest_flags`
## 하나만 본다.

## 다음 마을이 열리는 순서. 고향은 여기 없다 — 늘 열려 있다.
const ORDER := ["윤슬", "볕뉘", "가풀재", "하늬섬"]

## 마을마다 주울 것 개수. `places/*.gd` 의 `pickups()` 와 맞춰 둔다 —
## 씬을 새로 띄워 세는 대신 미리 세어 둔 숫자로 비교한다.
const PICKUP_TOTAL := {
	"윤슬": 6, "볕뉘": 6, "가풀재": 6, "하늬섬": 6,
}

## 마을마다 대화해야 하는 붙박이 folk_id 둘 (물범, 갈매기).
## 윤슬은 대화가 곧 물품 지급이라 따로 안 센다 — `has_map()`/`has_camera()`
## 가 이미 "그 사람과 첫 대화를 했다"는 뜻이다.
const TALK_FOLK := {
	"볕뉘": ["ju_seal", "ju_kid"],
	"가풀재": ["san_seal", "san_gull"],
	"하늬섬": ["do_seal", "do_kid"],
}

## 마을마다 "방문+사진" 짝. 방문 키는 `Place.quest_zones()` 가 남기고,
## 사진은 그 마을에서 한 장이라도 찍었으면 된다(어디를 찍었는지는 안 본다
## — 카메라를 갓 받은 사람에게 "정확히 이걸 찍어라"는 너무 빡빡하다).
const VISIT_KEY := {
	"윤슬": "윤슬:등대", "볕뉘": "볕뉘:능",
	"가풀재": "가풀재:능선", "하늬섬": "하늬섬:한바퀴",
}
## 사진까지 같이 요구하는 마을. 윤슬·가풀재·하늬섬은 카메라를 쓸 수
## 있을 때고, 볕뉘는 방문만으로 충분히 채워진다(대신 사진 퀘스트는
## 안 걸되, 찍었으면 자동으로 인정된다 — 아래 `photo_ok`).
const VISIT_NEEDS_PHOTO := {
	"윤슬": true, "볕뉘": false, "가풀재": true, "하늬섬": true,
}


static func has_map() -> bool:
	return JourneyState.count("map") > 0


static func has_camera() -> bool:
	return JourneyState.count("camera") > 0


static func _picked_all(village: String) -> bool:
	var need: int = PICKUP_TOTAL.get(village, 0)
	if need <= 0:
		return true
	var prefix := village + ":"
	var n := 0
	for k in JourneyState.taken.keys():
		if String(k).begins_with(prefix):
			n += 1
	return n >= need


static func _talked_all(village: String) -> bool:
	var ids: Array = TALK_FOLK.get(village, [])
	for id in ids:
		if JourneyState.heart(String(id)) < 1:
			return false
	return true


static func _photo_taken(village: String) -> bool:
	for p in JourneyState.photos:
		if String(p.get("place", "")) == village:
			return true
	return false


static func _visited(village: String) -> bool:
	var key: String = VISIT_KEY.get(village, "")
	if key == "":
		return true
	if not JourneyState.quest_done(key):
		return false
	if VISIT_NEEDS_PHOTO.get(village, false):
		return _photo_taken(village)
	return true


static func _shop_entered(village: String) -> bool:
	return JourneyState.quest_done("%s:가게" % village)


## 그 마을의 퀘스트를 다 마쳤나.
static func village_cleared(village: String) -> bool:
	match village:
		"윤슬":
			return has_map() and has_camera() \
				and _shop_entered("윤슬") and _visited("윤슬") \
				and _picked_all("윤슬") \
				and JourneyState.quest_done("윤슬:잠")
		"볕뉘", "가풀재", "하늬섬":
			return _talked_all(village) and _shop_entered(village) \
				and _visited(village) and _picked_all(village)
		_:
			return true    # 고향 등 목록 밖 장소는 늘 "클리어"로 친다


## 마을마다 물범·갈매기를 부르는 이름. 화면에 보여 줄 때만 쓴다.
const FOLK_NAME := {
	"ju_seal": "쿼빵집 아주머니", "ju_kid": "능 지키는 아이",
	"san_seal": "쿼면집 아저씨", "san_gull": "부두 청년",
	"do_seal": "쿼귤 파는 할머니", "do_kid": "자전거 탄 아이",
}

## 마을마다 "방문+사진" 퀘스트 한 줄에 붙일 이름.
const VISIT_LABEL := {
	"윤슬": "등대곶까지 가서 사진 찍기",
	"볕뉘": "능 한 바퀴 걷기",
	"가풀재": "능선까지 올라 노을 사진 찍기",
	"하늬섬": "섬 한 바퀴 돌기",
}


## 배낭(행복첩)에 보여 줄 "이 마을에서" 목록. `[{"label":..,"done":..}]`.
## 목록 밖 장소(고향·잿마루)면 빈 배열 — 새 판정을 안 만들고, 3.5절과
## 4절의 퀘스트를 순서 그대로 다시 읽는 것뿐이다.
static func quest_list(village: String) -> Array:
	if village == "윤슬":
		return [
			{"label": "가게 할머니와 인사하고 지도 받기", "done": has_map()},
			{"label": "갈매기 소년과 인사하고 카메라 받기", "done": has_camera()},
			{"label": "가게 들어가 보기", "done": _shop_entered("윤슬")},
			{"label": VISIT_LABEL["윤슬"], "done": _visited("윤슬")},
			{"label": "떨어진 것 다 줍기", "done": _picked_all("윤슬")},
			{"label": "쿼스텔에서 하루 자기", "done": JourneyState.quest_done("윤슬:잠")},
		]
	if ORDER.has(village):
		var ids: Array = TALK_FOLK.get(village, [])
		var out: Array = []
		if ids.size() >= 1:
			out.append({"label": "%s와 인사하기" % FOLK_NAME.get(ids[0], ""),
				"done": JourneyState.heart(String(ids[0])) >= 1})
		out.append({"label": "가게 들어가 보기", "done": _shop_entered(village)})
		if ids.size() >= 2:
			out.append({"label": "%s와 인사하기" % FOLK_NAME.get(ids[1], ""),
				"done": JourneyState.heart(String(ids[1])) >= 1})
		out.append({"label": VISIT_LABEL.get(village, "방문해 보기"),
			"done": _visited(village)})
		out.append({"label": "떨어진 것 다 줍기", "done": _picked_all(village)})
		return out
	return []


## 이 마을에 지금 갈 수 있나. 다녀온 곳은 언제나 그렇다 — 잠그는 건
## **아직 안 가 본 다음 마을**뿐이다 (`docs/quest-journey.md` 0절).
static func is_unlocked(village: String) -> bool:
	if village == "고향":
		return true
	if JourneyState.visited.has(village):
		return true
	var idx := ORDER.find(village)
	if idx <= 0:
		return true
	return village_cleared(ORDER[idx - 1])
