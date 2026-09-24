class_name Gear
extends RefCounted
## 무기·방어구·꿈조각 (`docs/redesign-dream.md` 4절).
##
## **드랍의 손맛이 이 게임을 계속 켜게 한다.** 같은 "불꽃 은빛 검" 도
## 등급과 옵션 줄이 다 달라서, 더 좋은 줄을 찾으려고 또 잡는다.
##
## 장비는 배낭(`JourneyState.bag`, 이름 → 개수)에 안 넣는다. 하나하나가
## 다르기 때문이다 - 여기 `items` 에 한 벌씩 따로 든다.
##
## 정적 싱글턴 (`Battle` 과 같은 까닭 - 갱신 팩으로 폰에 간다).

# ── 칸 · 종류 · 단계 · 등급 ─────────────────────────────────────────

const SLOTS := ["weapon", "hat", "top", "gloves", "shoes", "ring"]
const SLOT_NAME := {"weapon": "무기", "hat": "모자", "top": "옷", "gloves": "장갑",
	"shoes": "신발", "ring": "장신구"}
## 무기 종류. 직업마다 드는 것이 다르다 (`Battle.JOBS[..]["weapon"]`).
## 막대기는 꿈나그네의 것 - 누구나 든다.
const WEAPONS := {"stick": "막대기", "sword": "검", "staff": "지팡이",
	"bow": "활", "dagger": "단검"}
const ARMOR_NAME := {"hat": "모자", "top": "옷", "gloves": "장갑", "shoes": "신발",
	"ring": "반지"}
## 다섯 단계 - 몬스터 레벨 10 마다 한 단계.
const TIERS := [
	{"lv": 1, "name": "나무"}, {"lv": 10, "name": "쇠"}, {"lv": 20, "name": "은빛"},
	{"lv": 30, "name": "용맹"}, {"lv": 40, "name": "꿈결"},
]
const WEAPON_ATK := [4, 15, 27, 40, 54]
## 방어구 칸마다 기본으로 붙는 것 (단계마다 곱한다).
const ARMOR_BASE := {
	"hat": {"def": 2, "mp": 4}, "top": {"def": 3, "hp": 12},
	"gloves": {"atk": 2, "crit": 1}, "shoes": {"def": 2, "hp": 6},
	"ring": {"str": 1, "dex": 1, "int": 1, "luk": 1},
}
## 등급 다섯. 떨어질 때 **빛기둥 색**으로 먼저 안다.
const RARITY := [
	{"name": "일반", "col": "#E9E4DA", "opts": 0, "mult": 1.0},
	{"name": "고급", "col": "#69DB7C", "opts": 1, "mult": 1.12},
	{"name": "희귀", "col": "#4DABF7", "opts": 2, "mult": 1.27},
	{"name": "영웅", "col": "#B197FC", "opts": 3, "mult": 1.45},
	{"name": "전설", "col": "#FFA94D", "opts": 3, "mult": 1.7},
]
## 몬스터가 떨어뜨리는 등급의 확률 (%). 우두머리는 따로.
const DROP_ODDS := [70.0, 22.0, 6.5, 1.4, 0.1]
const BOSS_ODDS := [0.0, 35.0, 40.0, 20.0, 5.0]
## 몬스터 하나가 장비를 떨어뜨릴 확률.
const DROP_CHANCE := 0.12
## 무기 이름 앞에 붙는 속성.
const ELEM_PREFIX := {"none": "", "water": "물결", "fire": "불꽃", "wood": "숲",
	"earth": "대지", "wind": "바람"}

## 옵션 줄. 단계가 오를수록 값이 커진다 (`_opt_value`).
const OPTS := {
	"atk": {"name": "공격력", "base": 2.0, "pct": false},
	"def": {"name": "방어력", "base": 2.0, "pct": false},
	"hp": {"name": "체력", "base": 12.0, "pct": false},
	"mp": {"name": "마음력", "base": 5.0, "pct": false},
	"str": {"name": "힘", "base": 2.0, "pct": false},
	"dex": {"name": "민첩", "base": 2.0, "pct": false},
	"int": {"name": "지능", "base": 2.0, "pct": false},
	"luk": {"name": "행운", "base": 2.0, "pct": false},
	"crit": {"name": "치명타", "base": 2.0, "pct": true},
	"elem": {"name": "속성 피해", "base": 5.0, "pct": true},
	"coin": {"name": "꿈조각", "base": 6.0, "pct": true},
	"drop": {"name": "드랍률", "base": 5.0, "pct": true},
}
const OPT_KEYS := ["atk", "def", "hp", "mp", "str", "dex", "int", "luk",
	"crit", "elem", "coin", "drop"]
## 전설은 옵션 셋에 고유 효과가 하나 더 붙는다.
const LEGEND := {"elem": 20, "crit": 8}

