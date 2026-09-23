class_name Battle
extends RefCounted
## 마음 겨루기 — 그늘과 벌이는 턴제 전투.
##
## **오토로드가 아니라 정적 싱글턴이다.** 오토로드 목록은
## `project.godot` 에 있고 그건 APK 를 새로 깔아야 바뀐다 — 리소스 팩
## 갱신(`tools/publish-update.sh`)만으로는 폰에 전달되지 않는다
## (`back_handler.gd` 가 같은 벽에 부딪혀 `SceneTransition` 씬 안으로
## 들어간 그 문제다). `class_name` + `static var` 는 그냥 스크립트라
## 갱신으로 간다. 부르는 쪽은 `Battle.hp` 처럼 똑같이 쓴다.
##
## 그래서 시그널이 없다. 일어난 일은 함수가 **사건 배열**로 돌려주고
## 화면(`BattleUI`)이 그걸 재생한다 — 정적 멤버는 시그널을 못 든다.
##
## **이 게임에 전투가 없던 이유와, 그래도 넣은 이유.**
## 처음 설계는 "걷고 보고 만난다" 뿐이었다(`docs/redesign-journey.md` 3절).
## 그런데 그것만으로는 **계속하고 싶은 이유**가 약했다 — 할 일을 다
## 하고 나면 다음 마을까지 그냥 걷는 시간이 길다. 그래서 RPG 쪽으로
## 한 발 옮긴다: 레벨이 오르고, 스킬이 풀리고, 더 센 그늘이 나온다.
##
## 다만 **마을을 전장으로 만들지는 않는다.** 그늘은 눈에 보이게 서 있고
## 눌러야만 시작한다(`Shade`). 무작위 조우가 없으니 쉬러 온 사람은
## 그냥 지나가면 된다.
##
## 규칙은 셋만 지킨다:
## 1. **턴을 통째로 빼앗는 상태는 안 만든다** (기절·속박). 손을 놓고
##    맞기만 하는 턴은 불편하기만 하다.
## 2. **져도 잃지 않는다.** 쓰러지면 그 자리에서 마음이 가라앉고
##    (체력 절반으로 회복) 그늘은 그대로 남는다. 되돌릴 수 없는 벌은
##    여행 게임에 안 맞는다.
## 3. **행동 예고는 실제와 반드시 같다.** 적의 수는 무작위가 아니라
##    턴 수로만 정해지므로(`_enemy_plan`), 예고와 실제가 어긋날 수 없다.

# ── 사람 쪽 ──────────────────────────────────────────────────────────
#
# 성장은 **레벨 하나로만** 한다. 힘·민첩·행운을 따로 두면 어느 것을
# 올릴지 고르게 되고, 그러면 잘못 고를 수도 있게 된다. 여행 중에
# 빌드를 망쳤다는 기분은 겪게 하고 싶지 않다.

static var level := 1
static var xp := 0
## 레벨 1 의 가득 찬 값으로 시작한다. 오토로드가 아니라 `_ready()` 가
## 없어서 여기서 바로 채워 둬야 한다 — 0 으로 두면 첫 전투가 시작하자마자
## 쓰러진 상태다.
static var hp := HP_BASE
static var mp := MP_BASE
## 이 마을에서 오늘 쓰러뜨린 그늘의 자리. "마을:x,y" → true
static var cleared: Dictionary = {}
## 쓰러뜨린 날. 날이 바뀌면 그늘이 다시 선다.
static var cleared_day := 0

const HP_BASE := 44
const HP_PER := 11
const MP_BASE := 14
const MP_PER := 4
const ATK_BASE := 7
const ATK_PER := 2
const DEF_BASE := 2
const DEF_PER := 1
const LEVEL_MAX := 12


## **지닌 것이 보태는 힘**(`Catalog.bonus`)이 여기 한 곳에서 더해진다.
## 기념품·도장은 장착하지 않는다 - 배낭에 있기만 하면 된다. 고를 것이
## 없으니 잘못 고를 일도 없다 (위의 "성장은 레벨 하나로만" 과 같은 결).
static func hp_max() -> int:
	return HP_BASE + (level - 1) * HP_PER + Catalog.bonus("hp")


static func mp_max() -> int:
	return MP_BASE + (level - 1) * MP_PER + Catalog.bonus("mp")


static func attack_power() -> int:
	return ATK_BASE + (level - 1) * ATK_PER + _atk_buff + Catalog.bonus("atk")


static func defense() -> int:
	return DEF_BASE + (level - 1) * DEF_PER + Catalog.bonus("def")


