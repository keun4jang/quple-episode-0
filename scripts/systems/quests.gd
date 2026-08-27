class_name Quests
extends RefCounted
## 마을 퀘스트를 다 마쳤는지 셈한다. 상태를 안 갖는다 — `JourneyState`
## 에 이미 있는 기록에서 그때그때 다시 계산한다(`docs/quest-journey.md` 8절).
##
## 여기서 "정답"을 새로 안 만든다. 대화는 마음 칸, 줍기는 `taken`, 사진은
## `photos`, 나머지(가게·잠·방문)는 `Place`가 그때그때 남긴 `quest_flags`
## 하나만 본다.

## 다음 마을이 열리는 순서. 고향은 여기 없다 — 늘 열려 있다.
##
## 뒤 셋(굽이나루·방울못·갈밭머리)은 2탄 "담수 3부작" — 1탄 넷을 다
## 돌아본 사람에게만 열린다. 카피바라(물범의 강가 버전)를 여기서
## 처음 만난다.
const ORDER := [
	"윤슬", "볕뉘", "가풀재", "하늬섬",
	"굽이나루", "방울못", "갈밭머리",
	"솔은재", "꽃눈벌",
]

## 마을마다 주울 것 개수. `places/*.gd` 의 `pickups()` 와 맞춰 둔다 —
## 씬을 새로 띄워 세는 대신 미리 세어 둔 숫자로 비교한다.
const PICKUP_TOTAL := {
	"윤슬": 6, "볕뉘": 6, "가풀재": 6, "하늬섬": 6,
	"굽이나루": 5, "방울못": 5, "갈밭머리": 5,
	"솔은재": 5, "꽃눈벌": 5,
}

## 마을마다 대화해야 하는 붙박이 folk_id (물범/카피바라, 갈매기).
## 윤슬은 대화가 곧 물품 지급이라 따로 안 센다 — `has_map()`/`has_camera()`
## 가 이미 "그 사람과 첫 대화를 했다"는 뜻이다. 2탄부터는 카피바라
## 하나만 센다 — 갈매기는 방문+사진으로 대신한다(결 그대로 재사용).
const TALK_FOLK := {
	"볕뉘": ["ju_seal", "ju_kid"],
	"가풀재": ["san_seal", "san_gull"],
	"하늬섬": ["do_seal", "do_kid"],
	"굽이나루": ["cap_guinaru"],
	"방울못": ["cap_bangul"],
	"갈밭머리": ["cap_galbat"],
	"솔은재": ["cap_sol"],
	"꽃눈벌": ["cap_kkot"],
}

## 마을마다 "방문+사진" 짝. 방문 키는 `Place.quest_zones()` 가 남기고,
## 사진은 그 마을에서 한 장이라도 찍었으면 된다(어디를 찍었는지는 안 본다
## — 카메라를 갓 받은 사람에게 "정확히 이걸 찍어라"는 너무 빡빡하다).
const VISIT_KEY := {
	"윤슬": "윤슬:등대", "볕뉘": "볕뉘:능",
	"가풀재": "가풀재:능선", "하늬섬": "하늬섬:한바퀴",
	"굽이나루": "굽이나루:데크", "방울못": "방울못:데크",
	"갈밭머리": "갈밭머리:전망대", "솔은재": "솔은재:전망",
	"꽃눈벌": "꽃눈벌:도랑",
}
## 사진까지 같이 요구하는 마을. 윤슬·가풀재·하늬섬은 카메라를 쓸 수
## 있을 때고, 볕뉘는 방문만으로 충분히 채워진다(대신 사진 퀘스트는
## 안 걸되, 찍었으면 자동으로 인정된다 — 아래 `photo_ok`).
const VISIT_NEEDS_PHOTO := {
	"윤슬": true, "볕뉘": false, "가풀재": true, "하늬섬": true,
	"굽이나루": true, "방울못": true, "갈밭머리": true, "솔은재": true,
	"꽃눈벌": true,
}

## 잠자기까지 요구하는 마을. 1탄은 윤슬 하나(처음 배우는 자리)로
## 충분했지만, 2탄부터는 "쉬어 가는 마을"이라는 성격을 그대로 퀘스트로
## 옮긴다(다른 창 브레인스토밍 결과, `docs/planning/` 참고).
const NEEDS_SLEEP := {
	"윤슬": true, "굽이나루": true, "방울못": true, "갈밭머리": true,
	"솔은재": true, "꽃눈벌": true,
}

## 등대가 있어서 그 안(서브맵, `LighthouseInterior`)까지 들어가 봐야
## 하는 마을. "마을마다 서브맵이 여럿 있어야 퀘스트가 산다"는 요청으로
## 더했다 — 가게 실내와 같은 결로, 문을 지나 봤는지만 본다.
const HAS_LIGHTHOUSE := {
	"윤슬": true, "가풀재": true, "하늬섬": true,
}

