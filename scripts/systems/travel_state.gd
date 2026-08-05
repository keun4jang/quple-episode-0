extends Node
## 쿼플 코어 루프
##
##   여행 보내기  →  (앱을 꺼도 시간이 흐름)  →  돌아오면 사진과 일기를 확인
##
## 진행은 실제 시각(unix time) 기준이므로 앱을 종료해도 계속된다.
## 이것이 이 게임의 리텐션 장치다 — 플레이어는 "확인하러" 돌아온다.

signal trip_started(dest_id: String)
signal trip_arrived(souvenir: Dictionary)
signal souvenir_collected(souvenir: Dictionary)

## 개발 중에는 여행이 금방 끝나야 확인이 쉽다.
## QUPLE_FAST_TRAVEL=1 이면 초 단위, 아니면 출시용 시간을 쓴다.
static func _is_fast() -> bool:
	return OS.get_environment("QUPLE_FAST_TRAVEL") != ""

## 여행지 (해금 조건 포함)
##   unlock_dest / unlock_count : 그 여행지를 N번 다녀와야 열린다
## 막(章). 앞 막에서 정해진 곳 수만큼 다녀와야 다음 막이 열린다.
const CHAPTERS: Array[Dictionary] = [
	{"id": "korea",  "name": "국내",      "need_prev": 0},
	{"id": "world",  "name": "해외",      "need_prev": 3},
	{"id": "space",  "name": "우주",      "need_prev": 3},
	{"id": "beyond", "name": "다른 차원", "need_prev": 3},
]

const DESTINATIONS: Array[Dictionary] = [
	# ── 1막 국내 ──
	{"id": "seoul", "chapter": "korea", "name": "서울", "emoji": "🏯",
	 "tagline": "익숙한 골목에서 새로 발견하는 것들",
	 "duration_sec": 1800, "fast_sec": 20, "tint": Color(0.55, 0.78, 0.55)},
	{"id": "busan", "chapter": "korea", "name": "부산", "emoji": "🌊",
	 "tagline": "바다 냄새가 나는 언덕길",
	 "duration_sec": 2700, "fast_sec": 22, "tint": Color(0.45, 0.75, 0.85)},
	{"id": "jeju", "chapter": "korea", "name": "제주", "emoji": "🍊",
	 "tagline": "돌담 사이로 부는 바람",
	 "duration_sec": 3600, "fast_sec": 24, "tint": Color(0.95, 0.72, 0.42)},
	{"id": "gangneung", "chapter": "korea", "name": "강릉", "emoji": "🌅",
	 "tagline": "해 뜨는 걸 같이 보기로 했다",
	 "duration_sec": 5400, "fast_sec": 26, "tint": Color(0.98, 0.78, 0.62)},

	# ── 2막 해외 ──
	{"id": "kyoto", "chapter": "world", "name": "교토", "emoji": "🎋",
	 "tagline": "조용한 골목과 오래된 나무",
	 "duration_sec": 7200, "fast_sec": 30, "tint": Color(0.62, 0.82, 0.62)},
	{"id": "paris", "chapter": "world", "name": "파리", "emoji": "🗼",
	 "tagline": "처음 보는 하늘빛과 빵 냄새",
	 "duration_sec": 10800, "fast_sec": 34, "tint": Color(0.85, 0.70, 0.90)},
	{"id": "newyork", "chapter": "world", "name": "뉴욕", "emoji": "🗽",
	 "tagline": "잠들지 않는 불빛 사이에서",
	 "duration_sec": 14400, "fast_sec": 38, "tint": Color(0.70, 0.75, 0.92)},
	{"id": "cairo", "chapter": "world", "name": "카이로", "emoji": "🐫",
	 "tagline": "사막의 밤은 생각보다 춥다",
	 "duration_sec": 18000, "fast_sec": 42, "tint": Color(0.92, 0.80, 0.55)},

	# ── 3막 우주 ──
	{"id": "moon", "chapter": "space", "name": "달", "emoji": "🌙",
	 "tagline": "둘만 아는 조용한 곳",
	 "duration_sec": 21600, "fast_sec": 48, "tint": Color(0.78, 0.80, 0.88)},
	{"id": "mars", "chapter": "space", "name": "화성", "emoji": "🔴",
	 "tagline": "붉은 모래 위에 남긴 두 줄 발자국",
	 "duration_sec": 28800, "fast_sec": 54, "tint": Color(0.88, 0.52, 0.42)},
	{"id": "saturn", "chapter": "space", "name": "토성", "emoji": "🪐",
	 "tagline": "고리 위를 걷는 기분",
	 "duration_sec": 36000, "fast_sec": 60, "tint": Color(0.85, 0.78, 0.60)},

	# ── 엔딩: 다른 차원 (한 번만, 돌아오지 않는다) ──
	{"id": "rift", "chapter": "beyond", "name": "다른 차원", "emoji": "✨",
	 "tagline": "여기서부터는 지도가 없다",
	 "duration_sec": 43200, "fast_sec": 70, "tint": Color(1.00, 0.86, 0.62),
	 "final": true},
]