## 다음 레벨까지 필요한 것. 뒤로 갈수록 늘지만 가파르지는 않다 —
## 파밍을 시키려는 게 아니라 여행하다 보면 오르게 하려는 것이다.
static func xp_need() -> int:
	return 14 + (level - 1) * 12


## 피해 경감은 뺄셈이 아니라 비율이다. 뺄셈으로 두면 방어가 공격력을
## 넘는 순간 피해가 0 이 되어 전투가 통째로 무의미해진다.
static func _mitigation(d: int) -> float:
	return 100.0 / (100.0 + float(d) * 8.0)


# ── 스킬 ─────────────────────────────────────────────────────────────
#
# 레벨로 풀린다. 여섯이면 충분하다 — 고를 것이 열이 넘으면 고르는 게
# 아니라 훑는 게 된다.
#
# `weak`(약점)에는 반드시 `type == "attack"` 인 것만 쓴다. 회복·버프가
# 약점이 되면 "피해 0 + 적 턴 넘김" 이라 그 스킬만 반복해 무한 회복이
# 된다.
const SKILLS := {
	"smile": {
		"name": "웃어넘기기", "mp": 0, "type": "attack", "mult": 1.0, "lv": 1,
		"say": "별일 아니라는 듯 웃어 보였다",
	},
	"breathe": {
		"name": "심호흡", "mp": 3, "type": "heal", "amount": 26, "lv": 1,
		"grants": "warm", "say": "숨을 길게 들이쉬었다",
	},
	"remember": {
		"name": "좋았던 기억", "mp": 5, "type": "attack", "mult": 1.5, "lv": 2,
		"enemy_grants": "soften", "say": "좋았던 날을 떠올렸다",
	},
	"cheer": {
		"name": "혼잣말 응원", "mp": 4, "type": "buff", "atk_up": 6, "lv": 3,
		"say": "괜찮다고, 스스로에게 말했다",
	},
	"steady": {
		"name": "마음 단단히", "mp": 4, "type": "buff", "lv": 4,
		"grants": "firm", "say": "마음을 단단히 여몄다",
	},
	"walk_on": {
		"name": "그래도 걷는다", "mp": 8, "type": "attack", "mult": 2.0, "lv": 5,
		"enemy_grants": "fade", "say": "그래도 한 걸음 더 내디뎠다",
	},
}

## 화면에 보여 줄 차례. 딕셔너리는 순서를 믿을 수 없어서 따로 적는다.
const SKILL_ORDER := ["smile", "breathe", "remember", "cheer", "steady", "walk_on"]


static func skills() -> Array:
	var out: Array = []
	for id in SKILL_ORDER:
		if int(SKILLS[id]["lv"]) <= level:
			out.append(id)
	return out


## 다음 레벨에 풀리는 스킬 id. 없으면 "".
static func next_skill() -> String:
	for id in SKILL_ORDER:
		if int(SKILLS[id]["lv"]) == level + 1:
			return id
	return ""


# ── 상태 ─────────────────────────────────────────────────────────────
#
# 전투 중에만 붙고 끝나면 사라진다 (저장 안 한다).
const STATUSES := {
	"warm": {"name": "온기", "turns": 3, "hp_per_turn": 7, "good": true},
	"firm": {"name": "굳건함", "turns": 3, "good": true},
	"shrink": {"name": "위축", "turns": 3, "good": false},
	"numb": {"name": "먹먹함", "turns": 3, "good": false},
}

## 그늘에게 거는 것. 거는 방식이 달라서 표를 나눈다 — 내 상태는 적이
## 걸고 시간이 지나야 풀리지만, 적 상태는 내 스킬로만 걸린다.
const ENEMY_STATUSES := {
	"soften": {"name": "누그러짐", "turns": 3},
	"shake": {"name": "흔들림", "turns": 3},
	"fade": {"name": "사그라듦", "turns": 3, "hp_per_turn": -8},
}


