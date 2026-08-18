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


func pad_wide() -> bool:
	return false


func place_name() -> String:
	return "등대 안"


func _init() -> void:
	legend = {
		"f": "wood-floor",     # 저장고 바닥
		"s": "granite-step",   # 나선 계단
		"b": "basalt",         # 등대 벽
		"w": "wall-stone",     # 방을 향한 벽 얼굴 (make-wall-tiles.py)
	}
	solid_tiles = ["basalt", "wall-stone"]


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
				row += "w" if y == WALL - 1 else "b"
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
	# 세 마을이 같은 등대를 쓰지만 **꼭대기에서 보이는 것**은 마을마다
	# 다르다 — 첫 두 줄은 같고 마지막 줄만 그 마을의 것이다.
	var view := {
		"윤슬": "수평선 끝에 배 한 척이 아주 천천히 간다.",
		"가풀재": "비탈길 지붕들이 계단처럼 포개져 있다.",
		"하늬섬": "섬을 두른 길이 한눈에 다 들어온다.",
	}.get(village_we_came_from(), "여기서 보면 마을이 이렇게 작았구나 싶다.")
	put_spot(Vector2i(W / 2, 3), "전망", [
		"나선 계단을 다 올라왔다.",
		"불빛이 천천히 도는 소리만 들린다.",
		String(view),
	])


func bgm_track() -> String:
	return "room"


func ambient_kind() -> String:
	return "wind"
