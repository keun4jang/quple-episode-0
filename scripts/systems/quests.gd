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
	return JourneyState.quest_done(key)


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
			"kind": String(cur["kind"]), "key": String(cur["map"]),
			"photo": bool(cur.get("photo", false)),
			"waiting": waiting,
			"done": knot_done(village),
		})
		for e in SIDE[village]:
			out2.append({
				"label": "샛길 · " + String(e["label"]),
				"kind": String(e["kind"]), "key": String(e["map"]),
				"done": side_done(village, String(e["key"])),
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
