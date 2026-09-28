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
	if fever_t > 0.0:
		fever_t = maxf(0.0, fever_t - delta)
	_fever_idle += delta
	if _fever_idle > FEVER_IDLE and not fever_on() and fever > 0.0:
		fever = maxf(0.0, fever - delta * 3.0)
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


# ── 피버 타임 ────────────────────────────────────────────────────────
#
# **몇 분마다 한 번 터지는 것.** 쓰러뜨릴 때마다 게이지가 차고, 가득 차면
# 12초 동안 주는 피해 1.5배 · 경험과 꿈조각 2배. 화면 테두리가 무지개로 돈다.
# 한참 안 싸우면 게이지가 천천히 빠진다 - 몰아서 잡을수록 자주 터진다.

const FEVER_MAX := 100.0
const FEVER_SECS := 12.0
const FEVER_KILL := 9.0
const FEVER_ELITE := 35.0
const FEVER_BOSS := 60.0
const FEVER_WEAK := 2.0
## 이만큼(초) 안 싸우면 게이지가 빠지기 시작한다.
const FEVER_IDLE := 8.0
static var fever := 0.0
static var fever_t := 0.0
static var _fever_idle := 0.0


static func fever_on() -> bool:
	return fever_t > 0.0


## 게이지를 채운다. **이번에 피버가 터졌으면 참.**
static func fever_add(v: float) -> bool:
	_fever_idle = 0.0
	if fever_on():
		return false
	fever = minf(FEVER_MAX, fever + v * (1.0 + bless("fever")))
	if fever >= FEVER_MAX:
		fever = 0.0
		fever_t = FEVER_SECS
		return true
	return false


## 주는 피해 배율.
## **우두머리에게는 덜 든다** (0.1.192) - 우두머리의 길 졸개 열과 호위 둘을 잡으면 피버가
## 차서, 우두머리전 아홉 중 여섯이 피버로 시작했다 (시뮬레이션). 1.5배가 싸움 거의
## 전부에 걸려 약점 무기와 겹치면 4~8초에 끝났다. 경험·꿈조각 두 배와 연출은 그대로다.
const FEVER_BOSS_DMG := 1.2


static func fever_dmg(boss := false) -> float:
	if not fever_on():
		return 1.0
	return FEVER_BOSS_DMG if boss else 1.5


## 경험·꿈조각 배율.
static func fever_gain() -> float:
	return 2.0 if fever_on() else 1.0


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


## **이야기만큼만 열린다** - 쓰러뜨린 구역 우두머리 수 → 오를 수 있는 가장 높은 층.
## 대마왕을 물리친 뒤로는 끝이 없다.
##
## 0.1.186 시뮬레이션: 이 막힘이 없을 때는 윤슬 우두머리만 잡고 탑에 들어가도 **LV 9 → 50** 이
## 40분 만에 됐다 (네 직업 다). 층 몬스터가 나와 함께 세지니 축복을 쌓으며 끝없이
## 따라 오를 수 있었고, 나오면 남은 여덟 구역이 전부 싱거운 걸음이 됐다.
## 막는 층은 그 구역을 막 넘은 사람보다 네다섯 레벨 위다 - 도전할 거리는 되고,
## 앞질러 가는 사다리는 안 된다.
const TOWER_CAP := [0, 10, 15, 20, 20, 25, 30, 35, 40, 40]


static func bosses_down() -> int:
	var n := 0
	for v in Quests.ORDER:
		if Battle.boss_of(String(v)) != "" and Battle.boss_down(String(v)):
			n += 1
	return n


static func tower_cap() -> int:
	if JourneyState.quest_done("엔딩:대마왕"):
		return 9999
	return int(TOWER_CAP[clampi(bosses_down(), 0, TOWER_CAP.size() - 1)])


