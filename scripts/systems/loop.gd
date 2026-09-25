class_name Loop
extends RefCounted
## 계속 켜게 하는 것들 (`docs/redesign-dream.md` 5절).
##
## 세 겹 고리를 동시에 돌린다 - 어느 순간에 끄든 "조금만 더" 가 하나는 남게:
##   짧은   연타(콤보) · 정예 몬스터
##   중간   오늘의 임무 셋 (날짜가 바뀌면 새로)
##   긴     출석 7일 · 사냥 칭호(종마다 10·100·500) · 잠든 사이 모인 꿈조각
##
## 날짜는 **폰의 실제 날짜**다 (게임 속 하루가 아니다) - 내일 또 켤 이유.

## 테스트는 끈다 - 장소를 띄울 때마다 출석·잠든 사이 보상이 끼어들면 수가 흔들린다.
static var welcome_on := true

# ── 연타 ─────────────────────────────────────────────────────────────

## 이 안에 또 때리면 연타가 이어진다(초).
const COMBO_WINDOW := 3.0
static var combo := 0
static var combo_t := 0.0
static var best_combo := 0


static func hit(n: int = 1) -> void:
	combo += n
	combo_t = COMBO_WINDOW
	best_combo = maxi(best_combo, combo)
	note("combo", combo)


static func tick(delta: float) -> void:
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0


## 연타가 길면 쓰러뜨릴 때 경험을 더 준다.
static func combo_bonus() -> float:
	if combo >= 50:
		return 1.5
	if combo >= 30:
		return 1.25
	if combo >= 10:
		return 1.1
	return 1.0


# ── 정예 ─────────────────────────────────────────────────────────────

## 한 마리가 정예일 확률. 크고 금빛이고, 잘 떨어뜨린다.
const ELITE_CHANCE := 0.07
const ELITE_HP := 4.0
const ELITE_ATK := 1.3
const ELITE_XP := 5.0

# ── 사냥 칭호 ────────────────────────────────────────────────────────

static var kills: Dictionary = {}          # 종 → 쓰러뜨린 수 (모든 구역)
static var titles: Array = []              # 얻은 칭호
static var title := ""                     # 머리 위에 다는 것
const TITLE_STEPS := [10, 100, 500]
const TITLE_NAMES := ["사냥꾼", "전문가", "대가"]
## 칭호 하나마다 체력 최대 +5 - 모으는 보람이 몸에 남게.
const TITLE_HP := 5


## 쓰러뜨렸다. 새 칭호를 얻었으면 그 이름, 아니면 "".
static func add_kill(kind: String) -> String:
	kills[kind] = int(kills.get(kind, 0)) + 1
	var n := int(kills[kind])
	var i := TITLE_STEPS.find(n)
	if i < 0:
		return ""
	var nm := "%s %s" % [String(Battle.ENEMIES.get(kind, {}).get("name", kind)), TITLE_NAMES[i]]
	if not titles.has(nm):
		titles.append(nm)
	title = nm
	return nm


static func title_hp() -> int:
	return titles.size() * TITLE_HP


# ── 오늘의 임무 ──────────────────────────────────────────────────────

## 임무 틀. 날마다 날짜로 셋을 뽑는다.
const DAILY_POOL := [
	{"kind": "kill", "need": 40, "label": "몬스터 %d마리 쓰러뜨리기"},
	{"kind": "kill_elem", "need": 20, "label": "%s 속성 몬스터 %d마리"},
	{"kind": "elite", "need": 1, "label": "정예 몬스터 %d마리"},
	{"kind": "skill", "need": 30, "label": "스킬 %d번 쓰기"},
	{"kind": "combo", "need": 25, "label": "%d 연타 만들기"},
	{"kind": "weak", "need": 15, "label": "약점 %d번 찌르기"},
	{"kind": "enhance", "need": 1, "label": "장비 강화 %d번 해 보기"},
]

## `{date, list: [{kind, elem, need, have, label, claimed}]}`
static var daily: Dictionary = {}


static func today() -> String:
	return Time.get_date_string_from_system()


## 날짜가 바뀌었으면 새로 뽑는다.
static func ensure_daily() -> void:
	var d := today()
	if String(daily.get("date", "")) == d:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("daily|" + d)
	var pool := DAILY_POOL.duplicate()
	var list: Array = []
	for i in 3:
		var e: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var q := {"kind": String(e["kind"]), "need": int(e["need"]), "have": 0,
			"claimed": false, "elem": ""}
		if q["kind"] == "kill_elem":
			q["elem"] = String(Battle.ELEM_ORDER[rng.randi_range(0, 4)])
			q["label"] = String(e["label"]) % [Battle.elem_name(q["elem"]), q["need"]]
		else:
			q["label"] = String(e["label"]) % q["need"]
		list.append(q)
	daily = {"date": d, "list": list}