# ── 그늘 ─────────────────────────────────────────────────────────────
#
# 마을을 떠다니는 부정적인 마음이 형체를 얻은 것. 없애는 게 아니라
# **걷어낸다** — 쓰러뜨려도 다음 날이면 또 선다. 마음이 그런 것이다.
const ENEMIES := {
	"worry": {
		"name": "걱정", "hp": 34, "atk": 8, "def": 1, "xp": 9,
		"weak": "smile", "sheet": "worry", "drop": "b-barleytea",
		"pattern": {"kind": "multi", "times": 2, "mult": 0.55},
		"line": "…아까 그 말, 잘못한 거 아닐까.",
	},
	"hurry": {
		"name": "조급함", "hp": 40, "atk": 9, "def": 2, "xp": 12,
		"weak": "remember", "sheet": "hurry", "drop": "b-sikhye",
		"pattern": {"kind": "escalate", "step": 0.18, "cap": 2.2},
		"line": "이러고 있을 때가 아닌데.",
	},
	"lonely": {
		"name": "외로움", "hp": 44, "atk": 10, "def": 2, "xp": 14,
		"weak": "walk_on", "sheet": "lonely", "drop": "b-honeycake",
		"pattern": {"kind": "lonely"},
		"line": "아무도 없는 데까지 와서 뭘 하고 있나.",
	},
	"tired": {
		"name": "지침", "hp": 52, "atk": 9, "def": 3, "xp": 16,
		"weak": "smile", "sheet": "tired", "drop": "b-sweetpotato",
		"pattern": {"kind": "burst", "rest": 2, "mult": 2.0, "inflict": "numb"},
		"line": "…조금만 더 누워 있고 싶다.",
	},
	"regret": {
		"name": "후회", "hp": 58, "atk": 11, "def": 3, "xp": 19,
		"weak": "remember", "sheet": "regret", "drop": "b-citron-tea",
		"pattern": {"kind": "inflict", "every": 3, "status": "shrink"},
		"line": "그때 그러지 말았어야 했는데.",
	},
	"envy": {
		"name": "부러움", "hp": 62, "atk": 12, "def": 4, "xp": 22,
		"weak": "walk_on", "sheet": "envy", "drop": "b-yakgwa",
		"pattern": {"kind": "reflect", "back": 0.35},
		"line": "남들은 다 잘 지내는 것 같은데.",
	},
	"night": {
		"name": "밤그늘", "hp": 120, "atk": 14, "def": 5, "xp": 60,
		"sheet": "night", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "heavy", "every": 4, "mult": 2.1},
		"line": "밤이 길다. 아직 한참 남았다.",
	},
}


## 마을마다 서는 그늘. **한 자리에 몰아 두지 않는다** — 자리는
## `Place._shade_spots()` 가 걸을 수 있는 칸 중에서 고른다.
##
## `Quests.ORDER` 차례대로 세진다. 앞 마을에서 레벨을 올려 두면 뒷마을이
## 수월해지고, 안 올리고 지나가도 **막히지는 않는다** — 그늘은 피해
## 갈 수 있고, 져도 잃는 것이 없다.
##
## 프롤로그(잿마루)와 고향에는 없다. 회사와 집에서까지 싸우게 하면
## 이 여행이 무엇이었는지가 흐려진다.
# **초반부터 붙어 볼 것이 있어야 한다.** 첫 마을에 둘뿐이면 다음 마을
# 까지 걷는 동안 한 번 붙고 끝이다 - 마을마다 셋 넷으로 늘리고, 뒷마을은
# 그만큼 더 늘린다. 종류는 그대로 두고(약점·패턴은 안 바꾼다) **수만**
# 늘린다 - 새 그늘을 만드는 것보다 지금 있는 일곱으로 자주 붙는 쪽이
# 먼저다.
const SPAWNS := {
	"윤슬": ["worry", "worry", "worry", "hurry"],
	"볕뉘": ["worry", "worry", "hurry", "hurry"],
	"가풀재": ["hurry", "hurry", "worry", "lonely"],
	"하늬섬": ["lonely", "lonely", "hurry", "worry", "tired"],
	"굽이나루": ["lonely", "lonely", "tired", "tired"],
	"방울못": ["tired", "tired", "regret", "regret"],
	"갈밭머리": ["regret", "regret", "envy", "envy"],
	"솔은재": ["envy", "envy", "regret", "tired", "tired"],
	# 마지막 마을. 밤그늘 하나가 다른 그늘 둘보다 무겁다.
	"꽃눈벌": ["envy", "envy", "regret", "night"],
}


