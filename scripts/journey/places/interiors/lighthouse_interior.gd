class_name LighthouseInterior
extends Place
## 등대 안. 나선 계단을 올라 불빛이 도는 꼭대기까지.
##
## 윤슬·가풀재·하늬섬 셋 다 등대가 있다 — 밖에서 보는 모양은 저마다
## 달라도 안은 하나로 합친다 (`ShopInterior` 와 같은 결).
##
## 크기가 방 치고 큰 이유는 `ShopInterior` 와 같다 — 초광각 폰에서
## 지도 밖 회색이 안 드러나려면 가로세로 다 34칸은 있어야 한다.

const W := 35
const H := 18
const WALL := 2


func place_name() -> String:
	return "등대 안"


func _init() -> void:
	legend = {
		"f": "wood-floor",     # 저장고 바닥
		"s": "granite-step",   # 나선 계단
		"b": "basalt",         # 등대 벽
	}
	solid_tiles = ["basalt"]


## 가운데 계단이 고리 모양으로 돈다 — 곧게 놓으면 계단이 아니라 다리로
## 보인다. 문(아래 가운데)에서 시작해 고리를 따라 올라가면 꼭대기다.
func ground_map() -> String:
	var mid := W / 2
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			var dx := x - mid
			var dy := y - (H / 2)
			var d := sqrt(float(dx * dx) + float(dy * dy) * 2.25)
			# 등대도 **방이다.** 바깥 두 칸을 벽으로 두른다 — 안 그러면
			# 바닥이 허공에서 끊긴다. 아래 가운데는 문간이라 뚫어 둔다.
			var edge: bool = x < WALL or x >= W - WALL \
				or y < WALL or y >= H - WALL
			if y >= H - WALL and absi(x - mid) <= 1:
				edge = false
			if edge:
				row += "b"
			else:
				row += "s" if (d >= 5.0 and d <= 6.4) else "f"
		rows.append(row)
	return "\n".join(rows)


## 문 바로 안쪽에서 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(W / 2, H - 2)


func props() -> Array:
	var mid := W / 2
	return [
		# ── 저장고 (바닥) ────────────────────────────────────────────
		[mid - 3, H - 4, "jars", true],
		[mid + 3, H - 4, "jars", true],
		[mid - 5, H - 3, "firewood", false],
		[mid + 5, H - 3, "tools", true],
		[mid - 8, 9, "boulder", true],
		[mid + 8, 9, "boulder", true],
		# ── 계단 안쪽 빈터 ───────────────────────────────────────────
		[mid - 2, 8, "flower-pots", false],
		[mid + 2, 8, "flower-pots", false],
		# ── 꼭대기, 불빛이 도는 자리 ─────────────────────────────────
		[mid - 1, 2, "street-lamp", true],
		[mid + 1, 2, "street-lamp", true],
	]


## 문. 들어온 자리로 다시 나간다.
func doors() -> Array:
	return [{
		"tile": Vector2i(W / 2, H - 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


## 할 일은 **들어온 마을 것**을 이어 본다 (`Place.quest_village`).
func quest_village() -> String:
	return village_we_came_from()


func on_built() -> void:
	JourneyState.here = place_name()
	put_spot(Vector2i(W / 2, 3), "전망", [
		"나선 계단을 다 올라왔다.",
		"불빛이 천천히 도는 소리만 들린다.",
		"여기서 보면 마을이 이렇게 작았구나 싶다.",
	])


func bgm_track() -> String:
	return "room"


func ambient_kind() -> String:
	return "wind"
