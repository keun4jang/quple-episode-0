class_name GatherGround
extends Place
## 채집터. 마을 밖으로 한 걸음 더 나가는 작은 자리 — 갯바위·숲 그늘·
## 밭머리처럼, 그 마을 사람이 늘 다니진 않아도 아는 곳이다.
##
## 사냥이 아니라 **줍는다.** 살아 있는 것을 잡지 않는다 — 미역이나
## 소라처럼 물이 빠지면 그 자리에 그대로 있는 것들이다
## (`docs/stardew-lessons.md` (라) 절이 "낚시"를 안 배울 것으로 못
## 박아 둔 것과는 다른 갈래다. 사냥·낚시가 아니라 **걸어서 줍는
## 채집**이라 그 선을 안 넘는다).
##
## ## 왜 씬을 하나만 쓰나
##
## 가게 안(`ShopInterior`)·샛길(`SidePathInterior`)과 같은 수법이다.
## 골격(들어온 자리·나가는 문·채집 자리)은 한 곳에 두고, 지형과
## 무엇을 채집하는지만 마을마다 갈아 끼운다(`GROUNDS`).
##
## ## 샛길과 다른 점 — **매일 다시 채워진다**
##
## 샛길의 안쪽 자리는 한 번 닿으면 그걸로 끝이다. 여기는 다르다 —
## 오늘 걷어 가면 내일 다시 오면 또 있다. `JourneyState.gather_day` 가
## 이 자리를 마지막으로 채운 날을 기억해 뒀다가, 날이 바뀌면
## `clear_taken_for()` 로 되돌린다. **다시 와 볼 이유**를 만드는
## 여러 장치(재회 · 편지) 중 하나다.
##
## ## 할 일은 목록이 아니라 **줍는 것 자체**
##
## `Quests.quest_list()` 에 이 자리 몫이 없다 — 억지로 만들면 "몇 개
## 채웠나" 체크리스트가 된다(`docs/stardew-lessons.md` "도감·수집률·
## 업적" 항목). 대신 `open_goals()` 를 덮어써서, 오늘 아직 안 걷은
## 것이 있으면 그중 가장 가까운 것 하나만 화살표로 짚는다 — 이미 있는
## "떨어진 것 줍기" 화살표(`Place.goal_world` 의 pickup 갈래)를
## 그대로 빌려 쓴다.

## 마을 → 채집터의 모든 것.
## {name, legend, solid, ambient, spawn, rows, props, spots, flavor}
##
## **지금은 윤슬 하나뿐이다.** 다른 마을은 뼈대만 있으면 되므로,
## 재미가 확인되면 그때 하나씩 채운다(`docs/CLAUDE.md` 의 1탄 우선순위와
## 같은 결 — 한 곳을 제대로 만들고 넓힌다).
const GROUNDS := {
	"윤슬": {
		"name": "갯바위",
		"legend": {"s": "sand", "w": "water"},
		"solid": ["water"],
		"ambient": "water",
		"spawn": [17, 18],
		# 밀물 자국처럼 물웅덩이 넷을 흩어 둔다. 위쪽 넉 줄은 아예
		# 바다 — 물때가 안 빠지는 안쪽이다.
		"rows": [
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			"ssssssssssssssssssssssssssssssssss",
			"ssssssssssssssssssssssssssssssssss",
			"ssssssssssssssssssssswwwssssssssss",
			"ssssssssssssssssssssswwwssssssssss",
			"sssssssswwwsssssssssswwwssssssssss",
			"ssssssswwwwwssssssssssssssssssssss",
			"sssssssswwwsssssssssssssssssssssss",
			"ssssssssssssssssssssssssssssssssss",
			"ssssssssssssssssssssssssssssssssss",
			"sssssssssssssssswsssssssssssssssss",
			"ssssssssssssssswwwssssssssswssssss",
			"sssssssssssssssswssssssssswwwsssss",
			"ssssssssssssssssssssssssssswssssss",
			"ssssssssssssssssssssssssssssssssss",
			"ssssssssssssssssssssssssssssssssss",
			"ssssssssssssssssssssssssssssssssss",
		],
		"props": [
			# 물웅덩이 둘레의 바위. 사람이 놓은 게 아니니 한두 칸씩 어긋낸다.
			[6, 9, "boulder", true],
			[12, 9, "boulder", true],
			[24, 7, "boulder", true],
			[19, 6, "boulder", true],
			# 물웅덩이 자리에 걸터앉을 바위 - 아래 "flavor" 자리와 겹친다.
			[16, 12, "boulder", true],
			[10, 12, "pebbles", false],
			[23, 10, "pebbles", false],
			[15, 15, "beach-grass", false],
			[28, 16, "beach-grass", false],
			[29, 14, "beach-grass", false],
			[8, 6, "beach-grass", false],
		],
		# 매일 다시 채워지는 자리. [x, y, item_id]
		"spots": [
			[9, 11, "p-seaweed"],
			[22, 9, "p-conch"],
		],
		# 들여다볼 것 하나 — 여느 샛길처럼 보고 그대로 두는 자리다.
		"flavor": [16, 12, "물웅덩이", [
			"물이 빠지면서 웅덩이 하나가 남았다.",
			"작은 게 한 마리가 옆으로 걷다 돌 틈으로 숨는다.",
			"잡을 생각은 없다. 여기가 걔네 집이다.",
		]],
	},
}