# ── 손에 쥐고 쓰는 것 ────────────────────────────────────────────────
#
# **주운 것이 전투에 쓰인다.** 여태 조약돌·도토리는 배낭에 쌓이기만
# 하고 아무 데도 안 쓰였다. 먹을 것은 먹고, 고운 것은 들여다보고,
# 단단한 것은 손에 쥔다 — 그렇게 마음을 다잡는다.
#
# 퀘스트가 쓰는 것(바다유리·미역·소라)은 여기 안 넣는다. 써 버리면
# 매듭이 막힌다.
const FOODS := {
	"p-persimmon": {"hp": 30, "verb": "먹었다"},
	"p-tangerine": {"hp": 24, "verb": "까 먹었다"},
	"p-mushroom": {"hp": 18, "verb": "먹었다"},
	"p-flower": {"mp": 10, "verb": "들여다봤다"},
	"p-reed-plume": {"mp": 8, "verb": "들여다봤다"},
	"p-feather": {"mp": 7, "verb": "쓸어 봤다"},
	"p-pebble": {"hp": 10, "verb": "쥐어 봤다"},
	"p-acorn": {"hp": 12, "verb": "쥐어 봤다"},
	"p-pinecone": {"hp": 14, "verb": "쥐어 봤다"},
	"p-citrus-leaf": {"mp": 5, "verb": "코에 대 봤다"},
	"p-persimmon-leaf": {"mp": 5, "verb": "코에 대 봤다"},
	"p-pine-needle": {"mp": 6, "verb": "코에 대 봤다"},
	"p-reed-leaf": {"hp": 8, "verb": "만지작거렸다"},
	"p-shell": {"hp": 8, "verb": "귀에 대 봤다"},
}


## 전투에서 꺼내 먹을 수 있는 것. 주운 것 중 몇몇(`FOODS`)과, 할 일·
## 그늘에게서 받은 먹을 것(`Catalog` 의 snack) 전부.
static func usable_items() -> Array:
	var out: Array = []
	for id in JourneyState.bag.keys():
		if Catalog.edible(String(id)) and JourneyState.count(String(id)) > 0:
			out.append(String(id))
	out.sort()
	return out


## 먹으면 무엇이 되나. 주운 것은 `FOODS`, 받은 먹을 것은 `Catalog` 에 적혀 있다.
static func food_effect(id: String) -> Dictionary:
	if FOODS.has(id):
		return FOODS[id]
	return Catalog.of(id)


## **전투 밖에서 먹는다.** 배낭 설명 판의 [먹기]가 부른다. 체력·마음력이
## 다 차 있으면 안 먹는다 - 먹어 봤자 없어지기만 한다. 먹은 뒤 한 줄을
## 돌려준다 (빈 문자열이면 못 먹은 것).
static func eat(id: String) -> String:
	if in_battle or not Catalog.edible(id) or JourneyState.count(id) <= 0:
		return ""
	var f := food_effect(id)
	var full := bool(f.get("full", false))
	var need_hp := hp < hp_max() and (full or int(f.get("hp", 0)) > 0)
	var need_mp := mp < mp_max() and (full or int(f.get("mp", 0)) > 0)
	if not need_hp and not need_mp:
		return ""
	JourneyState.use(id)
	var hp0 := hp
	var mp0 := mp
	if full:
		hp = hp_max()
		mp = mp_max()
	else:
		hp = mini(hp_max(), hp + int(f.get("hp", 0)))
		mp = mini(mp_max(), mp + int(f.get("mp", 0)))
	var parts: Array = []
	if hp > hp0:
		parts.append("체력 +%d" % (hp - hp0))
	if mp > mp0:
		parts.append("마음력 +%d" % (mp - mp0))
	return "%s, %s" % [Catalog.name_of(id), " · ".join(parts)]


# ── 지금 벌어지고 있는 전투 ──────────────────────────────────────────

static var in_battle := false
static var kind := ""
static var enemy: Dictionary = {}
static var my_status: Dictionary = {}        # id → 남은 턴
static var enemy_status: Dictionary = {}
static var turn := 0
static var _atk_buff := 0
static var _last_dealt := 0                  # 부러움이 되돌리는 데 쓴다
## 약점으로 턴을 넘기는 것은 **전투당 한 번**이다. 매번 통하면 마음력
## 0 짜리 웃어넘기기가 약점인 그늘은 그 스킬만 반복해 영영 반격을
## 못 하게 된다.
static var _weak_used := false
## 이 전투에서 밝혀진 약점. 스킬 목록에 * 로 표시된다 (◆ 는 폰트에 없다).
static var found_weak := false


static func start(id: String) -> void:
	if not ENEMIES.has(id):
		push_warning("그런 그늘이 없다: %s" % id)
		return
	var e: Dictionary = ENEMIES[id]
	kind = id
	enemy = {
		"id": id, "name": String(e["name"]),
		"hp": int(e["hp"]), "hp_max": int(e["hp"]),
		"atk": int(e["atk"]), "def": int(e["def"]),
		"sheet": String(e["sheet"]), "line": String(e.get("line", "")),
		"boss": bool(e.get("boss", false)),
	}
	my_status = {}
	enemy_status = {}
	turn = 0
	_atk_buff = 0
	_last_dealt = 0
	_weak_used = false
	found_weak = false
	in_battle = true
	# 쓰러진 채로 다음 전투에 들어가지 않는다. 그건 시작하자마자 지는 것이다.
	if hp <= 0:
		hp = maxi(1, hp_max() / 2)