## 강화 +0 ~ +15. 한 칸마다 기본 수치 6% 오른다.
const PLUS_MAX := 15
const PLUS_STEP := 0.06

# ── 가진 것 ───────────────────────────────────────────────────────────

## 꿈조각 - 몬스터·퀘스트가 준다. 상점·강화에 쓴다.
static var coins := 0
## 강화석.
static var stones := 0
## 가진 장비 한 벌씩 `{uid, slot, kind, tier, rar, elem, plus, opts: [[키, 값]]}`.
static var items: Array = []
## 칸 → uid.
static var equipped: Dictionary = {}
static var _uid := 1


static func reset() -> void:
	coins = 0
	stones = 0
	items = []
	equipped = {}
	_uid = 1


static func get_item(uid: int) -> Dictionary:
	for it in items:
		if int(it["uid"]) == uid:
			return it
	return {}


static func worn(slot: String) -> Dictionary:
	if not equipped.has(slot):
		return {}
	return get_item(int(equipped[slot]))


static func is_worn(uid: int) -> bool:
	for s in equipped:
		if int(equipped[s]) == uid:
			return true
	return false


# ── 한 벌의 수치 ─────────────────────────────────────────────────────

static func tier_of_lv(lv: int) -> int:
	return clampi(lv / 10, 0, TIERS.size() - 1)