## 어느 마을에서 들어왔나. 나갈 문에 적힌 씬 경로에서 되짚는다.
const FROM_SCENE := {
	"Yunseul": "윤슬",
}


func from_village() -> String:
	return String(FROM_SCENE.get(
		JourneyState.exit_scene.get_file().get_basename(), ""))


func _cfg() -> Dictionary:
	return GROUNDS.get(from_village(), GROUNDS.values()[0] if GROUNDS.size() > 0 else {})


func pad_wide() -> bool:
	return false


func place_name() -> String:
	return String(_cfg().get("name", "채집터"))


## `_init()` 은 씬을 만들 때라 아직 어디서 왔는지 모른다. 지형은
## 여기서 정한다 — 그리고 **날이 바뀌었으면 어제 걷어 간 것을
## 되돌린다.** `super()` 가 `_build_pickups()` 를 부르기 전에 해야
## 오늘 것으로 채워진 채 지어진다.
func _ready() -> void:
	var c := _cfg()
	legend = c.get("legend", {"s": "sand"})
	var st: Array = c.get("solid", ["water"])
	solid_tiles.clear()
	for s in st:
		solid_tiles.append(String(s))
	var pname := place_name()
	if JourneyState.gather_day.get(pname, -1) != JourneyState.day:
		JourneyState.clear_taken_for(pname)
		JourneyState.gather_day[pname] = JourneyState.day
	super()


func ground_map() -> String:
	return "\n".join(_cfg().get("rows", ["ssss"]))


func props() -> Array:
	return _cfg().get("props", [])


## 매일 채워지는 자리. `Place._build_pickups()` 가 그대로 쓴다 —
## 새 장치를 안 만들고 이미 있는 줍기 길을 탄다.
func pickups() -> Array:
	return _cfg().get("spots", [])


## 들어온 자리. 바로 밑이 나가는 문이다.
func spawn_tile() -> Vector2i:
	var s: Array = _cfg().get("spawn", [2, 2])
	return Vector2i(int(s[0]), int(s[1]))


## 여기서는 안 잔다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


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
## 여기는 실내다. 나가는 문을 짚어 주는 근거가 된다 (`Place.is_indoors`).
func is_indoors() -> bool:
	return true


func quest_village() -> String:
	return village_we_came_from()


## **오늘 아직 안 걷은 것이 있으면 그것부터 짚는다.**
##
## 이 자리는 `Quests.quest_list()` 에 줄이 없다 — 몇 개 채웠나 세는
## 체크리스트를 만들지 않으려는 것이다(위 주석). 대신 이미 있는
## "떨어진 것 줍기" 화살표(`goal_world` 의 pickup 갈래)를 빌린다.
## 오늘 몫을 다 걷었으면 `super()` 로 넘어가 — 실내 기본값대로
## 나가는 문을 짚는다.
func open_goals() -> Array:
	if not _loose.is_empty():
		return [{"label": "여기서 뭐라도 건져 보기", "kind": "pickup",
			"key": "", "done": false}]
	return super()


func on_built() -> void:
	JourneyState.here = place_name()
	var c := _cfg()
	if c.has("flavor"):
		var fl: Array = c["flavor"]
		put_spot(Vector2i(int(fl[0]), int(fl[1])), String(fl[2]), fl[3])


func bgm_track() -> String:
	return "journey"


func ambient_kind() -> String:
	return String(_cfg().get("ambient", ""))