static func weak_of(id: String) -> String:
	return String(ENEMIES.get(id, {}).get("weak", ""))


static func has_status(id: String) -> bool:
	return my_status.get(id, 0) > 0


static func enemy_has(id: String) -> bool:
	return enemy_status.get(id, 0) > 0


# ── 사람의 차례 ──────────────────────────────────────────────────────

static func player_use_skill(id: String) -> Array:
	if not in_battle or not SKILLS.has(id):
		return []
	var s: Dictionary = SKILLS[id]
	if int(s["lv"]) > level:
		return []
	var cost := int(s["mp"])
	if mp < cost:
		return [{"kind": "line", "text": "마음력이 모자란다"}]
	mp -= cost
	var evs: Array = [{"kind": "line", "text": String(s["say"])}]
	turn += 1

	var skip_enemy := false
	match String(s["type"]):
		"attack":
			# 약점은 **공격 스킬로만** 판정한다 (위 주석의 그 사고).
			var hit_weak: bool = weak_of(kind) == id
			var mult := float(s["mult"])
			if hit_weak:
				mult *= 1.6
				found_weak = true
				evs.append({"kind": "line", "text": "약점을 찔렀다!"})
				if not _weak_used:
					_weak_used = true
					skip_enemy = true
				_give_enemy("shake", evs)
			var raw := float(attack_power()) * mult
			if has_status("shrink"):
				raw *= 0.75
			if enemy_has("shake"):
				raw *= 1.3
			var dmg := maxi(1, int(round(raw * _mitigation(int(enemy["def"])))))
			_last_dealt = dmg
			enemy["hp"] = maxi(0, int(enemy["hp"]) - dmg)
			evs.append({"kind": "damage", "to": "enemy", "amount": dmg,
				"weak": hit_weak})
			if s.has("enemy_grants"):
				_give_enemy(String(s["enemy_grants"]), evs)
		"heal":
			var amount := int(s["amount"])
			if has_status("numb"):
				amount = int(amount * 0.5)
			var before := hp
			hp = mini(hp_max(), hp + amount)
			evs.append({"kind": "heal", "to": "me", "amount": hp - before})
			if s.has("grants"):
				_give_me(String(s["grants"]), evs)
		"buff":
			if s.has("atk_up"):
				_atk_buff += int(s["atk_up"])
				evs.append({"kind": "status", "to": "me",
					"text": "마음의 힘 +%d" % int(s["atk_up"])})
			if s.has("grants"):
				_give_me(String(s["grants"]), evs)

	_after_player(evs, skip_enemy)
	return evs


static func player_use_item(id: String) -> Array:
	if not in_battle or not Catalog.edible(id) or JourneyState.count(id) <= 0:
		return []
	var f := food_effect(id)
	JourneyState.use(id)
	var nm := Catalog.name_of(id)
	var verb := String(f.get("verb", "먹었다"))
	var evs: Array = [{"kind": "line",
		"text": "%s을(를) %s" % [nm, verb]}]
	turn += 1
	var full := bool(f.get("full", false))
	if full or int(f.get("hp", 0)) > 0:
		var before := hp
		# **먹먹함은 아이템 회복을 안 막는다.** 막으면 대응할 길이
		# 통째로 사라진다 — 스킬 회복만 절반으로 준다.
		hp = hp_max() if full else mini(hp_max(), hp + int(f["hp"]))
		evs.append({"kind": "heal", "to": "me", "amount": hp - before})
	if full or int(f.get("mp", 0)) > 0:
		var before_mp := mp
		mp = mp_max() if full else mini(mp_max(), mp + int(f["mp"]))
		evs.append({"kind": "status", "to": "me",
			"text": "마음력 +%d" % (mp - before_mp)})
	# **풀기**는 나쁜 상태(위축·먹먹함)를 지운다. 대응할 길이 하나 더
	# 생긴다 - 스킬로는 못 푸는 것들이다.
	if bool(f.get("cure", false)):
		var cleared := false
		for bad in my_status.keys():
			if not bool(STATUSES[bad].get("good", false)):
				my_status.erase(bad)
				cleared = true
		if cleared:
			evs.append({"kind": "status", "to": "me", "text": "마음이 풀렸다"})
	if bool(f.get("warm", false)):
		_give_me("warm", evs)
	_after_player(evs, false)
	return evs