## 실제 적용될 소요 시간
func duration_of(d: Dictionary) -> int:
	return int(d.get("fast_sec", 20)) if _is_fast() else int(d.get("duration_sec", 1800))

## 막·해금 관련 함수는 collection 이 필요해 get_destination 뒤에 있다.

## 여행 중 애인이 보내오는 중간 소식.
##   at = 여행 진행률(0.0~1.0). 그 지점을 지나면 도착한다.
## 실제 시각 기준이라 앱을 꺼둔 사이에도 도착해 있다.
const MID_MESSAGES: Dictionary = {
	"seoul": [
		{"at": 0.35, "emoji": "🐈", "text": "지금 골목길 지나는 중이야.\n여기 고양이가 엄청 많아!"},
		{"at": 0.70, "emoji": "🌆", "text": "해가 지고 있어.\n너도 이거 봤으면 좋겠다."}],
	"busan": [
		{"at": 0.35, "emoji": "⛰", "text": "계단이 끝이 없어.\n근데 위에서 보는 바다가 진짜 좋아."},
		{"at": 0.70, "emoji": "🍢", "text": "시장에서 뭐 좀 샀어.\n돌아가서 같이 먹자."}],
	"jeju": [
		{"at": 0.35, "emoji": "🌬", "text": "바람이 진짜 세.\n모자 날아갈 뻔했어."},
		{"at": 0.70, "emoji": "🍊", "text": "귤을 하나 땄는데\n생각보다 훨씬 달아."}],
	"gangneung": [
		{"at": 0.35, "emoji": "🚃", "text": "기차 창밖으로\n바다가 계속 따라와."},
		{"at": 0.70, "emoji": "🌅", "text": "내일 해 뜨는 거 보려고\n일찍 자기로 했어."}],
	"kyoto": [
		{"at": 0.35, "emoji": "🎋", "text": "대나무가 너무 높아서\n하늘이 초록색이야."},
		{"at": 0.70, "emoji": "🏮", "text": "등불이 하나씩 켜지고 있어.\n조용하고 좋다."}],
	"paris": [
		{"at": 0.35, "emoji": "🥐", "text": "빵집 앞을 지났는데\n냄새가 너무 좋아서 한참 서 있었어."},
		{"at": 0.70, "emoji": "🗼", "text": "탑이 보이기 시작했어.\n생각보다 훨씬 커."}],
	"newyork": [
		{"at": 0.35, "emoji": "🏙", "text": "건물이 너무 높아서\n고개가 아파."},
		{"at": 0.70, "emoji": "🌃", "text": "밤인데도 대낮처럼 밝아.\n좀 신기해."}],
	"cairo": [
		{"at": 0.35, "emoji": "🐫", "text": "낙타를 탔는데\n생각보다 많이 흔들려."},
		{"at": 0.70, "emoji": "✨", "text": "해가 지니까 갑자기 추워.\n대신 별이 엄청나."}],
	"moon": [
		{"at": 0.35, "emoji": "🌌", "text": "중력이 약해서\n자꾸 웃음이 나."},
		{"at": 0.70, "emoji": "🌍", "text": "저기 파란 점이 지구래.\n우리 집도 저 안에 있대."}],
	"mars": [
		{"at": 0.35, "emoji": "🔴", "text": "온통 붉어서\n노을 속을 걷는 것 같아."},
		{"at": 0.70, "emoji": "🌗", "text": "달이 두 개야.\n사진으로는 잘 안 담기네."}],
	"saturn": [
		{"at": 0.35, "emoji": "🪐", "text": "고리가 생각보다 얇아.\n근데 끝이 안 보여."},
		{"at": 0.70, "emoji": "☀", "text": "해가 작은 점처럼 보여.\n그래도 안 무서워."}],
	"rift": [
		{"at": 0.30, "emoji": "🌀", "text": "여기는 위아래가 없어.\n근데 손은 계속 잡고 있어."},
		{"at": 0.65, "emoji": "✨", "text": "돌아가는 길은 안 보여.\n괜찮아, 같이 있잖아."}],
}

