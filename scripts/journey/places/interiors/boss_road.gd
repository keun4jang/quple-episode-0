class_name BossRoad
extends DreamRoom
## 우두머리의 길 - 마을의 붉은 틈(`Place._build_gates`)으로 들어오는 곳.
##
## 왼쪽 끝에서 들어와 구불구불한 길을 따라 오른쪽 끝 **우두머리 방**
## (`BossLair`)으로 간다. 길에는 그 구역 졸개들(`Battle.road_spawns`)이
## 마을보다 한두 레벨 높게 서 있다.
##
## **졸개를 다 쓰러뜨려야 방 문이 열린다** (`door_locked`). 한 번 우두머리를
## 쓰러뜨린 뒤로는 늘 열려 있다 - 다시 잡으러 올 때 길을 또 쓸게 하면 숙제다.

const W := 46
const H := 18
## 길 폭(가운데에서 위아래로 몇 칸).
const HALF := 3
## 왼쪽 몇 칸은 막아 둔다 - 길이 화면 왼쪽 끝에서 시작하면 왼쪽 위
## 메뉴 단추 밑에 쿼카와 졸개가 깔린다.
const LEFT := 4
const LAIR_SCENE := "res://scenes/journey/interiors/BossLair.tscn"


## 길 한가운데 줄 - 사인파로 구불거린다.
static func center(x: int) -> int:
	return 9 + int(round(3.0 * sin(float(x) / 5.5)))


func place_name() -> String:
	return String(theme()["road"])


func ground_map() -> String:
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += "f" if absi(y - center(x)) <= HALF and x >= LEFT else "x"
		rows.append(row)
	return "\n".join(rows)


func props() -> Array:
	var deco: Array = theme()["deco"]
	var out: Array = []
	var i := 0
	for x in range(LEFT + 6, W - 5, 5):
		var up := i % 2 == 0
		out.append([x, center(x) + (-HALF if up else HALF), String(deco[i % deco.size()]), true])
		# 가운데 조금 비켜 조약돌 - 길이라는 게 보이게.
		if i % 3 == 1:
			out.append([x + 2, center(x + 2) + (1 if up else -1), "pebbles", false])
		i += 1
	return out


func spawn_tile() -> Vector2i:
	return Vector2i(LEFT + 3, center(LEFT + 3))


func lair_door_tile() -> Vector2i:
	return Vector2i(W - 2, center(W - 2))


## 방에서 나오면 서는 자리 - 문 바로 앞.
static func back_tile() -> Vector2i:
	return Vector2i(W - 4, center(W - 4))


func doors() -> Array:
	return [{
		"tile": Vector2i(LEFT + 1, center(LEFT + 1)),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "마을로 나가기",
	}, {
		"tile": lair_door_tile(),
		"scene": LAIR_SCENE,
		"spawn": BossLair.SPAWN,
		"label": "우두머리 방 들어가기", "enter_key": "우두머리방",
	}]


func shades() -> Array:
	return Battle.road_spawns(village())


func door_locked(d: Dictionary) -> String:
	if String(d.get("enter_key", "")) != "우두머리방" or Battle.boss_down(village()):
		return ""
	var n := foes_left()
	if n <= 0:
		return ""
	return "졸개가 %d마리 남았어요. 다 쓰러뜨리면 문이 열려요." % n


func open_goals() -> Array:
	if door_locked({"enter_key": "우두머리방"}) != "":
		return [{"label": "졸개 쓰러뜨리기 (%d마리 남음)" % foes_left(),
			"kind": "shade", "key": "", "done": false}]
	return [{"label": "우두머리 방으로", "kind": "door", "key": "우두머리방",
		"done": false}]


var _gate_fx: DreamGate


func on_built() -> void:
	super()
	# 방 문 - 붉은 틈. 졸개가 남아 있으면 옅다.
	_gate_fx = DreamGate.new()
	_gate_fx.name = "LairGate"
	_gate_fx.kind = "boss"
	_gate_fx.title = "%s의 방" % String(Battle.ENEMIES[Battle.boss_of(village())]["name"])
	_gate_fx.position = world_of(lair_door_tile())
	add_child(_gate_fx)
	if hud != null and not Battle.boss_down(village()):
		hud._say_hint("졸개들을 헤치고 오른쪽 끝 우두머리 방으로 가요.", true, 2.6)


func _process(delta: float) -> void:
	super(delta)
	if _gate_fx != null:
		_gate_fx.modulate.a = 0.45 if door_locked({"enter_key": "우두머리방"}) != "" else 1.0


func on_shade_down(sh: Shade) -> void:
	super(sh)
	if foes_left() == 0 and hud != null and not Battle.boss_down(village()):
		hud._celebrate("우두머리 방이 열렸어요!", "오른쪽 끝 붉은 틈으로 들어가요")


func room_tint() -> Color:
	return Color(0.84, 0.78, 0.94)