## 능(서브맵, `TombPathInterior`)이 있어서 안쪽길을 돌아 봐야 하는 마을.
## 무덤 안이 아니라 볕 드는 자리까지 걷는 둘레길이다 — 완료 표시는
## 문이 아니라 그 자리에 닿았을 때 남는다(`TombPathInterior.quest_zones()`).
const HAS_TOMB := {
	"볕뉘": true,
}

## 마을마다 **딱 하나씩**, 거기서만 할 수 있는 것.
##
## 2탄 다섯 곳이 인사·가게·방문+사진·줍기·잠으로 완전히 같은 틀이었다.
## 이름과 배경만 다르고 할 일의 모양이 똑같으니, 네 번째 마을쯤부터는
## 새 곳에 와도 새로울 것이 없었다.
##
## **하나만 더한다.** 일곱 개, 여덟 개로 늘리면 체크리스트가 된다.
## "몇 개 모으기" 를 또 만들지 않고, 그 마을의 생김새를 몸으로 알게
## 되는 자리 하나를 준다 — 굽이도는 강, 둥근 연못, 갈대 틈, 솔숲,
## 井자로 난 밭둑. 이름도 "목표 지점 방문" 이 아니라 산책하듯 적는다.
##
## [지도에 찍을 종류, 그 열쇠, 이름, 다 했다는 표시].
##
## **표시(넷째)와 지도에 찍는 자리(첫 둘)를 따로 둔다.** 셋은 그 일이
## 샛길 **안쪽**에서 끝나기 때문이다 — 마을 지도에 찍을 수 있는 건
## 들어가는 문뿐인데, 문을 지난 것만으로 끝났다고 치면 샛길을 만든
## 뜻이 없어진다. 그래서 문에는 아무 뜻 없는 `enter_key` 를 주고
## (`샛길입구`), 진짜 표시는 안쪽 자리에 닿아야 남는다
## (`SidePathInterior.quest_zones()`). 능 안쪽길에서 쓴 그 수법이다.
const LOCAL := {
	# 1탄 넷도 하나씩. 말 걸기가 아니라 **몸으로 하는 것**만 고른다 —
	# 부두 끝까지 나가 보고, 마당까지 내려가 보고, 언덕에 올라 본다.
	"윤슬": ["visit", "윤슬:부두끝", "부두 끝까지 걸어 나가 보기",
		"윤슬:부두끝"],
	"볕뉘": ["visit", "볕뉘:흙마당", "볕 드는 흙마당까지 내려가 보기",
		"볕뉘:흙마당"],
	"가풀재": ["visit", "가풀재:부두끝", "부두 끝에서 마을 올려다보기",
		"가풀재:부두끝"],
	"하늬섬": ["visit", "하늬섬:언덕", "북쪽 언덕에 올라 바다 내려다보기",
		"하늬섬:언덕"],
	"굽이나루": ["door", "샛길입구", "모래톱 안쪽 물굽이까지 가 보기",
		"굽이나루:물굽이"],
	"방울못": ["visit", "방울못:물소리", "데크 끝에서 물소리 듣기",
		"방울못:물소리"],
	"갈밭머리": ["visit", "갈밭머리:빈자리", "갈대 사이 빈자리까지 걸어 보기",
		"갈밭머리:빈자리"],
	"솔은재": ["door", "샛길입구", "솔그늘 샛길 끝 자리까지 가 보기",
		"솔은재:솔그늘"],
	"꽃눈벌": ["door", "샛길입구", "밭사잇길 끝에서 들판 둘러보기",
		"꽃눈벌:밭사이"],
}


# ── 마음매듭 · 샛길 ───────────────────────────────────────────────────
#
# 여태 마을마다 할 일이 예닐곱 줄이었는데, 하는 일의 **동사**가 다섯
# 가지(말 걸기·문 지나기·가 보기·줍기·자기)뿐이라 아홉 마을이 다
# 같았다. 체크박스를 더 얹어도 반복은 그대로다.
#
# 그래서 **줄을 늘리는 대신 엮는다.**
#   - 마음매듭 하나: 그 마을의 이야기. 세 단계로 이어진다.
#     단계마다 조건이 다르다 — 언제 갔는지, 무엇을 들고 갔는지,
#     며칠째인지를 본다
#   - 샛길 넷: 골라서 하는 짧은 이야기. **둘만 해도 다음 마을이 열린다**
#
# 100% 를 요구하지 않는다. 다 하라고 하면서 고르라고 하면 가짜 선택이다.
#
# 지금은 **윤슬 하나만** 이 구조다. 여기서 재미가 확인되면 나머지
# 여덟 곳으로 넓힌다 (`docs/planning/` 상담 1단계 — 수직 슬라이스).
const KNOT := {
	"윤슬": {
		"title": "빛은 한 번에 보이지 않는다",
		"steps": [
			{"key": "윤슬:매듭:1", "kind": "talk", "map": "seal",
				"label": "가게 할머니와 갈매기 소년에게 인사하기"},
			{"key": "윤슬:매듭:2", "kind": "visit", "map": "윤슬:등대",
				"photo": true, "when": "저녁",
				"label": "저녁에 등대곶에서 불 켜진 등대 사진 남기기"},
			{"key": "윤슬:매듭:3", "kind": "talk", "map": "seagull",
				"label": "다음 날 바다유리를 소년에게 보여 주기"},
		],
	},
}