## 여행지별 기념품(사진 + 일기). 방문할 때마다 순서대로 하나씩 열린다.
const SOUVENIRS: Dictionary = {
	"seoul": [
		{"title": "[ 첫 골목 ]", "diary": "늘 지나치던 길인데\n오늘은 손을 잡고 걸었다.", "photo": "🏯"},
		{"title": "[ 한강의 오후 ]", "diary": "바람이 좋아서\n아무 말도 하지 않았다.", "photo": "🌊"},
		{"title": "[ 야경 ]", "diary": "불빛이 예쁘다고 했더니\n네가 나를 봤다.", "photo": "🌃"}],
	"busan": [
		{"title": "[ 언덕 위 집들 ]", "diary": "계단이 끝없이 이어져서\n둘 다 숨이 찼다.", "photo": "🏘"},
		{"title": "[ 파도 소리 ]", "diary": "밤바다는 보이지 않고\n소리만 들렸다.", "photo": "🌊"},
		{"title": "[ 시장의 김 ]", "diary": "뜨거운 걸 호호 불면서\n반씩 나눠 먹었다.", "photo": "🍜"}],
	"jeju": [
		{"title": "[ 돌담길 ]", "diary": "바람이 세서\n자꾸 붙어 걸었다.", "photo": "🌾"},
		{"title": "[ 귤밭 ]", "diary": "하나 따서 까줬더니\n웃었다.", "photo": "🍊"},
		{"title": "[ 검은 모래 ]", "diary": "발자국이 선명하게 남는다고\n한참 들여다봤다.", "photo": "🏖"}],
	"gangneung": [
		{"title": "[ 첫 해 ]", "diary": "해가 올라오는 동안\n아무도 말하지 않았다.", "photo": "🌅"},
		{"title": "[ 바다 옆 커피 ]", "diary": "잔이 식는 줄도 모르고\n오래 앉아 있었다.", "photo": "☕"},
		{"title": "[ 돌아오는 기차 ]", "diary": "창밖을 보다가\n어깨에 기대 잠들었다.", "photo": "🚃"}],
	"kyoto": [
		{"title": "[ 대나무 길 ]", "diary": "위를 올려다보니\n초록빛만 가득했다.", "photo": "🎋"},
		{"title": "[ 붉은 문 ]", "diary": "끝이 안 보이는 길을\n천천히 걸었다.", "photo": "⛩"},
		{"title": "[ 저녁 골목 ]", "diary": "등불이 하나씩 켜지는 걸\n서서 지켜봤다.", "photo": "🏮"}],
	"paris": [
		{"title": "[ 낯선 아침 ]", "diary": "빵 냄새로 눈을 떴다.\n여기가 어디든 좋았다.", "photo": "🥐"},
		{"title": "[ 탑 아래에서 ]", "diary": "고개를 한참 젖히고\n둘 다 아무 말도 못 했다.", "photo": "🗼"},
		{"title": "[ 비 오는 골목 ]", "diary": "우산이 하나뿐이라\n조금 더 붙어 걸었다.", "photo": "☔"}],
	"newyork": [
		{"title": "[ 올려다본 하늘 ]", "diary": "건물 사이로 난 하늘이\n생각보다 좁았다.", "photo": "🏙"},
		{"title": "[ 공원의 벤치 ]", "diary": "복잡한 도시 한가운데\n이렇게 조용한 곳이 있었다.", "photo": "🌳"},
		{"title": "[ 밤의 불빛 ]", "diary": "잠들지 않는 도시라더니\n정말 그랬다.", "photo": "🌆"}],
	"cairo": [
		{"title": "[ 사막의 밤 ]", "diary": "생각보다 추워서\n둘이 붙어 있었다.", "photo": "🏜"},
		{"title": "[ 오래된 돌 ]", "diary": "몇천 년 전에도\n누가 여기 서 있었을까.", "photo": "🔺"},
		{"title": "[ 별이 쏟아지는 ]", "diary": "이렇게 많은 별은\n처음 봤다.", "photo": "✨"}],
	"moon": [
		{"title": "[ 조용한 곳 ]", "diary": "소리가 하나도 없어서\n숨소리가 다 들렸다.", "photo": "🌙"},
		{"title": "[ 지구를 보다 ]", "diary": "저기 어딘가에\n우리 집이 있다고 했다.", "photo": "🌍"},
		{"title": "[ 발자국 ]", "diary": "나란히 찍힌 두 개의 발자국.\n지워지지 않는다고 했다.", "photo": "👣"}],
	"mars": [
		{"title": "[ 붉은 모래 ]", "diary": "온통 붉어서\n노을이 끝나지 않는 것 같았다.", "photo": "🔴"},
		{"title": "[ 마른 강바닥 ]", "diary": "예전엔 물이 흘렀대.\n여기도 누군가 살았을까.", "photo": "🏜"},
		{"title": "[ 두 개의 달 ]", "diary": "달이 두 개나 떠서\n한참 세어 봤다.", "photo": "🌗"}],
	"saturn": [
		{"title": "[ 고리 위에서 ]", "diary": "얼음 조각들이\n천천히 같이 돌고 있었다.", "photo": "🪐"},
		{"title": "[ 끝없는 폭풍 ]", "diary": "무서울 줄 알았는데\n이상하게 조용했다.", "photo": "🌀"},
		{"title": "[ 멀어진 해 ]", "diary": "해가 작은 점처럼 보였다.\n그래도 따뜻했다.", "photo": "☀"}],
	"rift": [
		{"title": "[ 지도의 끝 ]", "diary": "여기서부터는 아무도 가 본 적이 없대.\n그래서 같이 가기로 했다.", "photo": "✨"}],
}