## 막힌 층 계단에 적을 말 - 어느 우두머리를 잡으면 더 열리나.
##
## **막힌 층을 실제로 올려 주는 우두머리**를 댄다. 바로 다음 우두머리가 아닐 수 있다 -
## `TOWER_CAP` 에 같은 값이 이어진 칸(20·20, 40·40)이 있어서, 그걸 잡아도 안 열리는데
## "하늬섬 우두머리 처치 뒤에 열려요" 라고 했었다 (0.1.191 점검). 한 마리로 안 열리면
## **몇 마리 더** 인지로 말한다 - 이름으로 대면 순서를 건너뛴 사람(마을 할 일로 연 구역)
## 에겐 그 우두머리를 잡아도 안 열렸다 (0.1.196 점검).
static func tower_cap_note() -> String:
	var now := tower_cap()
	var down := bosses_down()
	# 몇 마리 더 잡아야 열리나 - 순서를 건너뛴 사람도 있으니 누구를 잡든 수로 센다.
	var need := 0
	for k in range(1, TOWER_CAP.size()):
		if down + k >= TOWER_CAP.size():
			break
		if int(TOWER_CAP[down + k]) > now:
			need = k
			break
	var next_v := ""
	var next_b := ""
	for v in Quests.ORDER:
		var b := Battle.boss_of(String(v))
		if b != "" and not Battle.boss_down(String(v)):
			next_v = String(v)
			next_b = String(Battle.ENEMIES[b]["name"])
			break
	if need == 0 or next_v == "":
		return "더 위층은 야근 대마왕 처치 뒤에 열려요"
	if need == 1:
		return "더 위층은 %s 우두머리 %s 처치 뒤에 열려요" % [next_v, next_b]
	return "더 위층은 우두머리 %d 마리를 더 쓰러뜨리면 열려요 - 다음은 %s 우두머리 %s" % [
		need, next_v, next_b]


## 들어가면 시작하는 층 - 넘은 쉼터(5의 배수) 바로 위. 막힌 층까지 다 넘었으면
## 막힌 층 앞 쉼터부터 다시 오른다 (첫 보상은 없고 경험·꿈조각은 그대로).
static func tower_start() -> int:
	var start := (tower_best / TOWER_BOSS_EVERY) * TOWER_BOSS_EVERY + 1
	return maxi(1, mini(start, tower_cap() - TOWER_BOSS_EVERY + 1))


static func is_boss_floor(n: int) -> bool:
	return n % TOWER_BOSS_EVERY == 0


## 그 층 몬스터의 레벨. 층 x1.3 (0.1.184 에 x1.6 에서 낮췄다 - `docs/game-design.md` 7절).
static func floor_lv(n: int) -> int:
	return clampi(1 + int(float(n) * 1.3), 1, 99)


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


## 30층을 넘으면 층마다 몸과 힘이 6% 씩 더 붙는다 - 레벨 50 뒤로도 끝이 없게.
## (레벨만 올려서는 LV 50 장비가 다 갖춰지면 60층까지 그냥 걸어 올라갔다 - 시뮬레이션.)
static func floor_power(n: int) -> float:
	return pow(1.06, float(maxi(0, n - 30)))


## 몬스터 하나를 탑의 배율만큼 세게 한다.
static func power_up(foe: Dictionary, k: float) -> void:
	foe["hp"] = int(float(foe["hp"]) * k)
	foe["hp_max"] = foe["hp"]
	foe["atk"] = int(float(foe["atk"]) * k)


## 탑 몬스터가 주는 경험은 이만큼. 탑은 **장비·꿈조각·기록** 을 벌러 오는 곳이다.
## 층 몬스터가 나와 함께 세지니, 경험을 그대로 주면 열린 층 안에서도 한 번 오를
## 때마다 열 레벨 넘게 올라 다음 구역이 통째로 싱거워졌다 (0.1.186 시뮬레이션:
## 가풀재 뒤 LV 21 → 34).
const TOWER_XP := 0.3


## 탑 n층의 몬스터로 만든다 - 30층 위의 힘과 줄인 경험. `TowerFloor` 와
## 시뮬레이션(`tools/sim/SimBalance`)이 같이 쓴다.
static func tower_foe(foe: Dictionary, n: int) -> void:
	var k := floor_power(n)
	if k > 1.0:
		power_up(foe, k)
	foe["xp"] = maxi(1, int(round(float(foe.get("xp", 1)) * TOWER_XP)))