const SIDE := {
	"윤슬": [
		{"key": "윤슬:샛길:가게", "kind": "door", "map": "가게",
			"label": "가게에 들어가 물건 구경하기"},
		{"key": "윤슬:샛길:등대안", "kind": "door", "map": "등대안",
			"label": "등대 안에 올라가 보기"},
		{"key": "윤슬:샛길:부두", "kind": "visit", "map": "윤슬:부두끝",
			"label": "부두 끝을 아침에도 저녁에도 보기"},
		{"key": "윤슬:샛길:고르기", "kind": "talk", "map": "seal",
			"label": "조개와 바다유리 중 하나를 골라 할머니에게 보여 주기"},
		# 숨은 자취 — 좌표를 안 찍어 준다. 지도의 표시는 "가장 가까운
		# 못 찾은 자리" 하나만 짚는다 (`Place.goal_world` 의 trace).
		{"key": "윤슬:샛길:자취", "kind": "trace", "map": "빛자리",
			"label": "갈매기 소년이 말한 반짝이는 자리 셋 찾기"},
		# 갯바위는 다른 넷과 결이 다르다 - 안쪽에서 무엇을 하나 세지
		# 않는다. 미역이든 소라든 아무거나 하나만 들고 오면 된다.
		{"key": "윤슬:샛길:채집", "kind": "door", "map": "갯바위",
			"label": "갯바위에 내려가 미역이나 소라 걷어 오기"},
	],
}


## 매듭 한 단계를 마쳤나. 단계마다 보는 것이 다르다.
static func knot_step_done(village: String, i: int) -> bool:
	if not KNOT.has(village):
		return false
	var st: Dictionary = KNOT[village]["steps"][i]
	match String(st["key"]):
		"윤슬:매듭:1":
			# 둘 다에게 인사하면 지도와 카메라가 손에 들어온다.
			# 옛 세이브는 표시로 이어 붙인다 (`_migrate_knots`).
			return (has_map() and has_camera()) \
				or JourneyState.quest_done("윤슬:매듭:1")
		"윤슬:매듭:2":
			# **저녁에** 가야 한다. 등대에 불이 들어오는 시간이다
			return JourneyState.quest_done("윤슬:등대@저녁") \
				and _photo_taken("윤슬")
		"윤슬:매듭:3":
			return JourneyState.quest_done("윤슬:매듭:3")
	return JourneyState.quest_done(String(st["key"]))


## 지금 이어가고 있는 단계 번호. 다 마쳤으면 단계 수를 돌려준다.
static func knot_at(village: String) -> int:
	if not KNOT.has(village):
		return 0
	var steps: Array = KNOT[village]["steps"]
	for i in steps.size():
		if not knot_step_done(village, i):
			return i
	return steps.size()


static func knot_done(village: String) -> bool:
	if not KNOT.has(village):
		return true
	return knot_at(village) >= (KNOT[village]["steps"] as Array).size()


static func side_done(village: String, key: String) -> bool:
	match key:
		"윤슬:샛길:가게":
			return _shop_entered("윤슬")
		"윤슬:샛길:등대안":
			return JourneyState.quest_done("윤슬:등대안")
		"윤슬:샛길:부두":
			# 같은 자리를 두 시간대에 — 그래야 "비교" 다
			return JourneyState.quest_done("윤슬:부두끝@아침") \
				and JourneyState.quest_done("윤슬:부두끝@저녁")
		"윤슬:샛길:자취":
			return JourneyState.quest_done("윤슬:본:빛자리1") \
				and JourneyState.quest_done("윤슬:본:빛자리2") \
				and JourneyState.quest_done("윤슬:본:빛자리3")
		"윤슬:샛길:채집":
			# 채집터는 매일 다시 채워지는 자리다 - 하나만 들고 오면
			# 되고, 나중에 또 가서 다른 걸 걷어 와도 상관없다.
			return JourneyState.count("p-seaweed") > 0 \
				or JourneyState.count("p-conch") > 0
	return JourneyState.quest_done(key)