## 진행 중인 여행 (없으면 빈 Dictionary)
var trip: Dictionary = {}
## 모은 기념품들 (앨범)
var collection: Array = []

# ── 조회 ────────────────────────────────────────────────────────────────

func get_destination(dest_id: String) -> Dictionary:
	for d in DESTINATIONS:
		if d.id == dest_id:
			return d
	return {}

## 어느 막에서 몇 곳을 다녀왔는가 (같은 곳 여러 번은 1로 센다)
func chapter_cleared(chapter_id: String) -> int:
	var seen := {}
	for sv in collection:
		var d: Dictionary = get_destination(str(sv.get("dest_id", "")))
		if not d.is_empty() and str(d.get("chapter", "")) == chapter_id:
			seen[d.id] = true
	return seen.size()

func get_chapter(chapter_id: String) -> Dictionary:
	for c in CHAPTERS:
		if c.id == chapter_id:
			return c
	return {}

func chapter_index(chapter_id: String) -> int:
	for i in range(CHAPTERS.size()):
		if CHAPTERS[i].id == chapter_id:
			return i
	return -1

## 그 막이 열렸는가 (앞 막을 정해진 곳 수만큼 다녀왔는가)
func is_chapter_unlocked(chapter_id: String) -> bool:
	var idx := chapter_index(chapter_id)
	if idx <= 0:
		return true
	var prev: Dictionary = CHAPTERS[idx - 1]
	var need: int = int(CHAPTERS[idx].get("need_prev", 3))
	return chapter_cleared(str(prev.id)) >= need

