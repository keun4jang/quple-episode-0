class_name Field
extends RefCounted
## 마을 한가운데서 실시간으로 벌이는 마음 겨루기.
##
## **바람의나라·메이플스토리처럼 공격 버튼으로 직접 때린다** (0.1.169).
## 여태는 그늘을 누르면 따로 턴제 화면이 떴다 - 고르고 기다리고 또
## 고르는 사이에 "내가 때린다" 는 손맛이 없다는 말을 들었다. 이제 마을에서
## 그대로, 가까이 가서 [공격] 을 누르면 그 자리에서 맞고 쓰러진다.
##
## 수치(레벨·스킬·그늘·패턴)는 `Battle` 표를 그대로 쓴다. 여기는 **시간**만
## 더한다: 스킬마다 다시 쓰기까지의 틈(`CD`), 상태가 가는 초, 그늘이
## 덤비는 박자. 턴제의 "한 턴" 은 여기서 `BEAT` 초다.
##
## 정적이라 시그널이 없다. 일어난 일은 **사건 배열**로 돌려주고 화면
## (`Place`·`Shade`·`JourneyHud`)이 그걸 띄운다 - 턴제 때와 같은 결.

## 턴제의 한 턴을 몇 초로 치나. 상태(온기·위축…)가 "3턴" 이면 9초.
const BEAT := 3.0
## 공격이 닿는 거리(px). 한 칸이 16 이라 두 칸이 조금 안 된다.
const REACH := 30.0
## 그래도 걷는다(LV5)는 둘레를 한꺼번에 친다.
const WIDE := 48.0
## 다시 쓰기까지(초). 기본 공격은 짧게 - 연타가 손맛이다. 셀수록 길다.
const CD := {
	"smile": 0.45, "remember": 2.4, "walk_on": 5.0,
	"breathe": 7.0, "cheer": 15.0, "steady": 12.0,
}
## 혼잣말 응원의 힘이 가는 시간.
const BUFF_SECS := 12.0
## 약점을 처음 찔리면 그늘이 이만큼 멈칫한다 (턴제의 "적 턴 넘김").
## **그늘마다 한 번뿐**이다 - 매번 통하면 약점이 웃어넘기기인 그늘은
## 연타만으로 영영 못 덤빈다.
const STAGGER := 1.4
## 쓰러졌다 일어나면 잠깐은 안 맞는다 - 일어나자마자 또 쓰러지지 않게.
const GUARD_SECS := 2.0

static var cooldown: Dictionary = {}     # 스킬 id → 남은 초
static var my_status: Dictionary = {}    # 상태 id → 남은 초
static var _buff := 0
static var _buff_t := 0.0
static var _beat_t := 0.0
static var invuln := 0.0


static func reset() -> void:
	cooldown = {}
	my_status = {}
	_buff = 0
	_buff_t = 0.0
	_beat_t = 0.0
	invuln = 0.0


static func atk_bonus() -> int:
	return _buff if _buff_t > 0.0 else 0


static func has_status(id: String) -> bool:
	return float(my_status.get(id, 0.0)) > 0.0


## 시간이 흐른다. 온기처럼 박자마다 차오르는 것은 사건으로 돌려준다.
static func tick(delta: float) -> Array:
	var evs: Array = []
	for id in cooldown.keys():
		cooldown[id] = float(cooldown[id]) - delta
		if float(cooldown[id]) <= 0.0:
			cooldown.erase(id)
	invuln = maxf(0.0, invuln - delta)
	_buff_t = maxf(0.0, _buff_t - delta)
	_beat_t += delta
	var beat := _beat_t >= BEAT
	if beat:
		_beat_t -= BEAT
	for id in my_status.keys():
		var st: Dictionary = Battle.STATUSES.get(id, {})
		if beat and st.has("hp_per_turn") and Battle.hp > 0:
			var before := Battle.hp
			Battle.hp = clampi(Battle.hp + int(st["hp_per_turn"]), 0, Battle.hp_max())
			if Battle.hp != before:
				evs.append({"kind": "heal", "amount": Battle.hp - before})
		my_status[id] = float(my_status[id]) - delta
		if float(my_status[id]) <= 0.0:
			my_status.erase(id)
	return evs


# ── 내 쪽 ────────────────────────────────────────────────────────────

## 지금 쓸 수 있나. 못 쓰면 까닭 한 마디, 쓸 수 있으면 "".
static func why_not(id: String) -> String:
	if not Battle.SKILLS.has(id) or int(Battle.SKILLS[id]["lv"]) > Battle.level:
		return "아직 못 쓴다"
	if float(cooldown.get(id, 0.0)) > 0.0:
		return "숨 고르는 중"
	if Battle.mp < int(Battle.SKILLS[id]["mp"]):
		return "마음력이 모자란다"
	return ""


## 다시 쓰기까지 남은 몫 (0 이면 지금 쓸 수 있다, 1 이면 막 썼다).
static func cd_ratio(id: String) -> float:
	var left := float(cooldown.get(id, 0.0))
	if left <= 0.0:
		return 0.0
	return clampf(left / float(CD.get(id, 1.0)), 0.0, 1.0)