## 지금 **무엇이 남았나** 를 한 마디로. 목록 줄 끝에 괄호로 붙는다.
##
## 여태 할 일 이름은 늘 **일 전체**를 적었다. "부두 끝을 아침에도
## 저녁에도 보기" 는 아침에 다녀온 다음에도 글자가 그대로라, 이미
## 반을 해 둔 것을 알 길이 없었다. 5일째 아침까지 이 줄이 그대로
## 떠 있던 화면을 받았다.
##
## 그래서 **남은 쪽만** 적는다. 진행이 눈에 보여야 계속 하게 된다.
static func side_note(village: String, key: String) -> String:
	match key:
		"윤슬:샛길:부두":
			var m := JourneyState.quest_done("윤슬:부두끝@아침")
			var e := JourneyState.quest_done("윤슬:부두끝@저녁")
			if m and not e:
				return "저녁에 한 번 더"
			if e and not m:
				return "아침에 한 번 더"
		"윤슬:샛길:자취":
			var n := 0
			for i in 3:
				if JourneyState.quest_done("윤슬:본:빛자리%d" % (i + 1)):
					n += 1
			if n > 0 and n < 3:
				return "%d/3 찾음" % n
	return ""


## 지금은 손댈 수 없나. 때를 기다려야 하는 것을 "지금 해볼 일" 로
## 띄우면, 할 수 없는 것을 계속 시키는 셈이다 (`Place.current_goal`).
##
## 목록에서 지우지는 않는다 - 때가 오면 그리 가야 하니까.
static func side_waiting(village: String, key: String) -> bool:
	if side_done(village, key):
		return false
	match key:
		"윤슬:샛길:부두":
			# 아침 몫을 이미 했으면 저녁까지는 더 할 것이 없다.
			var part := JourneyState.day_part()
			if JourneyState.quest_done("윤슬:부두끝@%s" % part):
				return true
			# 낮에는 아침도 저녁도 못 찍는다
			return part != "아침" and part != "저녁"
	return false


## 그 자리에 **닿았는데 아직 안 끝났을 때** 건네는 한 마디.
##
## 부두 끝까지 걸어 나가도 `@아침` 이 조용히 찍히고 끝이었다. 잔치는
## 줄 전체가 끝나야 뜨므로(`journey_hud._watch_done`), 반만 채운 사람은
## 화면에서 아무 변화를 못 본다. "왔는데 안 됐네" 로 읽고 다시 안 온다.
## 5일째 아침까지 그 줄이 그대로 떠 있던 화면을 받았다.
##
## 헛걸음처럼 만들지 않는다 - "틀렸다" 가 아니라 **"언제 오면 된다"** 로
## 적는다. 벌이 없는 게임이니 못 채운 것이 손해가 되면 안 된다.
## 지금 자면 **오늘 저녁에만 되는 일**을 건너뛰나. 남으면 그 이름.
##
## 자면 아침으로 간다. 저녁에만 되는 것을 남겨 둔 채 자면 그 저녁이
## 통째로 사라지고, 다음 저녁까지 하루를 더 기다려야 한다. 5일째까지
## 첫 마을 샛길이 안 끝난 화면을 받았는데, 이렇게 흐르면 그렇게 된다.
##
## **막지는 않는다.** 알고 자는 것과 모르고 자는 것만 가른다 -
## 벌이 없는 게임이니 "자면 안 된다" 가 되면 안 된다.
static func evening_left(village: String) -> String:
	if JourneyState.day_part() != "저녁":
		return ""
	for row in quest_list(village):
		if bool(row.get("done", false)):
			continue
		var id := String(row.get("id", ""))
		# 지금(저녁) 할 수 있는데 아직 안 한 것 중, **저녁이라야만**
		# 되는 것을 고른다. 낮에도 되는 것은 내일 해도 그만이다.
		if id == "윤슬:샛길:부두":
			if not JourneyState.quest_done("윤슬:부두끝@저녁"):
				return String(row.get("label", ""))
		elif id == "윤슬:매듭:2":
			return String(row.get("label", ""))
	return ""


static func zone_note(key: String) -> String:
	match key:
		"윤슬:부두끝":
			var m := JourneyState.quest_done("윤슬:부두끝@아침")
			var e := JourneyState.quest_done("윤슬:부두끝@저녁")
			if m and e:
				return ""
			if m:
				return "아침 바다는 봤어요. 저녁에 한 번 더 와 봐요."
			if e:
				return "저녁 바다는 봤어요. 아침에 한 번 더 와 봐요."
			return "아침이나 저녁에 오면 바다 빛이 달라요."
		"윤슬:등대":
			if knot_step_done("윤슬", 1):
				return ""
			if JourneyState.day_part() != "저녁":
				return "해가 지면 등대에 불이 들어와요. 그때 다시 와 봐요."
	return ""