## 여행지 해금 여부
func is_unlocked(dest_id: String) -> bool:
	var d: Dictionary = get_destination(dest_id)
	if d.is_empty():
		return false
	if not is_chapter_unlocked(str(d.get("chapter", ""))):
		return false
	# 엔딩 여행지는 한 번만 갈 수 있다
	if bool(d.get("final", false)) and ending_reached():
		return false
	return true

## 해금까지 무엇이 남았는지
func unlock_hint(dest_id: String) -> String:
	var d: Dictionary = get_destination(dest_id)
	if d.is_empty() or is_unlocked(dest_id):
		return ""
	if bool(d.get("final", false)) and ending_reached():
		return "이미 다녀왔어요"
	var idx := chapter_index(str(d.get("chapter", "")))
	if idx <= 0:
		return ""
	var prev: Dictionary = CHAPTERS[idx - 1]
	var need: int = int(CHAPTERS[idx].get("need_prev", 3))
	var have := chapter_cleared(str(prev.id))
	return "%s 여행지 %d곳을 더 다녀오면 열려요" % [prev.name, maxi(0, need - have)]

## 엔딩(다른 차원)에 다녀왔는가
func ending_reached() -> bool:
	for sv in collection:
		var d: Dictionary = get_destination(str(sv.get("dest_id", "")))
		if not d.is_empty() and bool(d.get("final", false)):
			return true
	return false

func is_traveling() -> bool:
	return not trip.is_empty() and not has_arrived()

func has_arrived() -> bool:
	if trip.is_empty():
		return false
	return _now() >= int(trip.get("arrive_at", 0))

func seconds_left() -> int:
	if trip.is_empty():
		return 0
	return maxi(0, int(trip.get("arrive_at", 0)) - _now())

## 0.0 ~ 1.0 진행률
func progress() -> float:
	if trip.is_empty():
		return 0.0
	var total := int(trip.get("arrive_at", 0)) - int(trip.get("depart_at", 0))
	if total <= 0:
		return 1.0
	return clampf(float(_now() - int(trip.get("depart_at", 0))) / float(total), 0.0, 1.0)

func visit_count(dest_id: String) -> int:
	var n := 0
	for s in collection:
		if s.get("dest_id", "") == dest_id:
			n += 1
	return n

# ── 여행 중 중간 소식 ──

## 지금까지 도착한 소식 (진행률 기준)
func arrived_messages() -> Array:
	if trip.is_empty():
		return []
	var pool: Array = MID_MESSAGES.get(trip.get("dest_id", ""), [])
	var prog := progress()
	var out: Array = []
	for i in range(pool.size()):
		if prog >= float(pool[i].get("at", 1.0)):
			var m: Dictionary = (pool[i] as Dictionary).duplicate(true)
			m["index"] = i
			out.append(m)
	return out

## 아직 읽지 않은 소식
func unread_messages() -> Array:
	var read: Array = trip.get("read_msgs", [])
	var out: Array = []
	for m in arrived_messages():
		if not read.has(int(m.get("index", -1))):
			out.append(m)
	return out

func unread_count() -> int:
	return unread_messages().size()

