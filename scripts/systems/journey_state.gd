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
##
## **타입을 적어 둔다.** `:=` 로 두면 `DAY_START` 가 int 라 minutes 도 int 가
## 되는데, 시계는 매 프레임 0.033분씩 더한다. int 면 그게 통째로 잘려 나가
## 시계가 오전 6:00 에 영영 멈춘다. 밤도 안 오고 하루도 안 끝난다.
var minutes: float = DAY_START

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


## 몇 번 떠났나. 여행자를 옮기는 박자를 여기서 센다.
var departures := 0


## 내가 떠나면 그 사람도 떠난다.
##
## 내가 가는 곳으로 **따라오게** 하지 않는다. 그건 우연이 아니라 스토킹이다.
## 그렇다고 그냥 한 칸씩 돌게 두면 안 된다 — 한동안 그렇게 뒀는데,
## 목록 순서대로 여행하는 가장 자연스러운 진행에서 여행자가 늘 한 칸
## 앞서서 **한 번도 못 만났다.** 이 게임의 심장이 안 뛰었다.
##
## 그래서 평소엔 제 갈 길로 돌되, **세 번에 한 번은 겹친다** — 그것도
## 아직 거기서 만난 적이 없을 때만. 플레이어에겐 우연으로 보이지만
## 실제로는 반드시 일어난다. 재회 대사가 세 단계인 것과 박자를 맞췄다.
func move_wanderer(dest: String = "", from: String = "") -> void:
	# 프롤로그를 떠날 때는 안 움직인다. 여기서 한 칸 밀면 첫 여행지에서
	# 스쳐 지나가고, 그 뒤로 계속 어긋난다.
	if from == "쿼울":
		return
	departures += 1
	if departures % 3 == 0 and WANDERER_STOPS.has(dest) \
			and not wanderer_seen.has(dest):
		wanderer_place = dest
		return
	var i := WANDERER_STOPS.find(wanderer_place)
	if i < 0:
		i = 0
	var n := WANDERER_STOPS.size()
	var nxt: String = WANDERER_STOPS[(i + 1) % n]
	if nxt == dest:
		# 겹칠 차례가 아닌데 겹치면 재회가 싸구려가 된다.
		nxt = WANDERER_STOPS[(i + 2) % n]
	wanderer_place = nxt


## 몇 번 도착했나. `visited` 와 다르다 — 같은 곳에 또 와도 하나 는다.
var arrivals := 0


func visit(place: String) -> void:
	if place == "":
		return
	arrivals += 1
	if place != "고향":
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
## 세는 것이 **다녀온 곳 수가 아니라 도착 횟수**인 이유:
## 1탄에 여행지가 넷뿐이라 `places_visited()` 는 아무리 다녀도 4 에서 멈춘다.
## 세 곳마다 한 통이면 편지가 평생 한 통이었다. 같은 곳에 다시 가는 것도
## 떠난 것이니, 떠난 횟수로 센다.
func maybe_letter() -> void:
	var due := int(arrivals / 2)
	while letters_sent < due and letters_sent < LETTERS.size():
		var text: String = LETTERS[letters_sent]
		letters.append({"text": text, "day": day, "read": false})
		letters_sent += 1
		letter_came.emit(text)
		AudioManager.message_arrive()


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


## 엽서에 **글이 있어야 한다.**
##
## 한동안 이름만 적어 뒀더니, 평상에 앉아 넘겨 보는 장면이 그냥
## 이름 목록이었다. 여행 끝에 읽는 것이 명단이면 안 된다.
const POSTCARD_LINES := [
	"그때 그 자리, 아직 그대로예요.",
	"바람이 좋아서 문득 생각났어요.",
	"잘 지내요? 여긴 여전해요.",
	"다음에 오면 그거 또 해요.",
	"혼자 걷다 보면 여기 생각날 거예요.",
	"오늘 노을이 그날이랑 비슷했어요.",
]


func give_postcard(folk_id: String, who: String) -> void:
	if folk_id == "" or postcards.has(folk_id):
		return
	# 누가 어떤 줄을 쓰는지는 늘 같아야 한다. 다시 켰을 때 글이 바뀌면
	# 받아 둔 엽서가 아니라 매번 새로 쓰이는 종이가 된다.
	var h := 0
	for i in folk_id.length():
		h = (h * 31 + folk_id.unicode_at(i)) % 100003
	postcards[folk_id] = {
		"who": who,
		"text": POSTCARD_LINES[h % POSTCARD_LINES.size()],
		"place": here,
		"day": day,
	}
	postcard_came.emit(folk_id)
	AudioManager.souvenir_get()


## 엽서 한 장을 사람이 읽는 두 줄로. 옛 저장본(이름 문자열)도 받아 준다.
func postcard_text(folk_id: String) -> String:
	var c = postcards.get(folk_id, null)
	if c == null:
		return ""
	if c is Dictionary:
		var place := String(c.get("place", ""))
		var head := String(c.get("who", "")) + (("  ·  " + place) if place != "" else "")
		return "%s\n%s" % [head, String(c.get("text", ""))]
	return String(c)


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
		"postcards": postcards.duplicate(true),
		"arrivals": arrivals,
		"departures": departures,
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
	postcards = d.get("postcards", {}).duplicate(true) \
		if d.get("postcards") is Dictionary else {}
	arrivals = maxi(0, int(d.get("arrivals", 0)))
	departures = maxi(0, int(d.get("departures", 0)))
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
	arrivals = 0
	departures = 0