static func sides_done(village: String) -> int:
	if not SIDE.has(village):
		return 0
	var n := 0
	for e in SIDE[village]:
		if side_done(village, String(e["key"])):
			n += 1
	return n


## 다음 마을이 열리는 조건. **다 하라고 하지 않는다** —
## 매듭 하나와 샛길 둘이면 된다 (마을 콘텐츠의 60% 남짓).
const SIDES_NEEDED := 2


## 그 마을만의 할 일을 마쳤나. 없는 마을이면 늘 참이다.
static func _local_ok(village: String) -> bool:
	if not LOCAL.has(village):
		return true
	return JourneyState.quest_done(_local_flag(village))


static func _local_flag(village: String) -> String:
	return String(LOCAL[village][3])


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


static func _slept_ok(village: String) -> bool:
	if not NEEDS_SLEEP.get(village, false):
		return true
	return JourneyState.quest_done("%s:잠" % village)


static func _lighthouse_ok(village: String) -> bool:
	if not HAS_LIGHTHOUSE.get(village, false):
		return true
	return JourneyState.quest_done("%s:등대안" % village)


static func _tomb_ok(village: String) -> bool:
	if not HAS_TOMB.get(village, false):
		return true
	return JourneyState.quest_done("%s:능안" % village)


## 그 마을의 퀘스트를 다 마쳤나.
static func village_cleared(village: String) -> bool:
	# 매듭이 있는 마을은 **100% 를 안 본다** — 이야기 하나와 샛길 둘.
	if KNOT.has(village):
		return knot_done(village) and sides_done(village) >= SIDES_NEEDED
	if TALK_FOLK.has(village):
		return _talked_all(village) and _shop_entered(village) \
			and _visited(village) and _picked_all(village) \
			and _slept_ok(village) and _lighthouse_ok(village) \
			and _tomb_ok(village) and _local_ok(village)
	return true    # 고향 등 목록 밖 장소는 늘 "클리어"로 친다


## 마을마다 물범·갈매기·카피바라를 부르는 이름. 화면에 보여 줄 때만 쓴다.
const FOLK_NAME := {
	"ju_seal": "빵집 아주머니", "ju_kid": "능 지키는 아이",
	"san_seal": "국수집 아저씨", "san_gull": "부두 청년",
	"do_seal": "귤 파는 할머니", "do_kid": "자전거 탄 아이",
	"cap_guinaru": "나루 가게 아저씨",
	"cap_bangul": "연못가 빵집 아주머니",
	"cap_galbat": "갈대밭 쉼터 할머니",
	"cap_sol": "고개 쉼터 아저씨",
	"cap_kkot": "밭머리 쉼터 아주머니",
}

## 마을마다 "방문+사진" 퀘스트 한 줄에 붙일 이름.
const VISIT_LABEL := {
	"윤슬": "등대곶까지 가서 사진 찍기",
	"볕뉘": "능 한 바퀴 걷기",
	"가풀재": "능선까지 올라 노을 사진 찍기",
	"하늬섬": "섬 한 바퀴 돌기",
	"굽이나루": "강 굽이 데크까지 가서 사진 찍기",
	"방울못": "연못 데크를 돌며 사진 찍기",
	"갈밭머리": "갈대 전망대까지 가서 사진 찍기",
	"솔은재": "고갯마루 전망 바위까지 가서 사진 찍기",
	"꽃눈벌": "밭 사이 도랑에 꽃잎 뜬 모습 사진 찍기",
}


## 배낭에 보여 줄 "이 마을에서" 목록.
## `[{"label":.., "done":.., "kind":.., "key":.., "photo":..}]`.
## 목록 밖 장소(고향)면 빈 배열 — 새 판정을 안 만들고, 3.5절과
## 4절의 퀘스트를 순서 그대로 다시 읽는 것뿐이다.
##
## ## `kind` 와 `key` 가 왜 붙어 있나
##
## 할 일이 **글자로만** 있었다. "고갯마루 전망 바위까지 가서 사진 찍기"
## 를 읽어도 그게 지도 위 어디인지 알 길이 없었다 — 목록과 지도가 서로
## 남이었다. 그래서 항목마다 **무엇인지(`kind`)** 와 **누구/어디인지
## (`key`)** 를 같이 적는다. 좌표는 여기 안 적는다. 좌표를 아는 건
## 마을 스크립트뿐이라 `Place.goal_world()` 가 이 둘을 받아 자리를 찾는다.
##
## 그래야 **목록·미니맵·테스트가 같은 데이터 하나**를 본다. 지도에
## 표시할 것을 따로 또 적어 두면 언젠가 둘이 어긋난다.
##
## `kind` 는 일곱: talk(인연) · prop(소품) · door(문) · visit(가 볼 자리) ·
## pickup(줍기) · sleep(잠자리) · depart(정류장).
## 목록 줄 하나를 가리키는 이름.
##
## 여태 `"kind:key"` 로 셌다. 그런데 윤슬 매듭 1(가게 할머니와 인사)과
## 샛길 고르기(할머니에게 보여 주기)가 **둘 다 `talk:seal`** 이다.
## 그래서 -
##   - 목록에서 하나를 접어 두면 엉뚱한 줄이 잡히고
##   - 하나가 끝나면 `_watch_done` 이 다른 하나를 "안 끝난 것" 으로 보고
##     매 프레임 `announced` 를 지웠다 다시 넣어, 잔치 카드가 안 끝난다
##
## 조개를 먼저 줍고 할머니에게 보여 준 다음 소년에게 안 가면 그 창에
## 들어간다. 그래서 **줄이 스스로 밝힌 이름(`id`)을 먼저 쓴다.**
static func row_id(item: Dictionary) -> String:
	var id := String(item.get("id", ""))
	if id != "":
		return id
	return "%s:%s" % [item.get("kind", ""), item.get("key", "")]


