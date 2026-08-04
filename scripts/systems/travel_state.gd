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

## 여행지. duration_sec 는 개발 중 짧게, 출시 시 늘린다.
const DESTINATIONS: Array[Dictionary] = [
	{
		"id": "seoul",
		"name": "서울",
		"tagline": "익숙한 골목에서 새로 발견하는 것들",
		"emoji": "🏯",
		"duration_sec": 60,
		"tint": Color(0.55, 0.78, 0.55),
	},
	{
		"id": "paris",
		"name": "파리",
		"tagline": "처음 보는 하늘빛과 빵 냄새",
		"emoji": "🗼",
		"duration_sec": 180,
		"tint": Color(0.85, 0.70, 0.90),
	},
	{
		"id": "moon",
		"name": "달",
		"tagline": "둘만 아는 조용한 곳",
		"emoji": "🌙",
		"duration_sec": 300,
		"tint": Color(0.65, 0.72, 0.95),
	},
]

## 여행지별 기념품(사진 + 일기). 방문할 때마다 순서대로 하나씩 열린다.
const SOUVENIRS: Dictionary = {
	"seoul": [
		{"title": "[ 첫 골목 ]", "diary": "늘 지나치던 길인데\n오늘은 손을 잡고 걸었다.", "photo": "🏯"},
		{"title": "[ 한강의 오후 ]", "diary": "바람이 좋아서\n아무 말도 하지 않았다.", "photo": "🌊"},
		{"title": "[ 야경 ]", "diary": "불빛이 예쁘다고 했더니\n네가 나를 봤다.", "photo": "🌃"},
	],
	"paris": [
		{"title": "[ 낯선 아침 ]", "diary": "빵 냄새로 눈을 떴다.\n여기가 어디든 좋았다.", "photo": "🥐"},
		{"title": "[ 탑 아래에서 ]", "diary": "고개를 한참 젖히고\n둘 다 아무 말도 못 했다.", "photo": "🗼"},
		{"title": "[ 비 오는 골목 ]", "diary": "우산이 하나뿐이라\n조금 더 붙어 걸었다.", "photo": "☔"},
	],
	"moon": [
		{"title": "[ 조용한 곳 ]", "diary": "소리가 하나도 없어서\n숨소리가 다 들렸다.", "photo": "🌙"},
		{"title": "[ 지구를 보다 ]", "diary": "저기 어딘가에\n우리 집이 있다고 했다.", "photo": "🌍"},
		{"title": "[ 발자국 ]", "diary": "나란히 찍힌 두 개의 발자국.\n지워지지 않는다고 했다.", "photo": "👣"},
	],
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
	var now := _now()
	trip = {
		"dest_id": dest_id,
		"depart_at": now,
		"arrive_at": now + int(d.duration_sec),
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
	collection.append(souvenir)
	trip = {}
	souvenir_collected.emit(souvenir)
	SaveManager.save_game()
	return souvenir

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
