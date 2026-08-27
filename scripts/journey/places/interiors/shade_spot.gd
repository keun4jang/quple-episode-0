class_name ShadeSpot
extends Place
## 그늘 자리. 마을 밖으로 한 걸음 더 나가는 작은 자리 — `GatherGround`
## 와 같은 결이지만, **아무것도 안 줍는다.**
##
## 여태 "마을 밖 한 걸음"은 늘 뭔가를 걷어 오는 것이었다(갯바위·갈밭
## 속). 그런데 처음 낸 아이디어가 이랬다 — "줍는 게 아니라 그냥 앉아
## 있는 자리. 벌이 없다는 걸 서브맵으로도 보여준다." 할 일도 목표도
## 없이 **앉아서 하루가 지나가는 걸 보는 것 자체**가 전부인 곳이다.
##
## 그래서 이 씬에는 없는 게 셋이다:
## - `pickups()` 가 없다 — 주울 것 자체가 없다
## - `quest_zones()` 가 없다 — 닿아야 끝나는 자리도 없다
## - `open_goals()` 를 안 덮어쓴다 — 화살표가 다른 무엇도 안 짚고,
##   조용히 나가는 문만 짚는다(`Place.open_goals` 의 실내 기본값)
##
## 하는 일은 하나 — 앉아서 말 한 줄을 듣는다. **시간대에 따라 다른
## 말**을 한다(아침·낮·저녁). 몇 번을 다시 와도 늘 다른 참이라, 도감
## 처럼 "다 봤다" 로 끝나지 않는다.
##
## ## 왜 목록에 안 올리나
##
## 방울못은 ORDER 마을이고 "마을마다 딱 하나씩" 규칙(`Quests.LOCAL`
## 주석)을 이미 "데크 끝에서 물소리 듣기" 가 쓰고 있다. 게다가 그
## 물소리 자리에는 이미 개구리 붙박이 NPC 까지 있다 — 여기 또 하나를
## 목록 줄로 얹으면 같은 결을 두 번 되풀이하면서 체크리스트만 는다.
## 그래서 `갈밭머리:갈밭속` 과 같은 결정을 또 따른다 — **문은 걸어서
## 찾을 수 있게 열어 두되, 목록에도 화살표에도 안 올린다.**
##
## ## 왜 씬을 하나만 쓰나
##
## `GatherGround`·`ShopInterior` 와 같은 수법이다. 지금은 방울못
## 하나뿐이지만, 다른 마을에 조용한 자리가 필요해지면 `SPOTS` 에
## 한 칸만 더하면 된다.

## 마을 → 그늘 자리의 모든 것.
## {name, legend, solid, ambient, spawn, rows, props, sit, lines}
const SPOTS := {
	"방울못": {
		"name": "연밭 그늘",
		"legend": {"g": "grass", "w": "water"},
		"solid": ["water"],
		"ambient": "water",
		"spawn": [17, 16],
		# 연못이 이어져 들어온 작은 물굽이 하나. 데크도 다리도 없다 —
		# 마을 사람들 다니는 길이 아니라, 물가를 따라 슬쩍 들어온
		# 자리다.
		"rows": [
			"gggggggggggggggggggggggggggggggggg",
			"ggggwwwggggggggggggggggggggggggggg",
			"ggwwwwwwwggggggggggggggggggggggggg",
			"ggwwwwwwwggggggggggggggggggggggggg",
			"gwwwwwwwwwgggggggggggggggggggggggg",
			"ggwwwwwwwggggggggggggggggggggggggg",
			"ggwwwwwwwggggggggggggggggggggggggg",
			"ggggwwwggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggggggggggggg",
		],
		"props": [
			# 물가의 나무 하나가 그늘을 드리운다. 그 그늘에 앉을 벤치.
			[12, 3, "tree", true],
			[11, 5, "bench", true],
			[3, 6, "beach-grass", false],
			[8, 2, "beach-grass", false],
			[6, 7, "pebbles", false],
		],
		# 앉는 자리 — 나무 그늘 밑 벤치와 같은 칸.
		"sit": [11, 5, "그늘 자리"],
		# 시간대별로 다른 말. 몇 번을 다시 와도 늘 다른 참이다.
		"lines": {
			"아침": [
				"이슬이 채 안 마른 잎이 볕에 반짝인다.",
				"개구리는 아직 조용하다.",
			],
			"낮": [
				"잠자리 몇 마리가 물 위를 스친다.",
				"그늘이 마침 딱 좋다.",
			],
			"저녁": [
				"개구리 울음이 하나둘 늘어난다.",
				"여기 앉아 있으면 그 소리가 다 들린다.",
			],
		},
	},
}

## 어느 마을에서 들어왔나.
const FROM_SCENE := {
	"Bangulmot": "방울못",
}


func from_village() -> String:
	return String(FROM_SCENE.get(
		JourneyState.exit_scene.get_file().get_basename(), ""))


func _cfg() -> Dictionary:
	return SPOTS.get(from_village(), SPOTS.values()[0] if SPOTS.size() > 0 else {})


func pad_wide() -> bool:
	return false


func place_name() -> String:
	return String(_cfg().get("name", "그늘 자리"))


func _ready() -> void:
	var c := _cfg()
	legend = c.get("legend", {"g": "grass"})
	var st: Array = c.get("solid", ["water"])
	solid_tiles.clear()
	for s in st:
		solid_tiles.append(String(s))
	super()


func ground_map() -> String:
	return "\n".join(_cfg().get("rows", ["gggg"]))


func props() -> Array:
	return _cfg().get("props", [])


## 여기서는 안 잔다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


func spawn_tile() -> Vector2i:
	var s: Array = _cfg().get("spawn", [2, 2])
	return Vector2i(int(s[0]), int(s[1]))


## 들어온 그 문 앞으로 다시 나간다.
func doors() -> Array:
	var s := spawn_tile()
	return [{
		"tile": Vector2i(s.x, s.y + 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


## 여기는 실내(서브맵)다 - 볼 것을 다 보면 화살표가 나가는 문을
## 짚는다 (`Place.open_goals` 의 기본값. 여기선 따로 덮어쓸 것도
## 없다 - 앉는 자리는 목록 줄이 아니라서 애초에 짚을 대상이 아니다).
func is_indoors() -> bool:
	return true


func quest_village() -> String:
	return village_we_came_from()


func on_built() -> void:
	JourneyState.here = place_name()
	var c := _cfg()
	if not c.has("sit"):
		return
	var sit: Array = c["sit"]
	var lines_by_part: Dictionary = c.get("lines", {})
	var lines: Array = lines_by_part.get(JourneyState.day_part(),
		["여기 앉아 잠깐 쉰다."])
	put_spot(Vector2i(int(sit[0]), int(sit[1])), String(sit[2]), lines)


func bgm_track() -> String:
	return "room"


func ambient_kind() -> String:
	return String(_cfg().get("ambient", ""))