## 말 전하기 — 인연 둘을 잇는다. 아이템도 서브맵도 없다.
##
## 여태 마을 밖 한 걸음(채집터·그늘 자리)은 죄다 **자리**를 하나 더
## 두는 방식이었다. 이건 다르다 - 자리가 아니라 **인연 둘 사이**를
## 여행자가 잇는다. 대부분의 인연은 제 마을을 못 떠난다("나는 여기서
## 태어났어요", "나는 여기 말고 가 본 데가 없어요") - 그런데
## 여행자는 다닌다. 그 다니는 것 자체가 이 미니 퀘스트의 전부다.
##
## 지키는 선:
## - **체크리스트가 아니다.** 목록에도 화살표에도 안 올린다 - 다음에
##   그 인연을 만났을 때 조용히 끼어드는 대사 한 줄일 뿐이다
## - **아이템이 없다.** 손에 쥐는 것도, 배낭에 남는 것도 없다.
##   말 그 자체를 들고 다닌다
## - **다 채워야 하는 게 아니다.** 안 만나면 그 말은 그냥 안 전해질
##   뿐이다. 벌이 없다
##
## 맡기는 쪽은 **마음을 다 채운 다음**에야 말을 맡긴다 - 처음 본
## 사람에게 남 얘기를 부탁하지 않는다.
const RELAYS := [
	{
		"id": "가풀재_솔은재_계단고개",
		"from_village": "가풀재", "from_npc": "san_seal",
		"to_village": "솔은재", "to_npc": "cap_sol",
		"give": [
			"요새 계단 오르내리기가 영 힘들어.",
			"혹시 솔은재 들르거든, 거기 쉼터 아저씨한테",
			"'계단보다 고개가 낫다고 놀리더라' 라고 좀 전해 줘.",
		],
		"deliver": [
			"허, 계단보다 고개가 낫다고?",
			"그 양반 여전하네.",
			"다음에 만나면 나도 한마디 해야겠어.",
		],
	},
	# 굽이나루가 "흐르는 물", 방울못이 "고여 있는 물" 이라는 두 마을의
	# 정체(각 스크립트 머리말)를 그대로 놀림감으로 쓴다.
	{
		"id": "굽이나루_방울못_물빛",
		"from_village": "굽이나루", "from_npc": "cap_guinaru",
		"to_village": "방울못", "to_npc": "cap_bangul",
		"give": [
			"우리 강은 여기서 굽이도느라 늘 바빠요.",
			"혹시 방울못 들르거든, 거기 빵집 아주머니한테",
			"'너희는 안 바빠서 좋겠다' 라고 좀 놀려 줘요.",
		],
		"deliver": [
			"허, 우리가 안 바빠서 좋겠다고?",
			"고여 있는 것도 나름 할 일이 많은데.",
			"다음에 만나면 나도 한마디 해야겠네.",
		],
	},
	# 밭머리의 까치는 "소식 전하는 새" 역할로 세워 둔 인연이다
	# (`kkonnunbeol.gd` 주석). 그 역할을 실제로 시킨다 - 능 지키는
	# 아이의 "언젠가 나도 걸어서 나가 볼래요" 를 여기서 받는다.
	{
		"id": "꽃눈벌_볕뉘_소식",
		"from_village": "꽃눈벌", "from_npc": "kk_magpie",
		"to_village": "볕뉘", "to_npc": "ju_kid",
		"give": [
			"…",
			"저 밭 너머에 사람 사는 마을이 또 있대요.",
			"능 지키는 아이한테 그 얘기 좀 전해 줄래요?",
		],
		"deliver": [
			"…정말요?",
			"밭 너머에 마을이 또 있다고요?",
			"…나도 언젠가 걸어서 가 볼래요.",
		],
	},
	# 갈밭머리 갈매기는 늘 "여기서 보면 다 작아 보여요" 라고 한다 -
	# 그 시선으로 하늬섬을 본다. 하늬섬 아이는 이미 "섬 한 바퀴
	# 십오 분이에요!" 라고 자랑해 왔다 - 그 자랑이 놀림으로 돌아온다.
	{
		"id": "갈밭머리_하늬섬_손톱만한섬",
		"from_village": "갈밭머리", "from_npc": "ga_gull",
		"to_village": "하늬섬", "to_npc": "do_kid",
		"give": [
			"여기서 보면 섬 하나가 손톱만 하게 보여요.",
			"하늬섬 가거든 자전거 타는 아이한테",
			"'그렇게 작은 섬을 자전거로 다 돈다니 대단하다' 라고 좀 전해 줘요.",
		],
		"deliver": [
			"에이, 손톱만 하다니.",
			"그래도 십오 분이면 다 도는 건 맞아요.",
			"그 갈매기, 다음엔 내려와서 직접 보라고 해요.",
		],
	},
]


