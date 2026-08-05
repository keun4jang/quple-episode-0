class_name TripStats
extends RefCounted

## 여행 기록 통계.
##
## 화면(StatsUI)과 계산을 분리해 둔다. 통계는 TravelState 한 곳만 읽으면
## 되는 순수 계산이라, UI 없이도 테스트하거나 다른 화면에서 재사용할 수 있다.
## 숫자를 화면에 그대로 늘어놓지 않기 위해 "비율"까지 여기서 만들어 준다.


## TravelState 를 읽어 통계를 한 번에 모은다.
## 반환 키:
##   visited / total          다녀온 고유 여행지 수, 전체 여행지 수
##   ratio                    전체 진행률 0~1
##   chapters                 [{id, name, visited, total, ratio, unlocked}]
##   records                  모은 기록(기념품) 수
##   top                      가장 많이 간 곳 {id, name, emoji, count} (없으면 빈 Dictionary)
##   quiet_days               조용한 하루 수
##   habits                   열린 습관 배열 (TravelState.unlocked_habits())
##   ending                   엔딩 도달 여부
static func gather() -> Dictionary:
	# 자동 로드(autoload)를 트리에서 직접 찾는다 — 정적 함수라 씬 노드에 기대지 않는다.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return _empty()
	# 타입을 붙이지 않는다 — TravelState 의 const/함수를 동적으로 읽기 위해서다.
	var state = tree.root.get_node_or_null("TravelState")
	if state == null:
		return _empty()

	var collection: Array = state.collection
	var destinations: Array = state.DESTINATIONS

	# 같은 곳을 여러 번 가도 "다녀온 곳"은 하나로 센다.
	var visit_counts := {}
	var quiet_days := 0
	for sv in collection:
		var did := str((sv as Dictionary).get("dest_id", ""))
		if did != "":
			visit_counts[did] = int(visit_counts.get(did, 0)) + 1
		if bool((sv as Dictionary).get("quiet", false)):
			quiet_days += 1

	var total: int = destinations.size()
	var visited: int = visit_counts.size()

	# 막별 진행 — 막대그래프로 그릴 재료
	var chapters: Array = []
	for ch in state.CHAPTERS:
		var cid := str((ch as Dictionary).get("id", ""))
		var ch_total := 0
		for d in destinations:
			if str((d as Dictionary).get("chapter", "")) == cid:
				ch_total += 1
		var ch_visited: int = state.chapter_cleared(cid)
		chapters.append({
			"id": cid,
			"name": str((ch as Dictionary).get("name", "")),
			"visited": ch_visited,
			"total": ch_total,
			"ratio": (float(ch_visited) / float(ch_total)) if ch_total > 0 else 0.0,
			"unlocked": bool(state.is_chapter_unlocked(cid)),
		})

	# 가장 많이 간 곳. 같은 횟수면 먼저 나온 곳을 쓴다(결과가 흔들리지 않게).
	var top: Dictionary = {}
	var best := 0
	for did in visit_counts.keys():
		var n := int(visit_counts[did])
		if n > best:
			best = n
			var d: Dictionary = state.get_destination(str(did))
			top = {
				"id": str(did),
				"name": str(d.get("name", did)),
				"emoji": str(d.get("emoji", "📍")),
				"count": n,
			}

	return {
		"visited": visited,
		"total": total,
		"ratio": (float(visited) / float(total)) if total > 0 else 0.0,
		"chapters": chapters,
		"records": collection.size(),
		"top": top,
		"quiet_days": quiet_days,
		"habits": state.unlocked_habits(),
		"ending": bool(state.ending_reached()),
		"visit_counts": visit_counts,
	}


## 전체 진행률 0~1 (다녀온 고유 여행지 / 전체 여행지)
static func progress_ratio() -> float:
	return float(gather().get("ratio", 0.0))


## TravelState 가 없을 때(테스트·툴 실행)도 화면이 안전하게 뜨도록 빈 통계를 준다.
static func _empty() -> Dictionary:
	return {
		"visited": 0, "total": 0, "ratio": 0.0, "chapters": [],
		"records": 0, "top": {}, "quiet_days": 0, "habits": [],
		"ending": false, "visit_counts": {},
	}