## 물러난다. 보스가 아니면 늘 된다 — 쉬러 온 사람을 붙잡아 두지 않는다.
static func player_flee() -> Array:
	if not in_battle:
		return []
	if bool(enemy.get("boss", false)):
		var evs: Array = [{"kind": "line", "text": "…발이 안 떨어진다"}]
		turn += 1
		_enemy_turn(evs)
		if hp <= 0:
			_lose(evs)
			return evs
		_tick(evs)
		if hp <= 0:
			_lose(evs)
			return evs
		return evs
	in_battle = false
	var out: Array = [{"kind": "line", "text": "조용히 돌아섰다"},
		{"kind": "fled"}]
	return out


static func _after_player(evs: Array, skip_enemy: bool) -> void:
	if int(enemy["hp"]) <= 0:
		_win(evs)
		return
	if skip_enemy:
		# 적이 안 움직였으면 **상태 시간도 안 흐른다.** 얻은 것과 잃은
		# 것이 한 묶음이라야 공평하다.
		evs.append({"kind": "line", "text": "그늘이 잠시 흔들린다"})
		return
	_enemy_turn(evs)
	if hp <= 0:
		_lose(evs)
		return
	_tick(evs)
	if int(enemy["hp"]) <= 0:
		_win(evs)
		return
	if hp <= 0:
		_lose(evs)
		return


# ── 그늘의 차례 ──────────────────────────────────────────────────────
#
# **무작위가 아니라 턴 수로만 정한다.** 그래야 행동 예고(`intent()`)와
# 실제가 어긋날 수 없다 — 예고해 놓고 딴짓을 하면 예고가 거짓말이 된다.
static func _enemy_plan(t: int) -> Dictionary:
	var p: Dictionary = ENEMIES[kind].get("pattern", {})
	match String(p.get("kind", "")):
		"multi":
			return {"act": "attack", "times": int(p.get("times", 2)),
				"mult": float(p.get("mult", 0.55))}
		"escalate":
			var m: float = minf(1.0 + float(p.get("step", 0.18)) * float(t - 1),
				float(p.get("cap", 2.2)))
			return {"act": "attack", "times": 1, "mult": m}
		"lonely":
			# **스토리와 이어진 패턴.** 마을에서 쌓은 마음이 많을수록
			# 외로움이 약해진다 — 인연을 만나 둔 것이 여기서 힘이 된다.
			var warmth := 0
			for v in JourneyState.hearts.values():
				warmth += int(v)
			var soft: float = clampf(1.5 - float(warmth) * 0.05, 0.5, 1.5)
			return {"act": "attack", "times": 1, "mult": soft}
		"burst":
			var rest := int(p.get("rest", 2))
			if t % (rest + 1) != 0:
				return {"act": "rest"}
			return {"act": "attack", "times": 1, "mult": float(p.get("mult", 2.0)),
				"inflict": String(p.get("inflict", ""))}
		"inflict":
			if t % int(p.get("every", 3)) == 0:
				return {"act": "inflict", "status": String(p.get("status", "shrink"))}
			return {"act": "attack", "times": 1, "mult": 1.0}
		"reflect":
			if _last_dealt > 0:
				return {"act": "reflect", "back": float(p.get("back", 0.35))}
			return {"act": "attack", "times": 1, "mult": 1.0}
		"heavy":
			if t % int(p.get("every", 4)) == 0:
				return {"act": "attack", "times": 1, "mult": float(p.get("mult", 2.1))}
			return {"act": "attack", "times": 1, "mult": 1.0}
	return {"act": "attack", "times": 1, "mult": 1.0}


## 누그러짐은 **여기 한 곳에서만** 곱한다. 실제 행동과 예고가 같은
## 함수를 쓰므로 예고 수치가 계속 실제와 맞는다.
static func _enemy_out() -> float:
	var m := 0.75 if enemy_has("soften") else 1.0
	# **그늘 조각.** 한 번 걷어낸 마음은 다음엔 덜 아프다. 여기 한 곳에서
	# 곱하므로 행동 예고(`expected_damage`)도 같이 맞는다.
	if Catalog.guards(kind):
		m *= Catalog.GUARD_MULT
	return m


static func _hit_me(raw: float, evs: Array) -> void:
	var v := raw * _enemy_out()
	if has_status("firm"):
		v *= 0.7
	var dmg := maxi(1, int(round(v * _mitigation(defense()))))
	hp = maxi(0, hp - dmg)
	evs.append({"kind": "damage", "to": "me", "amount": dmg})


