class_name ShopInterior
extends Place
## 가게 안. 문을 지나 들어온 안쪽.
##
## 마을 넷의 가게가 밖에서는 저마다 다르게 생겼지만, 안은 하나로
## 합친다 — 파는 사람은 밖에 그대로 서 있고 (`put_folk` 의 시간표가
## 하루 종일 움직인다), 안은 그저 물건을 좀 더 가까이 보는 자리다.
## 넷을 따로 그릴 이유가 없었다.
##
## **나갈 때는 들어온 그 문 앞으로.** `JourneyState.exit_scene` 과
## `exit_tile` 에 밖에서 들어오기 직전 서 있던 자리가 적혀 있다
## (`Place._do_enter()` 가 문을 지날 때 남긴다).
##
## ── 크기가 방 치고 큰 이유 ───────────────────────────────────────────
##
## 좁은 방 하나만 그릴 생각이었는데, 줌 규칙이 밖과 안을 가리지 않는다.
## 초광각 폰에서 4배로 봐도 지도 밖 회색이 안 드러나려면 가로세로 다
## 34칸은 있어야 한다 (`journey_camera.gd` 의 `_recalc_floor`). 그래서
## 방 하나가 아니라 **진열대 여럿을 갖춘 가게**로 채운다.

const W := 35
const H := 18


func place_name() -> String:
	return "가게 안"


func _init() -> void:
	legend = {"f": "wood-floor"}
	solid_tiles = []


func ground_map() -> String:
	var row := ""
	for x in W:
		row += "f"
	var rows: Array = []
	for y in H:
		rows.append(row)
	return "\n".join(rows)


## 문 바로 안쪽에서 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(W / 2, H - 2)


## 진열대를 가운데로 모으고, 문 앞 세로줄(x = W/2)은 비워 둔다 —
## 들어오자마자 무엇에도 막히지 않아야 한다.
func props() -> Array:
	var mid := W / 2
	return [
		# 접수대 — 문에서 보자마자 마주치는 자리. 좌우로 대칭.
		[mid - 4, 4, "reception", true],
		[mid + 4, 4, "reception", true],
		# 진열장 두 줄
		[mid - 9, 3, "cabinet", true],
		# "진열대" 대사가 걸리는 그 진열장이다 (아래 `on_built()` 의
		# `put_spot()` 과 같은 칸) — 금색 테두리로 표시된다.
		[mid - 2, 3, "cabinet", true, true],
		[mid + 2, 3, "cabinet", true],
		[mid + 9, 3, "cabinet", true],
		# 아이스박스 — 시원한 것들
		[mid - 12, 7, "icebox", true],
		[mid + 12, 7, "icebox", true],
		[mid - 12, 8, "firewood", false],
		[mid + 12, 8, "firewood", false],
		# 장독대 — 가게에도 항아리는 있다. 한쪽만 있으면 어색하니 양쪽에.
		[mid - 5, 9, "jars", true],
		[mid - 3, 9, "jars", true],
		[mid + 3, 9, "jars", true],
		[mid + 5, 9, "jars", true],
		# 화분 — 살아 있는 것이 하나는 있어야 가게가 안 차갑다
		[mid - 7, 11, "flower-pots", false],
		[mid + 7, 11, "flower-pots", false],
		# 안쪽 좌판 — 문에서 먼 벽 쪽이 비어 보이지 않게 한 줄 더 채운다
		[mid - 9, 13, "stall", true],
		[mid + 9, 13, "stall", true],
		[mid - 11, 14, "tools", true],
		[mid + 11, 14, "washtub", false],
		# 손님 자리 — 문 앞 통로 바로 옆
		[mid - 3, 15, "bench", true],
		[mid + 3, 15, "bench", true],
	]


## 문. 들어온 자리로 다시 나간다.
func doors() -> Array:
	return [{
		"tile": Vector2i(W / 2, H - 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	put_spot(Vector2i(W / 2 - 2, 3), "진열대", [
		"이것저것 소소한 것들이 놓여 있다.",
		"여행 중에 필요한 건 대충 다 있는 듯하다.",
	])


func bgm_track() -> String:
	return "room"


func ambient_kind() -> String:
	return ""
