extends Node
## 여행 중에 지니고 다니는 것 (오토로드 `JourneyState`).
##
## 배낭에 든 것과, 어디서 무엇을 이미 주웠는지를 기억한다.
## 한 번 주운 것은 그 자리에 다시 안 생긴다 — 같은 자리를 왔다 갔다 하며
## 퍼 담는 게임이 아니다.

signal picked(item: String, total: int)
signal heart_up(folk_id: String, heart: int)
signal day_passed(day: int)
signal letter_came(text: String)
signal postcard_came(folk_id: String)
signal photo_taken(photo: Dictionary)

## 아이템 이름 → 개수
var bag: Dictionary = {}
## 이미 주운 자리. "고향:12,7" 같은 문자열
var taken: Dictionary = {}
## 지금 어느 여행지에 있나
var here := ""

## 인연 → 마음 칸 (0~5). 숫자는 화면에 절대 안 보여 준다.
var hearts: Dictionary = {}
## 며칠째인가
var day := 1
## 지금 몇 분인가. 아침 6시에 시작해 자정에 하루가 끝난다.
var minutes := DAY_START

const DAY_START := 6 * 60
const DAY_END := 24 * 60
const HEART_MAX := 5


# ── 마음 ──────────────────────────────────────────────────────────────

func heart(folk_id: String) -> int:
	return int(hearts.get(folk_id, 0))


func warm(folk_id: String, by: int = 1) -> void:
	if folk_id == "":
		return
	var h := mini(heart(folk_id) + by, HEART_MAX)
	hearts[folk_id] = h
	heart_up.emit(folk_id, h)


## 몇 군데나 다녀왔나 (고향은 안 센다)
var visited: Dictionary = {}

# ── 여행자 ────────────────────────────────────────────────────────────
#
# 붙박이는 그 마을에 산다. **여행자는 나처럼 돌아다닌다.**
# 부산에서 만난 너구리를 파리에서 다시 만나는 것 — 이 게임은 그 한
# 순간을 위해 나머지가 다 있다 (`docs/redesign-journey.md` 5절).
#
# 우연에 맡기면 영영 안 만날 수도 있다. 그래서 **자리를 정해 놓고 옮긴다.**
# 플레이어에겐 우연으로 보이지만 실제로는 반드시 일어난다.

## 여행자가 지금 어디 있나
var wanderer_place := "쿼릉"
## 어디서 만났었나
var wanderer_seen: Dictionary = {}
## 여행자가 갈 수 있는 곳 (고향은 뺀다 — 남의 고향에 갈 리 없다)
const WANDERER_STOPS := ["쿼릉", "쿼주", "쿼산", "쿼도"]


func wanderer_here(place: String) -> bool:
	return wanderer_place == place


## 처음이 아니고, **처음 보는 곳**에서 만났나
func is_reunion(place: String) -> bool:
	return not wanderer_seen.is_empty() and not wanderer_seen.has(place) \
		and wanderer_here(place)


func meet_wanderer(place: String) -> void:
	wanderer_seen[place] = true


## 내가 떠나면 그 사람도 떠난다.
##
## 내가 가는 곳으로 **따라오게** 하지 않는다. 그건 우연이 아니라 스토킹이다.
## 대신 목록을 한 칸씩 돌게 두면, 서로 다른 속도로 돌다 언젠가 겹친다.
func move_wanderer() -> void:
	var i := WANDERER_STOPS.find(wanderer_place)
	if i < 0:
		i = 0
	wanderer_place = WANDERER_STOPS[(i + 1) % WANDERER_STOPS.size()]


func visit(place: String) -> void:
	if place != "" and place != "고향":
		visited[place] = true


func places_visited() -> int:
	return visited.size()


# ── 편지 · 엽서 · 사진 ────────────────────────────────────────────────

## 엄마 편지. 안 읽어도 벌이 없다 (`docs/story-journey.md` 5절).
var letters: Array = []
## 마음 다섯 칸을 채운 인연에게서 온 엽서. folk_id → 이름
var postcards: Dictionary = {}
## 직접 찍은 사진
var photos: Array = []
## 이미 몇 통 보냈나
var letters_sent := 0

## 여행지 세 곳마다 한 통. 짧다.
const LETTERS := [
	"밥은 먹고 다니니.",
	"김치 담갔다. 너 좋아하는 거.",
	"바쁘면 안 와도 된다.",
	"아버지가 마당 손봤다.",
	"감 익었더라.",
]


