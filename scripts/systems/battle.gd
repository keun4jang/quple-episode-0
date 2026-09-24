class_name Battle
extends RefCounted
## 마음 겨루기 — 수치와 규칙의 표.
##
## **오토로드가 아니라 정적 싱글턴이다.** 오토로드 목록은
## `project.godot` 에 있고 그건 APK 를 새로 깔아야 바뀐다 — 리소스 팩
## 갱신(`tools/publish-update.sh`)만으로는 폰에 전달되지 않는다
## (`back_handler.gd` 가 같은 벽에 부딪혀 `SceneTransition` 씬 안으로
## 들어간 그 문제다). `class_name` + `static var` 는 그냥 스크립트라
## 갱신으로 간다. 부르는 쪽은 `Battle.hp` 처럼 똑같이 쓴다.
##
## 여기는 **누가 얼마나 센가**(레벨·스킬·그늘·패턴)와 성장·저장만 든다.
## 실제로 치고받는 것은 `Field` 가 마을 한가운데서 실시간으로 한다
## (0.1.169 - 바람의나라·메이플스토리처럼 공격 버튼으로 직접 때린다).
## 한때는 따로 뜨는 턴제 화면(`BattleUI`)이었다.
##
## **이 게임에 전투가 없던 이유와, 그래도 넣은 이유.**
## 처음 설계는 "걷고 보고 만난다" 뿐이었다(`docs/redesign-journey.md` 3절).
## 그런데 그것만으로는 **계속하고 싶은 이유**가 약했다 — 할 일을 다
## 하고 나면 다음 마을까지 그냥 걷는 시간이 길다. 그래서 RPG 쪽으로
## 한 발 옮긴다: 레벨이 오르고, 스킬이 풀리고, 더 센 그늘이 나온다.
##
## 다만 **마을을 전장으로 만들지는 않는다.** 그늘은 눈에 보이게 서 있고
## 먼저 때려야만 덤빈다(`Shade`). 쉬러 온 사람은 그냥 지나가면 된다.
##
## 규칙은 셋만 지킨다:
## 1. **손을 통째로 묶는 상태는 안 만든다** (기절·속박). 손을 놓고
##    맞기만 하는 시간은 불편하기만 하다.
## 2. **져도 잃지 않는다.** 쓰러지면 그 자리에서 마음이 가라앉고
##    (체력 절반으로 회복) 그늘은 제자리로 돌아간다.
## 3. **예고는 실제와 반드시 같다.** 그늘의 수는 무작위가 아니라 몇 번째
##    공격인지로만 정해지므로(`plan_for`), 머리 위 예고와 실제가 어긋날 수 없다.

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
	return ATK_BASE + (level - 1) * ATK_PER + Field.atk_bonus() + Catalog.bonus("atk")


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

## **여섯 배.** "그늘이 더 많아야 붙어 볼 맛이 난다" 는 요청. 위 표는
## 마을마다의 **비율**로 두고, 실제로 서는 수는 여기서 곱한다 - 표를
## 스물넷씩 늘어놓으면 난이도 곡선을 한눈에 못 본다.
## 우두머리(`boss`)는 곱하지 않는다. 밤그늘 여섯은 쉬러 온 마을이 아니다.
const SPAWN_MULT := 6

## 그 마을에 실제로 서는 그늘들. **섞어서** 늘어놓는다 - 자리가 모자라
## 뒤가 잘려도 한 종류만 남지 않게.
static func spawns(village: String) -> Array:
	var base: Array = SPAWNS.get(village, [])
	var out: Array = []
	for i in SPAWN_MULT:
		for k in base:
			if i > 0 and bool(ENEMIES.get(String(k), {}).get("boss", false)):
				continue
			out.append(String(k))
	return out


## 걷어냈을 때 얻는 경험의 몫. 그늘이 여섯 배가 되면서 표의 경험을
## 그대로 주면 첫 두 마을에서 LV9 가 된다 - 뒷마을이 아무 긴장 없이
## 지나간다. 경험은 줄이는 대신 **남기는 것**(먹을 것)은 그대로 준다.
const KILL_XP_MULT := 0.5


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


## 먹으면 무엇이 되나. 주운 것은 `FOODS`, 받은 먹을 것은 `Catalog` 에 적혀 있다.
static func food_effect(id: String) -> Dictionary:
	if FOODS.has(id):
		return FOODS[id]
	return Catalog.of(id)


## 배낭 설명 판의 [먹기]가 부른다 (싸우는 중에도 - 배낭을 열면 그늘이 멈춘다). 체력·마음력이
## 다 차 있으면 안 먹는다 - 먹어 봤자 없어지기만 한다. 먹은 뒤 한 줄을
## 돌려준다 (빈 문자열이면 못 먹은 것).
static func eat(id: String) -> String:
	if not Catalog.edible(id) or JourneyState.count(id) <= 0:
		return ""
	var f := food_effect(id)
	var full := bool(f.get("full", false))
	var need_hp := hp < hp_max() and (full or int(f.get("hp", 0)) > 0)
	var need_mp := mp < mp_max() and (full or int(f.get("mp", 0)) > 0)
	# **풀기**(유자차·매실차·솔잎차)는 나쁜 상태가 걸려 있으면 배가
	# 불러도 먹는다 - 위축·먹먹함을 푸는 길이 이것뿐이다.
	var bad := false
	for st in Field.my_status.keys():
		if not bool(STATUSES.get(st, {}).get("good", false)):
			bad = true
	var need_cure := bad and bool(f.get("cure", false))
	if not need_hp and not need_mp and not need_cure:
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
	if need_cure:
		for st in Field.my_status.keys():
			if not bool(STATUSES.get(st, {}).get("good", false)):
				Field.my_status.erase(st)
		parts.append("마음이 풀렸다")
	# **온기**(꿀떡·군밤)는 먹은 뒤로 한동안 체력이 조금씩 찬다.
	if bool(f.get("warm", false)):
		Field.my_status["warm"] = float(STATUSES["warm"]["turns"]) * Field.BEAT
		parts.append("온기")
	return "%s, %s" % [Catalog.name_of(id), " · ".join(parts)]


static func weak_of(id: String) -> String:
	return String(ENEMIES.get(id, {}).get("weak", ""))


## 그늘이 `t` 번째로 덤빌 때 무엇을 하나.
##
## **무작위가 아니라 몇 번째인지로만 정한다.** 그래야 머리 위 예고
## (`Field.foe_intent`)와 실제가 어긋날 수 없다 — 예고해 놓고 딴짓을
## 하면 예고가 거짓말이 된다. `dealt` 는 지난번 덤빈 뒤로 그늘이 맞은
## 피해의 합(부러움이 되돌린다).
static func plan_for(kind: String, t: int, dealt: int) -> Dictionary:
	var p: Dictionary = ENEMIES.get(kind, {}).get("pattern", {})
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
			if dealt > 0:
				return {"act": "reflect", "back": float(p.get("back", 0.35))}
			return {"act": "attack", "times": 1, "mult": 1.0}
		"heavy":
			if t % int(p.get("every", 4)) == 0:
				return {"act": "attack", "times": 1, "mult": float(p.get("mult", 2.1))}
			return {"act": "attack", "times": 1, "mult": 1.0}
	return {"act": "attack", "times": 1, "mult": 1.0}


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
	Field.reset()


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