## 스킬을 쓴다. 마음력을 내고 틈을 건다. 회복·버프는 여기서 바로 듣는다.
## 공격이면 맞힐 대상은 부르는 쪽(`Place`)이 찾아 `strike()` 로 친다.
## 못 쓰면 빈 배열.
static func use(id: String) -> Array:
	if why_not(id) != "":
		return []
	var s: Dictionary = Battle.SKILLS[id]
	Battle.mp -= int(s["mp"])
	cooldown[id] = float(CD.get(id, 1.0))
	var evs: Array = [{"kind": "cast", "skill": id}]
	match String(s["type"]):
		"heal":
			var amount := int(s["amount"])
			if has_status("numb"):
				amount = int(amount * 0.5)
			var before := Battle.hp
			Battle.hp = mini(Battle.hp_max(), Battle.hp + amount)
			evs.append({"kind": "heal", "amount": Battle.hp - before})
		"buff":
			if s.has("atk_up"):
				_buff = int(s["atk_up"])
				_buff_t = BUFF_SECS
				evs.append({"kind": "status", "text": "마음의 힘 +%d" % _buff})
	if s.has("grants"):
		_give_me(String(s["grants"]), evs)
	return evs


static func _give_me(id: String, evs: Array) -> void:
	if not Battle.STATUSES.has(id):
		return
	my_status[id] = float(Battle.STATUSES[id]["turns"]) * BEAT
	evs.append({"kind": "status", "text": String(Battle.STATUSES[id]["name"])})


# ── 그늘 쪽 ──────────────────────────────────────────────────────────

## 마을에 선 그늘 하나의 몸 상태. `Shade` 가 들고 있는다.
static func new_foe(kind: String) -> Dictionary:
	var e: Dictionary = Battle.ENEMIES.get(kind, {})
	return {
		"kind": kind, "hp": int(e.get("hp", 1)), "hp_max": int(e.get("hp", 1)),
		"atk": int(e.get("atk", 1)), "def": int(e.get("def", 0)),
		"boss": bool(e.get("boss", false)),
		"turn": 0, "dealt": 0, "status": {}, "staggered": false,
		"found_weak": false,
	}


static func foe_has(foe: Dictionary, id: String) -> bool:
	return float(foe["status"].get(id, 0.0)) > 0.0


## 친다. `{dmg, weak, killed, events}`. 공격 스킬만 피해를 준다.
static func strike(id: String, foe: Dictionary) -> Dictionary:
	var s: Dictionary = Battle.SKILLS.get(id, {})
	var out := {"dmg": 0, "weak": false, "killed": false, "stagger": 0.0, "events": []}
	if String(s.get("type", "")) != "attack" or int(foe["hp"]) <= 0:
		return out
	var evs: Array = out["events"]
	# 약점은 **공격 스킬로만** 판정한다 - 회복이 약점이면 무한 회복이 된다.
	var weak: bool = Battle.weak_of(String(foe["kind"])) == id
	var mult := float(s["mult"])
	if weak:
		mult *= 1.6
		foe["found_weak"] = true
		if not bool(foe["staggered"]):
			foe["staggered"] = true
			out["stagger"] = STAGGER
		_give_foe(foe, "shake", evs)
	var raw := float(Battle.attack_power()) * mult
	if has_status("shrink"):
		raw *= 0.75
	if foe_has(foe, "shake"):
		raw *= 1.3
	var dmg := maxi(1, int(round(raw * Battle._mitigation(int(foe["def"])))))
	foe["hp"] = maxi(0, int(foe["hp"]) - dmg)
	foe["dealt"] = int(foe["dealt"]) + dmg
	if s.has("enemy_grants"):
		_give_foe(foe, String(s["enemy_grants"]), evs)
	out["dmg"] = dmg
	out["weak"] = weak
	out["killed"] = int(foe["hp"]) <= 0
	return out


static func _give_foe(foe: Dictionary, id: String, evs: Array) -> void:
	if not Battle.ENEMY_STATUSES.has(id):
		return
	foe["status"][id] = float(Battle.ENEMY_STATUSES[id]["turns"]) * BEAT
	evs.append({"kind": "foe_status", "text": String(Battle.ENEMY_STATUSES[id]["name"])})


## 그늘 쪽 시간. 사그라듦은 박자마다 깎는다 - 깎은 양을 돌려준다.
static func foe_tick(foe: Dictionary, delta: float) -> int:
	var lost := 0
	foe["beat"] = float(foe.get("beat", 0.0)) + delta
	var beat := float(foe["beat"]) >= BEAT
	if beat:
		foe["beat"] = float(foe["beat"]) - BEAT
	var st: Dictionary = foe["status"]
	for id in st.keys():
		var def: Dictionary = Battle.ENEMY_STATUSES.get(id, {})
		if beat and def.has("hp_per_turn") and int(foe["hp"]) > 0:
			var d := -int(def["hp_per_turn"])
			foe["hp"] = maxi(0, int(foe["hp"]) - d)
			lost += d
		st[id] = float(st[id]) - delta
		if float(st[id]) <= 0.0:
			st.erase(id)
	return lost