## 다음 턴에 얼마쯤 맞을까. 예고에 적는 수다.
static func expected_damage() -> int:
	if not in_battle:
		return 0
	var plan := _enemy_plan(turn + 1)
	if String(plan["act"]) == "rest":
		return 0
	if String(plan["act"]) == "reflect":
		return maxi(1, int(round(float(_last_dealt) * float(plan["back"]))))
	if String(plan["act"]) == "inflict":
		return 0
	var raw := float(enemy["atk"]) * float(plan.get("mult", 1.0)) * _enemy_out()
	if has_status("firm"):
		raw *= 0.7
	var once := maxi(1, int(round(raw * _mitigation(defense()))))
	return once * int(plan.get("times", 1))


static func intent() -> String:
	if not in_battle:
		return ""
	var plan := _enemy_plan(turn + 1)
	match String(plan["act"]):
		"rest":
			return "늘어져 있다"
		"inflict":
			var nm := String(STATUSES[String(plan["status"])]["name"])
			return "무언가를 걸려 한다 - %s" % nm
		"reflect":
			return "맞은 만큼 되돌리려 한다 - %d" % expected_damage()
	var times := int(plan.get("times", 1))
	var one := expected_damage() / maxi(1, times)
	if times > 1:
		return "%d씩 %d번 올 것 같다" % [one, times]
	return "%d쯤 올 것 같다" % expected_damage()


static func _enemy_turn(evs: Array) -> void:
	var plan := _enemy_plan(turn)
	match String(plan["act"]):
		"rest":
			evs.append({"kind": "line", "text": "%s이(가) 늘어져 있다"
				% String(enemy["name"])})
		"inflict":
			_give_me(String(plan["status"]), evs)
		"reflect":
			var back := maxi(1, int(round(float(_last_dealt) * float(plan["back"]))))
			hp = maxi(0, hp - back)
			evs.append({"kind": "damage", "to": "me", "amount": back})
		_:
			for i in int(plan.get("times", 1)):
				if hp <= 0:
					break
				_hit_me(float(enemy["atk"]) * float(plan.get("mult", 1.0)), evs)
			if String(plan.get("inflict", "")) != "":
				_give_me(String(plan["inflict"]), evs)
	_last_dealt = 0


# ── 상태 흐르기 ──────────────────────────────────────────────────────
#
# **적이 움직인 뒤 한 번만** 흐른다. 약점으로 적 턴을 건너뛰면 상태
# 시간도 안 흐른다 — 얻은 것과 잃은 것이 한 묶음이라야 공평하다.
static func _tick(evs: Array) -> void:
	for id in my_status.keys():
		var st: Dictionary = STATUSES[id]
		if st.has("hp_per_turn") and hp > 0:
			var before := hp
			hp = clampi(hp + int(st["hp_per_turn"]), 0, hp_max())
			if hp != before:
				evs.append({"kind": "heal", "to": "me", "amount": hp - before})
		my_status[id] = int(my_status[id]) - 1
		if int(my_status[id]) <= 0:
			my_status.erase(id)
	for id in enemy_status.keys():
		var st2: Dictionary = ENEMY_STATUSES[id]
		if st2.has("hp_per_turn"):
			var d := -int(st2["hp_per_turn"])
			enemy["hp"] = maxi(0, int(enemy["hp"]) - d)
			evs.append({"kind": "damage", "to": "enemy", "amount": d})
		enemy_status[id] = int(enemy_status[id]) - 1
		if int(enemy_status[id]) <= 0:
			enemy_status.erase(id)


static func _give_me(id: String, evs: Array) -> void:
	if not STATUSES.has(id):
		return
	my_status[id] = int(STATUSES[id]["turns"])
	evs.append({"kind": "status", "to": "me",
		"text": String(STATUSES[id]["name"])})


static func _give_enemy(id: String, evs: Array) -> void:
	if not ENEMY_STATUSES.has(id):
		return
	enemy_status[id] = int(ENEMY_STATUSES[id]["turns"])
	evs.append({"kind": "status", "to": "enemy",
		"text": String(ENEMY_STATUSES[id]["name"])})


# ── 끝 ───────────────────────────────────────────────────────────────