# ── 탑의 축복 (한 번 오르는 동안만) ─────────────────────────────────
#
# 층을 넘을 때마다 **셋 중 하나**를 고른다 (`BlessPick`). 고른 것은 이번에
# 오르는 동안 쌓인다 - 마을에서 푸른 틈으로 새로 들어오면 비운다.
# 같은 층을 매번 똑같이 오르지 않게, 그리고 "이번엔 이렇게 짜 볼까" 가 되게.

const BLESSINGS := {
	"might": {"name": "꿈의 힘", "desc": "주는 피해 +20퍼센트", "atk": 0.2},
	"keen": {"name": "날카로운 꿈", "desc": "치명타 확률 +12퍼센트", "crit": 0.12},
	"shell": {"name": "단단한 꿈", "desc": "받는 피해 -15퍼센트", "guard": 0.15},
	"leech": {"name": "배부른 꿈", "desc": "쓰러뜨릴 때마다 체력 8퍼센트 회복", "leech": 0.08},
	"flow": {"name": "샘솟는 꿈", "desc": "마음력이 두 배로 찬다", "mp": 1.0},
	"gold": {"name": "반짝이는 꿈", "desc": "꿈조각 +40퍼센트", "coin": 0.4},
	"hot": {"name": "달아오른 꿈", "desc": "피버 게이지가 두 배로 찬다", "fever": 1.0},
}
## 받는 피해는 여기까지만 줄어든다 - 겹쳐 쌓아도 무적이 되지 않게.
const BLESS_GUARD_CAP := 0.6
## **같은 축복은 이만큼까지만 쌓인다.** 끝없이 쌓이면 LV 9 로도 60층을 넘었다
## (0.1.184 시뮬레이션). 다 찬 축복은 더 내밀지 않는다.
const BLESS_MAX := 3
static var blessings: Array = []
## 이번에 오르는 동안 쓴 층들. 탑은 오를 때마다 새로 서지만(`TowerFloor`), 앱을
## 껐다 켜 **같은 층으로 이어하면** 몬스터가 다시 서고 축복을 또 내밀었다 - 껐다
## 켜기만으로 축복을 다 채울 수 있었다 (0.1.191 점검). 마을에서 새로 들어오면 비운다.
static var climb_cleared: Array = []


## 새로 오르기 시작한다 - 마을의 푸른 틈으로 들어올 때.
static func start_climb() -> void:
	blessings.clear()
	climb_cleared.clear()


## 고른 축복이 주는 그 값의 합.
static func bless(key: String) -> float:
	var v := 0.0
	for id in blessings:
		v += float(BLESSINGS.get(String(id), {}).get(key, 0.0))
	if key == "guard":
		v = minf(v, BLESS_GUARD_CAP)
	return v


## 층을 넘었다 - 고를 것 셋. 층과 지금까지 고른 수로 씨를 심는다.
static func bless_offer(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bless|%d|%d" % [n, blessings.size()])
	var pool: Array = BLESSINGS.keys().filter(func(k): return blessings.count(k) < BLESS_MAX)
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


static func add_blessing(id: String) -> void:
	if BLESSINGS.has(id) and blessings.count(id) < BLESS_MAX:
		blessings.append(id)


## 그 층을 처음 넘으면 받는 것.
static func floor_reward(n: int) -> Dictionary:
	var boss := is_boss_floor(n)
	return {"coins": 40 + 12 * n, "stones": 3 if boss else (1 if n % 2 == 0 else 0),
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
	blessings = []
	climb_cleared = []
	fever = 0.0
	fever_t = 0.0


static func to_dict() -> Dictionary:
	return {"kills": kills.duplicate(), "titles": titles.duplicate(), "title": title,
		"daily": daily.duplicate(true), "attend": attend.duplicate(),
		"last_seen": int(Time.get_unix_time_from_system()), "best_combo": best_combo,
		"tower_best": tower_best, "tower_now": tower_now, "blessings": blessings.duplicate(),
		"climb_cleared": climb_cleared.duplicate(), "fever": fever}


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
	if d.get("blessings") is Array:
		blessings = d["blessings"].duplicate()
	if d.get("climb_cleared") is Array:
		climb_cleared = d["climb_cleared"].duplicate()
	fever = clampf(float(d.get("fever", 0.0)), 0.0, FEVER_MAX - 1.0)