## 무언가 했다. `combo` 는 더하지 않고 가장 긴 것을 적는다.
static func note(kind: String, amount: int = 1, elem: String = "") -> void:
	ensure_daily()
	for q in daily["list"]:
		if bool(q["claimed"]) or int(q["have"]) >= int(q["need"]):
			continue
		if String(q["kind"]) != kind:
			continue
		if kind == "kill_elem" and String(q["elem"]) != elem:
			continue
		if kind == "combo":
			q["have"] = mini(int(q["need"]), maxi(int(q["have"]), amount))
		else:
			q["have"] = mini(int(q["need"]), int(q["have"]) + amount)


## 임무 하나의 보상. 레벨이 오를수록 꿈조각이 는다.
static func daily_reward() -> Dictionary:
	return {"coins": 150 + Battle.level * 15, "stones": 1, "xp": Battle.xp_need() / 5}


## 다 한 임무를 받는다. 받은 것들 `[{label, coins, stones, xp, events}]`.
static func claim_ready() -> Array:
	ensure_daily()
	var out: Array = []
	for q in daily["list"]:
		if bool(q["claimed"]) or int(q["have"]) < int(q["need"]):
			continue
		q["claimed"] = true
		var r := daily_reward()
		Gear.coins += int(r["coins"])
		Gear.stones += int(r["stones"])
		var evs := Battle.gain_xp(int(r["xp"]))
		out.append({"label": String(q["label"]), "coins": int(r["coins"]),
			"stones": int(r["stones"]), "xp": int(r["xp"]), "events": evs})
	return out


# ── 출석 ─────────────────────────────────────────────────────────────

## 이레 동안 날마다 하나. 일곱째 날은 영웅 장비.
const ATTEND := [
	{"coins": 200, "text": "꿈조각 200"},
	{"stones": 2, "text": "강화석 2"},
	{"coins": 400, "text": "꿈조각 400"},
	{"box": 1, "text": "꿈 상자"},
	{"stones": 5, "text": "강화석 5"},
	{"coins": 800, "text": "꿈조각 800"},
	{"hero": 1, "text": "영웅 장비"},
]
static var attend: Dictionary = {"last": "", "count": 0}


## 오늘 처음 켰으면 출석 보상을 준다. `{day, text}` 또는 빈 것.
static func check_attend() -> Dictionary:
	var d := today()
	if String(attend.get("last", "")) == d:
		return {}
	attend["last"] = d
	attend["count"] = int(attend.get("count", 0)) % ATTEND.size() + 1
	var r: Dictionary = ATTEND[int(attend["count"]) - 1]
	Gear.coins += int(r.get("coins", 0))
	Gear.stones += int(r.get("stones", 0))
	if r.has("box") or r.has("hero"):
		var it := Gear.roll_gear("", Battle.level, false)
		Gear._reroll(it, 3 if r.has("hero") else maxi(1, int(it["rar"])))
		Gear.items.append(it)
	return {"day": int(attend["count"]), "text": String(r["text"])}


# ── 잠든 사이 ────────────────────────────────────────────────────────

## 이 게임의 주제와 맞는다 - **앱을 끄고 자는 동안에도 꿈이 모인다.**
## 10분마다 (5 + 레벨) 꿈조각, 최대 8시간치.
const IDLE_MAX_MIN := 480
static var last_seen := 0


## 켜자마자 부른다. 모인 꿈조각을 주고 그 수를 돌려준다 (10분이 안 됐으면 0).
static func check_idle() -> int:
	var now := int(Time.get_unix_time_from_system())
	var got := 0
	if last_seen > 0 and now > last_seen:
		var mins := mini(IDLE_MAX_MIN, (now - last_seen) / 60)
		if mins >= 10:
			got = (mins / 10) * (5 + Battle.level)
			Gear.coins += got
	last_seen = now
	return got


# ── 꿈의 탑 ──────────────────────────────────────────────────────────
#
# 끝이 없는 층 오르기 (`TowerFloor`). 층을 다 쓸면 계단이 열린다. 층마다
# 몬스터가 두 레벨쯤 세지고, **다섯 층마다 우두머리 층**이다 - 아홉 구역
# 보스가 차례로 다시 선다. 처음 넘는 층마다 꿈조각, 우두머리 층은 강화석과
# 고급 이상 장비. **다섯 층마다 쉼터** - 다음에 들어오면 거기서 시작한다.
#
# 윤슬 보스를 쓰러뜨려 첫 꿈의 문이 열리면 마을마다 푸른 틈으로 열린다.

