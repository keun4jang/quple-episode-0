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
## [종류, 열쇠, 이름]. visit 은 `Place.quest_zones()` 가, prop 은
## 소품을 들여다볼 때(`Place.talk_to_near`) 표시를 남긴다.
const LOCAL := {
	"굽이나루": ["visit", "굽이나루:물굽이", "강이 두 번 굽어 보이는 자리까지 가 보기"],
	"방울못": ["visit", "방울못:물소리", "데크 끝에서 물소리 듣기"],
	"갈밭머리": ["visit", "갈밭머리:빈자리", "갈대 사이 빈자리까지 걸어 보기"],
	"솔은재": ["prop", "솔방울 묻은 자리", "소나무 아래 작은 자리를 살펴보기"],
	"꽃눈벌": ["visit", "꽃눈벌:밭둑", "가운데 밭둑에서 들판 둘러보기"],
}


## 그 마을만의 할 일을 마쳤나. 없는 마을이면 늘 참이다.
static func _local_ok(village: String) -> bool:
	if not LOCAL.has(village):
		return true
	return JourneyState.quest_done(_local_flag(village))


static func _local_flag(village: String) -> String:
	var e: Array = LOCAL[village]
	if String(e[0]) == "prop":
		return "%s:본:%s" % [village, e[1]]
	return String(e[1])


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
	if village == "윤슬":
		return has_map() and has_camera() \
			and _shop_entered("윤슬") and _visited("윤슬") \
			and _picked_all("윤슬") and _slept_ok("윤슬") \
			and _lighthouse_ok("윤슬")
	if TALK_FOLK.has(village):
		return _talked_all(village) and _shop_entered(village) \
			and _visited(village) and _picked_all(village) \
			and _slept_ok(village) and _lighthouse_ok(village) \
			and _tomb_ok(village) and _local_ok(village)
	return true    # 고향 등 목록 밖 장소는 늘 "클리어"로 친다


## 마을마다 물범·갈매기·카피바라를 부르는 이름. 화면에 보여 줄 때만 쓴다.
const FOLK_NAME := {
	"ju_seal": "쿼빵집 아주머니", "ju_kid": "능 지키는 아이",
	"san_seal": "쿼면집 아저씨", "san_gull": "부두 청년",
	"do_seal": "쿼귤 파는 할머니", "do_kid": "자전거 탄 아이",
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
	if village == "윤슬":
		# **처음엔 둘만 보여준다.** 지도·카메라를 받기 전에 나머지
		# 다섯 개까지 다 늘어놓으면 "숙제장"처럼 보인다는 지적이 있었다.
		# 사진 항목은 카메라가 없으면 아예 뜻이 안 통하기도 하고 — 둘 다
		# 받고 나서야 이 마을이 실제로 "무엇으로 채워지는지" 보여준다.
		var out0: Array = [
			{"label": "가게 할머니와 인사하고 지도 받기", "kind": "talk",
				"key": "seal", "done": has_map()},
			{"label": "갈매기 소년과 인사하고 카메라 받기", "kind": "talk",
				"key": "seagull", "done": has_camera()},
		]
		if not (has_map() and has_camera()):
			return out0
		out0.append({"label": "가게 들어가 보기", "kind": "door", "key": "가게",
			"done": _shop_entered("윤슬")})
		out0.append({"label": VISIT_LABEL["윤슬"], "kind": "visit",
			"key": VISIT_KEY["윤슬"], "photo": VISIT_NEEDS_PHOTO.get("윤슬", false),
			"done": _visited("윤슬")})
		out0.append({"label": "떨어진 것 다 줍기", "kind": "pickup", "key": "",
			"done": _picked_all("윤슬")})
		out0.append({"label": "쿼스텔에서 하루 자기", "kind": "sleep", "key": "",
			"done": JourneyState.quest_done("윤슬:잠")})
		if HAS_LIGHTHOUSE.get("윤슬", false):
			out0.append({"label": "등대 안에 들어가 보기", "kind": "door",
				"key": "등대안", "done": JourneyState.quest_done("윤슬:등대안")})
		return out0
	if ORDER.has(village):
		var ids: Array = TALK_FOLK.get(village, [])
		var out: Array = []
		if ids.size() >= 1:
			out.append({"label": "%s와 인사하기" % FOLK_NAME.get(ids[0], ""),
				"kind": "talk", "key": String(ids[0]),
				"done": JourneyState.heart(String(ids[0])) >= 1})
		out.append({"label": "가게 들어가 보기", "kind": "door", "key": "가게",
			"done": _shop_entered(village)})
		if ids.size() >= 2:
			out.append({"label": "%s와 인사하기" % FOLK_NAME.get(ids[1], ""),
				"kind": "talk", "key": String(ids[1]),
				"done": JourneyState.heart(String(ids[1])) >= 1})
		out.append({"label": VISIT_LABEL.get(village, "방문해 보기"),
			"kind": "visit", "key": VISIT_KEY.get(village, ""),
			"photo": VISIT_NEEDS_PHOTO.get(village, false),
			"done": _visited(village)})
		out.append({"label": "떨어진 것 다 줍기", "kind": "pickup", "key": "",
			"done": _picked_all(village)})
		if NEEDS_SLEEP.get(village, false):
			out.append({"label": "하룻밤 쉬기", "kind": "sleep", "key": "",
				"done": JourneyState.quest_done("%s:잠" % village)})
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
		# 그 마을만의 것은 **맨 뒤**에. 앞의 다섯을 하며 마을을 한 바퀴
		# 돈 다음에야 "여기만 이런 게 있네" 가 온다.
		if LOCAL.has(village):
			var e: Array = LOCAL[village]
			out.append({"label": String(e[2]), "kind": String(e[0]),
				"key": String(e[1]), "done": _local_ok(village)})
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