static func relay_given(id: String) -> bool:
	return JourneyState.quest_done("말:%s:받음" % id)


static func relay_delivered(id: String) -> bool:
	return JourneyState.quest_done("말:%s:전함" % id)


## 그 인연에게 말을 걸 때 끼어들 말이 있나. 두 갈래다 - 아직 안
## 맡긴 말을 맡기거나(from), 맡아 온 말을 전하거나(to). `Place`
## 어디서든 마을 이름과 지금 말 거는 인연의 이름만 넘기면 된다 -
## 새 서브맵도, 새 저장 칸도 필요 없다(기존 `quest_flags` 를 쓴다).
static func relay_line(village: String, npc_id: String) -> Array:
	if npc_id == "":
		return []
	for r in RELAYS:
		if String(r["from_village"]) == village and String(r["from_npc"]) == npc_id \
				and not relay_given(String(r["id"])) \
				and JourneyState.heart(npc_id) >= JourneyState.HEART_MAX:
			JourneyState.mark_quest("말:%s:받음" % r["id"])
			return r["give"]
		if String(r["to_village"]) == village and String(r["to_npc"]) == npc_id \
				and relay_given(String(r["id"])) and not relay_delivered(String(r["id"])):
			JourneyState.mark_quest("말:%s:전함" % r["id"])
			return r["deliver"]
	return []


