class_name ShopInterior
extends Place
## 가게 안. 문을 지나 들어온 안쪽.
##
## 파는 사람은 밖에 그대로 서 있고, 안은 물건을 좀 더 가까이 보는
## 자리다. 그래서 씬은 하나만 쓴다 — 아홉 마을에 아홉 개를 그릴 일이
## 아니다.
##
## **다만 아홉 곳이 완전히 똑같으면 안 된다.** 문 아홉 개가 같은 방
## 하나로 이어져서, 네 번째 마을쯤 들어가면 "아, 또 이 방" 이 된다.
## 골격(문·통로·진열대)은 그대로 두고 **바닥과 곁의 물건만** 마을 결에
## 맞춰 바꾼다 (`SKIN`). 그림을 새로 안 그리고, 이미 있는 소품을
## 다시 쓴다 — 바닷가 가게에는 그물과 부표가, 고갯길 가게에는 장작과
## 연장이 있는 식이다.
##
## **나갈 때는 들어온 그 문 앞으로.** `JourneyState.exit_scene` 과
## `exit_tile` 에 밖에서 들어오기 직전 서 있던 자리가 적혀 있다
## (`Place._do_enter()` 가 문을 지날 때 남긴다).
##
## ── 크기가 방 치고 큰 이유 ───────────────────────────────────────────
##
## 좁은 방 하나만 그릴 생각이었는데, 줌 규칙이 밖과 안을 가리지 않는다.
## 초광각 폰에서 4배로 봐도 지도 밖 회색이 안 드러나려면 가로세로 다
## 34칸은 있어야 한다 (`journey_camera.gd` 의 `_recalc_floor`). 그래서
## 방 하나가 아니라 **진열대 여럿을 갖춘 가게**로 채운다.

const W := 35
const H := 18

## 곁 물건을 놓는 자리. **들어서자마자 보이는 데** 둔다.
##
## 처음엔 바깥 기둥(x 2, 32)에 뒀는데, 문 앞에서 화면에 잡히는 건
## 가로로 스무 칸 남짓이라 **들어가도 안 보였다** — 마을마다 다르게
## 해 놓고 정작 다른 줄을 모르는 꼴이었다. 문 앞 통로(x = W/2)와
## 이미 골격이 쓰는 칸은 비켜서, 문에서 보이는 자리로 옮겼다.
const SKIN_POS := [[11, 16], [23, 16], [12, 12], [22, 12], [5, 11]]

## 마을마다 다른 결. [바닥, 진열대 둘째 줄, 곁 물건 다섯]
##
## 곁 물건은 다 **지나갈 수 있게** 둔다. 좁은 방에 막는 것을 더 놓으면
## 들어오자마자 갇힌 것처럼 느껴진다.
const SKIN := {
	"윤슬": ["wood-floor", "바닷바람 냄새가 밴 가게다.",
		["net", "buoy", "parasol", "icebox", "pebbles"]],
	"볕뉘": ["stone-slab", "오래된 돌담 마을의 가게다.",
		["jars", "flower-pots", "jars", "stone-wall", "bench"]],
	"가풀재": ["wood-floor", "고갯길을 오르내리는 사람들이 들르는 가게다.",
		["firewood", "tools", "bench", "boulder", "firewood"]],
	"하늬섬": ["stone-slab", "바람이 센 섬의 가게다. 문을 꼭 닫아 둔다.",
		["clothesline", "jars", "boulder", "jars", "pebbles"]],
	"굽이나루": ["wood-floor", "강에서 막 올라온 것들이 놓인 가게다.",
		["buoy", "net", "pebbles", "washtub", "bench"]],
	"방울못": ["wood-floor", "빵 냄새가 남아 있는 가게다.",
		["cabinet", "flower-pots", "bench", "cabinet", "jars"]],
	"갈밭머리": ["clay-earth", "갈대밭 한가운데 선 쉼터 같은 가게다.",
		["shrub", "firewood", "bench", "beach-grass", "washtub"]],
	"솔은재": ["wood-floor", "솔향이 도는 고개 중턱의 가게다.",
		["boulder", "firewood", "bench", "pine", "tools"]],
	"꽃눈벌": ["clay-earth", "들판 한복판, 밭에서 난 것들이 놓인 가게다.",
		["flower-pots", "fence", "mailbox", "washtub", "flower-pots"]],
}

