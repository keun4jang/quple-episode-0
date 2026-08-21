class_name SidePathInterior
extends Place
## 샛길. 마을 큰길에서 옆으로 빠지는, 반쯤 숨은 자리.
##
## **문을 열고 방에 들어가는 게 아니다.** 가게·등대는 네모난 방이고 능
## 안쪽길은 둥근 둘레길인데, 여기는 셋 다와 달라야 한다 — 강 한복판
## 모래톱이거나, 솔숲 사이 굽은 길이거나, 밭과 밭 사이 두렁이다.
## 문 시스템을 그대로 쓰되 플레이어에게는 "문" 이 아니라 **샛길**로 보인다.
##
## ## 왜 씬을 하나만 쓰나
##
## 가게 안(`ShopInterior`)과 같은 수법이다. 셋을 따로 그리면 셋을 따로
## 고쳐야 한다. 골격(들어온 자리·나가는 문·안쪽 자리)은 한 곳에 두고,
## 지형과 소품만 마을마다 갈아 끼운다(`PATHS`).
##
## ## 완료는 문이 아니라 **안쪽 자리**에서 난다
##
## 마을 쪽 문에는 뜻 없는 `enter_key`("샛길입구")를 준다. 문을 지난 것만
## 으로 끝났다고 치면 샛길을 만든 뜻이 없어지기 때문이다. 진짜 표시는
## `quest_zones()` 가 안쪽 자리에서 남긴다 — 능 안쪽길에서 쓴 그 방식이고,
## `Quests.LOCAL` 의 넷째 칸(표시)이 이 열쇠와 짝이다.