static func quest_list(village: String) -> Array:
	# 프롤로그(쿼카컴퍼니가 있는 잿마루)에도 할 일을 둔다.
	#
	# **여기가 게임의 첫 화면이다.** 여기에 목록이 없으면, 배낭을 열어 봐도
	# "여기서는 딱히 할 일이 없어요" 만 뜬다 — 시작하자마자 길잡이가
	# 할 일을 가리키는데 정작 열어 보면 비어 있는 셈이었다.
	#
	# **잠그지 않는다.** 잿마루는 `ORDER` 밖이라 `village_cleared()` 가 늘
	# 참이다. 다 안 해도 떠날 수 있다 — 벌이 없다는 원칙 그대로,
	# 이 목록은 "해도 되는 것"을 적어 둔 것뿐이다.
	if village == "잿마루":
		return [
			{"label": "옆자리 동료에게 인사하기", "kind": "talk", "key": "coworker",
				"done": JourneyState.heart("coworker") >= 1},
			{"label": "창가에서 밖을 내다보기", "kind": "prop", "key": "창밖",
				"done": JourneyState.quest_done("잿마루:본:창밖")},
			{"label": "반납함에 사원증 넣기", "kind": "prop", "key": "반납함",
				"done": JourneyState.quest_done("잿마루:본:반납함")},
			{"label": "로비에서 경비 아저씨에게 인사하기", "kind": "talk", "key": "guard",
				"done": JourneyState.heart("guard") >= 1},
			{"label": "회사 앞으로 걸어 나가기", "kind": "prop", "key": "회사 앞",
				"done": JourneyState.quest_done("잿마루:본:회사 앞")},
			{"label": "정류장에서 첫 여행지 고르기", "kind": "depart", "key": "",
				"done": JourneyState.quest_done("잿마루:정류장")},
		]
	# ── 매듭이 있는 마을 ──────────────────────────────────────────
	#
	# 목록에는 **다섯 줄**만 보인다 — 매듭 한 줄과 샛길 넷. 매듭 줄은
	# 지금 이어가는 **한 단계**만 적는다. 세 단계를 한꺼번에 늘어놓으면
	# 그것도 결국 체크리스트다.
	if KNOT.has(village):
		var out2: Array = []
		var steps: Array = KNOT[village]["steps"]
		var at: int = knot_at(village)
		var cur: Dictionary = steps[mini(at, steps.size() - 1)]
		# **아직 때가 아니면 그렇다고 적는다.** "저녁에 등대곶" 이
		# 아침 내내 "지금 해볼 일" 로 떠 있으면, 할 수 없는 것을 계속
		# 시키는 셈이다. 목록에는 남기되 지금 할 것으로는 안 고른다
		# (`Place.current_goal`).
		var when := String(cur.get("when", ""))
		var waiting: bool = when != "" and JourneyState.day_part() != when \
			and not knot_done(village)
		out2.append({
			# **층을 글자로 나눈다.** 매듭 줄과 샛길 줄이 똑같이 생기면
			# 다시 체크리스트로 읽힌다. 폰트에 없는 그림글자는 못 쓰니
			# 앞머리 낱말로 가른다 (`CLAUDE.md` 폰트 규칙).
			"label": "이야기 %d/%d · %s%s" % [mini(at + 1, steps.size()),
				steps.size(), String(cur["label"]),
				"  (%s에)" % when if waiting else ""],
			"id": String(cur["key"]),
		"kind": String(cur["kind"]), "key": String(cur["map"]),
			"photo": bool(cur.get("photo", false)),
			"waiting": waiting,
			"done": knot_done(village),
		})
		for e in SIDE[village]:
			var sk := String(e["key"])
			var note := side_note(village, sk)
			out2.append({
				"label": "샛길 · %s%s" % [String(e["label"]),
					"  (%s)" % note if note != "" else ""],
				"id": sk,
			"kind": String(e["kind"]), "key": String(e["map"]),
				"waiting": side_waiting(village, sk),
				"done": side_done(village, sk),
			})
		return out2
	if ORDER.has(village):
		# ── 순서 ──────────────────────────────────────────────────
		#
		# 어긋난 데가 둘 있었다.
		#  - 가게가 **인사 둘 사이**에 끼어 있었다. 사람을 만나다 말고
		#    가게에 들어갔다 다시 나와 사람을 만나는 꼴이다
		#  - **하룻밤 쉬기가 중간**에 있었다. 자면 하루가 끝나는데 그
		#    아래로 등대 안·능 안쪽길·그 마을만의 것이 남아 있었다 —
		#    목록이 "자라" 고 한 다음에 "아직 셋 남았다" 고 하는 셈이다
		#
		# 지금 순서: 사람 -> 실내 -> 멀리 가 보기 -> 그 마을만의 것 ->
		# 남은 것 줍기 -> 자기. **잠은 언제나 맨 뒤다.**
		var ids: Array = TALK_FOLK.get(village, [])
		var out: Array = []
		for id in ids:
			out.append({"label": "%s와 인사하기" % FOLK_NAME.get(id, ""),
				"kind": "talk", "key": String(id),
				"done": JourneyState.heart(String(id)) >= 1})
		out.append({"label": "가게 들어가 보기", "kind": "door", "key": "가게",
			"done": _shop_entered(village)})
		out.append({"label": VISIT_LABEL.get(village, "방문해 보기"),
			"kind": "visit", "key": VISIT_KEY.get(village, ""),
			"photo": VISIT_NEEDS_PHOTO.get(village, false),
			"done": _visited(village)})
		if HAS_LIGHTHOUSE.get(village, false):
			out.append({"label": "등대 안에 들어가 보기", "kind": "door",
				"key": "등대안",
				"done": JourneyState.quest_done("%s:등대안" % village)})
		if HAS_TOMB.get(village, false):
			# 표시는 **문 앞**을 가리킨다. 완료는 안쪽 자리에서 나지만
			# (`TombPathInterior.quest_zones`), 마을 지도에 찍을 수 있는
			# 자리는 들어가는 문뿐이다.
			out.append({"label": "능 안쪽길에서 볕든 돌담 사진 남기기",
				"kind": "door", "key": "능입구",
				"done": JourneyState.quest_done("%s:능안" % village)})
		# 그 마을만의 것은 한 바퀴 돈 다음에야 "여기만 이런 게 있네" 가 온다
		if LOCAL.has(village):
			var e: Array = LOCAL[village]
			out.append({"label": String(e[2]), "kind": String(e[0]),
				"key": String(e[1]), "done": _local_ok(village)})
		out.append({"label": "떨어진 것 다 줍기", "kind": "pickup", "key": "",
			"done": _picked_all(village)})
		# **잠은 맨 뒤.** 자면 하루가 끝난다
		if NEEDS_SLEEP.get(village, false):
			out.append({"label": "하룻밤 쉬기", "kind": "sleep", "key": "",
				"done": JourneyState.quest_done("%s:잠" % village)})
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
