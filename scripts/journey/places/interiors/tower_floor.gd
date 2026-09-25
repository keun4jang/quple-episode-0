class_name TowerFloor
extends DreamRoom
## 꿈의 탑 한 층 (`Loop` 의 "꿈의 탑").
##
## 네모난 방. 아래 문으로 들어와 몬스터를 다 쓰러뜨리면 위쪽 **계단**(푸른
## 틈)이 열리고, 그리로 올라가면 같은 씬을 한 층 위로 다시 짓는다
## (`Loop.tower_now`). 다섯 층마다 우두머리 층이다.
##
## 우두머리 층의 보스는 구역 보스와 같은 종이지만 **꿈의 문을 열지는
## 않는다** (`_boss_story`) - 탑에서 볕뉘 보스를 잡았다고 볕뉘 다음
## 구역이 열리면 구역을 건너뛰게 된다.

const W := 26
const H := 18
const SPAWN := Vector2i(13, 14)
const STAIRS := Vector2i(13, 3)

var _stairs_fx: DreamGate
var _done := false


func floor_no() -> int:
	return maxi(1, Loop.tower_now)


func place_name() -> String:
	return "꿈의 탑 %d층" % floor_no()


func ground_map() -> String:
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += "f" if x >= 2 and x <= W - 3 and y >= 2 and y <= H - 2 else "x"
		rows.append(row)
	return "\n".join(rows)


## 탑은 마을 결이 아니라 늘 돌바닥이다.
func theme() -> Dictionary:
	return {"floor": "stone-slab", "edge": "wall-stone",
		"deco": ["stone-wall", "boulder", "stone-wall"], "road": ""}


func props() -> Array:
	return [
		[4, 4, "stone-wall", true], [21, 4, "stone-wall", true],
		[4, 12, "stone-wall", true], [21, 12, "stone-wall", true],
	]


func spawn_tile() -> Vector2i:
	return SPAWN


func doors() -> Array:
	return [{
		"tile": Vector2i(SPAWN.x, SPAWN.y + 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "탑에서 나가기",
	}, {
		"tile": STAIRS,
		"scene": Place.TOWER_SCENE,
		"spawn": SPAWN,
		"label": "%d층으로 올라가기" % (floor_no() + 1),
		"enter_key": "탑계단", "tower_floor": floor_no() + 1,
	}]


func shades() -> Array:
	return Loop.floor_spawns(floor_no())


func _shade_spots(n: int) -> Array:
	if not Loop.is_boss_floor(floor_no()):
		return super(n)
	return [Vector2i(13, 6), Vector2i(8, 8), Vector2i(18, 8)].slice(0, n)


func door_locked(d: Dictionary) -> String:
	if String(d.get("enter_key", "")) != "탑계단" or foes_left() <= 0:
		return ""
	return "이 층 몬스터를 다 쓰러뜨려야 계단이 열려요 (%d마리 남음)." % foes_left()


func open_goals() -> Array:
	if foes_left() > 0:
		return [{"label": "%d층 몬스터 쓰러뜨리기 (%d마리 남음)" % [floor_no(), foes_left()],
			"kind": "shade", "key": "", "done": false}]
	return [{"label": "%d층으로 올라가기" % (floor_no() + 1), "kind": "door",
		"key": "탑계단", "done": false}]


func display_name() -> String:
	return "꿈의 탑 %d층%s" % [floor_no(), "  우두머리 층" if Loop.is_boss_floor(floor_no()) else ""]


func on_built() -> void:
	super()
	_stairs_fx = DreamGate.new()
	_stairs_fx.name = "Stairs"
	_stairs_fx.kind = "tower"
	_stairs_fx.title = "%d층 계단" % (floor_no() + 1)
	_stairs_fx.position = world_of(STAIRS)
	add_child(_stairs_fx)
	# 몬스터는 이 다음에 선다. 오늘 이미 다 쓸어 둔 층이면 곧장 열린다.
	await get_tree().process_frame
	if is_inside_tree():
		_check_done()


func _process(delta: float) -> void:
	super(delta)
	if _stairs_fx != null:
		_stairs_fx.modulate.a = 1.0 if foes_left() <= 0 else 0.3


func on_shade_down(sh: Shade) -> void:
	super(sh)
	_check_done()


func _check_done() -> void:
	if _done or foes_left() > 0:
		return
	_done = true
	var n := floor_no()
	var r := Loop.clear_floor(n)
	SaveManager.save_now()
	if hud == null:
		return
	if r.is_empty():
		hud._say_hint("계단이 열렸어요. 위로 올라가요.", false, 1.8)
		return
	var bits: Array = ["꿈조각 +%d" % int(r["coins"])]
	if int(r["stones"]) > 0:
		bits.append("강화석 +%d" % int(r["stones"]))
	if r.has("item"):
		bits.append("%s %s" % [String(Gear.RARITY[int(r["item"]["rar"])]["name"]),
			Gear.name_of(r["item"])])
	hud._celebrate("%d층 돌파! 최고 기록" % n, " · ".join(bits))
	if n % Loop.TOWER_BOSS_EVERY == 0:
		hud._say_hint("쉼터에 닿았어요. 다음엔 %d층부터 올라요." % (n + 1), true, 2.4)


## 탑 안에서는 하늘이 안 보인다.
func sky_open() -> bool:
	return false


## 탑의 우두머리는 꿈의 문을 열지 않는다 (위 주석).
func _boss_story(_kind: String) -> void:
	pass


func bgm_track() -> String:
	return "room"


func room_tint() -> Color:
	return Color(0.74, 0.82, 0.98)
