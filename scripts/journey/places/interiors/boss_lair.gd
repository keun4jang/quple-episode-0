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
}


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