## 마을 → 이 샛길의 모든 것.
## {name, legend, solid, w, h, rows, props, spawn, goal_key, goal, radius, spot}
const PATHS := {
	"굽이나루": {
		"name": "모래톱 샛길",
		"legend": {"w": "water", "s": "sand", "y": "dry-grass", "d": "deck"},
		"solid": ["water"],
		"spawn": [18, 20],
		"goal_key": "굽이나루:물굽이", "goal": [21, 2], "radius": 40.0,
		"ambient": "water",
		"spot": [20, 2, "두 굽이", ["여기서는 강이 두 번 굽는 것이 한눈에 보인다.", "위에서 한 번, 모래톱을 지나 아래에서 또 한 번.", "물은 서두르는 법이 없다."]],
		"rows": [
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwwwwswwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwwssswwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwssswwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwssssswwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwssssswwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwssssswwwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwssssssswwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwssssssswwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwssssssswwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwssssssssswwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwssssssssswwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwssssssssswwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwssssssssyyywwwwwwwwww",
			"wwwwwwwwwwwwwwwwssssssssyyywwwwwwwwww",
			"wwwwwwwwwwwwwwsssssssssyyyywwwwwwwwww",
			"wwwwwwwwwwwwwwsssssssssyyyywwwwwwwwww",
			"wwwwwwwwwwwwwwsssssssssyyyywwwwwwwwww",
			"wwwwwwwwwwwwwwwwwdddwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwdddwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwdddwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwdddwwwwwwwwwwwwwwwww",
		],
		"props": [
			[7, 10, "buoy", false],
			[30, 8, "buoy", false],
			[9, 4, "boulder", true],
			[28, 18, "boulder", true],
			[24, 2, "boulder", true],
			[18, 11, "boulder", true],
			[14, 16, "beach-grass", false],
			[25, 13, "beach-grass", false],
			[11, 7, "beach-grass", false],
			[15, 5, "beach-grass", false],
			[16, 9, "pebbles", false],
		],
	},
	"솔은재": {
		"name": "솔그늘 샛길",
		"legend": {"g": "grass", "d": "dirt", ".": "dry-grass"},
		# **소나무만으로는 길이 안 갇힌다.** 막는 소품의 몸은 칸 아래쪽
		# 8px 뿐이고(`Place._build_props` — "밑동만 막는다"), 주인공 몸은
		# 6px 라 그 위로 8px 짜리 틈이 남는다. 나무 뒤로 지나갈 수 있는
		# 건 일부러 그렇게 만든 것이다. 그래서 나무 줄을 벽으로 쓰면
		# 비스듬히 숲을 가로질러 버린다 — 굽이도는 길이 뜻을 잃는다.
		# 형제 둘(물·밭)처럼 **바닥으로** 막는다. `_build_solid_floor()`
		# 가 칸 높이 그대로 이어진 벽을 세운다.
		"solid": ["grass"],
		"spawn": [18, 20],
		"goal_key": "솔은재:솔그늘", "goal": [26, 2], "radius": 40.0,
		"ambient": "",
		"spot": [26, 1, "솔방울 묻은 자리", ["솔잎이 유난히 도톰하게 쌓인 데가 있다.", "손을 대지는 않았다.", "누가 겨울을 미리 챙겨 둔 자리다."]],
		"rows": [
			"gggggggggggggggggggggggggggggggggggg",
			"gggggggggggggggggggggggg.....ggggggg",
			"ggggggggggggggggggggggg......ggggggg",
			"gggggggggggggggggggggggdddgggggggggg",
			"gggggggggggggggggggggdddgggggggggggg",
			"ggggggggggggggggggddddgggggggggggggg",
			"ggggggggggggggggdddggggggggggggggggg",
			"gggggggggggggddddggggggggggggggggggg",
			"gggggggggggdddgggggggggggggggggggggg",
			"ggggggggddddgggggggggggggggggggggggg",
			"gggggggdddgggggggggggggggggggggggggg",
			"ggggggddddgggggggggggggggggggggggggg",
			"ggggggddddgggggggggggggggggggggggggg",
			"gggggggdddgggggggggggggggggggggggggg",
			"ggggggggddddgggggggggggggggggggggggg",
			"ggggggggggdddggggggggggggggggggggggg",
			"ggggggggggggdddggggggggggggggggggggg",
			"gggggggggggggddddggggggggggggggggggg",
			"gggggggggggggggdddgggggggggggggggggg",
			"ggggggggggggggggdddggggggggggggggggg",
			"gggggggggggggggggdddgggggggggggggggg",
			"gggggggggggggggggdddgggggggggggggggg",
		],
		"props": [
			[24, 0, "pine", true],
			[25, 0, "pine", true],
			[26, 0, "pine", true],
			[27, 0, "pine", true],
			[28, 0, "boulder", true],
			[23, 1, "pine", true],
			[29, 1, "pine", true],
			[22, 2, "pine", true],
			[29, 2, "pine", true],
			[21, 3, "pine", true],
			[22, 3, "pine", true],
			[26, 3, "pine", true],
			[27, 3, "pine", true],
			[28, 3, "boulder", true],
			[18, 4, "pine", true],
			[19, 4, "pine", true],
			[20, 4, "pine", true],
			[24, 4, "pine", true],
			[25, 4, "pine", true],
			[16, 5, "pine", true],
			[17, 5, "pine", true],
			[22, 5, "pine", true],
			[23, 5, "boulder", true],
			[13, 6, "pine", true],
			[14, 6, "pine", true],
			[15, 6, "pine", true],
			[19, 6, "pine", true],
			[20, 6, "pine", true],
			[21, 6, "pine", true],
			[11, 7, "pine", true],
			[12, 7, "pine", true],
			[17, 7, "boulder", true],
			[18, 7, "pine", true],
			[8, 8, "pine", true],
			[9, 8, "pine", true],
			[10, 8, "pine", true],
			[14, 8, "pine", true],
			[15, 8, "pine", true],
			[16, 8, "pine", true],
			[7, 9, "pine", true],
			[12, 9, "boulder", true],
			[13, 9, "pine", true],
			[6, 10, "pine", true],
			[10, 10, "pine", true],
			[11, 10, "pine", true],
			[5, 11, "pine", true],
			[10, 11, "pine", true],
			[5, 12, "pine", true],
			[10, 12, "pine", true],
			[6, 13, "boulder", true],
			[10, 13, "pine", true],
			[11, 13, "pine", true],
			[7, 14, "pine", true],
			[12, 14, "pine", true],
			[8, 15, "pine", true],
			[9, 15, "pine", true],
			[13, 15, "pine", true],
			[14, 15, "pine", true],
			[10, 16, "boulder", true],
			[11, 16, "pine", true],
			[15, 16, "pine", true],
			[16, 16, "pine", true],
			[12, 17, "pine", true],
			[17, 17, "pine", true],
			[13, 18, "pine", true],
			[14, 18, "pine", true],
			[18, 18, "pine", true],
			[15, 19, "boulder", true],
			[19, 19, "pine", true],
			[16, 20, "pine", true],
			[20, 20, "pine", true],
			[16, 21, "pine", true],
			[20, 21, "pine", true],
			[9, 11, "bench", true],
			[7, 13, "shrub", false],
			[15, 17, "shrub", false],
			[12, 8, "shrub", false],
			[24, 1, "bench", true],
			[26, 1, "pebbles", false],
			[23, 2, "shrub", false],
		],
	},
	"꽃눈벌": {
		"name": "밭사잇길",
		"legend": {"f": "tilled-soil", "d": "dirt", "g": "grass", "y": "dry-grass"},
		"solid": ["tilled-soil"],
		"spawn": [19, 22],
		"goal_key": "꽃눈벌:밭사이", "goal": [3, 2], "radius": 40.0,
		"ambient": "",
		"spot": [5, 2, "들판 끝", ["여기 서면 지나온 뙈기가 다 내려다보인다.", "누가 몇 해를 갈아 온 자리인지 알 것 같다.", "올라온 길은 벌써 안 보인다."]],
		"rows": [
			"ffyyyyyyffffffffffffffffffffffffffffff",
			"fyyyyyyyyfffffffffffffffffffffffffffff",
			"fyyyyyyyyddfffffffffffffffffffffffffff",
			"ffyyyyyyydddddddddddffffffffffffffffff",
			"ffffyyyyyggddddddddddddddddddfffffffff",
			"fffffffffffgggggggggddddddddddddddgggf",
			"ffffffffffffffffffffgggggggggdddddgggf",
			"fffffffffffffffffffffffffffffggggggggf",
			"ffffffffffffffffffffffffffffffgggggggf",
			"ffffffffffffffffffffffffffffffddddgggf",
			"ffffffffffffffffffffddddddddddddddgggf",
			"ffffffffffddddddddddddddddddddgggggggf",
			"ffffddddddddddddddddggggggggggffffffff",
			"ffffddddddggggggggggffffffffffffffffff",
			"ffffddggggffffffffffffffffffffffffffff",
			"ffffddffffffffffffffffffffffffffffffff",
			"ffddddffffffffffffffffffffffffffffffff",
			"ffddddddddddffffffffffffffffffffffffff",
			"fgggddddddddddddddddffffffffffffffffff",
			"fgggggggggggdddddddddddddfffffffffffff",
			"fgggffffffffggggggdddddddfffffffffffff",
			"ffffffffffffffffffddgggggfffffffffffff",
			"ffffffffffffffffffddffffffffffffffffff",
			"ffffffffffffffffffddffffffffffffffffff",
		],
		"props": [
			[17, 20, "signpost", false],
			[21, 22, "fence", false],
			[24, 21, "pebbles", false],
			[12, 14, "fence", false],
			[7, 15, "tree", true],
			[26, 8, "tree", true],
			[30, 17, "tree", true],
			[35, 8, "shrub", false],
			[5, 2, "flower-pots", false],
		],
	},
}