## 가장 높이 넘은 층 (기록).
static var tower_best := 0
## 지금 서 있는 층. 탑 씬이 이걸 보고 층을 짓는다.
static var tower_now := 1
const TOWER_BOSS_EVERY := 5
## 층에 서는 몬스터 (뒷층일수록 뒷구역 종이 섞인다).
const TOWER_KINDS := ["drop", "ember", "sprout", "pebble", "gust", "whirl", "thorn",
	"mole", "storm", "blaze"]


static func tower_open() -> bool:
	return Battle.boss_down("윤슬")


## 들어가면 시작하는 층 - 넘은 쉼터(5의 배수) 바로 위.
static func tower_start() -> int:
	return (tower_best / TOWER_BOSS_EVERY) * TOWER_BOSS_EVERY + 1


static func is_boss_floor(n: int) -> bool:
	return n % TOWER_BOSS_EVERY == 0


## 그 층 몬스터의 레벨. 30층이 LV 50 쯤이다.
static func floor_lv(n: int) -> int:
	return clampi(2 + int(float(n) * 1.6), 1, 99)


## 그 층에 서는 몬스터 `[종, 레벨]`. 층 번호로 씨를 심는다 - 같은 층은 늘 같은 무리.
static func floor_spawns(n: int) -> Array:
	var lv := floor_lv(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tower|%d" % n)
	var pool: Array = TOWER_KINDS.slice(0, mini(TOWER_KINDS.size(), 3 + n / 2))
	var out: Array = []
	if is_boss_floor(n):
		var bosses: Array = []
		for v in Quests.ORDER:
			if Battle.boss_of(String(v)) != "":
				bosses.append(Battle.boss_of(String(v)))
		out.append([String(bosses[(n / TOWER_BOSS_EVERY - 1) % bosses.size()]), lv + 2])
		for i in 2:
			out.append([String(pool[rng.randi_range(0, pool.size() - 1)]), lv])
		return out
	for i in mini(4 + n / 3, 10):
		out.append([String(pool[rng.randi_range(0, pool.size() - 1)]),
			clampi(lv + rng.randi_range(-1, 1), 1, 99)])
	return out


## 그 층을 처음 넘으면 받는 것.
static func floor_reward(n: int) -> Dictionary:
	var boss := is_boss_floor(n)
	return {"coins": 60 + 25 * n, "stones": 3 if boss else (1 if n % 2 == 0 else 0),
		"gear": boss}


## 층을 다 쓸었다. **처음 넘는 층**이면 보상을 주고 그 내용을, 아니면 빈 것.
static func clear_floor(n: int) -> Dictionary:
	if n <= tower_best:
		return {}
	tower_best = n
	var r := floor_reward(n)
	Gear.coins += int(r["coins"])
	Gear.stones += int(r["stones"])
	if bool(r["gear"]):
		var it := Gear.roll_gear("", floor_lv(n), true)
		Gear._reroll(it, maxi(2, int(it["rar"])))
		Gear.items.append(it)
		r["item"] = it
	return r


# ── 저장 ─────────────────────────────────────────────────────────────

static func reset() -> void:
	combo = 0
	combo_t = 0.0
	best_combo = 0
	kills = {}
	titles = []
	title = ""
	daily = {}
	attend = {"last": "", "count": 0}
	last_seen = 0
	tower_best = 0
	tower_now = 1


static func to_dict() -> Dictionary:
	return {"kills": kills.duplicate(), "titles": titles.duplicate(), "title": title,
		"daily": daily.duplicate(true), "attend": attend.duplicate(),
		"last_seen": int(Time.get_unix_time_from_system()), "best_combo": best_combo,
		"tower_best": tower_best, "tower_now": tower_now}


static func from_dict(d: Dictionary) -> void:
	reset()
	if d.get("kills") is Dictionary:
		kills = d["kills"].duplicate()
	if d.get("titles") is Array:
		titles = d["titles"].duplicate()
	title = String(d.get("title", ""))
	if d.get("daily") is Dictionary:
		daily = d["daily"].duplicate(true)
	if d.get("attend") is Dictionary:
		attend = d["attend"].duplicate()
	last_seen = int(d.get("last_seen", 0))
	best_combo = int(d.get("best_combo", 0))
	tower_best = maxi(0, int(d.get("tower_best", 0)))
	tower_now = maxi(1, int(d.get("tower_now", 1)))
