class_name BossLair
extends DreamRoom
## 우두머리 방 - 우두머리의 길(`BossRoad`) 끝에서 들어온다.
##
## 둥근 방 한가운데 위쪽에 구역 보스가, 양옆에 졸개 둘이 선다
## (`Battle.lair_spawns`). 날마다 다시 선다 - 드랍을 노리고 또 와도 된다.
## 처음 쓰러뜨리면 꿈의 문이 열리고 첫 처치 보상이 나온다 (`Place._boss_story`).

const W := 30
const H := 18
const SPAWN := Vector2i(15, 14)
## 우두머리와 졸개 둘이 서는 자리.
const SPOTS := [Vector2i(15, 5), Vector2i(10, 7), Vector2i(20, 7)]

## 들어서면 우두머리가 한마디 한다.
const TAUNT := {
	"drop_king": "내 물방울 왕국에 발을 들이다니! 흠뻑 적셔 주마!",
	"dokkaebi": "도깨비불 구경 왔느냐? 홀랑 태워 주지!",
	"golem": "…쿵. 여기는… 지나갈 수… 없다.",
	"gull": "끼룩! 내 바람을 버틸 수 있을 것 같아?",
	"carp": "소용돌이 속으로 빨려 들어가 보겠느냐.",
	"lotus": "연못의 꿈을 깨우는 자… 잠들게 해 주마.",
	"thorn_queen": "가시덩굴이 너를 놓아주지 않을 거야.",
	"mole_king": "땅 밑이 내 왕국이다! 꺼져라, 땅아!",
	"deer": "꽃눈벌을 태우는 불꽃, 그게 나다.",
	"night": "…왔군요. 이것만 끝내고 가요. 내일 아침까지.",
}

## **마지막 우두머리의 2단계** (0.1.189) - 체력이 이만큼 아래로 떨어지면 한 번,
## 곁에 졸개를 부르며 말한다. 마지막 장이 한 방 싸움으로 끝나지 않게.
## 다른 구역 우두머리는 그대로다 - 쉽게 해 달라고 한 싸움들이다.
const PHASE2 := {
	"night": {"at": 0.5, "adds": [["paper", 49], ["memo", 49]],
		"line": "…추가 업무예요. 이것도 내일 아침까지.",
		"head": "야근 대마왕이 추가 업무를 불렀어요!", "sub": "결재 서류와 회의록이 나타났어요"},
}
const PHASE2_SPOTS := [Vector2i(11, 10), Vector2i(19, 10)]
var _phase2_done := false


func place_name() -> String:
	return "%s의 방" % String(Battle.ENEMIES[Battle.boss_of(village())]["name"])


func ground_map() -> String:
	var rows: Array = []
	var c := Vector2(14.5, 8.5)
	for y in H:
		var row := ""
		for x in W:
			var d := Vector2((float(x) - c.x) / 12.5, (float(y) - c.y) / 7.6)
			row += "f" if d.length() <= 1.0 else "x"
		rows.append(row)
	return "\n".join(rows)


func props() -> Array:
	var deco: Array = theme()["deco"]
	return [
		# 네 귀퉁이 기둥 - 방이라는 것이 보이게.
		[6, 4, String(deco[0]), true], [23, 4, String(deco[0]), true],
		[6, 13, String(deco[1]), true], [23, 13, String(deco[1]), true],
	]


func spawn_tile() -> Vector2i:
	return SPAWN


func doors() -> Array:
	return [{
		"tile": Vector2i(SPAWN.x, SPAWN.y + 1),
		"scene": Place.BOSS_ROAD_SCENE,
		"spawn": BossRoad.back_tile(),
		"label": "길로 나가기",
	}]


func shades() -> Array:
	return Battle.lair_spawns(village())


func _shade_spots(n: int) -> Array:
	return SPOTS.slice(0, mini(n, SPOTS.size()))


func open_goals() -> Array:
	var b := _boss_shade()
	if b != null:
		return [{"label": "우두머리 %s 쓰러뜨리기" % String(Battle.ENEMIES[b.shade_kind]["name"]),
			"kind": "boss", "key": b.shade_kind, "done": false}]
	return [{"label": "나가기", "kind": "exit", "key": "", "done": false}]


func on_built() -> void:
	super()
	var kind := Battle.boss_of(village())
	# 몬스터는 `on_built` 다음에 선다 - 조금 기다렸다 본다.
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or say == null or say.is_busy() or _boss_shade() == null:
		return
	say.say(String(Battle.ENEMIES[kind]["name"]), [String(TAUNT.get(kind, "…"))])


func room_tint() -> Color:
	return Color(0.92, 0.74, 0.78)


func _process(delta: float) -> void:
	super(delta)
	_tick_phase2()


func _tick_phase2() -> void:
	if _phase2_done:
		return
	var b := _boss_shade()
	if b == null:
		return
	var p2: Dictionary = PHASE2.get(b.shade_kind, {})
	if p2.is_empty() or float(b.foe["hp"]) > float(b.foe["hp_max"]) * float(p2["at"]):
		return
	_phase2_done = true
	var adds: Array = p2["adds"]
	for i in mini(adds.size(), PHASE2_SPOTS.size()):
		var sh := put_shade(PHASE2_SPOTS[i], String(adds[i][0]), int(adds[i][1]))
		if sh != null:
			FieldFx.burst(self, sh.global_position + Vector2(0, -10), "gone", true)
	FieldFx.shake(cam, 7.0, 0.5)
	if hud != null:
		hud._celebrate(String(p2["head"]), String(p2["sub"]))
	if say != null and not say.is_busy():
		say.say(String(Battle.ENEMIES[b.shade_kind]["name"]), [String(p2["line"])])
