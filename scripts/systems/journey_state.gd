extends Node
## 여행 중에 지니고 다니는 것 (오토로드 `JourneyState`).
##
## 배낭에 든 것과, 어디서 무엇을 이미 주웠는지를 기억한다.
## 한 번 주운 것은 그 자리에 다시 안 생긴다 — 같은 자리를 왔다 갔다 하며
## 퍼 담는 게임이 아니다.

signal picked(item: String, total: int)

## 아이템 이름 → 개수
var bag: Dictionary = {}
## 이미 주운 자리. "고향:12,7" 같은 문자열
var taken: Dictionary = {}
## 지금 어느 여행지에 있나
var here := ""


func pick(item: String, count: int = 1) -> void:
	bag[item] = int(bag.get(item, 0)) + count
	picked.emit(item, bag[item])


func count(item: String) -> int:
	return int(bag.get(item, 0))


func total() -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


func kinds() -> int:
	return bag.size()


## 그 자리 것을 이미 주웠나
func is_taken(place: String, t: Vector2i) -> bool:
	return taken.has(_key(place, t))


func mark_taken(place: String, t: Vector2i) -> void:
	taken[_key(place, t)] = true


func _key(place: String, t: Vector2i) -> String:
	return "%s:%d,%d" % [place, t.x, t.y]


# ── 저장 ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"bag": bag.duplicate(),
		"taken": taken.duplicate(),
		"here": here,
	}


func from_dict(d: Dictionary) -> void:
	bag = d.get("bag", {}).duplicate() if d.get("bag") is Dictionary else {}
	taken = d.get("taken", {}).duplicate() if d.get("taken") is Dictionary else {}
	here = String(d.get("here", ""))


func reset() -> void:
	bag = {}
	taken = {}
	here = ""