static func _win(evs: Array) -> void:
	in_battle = false
	evs.append({"kind": "line", "text": "%s이(가) 옅어졌다" % String(enemy["name"])})
	var got := int(ENEMIES[kind]["xp"])
	evs.append({"kind": "xp", "amount": got})
	evs.append_array(gain_xp(got))
	# **그늘이 남기는 것.** 무작위가 아니다 - 그늘마다 늘 같은 것을 남긴다.
	var drop := String(ENEMIES[kind].get("drop", ""))
	if drop != "":
		JourneyState.pick(drop)
		evs.append({"kind": "line", "text": "%s을(를) 얻었다" % Catalog.name_of(drop)})
	# 처음 걷어낸 종류면 조각 하나. 두 번은 안 준다 - 도감 기록을 본다.
	var piece := "m-" + kind
	if Catalog.has(piece) and not JourneyState.seen_items.has(piece):
		JourneyState.pick(piece)
		evs.append({"kind": "line", "text": "%s을(를) 얻었다" % Catalog.name_of(piece)})
	evs.append({"kind": "victory"})


## 경험을 얻는다. 전투에서도, 할 일을 마쳐도(`Rewards`) 같은 길로 온다.
## 레벨이 오른 만큼 `level_up` 사건을 돌려준다.
static func gain_xp(got: int) -> Array:
	var evs: Array = []
	xp += maxi(0, got)
	while level < LEVEL_MAX and xp >= xp_need():
		xp -= xp_need()
		level += 1
		# 레벨이 오르면 그 자리에서 몸도 마음도 가득 찬다. 여행 중에
		# 회복할 데가 마땅치 않아서(잠자리는 마을마다 하나다) 이만큼은
		# 돌려준다.
		hp = hp_max()
		mp = mp_max()
		evs.append({"kind": "level_up", "level": level,
			"skill": String(SKILLS.get(_skill_at(level), {}).get("name", ""))})
	return evs


static func _skill_at(lv: int) -> String:
	for id in SKILL_ORDER:
		if int(SKILLS[id]["lv"]) == lv:
			return id
	return ""


## **져도 잃는 것이 없다.** 마음이 가라앉을 뿐이다. 그늘은 그대로
## 서 있으니 다시 붙어도 되고 지나가도 된다.
## **여기서 회복시키지 않는다.** 화면이 아직 마지막 한 대를 그리는
## 중이라, 여기서 체력을 되돌리면 막대가 0 으로 내려가기도 전에 반쯤
## 차 버린다. 사람이 판을 닫을 때 `recover_after_loss()` 가 되돌린다.
static func _lose(evs: Array) -> void:
	in_battle = false
	evs.append({"kind": "line", "text": "마음이 한 번 주저앉았다"})
	evs.append({"kind": "defeat"})


## 쓰러진 뒤 추스른다. 잃는 것은 없다 — 그늘도 그 자리에 그대로 있다.
static func recover_after_loss() -> void:
	if hp <= 0:
		hp = maxi(1, hp_max() / 2)
		mp = mini(mp_max(), mp + 4)


# ── 저장 ─────────────────────────────────────────────────────────────

static func to_dict() -> Dictionary:
	return {
		"level": level, "xp": xp, "hp": hp, "mp": mp,
		"cleared": cleared.duplicate(), "cleared_day": cleared_day,
	}


static func from_dict(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, LEVEL_MAX)
	xp = maxi(0, int(d.get("xp", 0)))
	hp = clampi(int(d.get("hp", hp_max())), 1, hp_max())
	mp = clampi(int(d.get("mp", mp_max())), 0, mp_max())
	cleared = d.get("cleared", {}).duplicate() if d.get("cleared") is Dictionary else {}
	cleared_day = int(d.get("cleared_day", 0))


static func reset() -> void:
	level = 1
	xp = 0
	hp = hp_max()
	mp = mp_max()
	cleared = {}
	cleared_day = 0
	in_battle = false
	enemy = {}
	my_status = {}
	enemy_status = {}


# ── 걷어낸 자리 기억 ─────────────────────────────────────────────────
#
# 쓰러뜨린 그늘은 그날 하루 안 선다. 날이 바뀌면 다시 선다 — 마음은
# 한 번 걷어냈다고 영영 안 오지 않는다. (그리고 그래야 다음 날에도
# 레벨을 올릴 데가 있다.)
static func clear_key(place: String, t: Vector2i) -> String:
	return "%s:%d,%d" % [place, t.x, t.y]


static func is_cleared(place: String, t: Vector2i) -> bool:
	_check_day()
	return bool(cleared.get(clear_key(place, t), false))


static func mark_cleared(place: String, t: Vector2i) -> void:
	_check_day()
	cleared[clear_key(place, t)] = true


static func _check_day() -> void:
	if cleared_day != JourneyState.day:
		cleared_day = JourneyState.day
		cleared = {}


## 잠자리에서 하루를 마치면 몸과 마음이 돌아온다.
static func rest_full() -> void:
	hp = hp_max()
	mp = mp_max()