## 다음에 덤빌 때의 수. 머리 위 예고와 실제가 **같은 함수**를 쓴다.
static func foe_plan(foe: Dictionary) -> Dictionary:
	return Battle.plan_for(String(foe["kind"]), int(foe["turn"]) + 1, int(foe["dealt"]))


## 누그러짐·그늘 조각은 **여기 한 곳에서만** 곱한다 - 예고와 실제가 같이 맞는다.
static func _foe_out(foe: Dictionary) -> float:
	var m := 0.75 if foe_has(foe, "soften") else 1.0
	if Catalog.guards(String(foe["kind"])):
		m *= Catalog.GUARD_MULT
	return m


static func _one_hit(foe: Dictionary, mult: float) -> int:
	var v := float(foe["atk"]) * mult * _foe_out(foe)
	if has_status("firm"):
		v *= 0.7
	return maxi(1, int(round(v * Battle._mitigation(Battle.defense()))))


## 다음에 얼마쯤 맞을까.
static func foe_expected(foe: Dictionary) -> int:
	var plan := foe_plan(foe)
	match String(plan["act"]):
		"rest", "inflict":
			return 0
		"reflect":
			return maxi(1, int(round(float(foe["dealt"]) * float(plan["back"]))))
	return _one_hit(foe, float(plan.get("mult", 1.0))) * int(plan.get("times", 1))


## 머리 위에 잠깐 띄우는 예고. 짧게 - 싸우는 중에 읽을 틈이 적다.
static func foe_intent(foe: Dictionary) -> String:
	var plan := foe_plan(foe)
	match String(plan["act"]):
		"rest":
			return "늘어져 있다"
		"inflict":
			return String(Battle.STATUSES[String(plan["status"])]["name"])
		"reflect":
			return "되돌린다 %d" % foe_expected(foe)
	var times := int(plan.get("times", 1))
	if times > 1:
		return "%d x %d" % [_one_hit(foe, float(plan.get("mult", 1.0))), times]
	return "%d" % foe_expected(foe)


## 덤빈다. 쓰러졌는지는 `Battle.hp <= 0` 으로 본다.
static func foe_attack(foe: Dictionary) -> Array:
	var evs: Array = []
	var plan := foe_plan(foe)
	foe["turn"] = int(foe["turn"]) + 1
	match String(plan["act"]):
		"rest":
			evs.append({"kind": "foe_line", "text": "늘어져 있다"})
		"inflict":
			if invuln <= 0.0:
				_give_me(String(plan["status"]), evs)
		"reflect":
			var back := maxi(1, int(round(float(foe["dealt"]) * float(plan["back"]))))
			_hurt(back, evs)
		_:
			for i in int(plan.get("times", 1)):
				if Battle.hp <= 0:
					break
				_hurt(_one_hit(foe, float(plan.get("mult", 1.0))), evs)
			if String(plan.get("inflict", "")) != "" and invuln <= 0.0:
				_give_me(String(plan["inflict"]), evs)
	foe["dealt"] = 0
	return evs


static func _hurt(dmg: int, evs: Array) -> void:
	if invuln > 0.0:
		evs.append({"kind": "miss"})
		return
	Battle.hp = maxi(0, Battle.hp - dmg)
	evs.append({"kind": "hurt", "amount": dmg})


# ── 끝 ───────────────────────────────────────────────────────────────

## 걷어냈다. 경험·남기는 것·처음이면 조각. 레벨이 오르면 `level_up` 사건.
static func defeat(kind: String) -> Array:
	var e: Dictionary = Battle.ENEMIES.get(kind, {})
	var got := maxi(1, int(round(float(e.get("xp", 1)) * Battle.KILL_XP_MULT)))
	var evs: Array = [{"kind": "xp", "amount": got}]
	evs.append_array(Battle.gain_xp(got))
	# **그늘이 남기는 것.** 무작위가 아니다 - 그늘마다 늘 같은 것을 남긴다.
	var drop := String(e.get("drop", ""))
	if drop != "":
		JourneyState.pick(drop)
	# 처음 걷어낸 종류면 조각 하나. 두 번은 안 준다 - 도감 기록을 본다.
	var piece := "m-" + kind
	if Catalog.has(piece) and not JourneyState.seen_items.has(piece):
		JourneyState.pick(piece)
	return evs


## **쓰러져도 잃는 것이 없다.** 마음이 한 번 가라앉을 뿐 - 체력 절반으로
## 일어나고, 나쁜 상태는 걷히고, 잠깐은 안 맞는다.
static func fall() -> void:
	Battle.hp = maxi(1, Battle.hp_max() / 2)
	Battle.mp = mini(Battle.mp_max(), Battle.mp + 4)
	for id in my_status.keys():
		if not bool(Battle.STATUSES[id].get("good", false)):
			my_status.erase(id)
	invuln = GUARD_SECS
