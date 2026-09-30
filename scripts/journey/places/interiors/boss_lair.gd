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

## **우두머리의 2단계** - 체력이 이만큼 아래로 떨어지면 한 번, 곁에 졸개를 부르며 말한다.
## 마지막 우두머리(0.1.189)에 이어 구역 우두머리 아홉 모두에게 넣었다 (0.1.198) - 여덟은
## 체력만 큰 한 덩어리라 "마지막 보스만 특별하다" 는 말이 나왔다. 순하게 해 달라던 싸움들이라
## 부르는 졸개는 첫 둘이 하나, 나머지는 둘이다. 졸개는 그 방 호위와 같은 종(`Battle.lair_spawns`),
## 마지막 우두머리만 정해 둔 `adds`. `phase2_adds()` 가 실제로 부를 것을 돌려준다.
const PHASE2 := {
	"drop_king": {"at": 0.5, "n": 1, "line": "이 물방울들, 다 내 부하야! 튀어라!",
		"head": "물방울 대왕이 부하를 불렀어요!"},
	"dokkaebi": {"at": 0.5, "n": 1, "line": "불이 붙었다! 다들 모여라!",
		"head": "불꽃 도깨비가 부하를 불렀어요!"},
	"golem": {"at": 0.5, "n": 2, "line": "…쿵. 돌… 일어나라…",
		"head": "바위 거인이 돌을 깨웠어요!"},
	"gull": {"at": 0.5, "n": 2, "line": "끼룩끼룩! 바람아, 다 모여라!",
		"head": "태풍 갈매기가 바람을 불렀어요!"},
	"carp": {"at": 0.5, "n": 2, "line": "소용돌이가 커진다… 같이 돌자.",
		"head": "소용돌이 잉어왕이 물살을 불렀어요!"},
	"lotus": {"at": 0.5, "n": 2, "line": "연못이 깨어난다… 너희도 일어나렴.",
		"head": "연꽃 정령이 연못을 깨웠어요!"},
	"thorn_queen": {"at": 0.5, "n": 2, "line": "덩굴들아, 저 애를 붙잡으렴.",
		"head": "가시덩굴 여왕이 덩굴을 불렀어요!"},
	"mole_king": {"at": 0.5, "n": 2, "line": "땅 밑 신하들아, 올라와라!",
		"head": "산골 두더지왕이 신하를 불렀어요!"},
	"deer": {"at": 0.5, "n": 2, "line": "꽃불이 번진다. 다 함께 타오르자.",
		"head": "꽃사슴이 꽃불을 불렀어요!"},
	"night": {"at": 0.5, "adds": [["paper", 49], ["memo", 49]],
		"line": "…추가 업무예요. 이것도 내일 아침까지.",
		"head": "야근 대마왕이 추가 업무를 불렀어요!", "sub": "결재 서류와 회의록이 나타났어요"},
}
const PHASE2_SPOTS := [Vector2i(11, 10), Vector2i(19, 10)]


## 이 우두머리가 2단계에 부를 졸개 `[[종, 레벨], ...]` (없으면 빈 것).
static func phase2_adds(village: String, kind: String) -> Array:
	var p2: Dictionary = PHASE2.get(kind, {})
	if p2.is_empty():
		return []
	if p2.has("adds"):
		return p2["adds"]
	var out: Array = []
	var lair := Battle.lair_spawns(village)
	for i in range(1, lair.size()):
		if out.size() >= int(p2.get("n", 1)):
			break
		out.append([String(lair[i][0]), int(lair[i][1])])
	return out


## 부르는 졸개 이름들 - "졸개가 왔어요 - 물방울뭉·불꽃". (조사는 받침에 따라 틀리니 안 쓴다.)
static func phase2_sub(adds: Array) -> String:
	var names: Array = []
	for a in adds:
		var nm := String(Battle.ENEMIES[String(a[0])]["name"])
		if not names.has(nm):
			names.append(nm)
	return "졸개가 왔어요 - %s" % "·".join(names)
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
	# 이미 쓰러진 우두머리는 졸개를 부르지 않는다 (체력 0 도 "반 아래" 라서 막아 둔다).
	if p2.is_empty() or int(b.foe["hp"]) <= 0 \
			or float(b.foe["hp"]) > float(b.foe["hp_max"]) * float(p2["at"]):
		return
	_phase2_done = true
	var adds := phase2_adds(village(), b.shade_kind)
	for i in mini(adds.size(), PHASE2_SPOTS.size()):
		var sh := put_shade(PHASE2_SPOTS[i], String(adds[i][0]), int(adds[i][1]))
		if sh != null:
			FieldFx.burst(self, sh.global_position + Vector2(0, -10), "gone", true)
			# 부른 졸개는 곧장 싸움에 낀다 - 서 있기만 하면 2단계가 겉모습뿐이다.
			sh.join_fight()
	FieldFx.shake(cam, 7.0, 0.5)
	if hud != null:
		hud._celebrate(String(p2["head"]), String(p2.get("sub", phase2_sub(adds))))
	if say != null and not say.is_busy():
		say.say(String(Battle.ENEMIES[b.shade_kind]["name"]), [String(p2["line"])])