## 어느 마을에서 들어왔나. 나갈 문에 적힌 씬 경로에서 되짚는다.
const FROM_SCENE := {
	"Gubinaru": "굽이나루", "Soleunjae": "솔은재", "Kkonnunbeol": "꽃눈벌",
}

func from_village() -> String:
	return String(FROM_SCENE.get(
		JourneyState.exit_scene.get_file().get_basename(), ""))


func _cfg() -> Dictionary:
	return PATHS.get(from_village(), PATHS.values()[0] if PATHS.size() > 0 else {})


func pad_wide() -> bool:
	return false


func place_name() -> String:
	return String(_cfg().get("name", "샛길"))


## 지형은 들어온 마을을 알아야 정해진다. `_init()` 때는 아직 모른다.
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


func pickups() -> Array:
	return []


## 들어온 자리 — 아래쪽 가운데. 바로 밑이 나가는 문이다.
func spawn_tile() -> Vector2i:
	var s: Array = _cfg().get("spawn", [2, 2])
	return Vector2i(int(s[0]), int(s[1]))


## 여기서는 안 잔다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


## 안쪽 자리. **여기 닿아야** 그 마을의 할 일이 끝난다.
func quest_zones() -> Array:
	var c := _cfg()
	if not c.has("goal"):
		return []
	var g: Array = c["goal"]
	# 네 번째 칸은 **띠에 적을 이름**이다. 비워 두면 실내에서
	# 위쪽 안내가 통째로 사라진다 (`Place.open_goals`).
	return [[String(c.get("goal_key", "")), Vector2i(int(g[0]), int(g[1])),
		float(c.get("radius", 48.0)),
		String(c.get("goal_name", "안쪽 끝까지 가 보기"))]]


## 들어온 그 문 앞으로 다시 나간다.
func doors() -> Array:
	var s := spawn_tile()
	return [{
		"tile": Vector2i(s.x, s.y + 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


## 할 일은 **들어온 마을 것**을 이어 본다 (`Place.quest_village`).
## 여기는 실내다. 나가는 문을 짚어 주는 근거가 된다
## (`Place.is_indoors`).
func is_indoors() -> bool:
	return true


func quest_village() -> String:
	return village_we_came_from()


func on_built() -> void:
	JourneyState.here = place_name()
	var c := _cfg()
	# 안쪽 자리에 들여다볼 것 하나. 파거나 가져오지 않는다 — 보고 그대로
	# 두는 것이 이 게임의 결이다.
	if c.has("spot"):
		var sp: Array = c["spot"]
		put_spot(Vector2i(int(sp[0]), int(sp[1])), String(sp[2]), sp[3])


func bgm_track() -> String:
	return "journey"


func ambient_kind() -> String:
	return String(_cfg().get("ambient", ""))