static func name_of(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var t := String(TIERS[int(it["tier"])]["name"])
	var base := ""
	if String(it["slot"]) == "weapon":
		var pre := String(ELEM_PREFIX.get(String(it.get("elem", "none")), ""))
		base = "%s %s" % [t, String(WEAPONS[String(it["kind"])])]
		if pre != "":
			base = pre + " " + base
	else:
		base = "%s %s" % [t, String(ARMOR_NAME[String(it["slot"])])]
	if int(it.get("plus", 0)) > 0:
		base = "+%d %s" % [int(it["plus"]), base]
	return base


static func rarity_col(it: Dictionary) -> Color:
	return Color(String(RARITY[int(it.get("rar", 0))]["col"]))


static func _grow(it: Dictionary) -> float:
	return float(RARITY[int(it["rar"])]["mult"]) * (1.0 + PLUS_STEP * float(it.get("plus", 0)))


## 무기 공격력.
static func atk_of(it: Dictionary) -> int:
	if it.is_empty() or String(it["slot"]) != "weapon":
		return 0
	return int(round(float(WEAPON_ATK[int(it["tier"])]) * _grow(it)))


## 한 벌이 주는 것 전부 `{능력치: 값}` (기본 + 옵션 + 전설).
static func stats_of(it: Dictionary) -> Dictionary:
	var out := {}
	if it.is_empty():
		return out
	var slot := String(it["slot"])
	if slot != "weapon":
		var base: Dictionary = ARMOR_BASE[slot]
		for k in base:
			out[k] = int(out.get(k, 0)) + int(round(float(base[k]) * (1.0 + int(it["tier"]) * 1.2)
				* _grow(it)))
	for o in it.get("opts", []):
		out[String(o[0])] = int(out.get(String(o[0]), 0)) + int(o[1])
	if int(it["rar"]) >= 4:
		for k in LEGEND:
			out[k] = int(out.get(k, 0)) + int(LEGEND[k])
	return out


## 입은 것 전부가 주는 그 능력치.
static func bonus(stat: String) -> int:
	var n := 0
	for s in equipped:
		n += int(stats_of(worn(String(s))).get(stat, 0))
	return n


## 든 무기의 공격력. 맨손이면 3.
static func weapon_atk() -> int:
	var w := worn("weapon")
	return atk_of(w) if not w.is_empty() else 3


## 든 무기의 속성. 맨손·무속성이면 "none".
static func weapon_elem() -> String:
	return String(worn("weapon").get("elem", "none"))


static func weapon_kind() -> String:
	return String(worn("weapon").get("kind", ""))


## 이 직업이 들 수 있나. 꿈나그네는 무엇이든, 전직하면 제 무기만. 막대기는 누구나.
static func can_wield(it: Dictionary, job: String = "") -> bool:
	if String(it.get("slot", "")) != "weapon":
		return true
	var j := job if job != "" else Battle.job
	var k := String(it["kind"])
	if k == "stick" or j == "novice":
		return true
	return String(Battle.JOBS[j]["weapon"]) == k


## 한 줄 설명들 (배낭 설명 판).
static func lines_of(it: Dictionary) -> Array:
	var out: Array = []
	if String(it["slot"]) == "weapon":
		out.append("공격력 %d   속성 %s" % [atk_of(it), Battle.elem_name(String(it["elem"]))])
	var st := stats_of(it)
	for k in OPT_KEYS:
		if st.has(k):
			var o: Dictionary = OPTS[k]
			out.append("%s +%d%s" % [String(o["name"]), int(st[k]), " 퍼센트" if bool(o["pct"]) else ""])
	return out


# ── 만들기 · 떨어뜨리기 ──────────────────────────────────────────────

static func _opt_value(key: String, tier: int) -> int:
	var o: Dictionary = OPTS[key]
	var v := float(o["base"]) * (1.0 + 0.8 * tier)
	if bool(o["pct"]):
		v = float(o["base"]) + tier * float(o["base"]) * 0.4
	return maxi(1, int(round(v * randf_range(0.7, 1.3))))


static func make(slot: String, kind: String, tier: int, rar: int, elem: String) -> Dictionary:
	var it := {"uid": _uid, "slot": slot, "kind": kind, "tier": tier, "rar": rar,
		"elem": elem if slot == "weapon" else "none", "plus": 0, "opts": []}
	_uid += 1
	var pool := OPT_KEYS.duplicate()
	pool.shuffle()
	for i in int(RARITY[rar]["opts"]):
		it["opts"].append([String(pool[i]), _opt_value(String(pool[i]), tier)])
	return it


static func _roll_rarity(odds: Array) -> int:
	var total := 0.0
	for o in odds:
		total += float(o)
	# 드랍률 옵션만큼 좋은 쪽으로 조금 민다.
	var r := randf() * total * (1.0 - clampf(bonus("drop") / 200.0, 0.0, 0.3))
	for i in odds.size():
		r -= float(odds[i])
		if r <= 0.0:
			return i
	return 0


## 몬스터가 쓰러질 때 떨어뜨리는 것. `{coins, stones, gear: [한 벌…]}`.
## 줍는 것은 부르는 쪽이 `take()` 로 한다.
static func roll_drops(kind: String, lv: int, boss: bool) -> Dictionary:
	var out := {"coins": 0, "stones": 0, "gear": []}
	var c := lv * 3 + randi_range(0, maxi(1, lv))
	c = int(c * (1.0 + bonus("coin") / 100.0))
	out["coins"] = c * (20 if boss else 1)
	if randf() < (1.0 if boss else 0.08):
		out["stones"] = 3 if boss else 1
	var n := 2 if boss else (1 if randf() < DROP_CHANCE * (1.0 + bonus("drop") / 100.0) else 0)
	for i in n:
		out["gear"].append(roll_gear(kind, lv, boss))
	return out


## 한 벌. 무기가 반, 방어구가 반. 무기 속성은 **절반쯤 그 몬스터의 속성**을
## 닮는다 - 물 몬스터를 잡으면 물결 무기가 잘 나온다.
static func roll_gear(kind: String, lv: int, boss: bool) -> Dictionary:
	var tier := tier_of_lv(lv)
	var rar := _roll_rarity(BOSS_ODDS if boss else DROP_ODDS)
	if randf() < 0.5:
		var kinds := ["sword", "staff", "bow", "dagger"]
		var mine := String(Battle.JOBS[Battle.job]["weapon"])
		var wk := mine if mine != "" and randf() < 0.6 else String(kinds.pick_random())
		var fe := String(Battle.ENEMIES.get(kind, {}).get("elem", "none"))
		var el := fe if randf() < 0.5 and Battle.BEATS.has(fe) \
			else String(Battle.ELEM_ORDER.pick_random())
		return make("weapon", wk, tier, rar, el)
	var slot := String(["hat", "top", "gloves", "shoes", "ring"].pick_random())
	return make(slot, slot, tier, rar, "none")


## 떨어진 것을 줍는다.
static func take(drops: Dictionary) -> void:
	coins += int(drops.get("coins", 0))
	stones += int(drops.get("stones", 0))
	for it in drops.get("gear", []):
		items.append(it)


## 전직하면 제 무기 하나를 받아 든다 (쇠 단계 일반, 무속성).
static func starter_weapon(job: String) -> Dictionary:
	var k := String(Battle.JOBS.get(job, {}).get("weapon", ""))
	if k == "":
		return {}
	var it := make("weapon", k, 1, 0, "none")
	items.append(it)
	equip(int(it["uid"]))
	return it


## 처음 시작할 때 드는 나무 막대기.
static func starter_stick() -> void:
	if not items.is_empty():
		return
	var it := make("weapon", "stick", 0, 0, "none")
	items.append(it)
	equip(int(it["uid"]))


# ── 입기 · 벗기 · 강화 · 팔기 ───────────────────────────────────────

static func equip(uid: int) -> bool:
	var it := get_item(uid)
	if it.is_empty() or not can_wield(it):
		return false
	var hp_was := Battle.hp_max()
	equipped[String(it["slot"])] = uid
	# 체력 최대가 늘면 늘어난 만큼 같이 찬다 (벗으면 넘친 만큼만 깎는다).
	Battle.hp = clampi(Battle.hp + maxi(0, Battle.hp_max() - hp_was), 1, Battle.hp_max())
	Battle.mp = mini(Battle.mp, Battle.mp_max())
	return true


static func unequip(slot: String) -> void:
	equipped.erase(slot)
	Battle.hp = clampi(Battle.hp, 1, Battle.hp_max())
	Battle.mp = mini(Battle.mp, Battle.mp_max())


## 강화에 드는 꿈조각.
static func plus_cost(it: Dictionary) -> int:
	return (int(it["tier"]) + 1) * 25 * (int(it.get("plus", 0)) + 1)


## 성공 확률 (0~1). +1~+5 는 늘 성공, 그 뒤로 내려간다.
static func plus_rate(it: Dictionary) -> float:
	var p := int(it.get("plus", 0))
	if p < 5:
		return 1.0
	if p < 10:
		return 0.9 - (p - 5) * 0.1
	return 0.3 - (p - 10) * 0.05


## 강화. `ok`(성공했나), `why`(못 했으면 까닭). **실패해도 수치는 안 내려간다** -
## 강화석과 꿈조각만 사라진다 (`docs/redesign-dream.md` 6절).
static func enhance(uid: int) -> Dictionary:
	var it := get_item(uid)
	if it.is_empty():
		return {"ok": false, "why": "없는 장비"}
	if int(it["plus"]) >= PLUS_MAX:
		return {"ok": false, "why": "더 오를 데가 없어요"}
	var cost := plus_cost(it)
	if coins < cost:
		return {"ok": false, "why": "꿈조각이 모자라요"}
	if stones < 1:
		return {"ok": false, "why": "강화석이 없어요"}
	coins -= cost
	stones -= 1
	var hp_was := Battle.hp_max()
	if randf() < plus_rate(it):
		it["plus"] = int(it["plus"]) + 1
		if is_worn(uid):
			Battle.hp = mini(Battle.hp + maxi(0, Battle.hp_max() - hp_was), Battle.hp_max())
		return {"ok": true, "why": ""}
	return {"ok": false, "why": "실패", "tried": true}


static func sell_price(it: Dictionary) -> int:
	return (int(it["tier"]) + 1) * 12 * (int(it["rar"]) * 2 + 1) + int(it.get("plus", 0)) * 20


static func sell(uid: int) -> int:
	var it := get_item(uid)
	if it.is_empty() or is_worn(uid):
		return 0
	var p := sell_price(it)
	coins += p
	items.erase(it)
	return p


## 입지 않은 일반·고급을 한꺼번에 판다. 판 값을 돌려준다.
static func sell_junk(max_rar := 1) -> int:
	var got := 0
	for it in items.duplicate():
		if int(it["rar"]) <= max_rar and not is_worn(int(it["uid"])):
			got += sell(int(it["uid"]))
	return got


## 입은 것보다 나은가 - 배낭에 화살표를 띄운다. 무기는 공격력, 나머지는 옵션 합.
static func score(it: Dictionary) -> float:
	if String(it["slot"]) == "weapon":
		return float(atk_of(it)) + float(stats_of(it).get("atk", 0)) * 2.0
	var s := 0.0
	var st := stats_of(it)
	for k in st:
		s += float(st[k]) * (0.3 if k in ["hp", "mp"] else 1.0)
	return s


static func better(it: Dictionary) -> bool:
	if not can_wield(it) or is_worn(int(it["uid"])):
		return false
	var cur := worn(String(it["slot"]))
	return cur.is_empty() or score(it) > score(cur) + 0.5


# ── 저장 ─────────────────────────────────────────────────────────────

static func to_dict() -> Dictionary:
	return {"coins": coins, "stones": stones, "items": items.duplicate(true),
		"equipped": equipped.duplicate(), "uid": _uid}


static func from_dict(d: Dictionary) -> void:
	reset()
	coins = maxi(0, int(d.get("coins", 0)))
	stones = maxi(0, int(d.get("stones", 0)))
	_uid = maxi(1, int(d.get("uid", 1)))
	for it in d.get("items", []):
		if it is Dictionary and it.has("uid") and SLOTS.has(String(it.get("slot", ""))):
			var c: Dictionary = it.duplicate(true)
			c["uid"] = int(c["uid"])
			c["tier"] = clampi(int(c.get("tier", 0)), 0, TIERS.size() - 1)
			c["rar"] = clampi(int(c.get("rar", 0)), 0, RARITY.size() - 1)
			c["plus"] = clampi(int(c.get("plus", 0)), 0, PLUS_MAX)
			items.append(c)
			_uid = maxi(_uid, int(c["uid"]) + 1)
	var eq = d.get("equipped", {})
	if eq is Dictionary:
		for s in eq:
			if not get_item(int(eq[s])).is_empty():
				equipped[String(s)] = int(eq[s])