## 소식을 읽음 처리한다
func mark_messages_read() -> void:
	if trip.is_empty():
		return
	var read: Array = trip.get("read_msgs", [])
	for m in arrived_messages():
		var i := int(m.get("index", -1))
		if i >= 0 and not read.has(i):
			read.append(i)
	trip["read_msgs"] = read
	SaveManager.save_game()

## 다음 소식까지 남은 시간(초). 없으면 -1
func seconds_to_next_message() -> int:
	if trip.is_empty():
		return -1
	var pool: Array = MID_MESSAGES.get(trip.get("dest_id", ""), [])
	var total := int(trip.get("arrive_at", 0)) - int(trip.get("depart_at", 0))
	if total <= 0:
		return -1
	var prog := progress()
	for m in pool:
		var at := float(m.get("at", 1.0))
		if prog < at:
			return int((at - prog) * float(total))
	return -1

func format_time_left() -> String:
	var s := seconds_left()
	if s <= 0:
		return "도착!"
	var m := s / 60
	var sec := s % 60
	if m >= 60:
		return "%d시간 %d분" % [m / 60, m % 60]
	if m > 0:
		return "%d분 %d초" % [m, sec]
	return "%d초" % sec

# ── 코어 루프 ────────────────────────────────────────────────────────────

## 1단계: 여행 보내기
func start_trip(dest_id: String) -> bool:
	if is_traveling() or has_arrived():
		return false
	var d := get_destination(dest_id)
	if d.is_empty():
		return false
	if not is_unlocked(dest_id):
		return false
	var now := _now()
	trip = {
		"dest_id": dest_id,
		"depart_at": now,
		"arrive_at": now + duration_of(d),
		"read_msgs": [],
	}
	trip_started.emit(dest_id)
	SaveManager.save_game()
	return true

## 2단계: (앱을 꺼도 시간이 흐름 — 별도 처리 불필요)

## 3단계: 돌아온 쿼카들에게서 사진과 일기를 받는다
func collect_arrival() -> Dictionary:
	if not has_arrived():
		return {}
	var dest_id: String = trip.get("dest_id", "")
	var souvenir := _pick_souvenir(dest_id)
	souvenir["dest_id"] = dest_id
	souvenir["collected_at"] = _now()
	# 0편에서 챙긴 물건에 따라 기록의 내용이 달라진다
	if not _has_item("camera"):
		souvenir["photo"] = "📭"
		souvenir["title"] = "[ 사진 없음 ]"
	if not _has_item("notebook"):
		souvenir["diary"] = "적어둘 수첩이 없어서\n기억으로만 남았다."
	collection.append(souvenir)
	trip = {}
	souvenir_collected.emit(souvenir)
	SaveManager.save_game()
	return souvenir

## 0편에서 챙긴 물건이 여행 기록에 반영된다.
##   카메라 없으면 사진이 없고, 수첩 없으면 일기가 없다.
func _has_item(item: String) -> bool:
	var st := get_node_or_null("/root/Episode0State")
	if st == null:
		return true   # 0편을 건너뛴 경우엔 제한하지 않는다
	match item:
		"camera": return st.has_camera
		"notebook": return st.has_notebook
		"bag": return st.has_travel_bag
	return true

func _pick_souvenir(dest_id: String) -> Dictionary:
	var pool: Array = SOUVENIRS.get(dest_id, [])
	if pool.is_empty():
		return {"title": "[ 기록 ]", "diary": "무언가를 보고 왔다.", "photo": "📷"}
	# 방문 횟수만큼 다음 것을 열고, 다 보면 순환한다
	var idx: int = visit_count(dest_id) % pool.size()
	return (pool[idx] as Dictionary).duplicate(true)

# ── 저장 ────────────────────────────────────────────────────────────────

func reset() -> void:
	trip = {}
	collection = []

func to_dict() -> Dictionary:
	return {"trip": trip, "collection": collection}

func from_dict(d: Dictionary) -> void:
	trip = d.get("trip", {})
	collection = d.get("collection", [])

func _now() -> int:
	return int(Time.get_unix_time_from_system())