## 어느 마을에서 들어왔나. 나갈 문에 적힌 씬 경로에서 되짚는다 —
## 그 하나로 충분해서 새 저장 항목을 만들지 않았다.
const FROM_SCENE := {
	"Yunseul": "윤슬", "Byeotnwi": "볕뉘", "Gapuljae": "가풀재",
	"Hanuiseom": "하늬섬", "Gubinaru": "굽이나루", "Bangulmot": "방울못",
	"Galbatmeori": "갈밭머리", "Soleunjae": "솔은재", "Kkonnunbeol": "꽃눈벌",
}


func from_village() -> String:
	return String(FROM_SCENE.get(
		JourneyState.exit_scene.get_file().get_basename(), ""))


func _skin() -> Array:
	return SKIN.get(from_village(), ["wood-floor", "", []])


func place_name() -> String:
	return "가게 안"


func _init() -> void:
	legend = {"f": "wood-floor"}
	solid_tiles = []


## `_init()` 은 씬을 만들 때라 아직 어디서 왔는지 모른다. 바닥은
## 지도를 짓기 직전에 정해야 한다.
func _ready() -> void:
	legend = {"f": String(_skin()[0])}
	super()


func ground_map() -> String:
	var row := ""
	for x in W:
		row += "f"
	var rows: Array = []
	for y in H:
		rows.append(row)
	return "\n".join(rows)


## 문 바로 안쪽에서 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(W / 2, H - 2)


## 진열대를 가운데로 모으고, 문 앞 세로줄(x = W/2)은 비워 둔다 —
## 들어오자마자 무엇에도 막히지 않아야 한다.
func props() -> Array:
	var mid := W / 2
	return [
		# 접수대 — 문에서 보자마자 마주치는 자리. 좌우로 대칭.
		[mid - 4, 4, "reception", true],
		[mid + 4, 4, "reception", true],
		# 진열장 두 줄
		[mid - 9, 3, "cabinet", true],
		# "진열대" 대사가 걸리는 그 진열장이다 (아래 `on_built()` 의
		# `put_spot()` 과 같은 칸) — 금색 테두리로 표시된다.
		[mid - 2, 3, "cabinet", true, true],
		[mid + 2, 3, "cabinet", true],
		[mid + 9, 3, "cabinet", true],
		# 아이스박스 — 시원한 것들
		[mid - 12, 7, "icebox", true],
		[mid + 12, 7, "icebox", true],
		[mid - 12, 8, "firewood", false],
		[mid + 12, 8, "firewood", false],
		# 장독대 — 가게에도 항아리는 있다. 한쪽만 있으면 어색하니 양쪽에.
		[mid - 5, 9, "jars", true],
		[mid - 3, 9, "jars", true],
		[mid + 3, 9, "jars", true],
		[mid + 5, 9, "jars", true],
		# 화분 — 살아 있는 것이 하나는 있어야 가게가 안 차갑다
		[mid - 7, 11, "flower-pots", false],
		[mid + 7, 11, "flower-pots", false],
		# 안쪽 좌판 — 문에서 먼 벽 쪽이 비어 보이지 않게 한 줄 더 채운다
		[mid - 9, 13, "stall", true],
		[mid + 9, 13, "stall", true],
		[mid - 11, 14, "tools", true],
		[mid + 11, 14, "washtub", false],
		# 손님 자리 — 문 앞 통로 바로 옆
		[mid - 3, 15, "bench", true],
		[mid + 3, 15, "bench", true],
	] + _skin_props()


## 마을마다 다른 곁 물건. 정해진 자리에 이름만 갈아 끼운다.
func _skin_props() -> Array:
	var names: Array = _skin()[2]
	var out: Array = []
	for i in mini(names.size(), SKIN_POS.size()):
		out.append([SKIN_POS[i][0], SKIN_POS[i][1], String(names[i]), false])
	return out


## 문. 들어온 자리로 다시 나간다.
func doors() -> Array:
	return [{
		"tile": Vector2i(W / 2, H - 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	# 둘째 줄만 마을마다 다르다. 첫 줄은 어느 가게에서나 같은 말이다.
	var lines: Array = ["이것저것 소소한 것들이 놓여 있다."]
	var mine := String(_skin()[1])
	lines.append(mine if mine != "" else "여행 중에 필요한 건 대충 다 있는 듯하다.")
	put_spot(Vector2i(W / 2 - 2, 3), "진열대", lines)


func bgm_track() -> String:
	return "room"


func ambient_kind() -> String:
	return ""