## 여행지를 다녀올 때마다 살핀다. 세 곳마다 한 통.
##
## 가라고 시키지 않는 대신 편지가 쌓인다. 화살표도 느낌표도 안 쓴다 —
## 세 통쯤 쌓이면 대부분 알아서 간다.
func maybe_letter() -> void:
	var due := int(places_visited() / 3.0)
	while letters_sent < due and letters_sent < LETTERS.size():
		var text: String = LETTERS[letters_sent]
		letters.append({"text": text, "day": day, "read": false})
		letters_sent += 1
		letter_came.emit(text)


func unread_letters() -> int:
	var n := 0
	for l in letters:
		if not bool(l.get("read", false)):
			n += 1
	return n


func read_letters() -> void:
	for l in letters:
		l["read"] = true


## 고향에 다녀오면 편지는 다 읽은 것으로 친다 — 직접 만났으니까.
func came_home() -> void:
	read_letters()


func give_postcard(folk_id: String, who: String) -> void:
	if folk_id == "" or postcards.has(folk_id):
		return
	postcards[folk_id] = who
	postcard_came.emit(folk_id)


func take_photo(place: String, subject: String) -> Dictionary:
	var p := {
		"place": place,
		"day": day,
		"time": time_text(),
		"subject": subject,
	}
	photos.append(p)
	photo_taken.emit(p)
	return p


# ── 하루 ──────────────────────────────────────────────────────────────

func time_text() -> String:
	var h := int(minutes / 60.0)
	var m := int(minutes) % 60
	var ampm := "오전" if h < 12 else "오후"
	var hh := h % 12
	if hh == 0:
		hh = 12
	return "%s %d:%02d" % [ampm, hh, m]


## 밤인가 (화면을 어둡게 할지)
func night_amount() -> float:
	# 오후 5시부터 어두워지기 시작해 밤 9시에 가장 어둡다.
	if minutes < 17 * 60:
		return 0.0
	return clampf((minutes - 17 * 60) / float(4 * 60), 0.0, 1.0)


func advance_time(mins: float) -> void:
	minutes = minf(minutes + mins, DAY_END)


func day_is_over() -> bool:
	return minutes >= DAY_END


func sleep() -> void:
	day += 1
	minutes = DAY_START
	day_passed.emit(day)


func pick(item: String, count: int = 1) -> void:
	bag[item] = int(bag.get(item, 0)) + count
	picked.emit(item, bag[item])


func count(item: String) -> int:
	return int(bag.get(item, 0))


func total() -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


func kinds() -> int:
	return bag.size()


## 그 자리 것을 이미 주웠나
func is_taken(place: String, t: Vector2i) -> bool:
	return taken.has(_key(place, t))


func mark_taken(place: String, t: Vector2i) -> void:
	taken[_key(place, t)] = true


func _key(place: String, t: Vector2i) -> String:
	return "%s:%d,%d" % [place, t.x, t.y]


# ── 저장 ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"bag": bag.duplicate(),
		"taken": taken.duplicate(),
		"here": here,
		"hearts": hearts.duplicate(),
		"day": day,
		"minutes": minutes,
		"visited": visited.duplicate(),
		"wanderer_place": wanderer_place,
		"wanderer_seen": wanderer_seen.duplicate(),
		"letters": letters.duplicate(true),
		"letters_sent": letters_sent,
		"postcards": postcards.duplicate(),
		"photos": photos.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	bag = d.get("bag", {}).duplicate() if d.get("bag") is Dictionary else {}
	taken = d.get("taken", {}).duplicate() if d.get("taken") is Dictionary else {}
	here = String(d.get("here", ""))
	hearts = d.get("hearts", {}).duplicate() if d.get("hearts") is Dictionary else {}
	day = maxi(1, int(d.get("day", 1)))
	minutes = clampf(float(d.get("minutes", DAY_START)), DAY_START, DAY_END)
	visited = d.get("visited", {}).duplicate() if d.get("visited") is Dictionary else {}
	wanderer_place = String(d.get("wanderer_place", "쿼릉"))
	wanderer_seen = d.get("wanderer_seen", {}).duplicate() \
		if d.get("wanderer_seen") is Dictionary else {}
	letters = d.get("letters", []).duplicate(true) if d.get("letters") is Array else []
	letters_sent = int(d.get("letters_sent", 0))
	postcards = d.get("postcards", {}).duplicate() \
		if d.get("postcards") is Dictionary else {}
	photos = d.get("photos", []).duplicate(true) if d.get("photos") is Array else []


func reset() -> void:
	bag = {}
	taken = {}
	here = ""
	hearts = {}
	day = 1
	minutes = DAY_START
	visited = {}
	wanderer_place = "쿼릉"
	wanderer_seen = {}
	letters = []
	letters_sent = 0
	postcards = {}
	photos = []
