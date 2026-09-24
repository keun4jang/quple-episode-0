class_name Field
extends RefCounted
## 마을 한가운데서 실시간으로 벌이는 싸움.
##
## **바람의나라·메이플스토리처럼 버튼으로 직접 때린다.** 수치(레벨·능력치·
## 스킬·몬스터·상성)는 `Battle`, 무기는 `Gear` 를 쓴다. 여기는 **시간**과
## **한 대의 계산**을 맡는다: 스킬마다 다시 쓰기까지의 틈, 상태가 가는 초,
## 속성 상성·치명타·연타, 몬스터가 덤비는 수.
##
## 정적이라 시그널이 없다. 일어난 일은 **사건 배열**로 돌려주고 화면
## (`Place`·`Shade`·`JourneyHud`)이 그걸 띄운다.

## 턴제의 한 턴을 몇 초로 치나. 상태 "3턴" 이면 9초.
const BEAT := 3.0
## 기본 공격이 닿는 거리(px). 한 칸이 16 이라 두 칸이 조금 안 된다.
const REACH := 30.0
## 쓰러지면 잠깐은 안 맞는다 - 일어나자마자 또 쓰러지지 않게.
const GUARD_SECS := 2.0
## 잘 드는 속성으로 처음 맞히면 몬스터가 이만큼 멈칫한다 (몬스터마다 한 번).
const STAGGER := 1.4
## 쓰러지면 잃는 꿈조각의 몫 (`docs/redesign-dream.md` 6절).
const FALL_COIN := 0.1

## 피해에 흔들림을 줄까. 테스트는 끄고 수를 정확히 잰다.
static var jitter := true

static var cooldown: Dictionary = {}     # 스킬 id → 남은 초
static var my_status: Dictionary = {}    # 상태 id → 남은 초
static var invuln := 0.0
static var _beat_t := 0.0


static func reset() -> void:
	cooldown = {}
	my_status = {}
	_beat_t = 0.0
	invuln = 0.0


## 지금은 버프가 공격력을 직접 더하지 않는다 (날카로움은 치명타로 간다).
static func atk_bonus() -> int:
	return 0


static func has_status(id: String) -> bool:
	return float(my_status.get(id, 0.0)) > 0.0


## 시간이 흐른다. 박자마다 온기가 차고 마음력이 조금씩 돈다.
static func tick(delta: float) -> Array:
	var evs: Array = []
	for id in cooldown.keys():
		cooldown[id] = float(cooldown[id]) - delta
		if float(cooldown[id]) <= 0.0:
			cooldown.erase(id)
	invuln = maxf(0.0, invuln - delta)
	_beat_t += delta
	var beat := _beat_t >= BEAT
	if beat:
		_beat_t -= BEAT
		# **마음력은 저절로 조금씩 찬다.** 스킬이 싸움의 중심이라, 먹을 것
		# 없이도 한 판에 몇 번은 쓸 수 있어야 한다.
		if Battle.mp < Battle.mp_max():
			Battle.mp = mini(Battle.mp_max(), Battle.mp + maxi(1, Battle.mp_max() / 30))
	for id in my_status.keys():
		var st: Dictionary = Battle.STATUSES.get(id, {})
		if beat and st.has("hp_pct") and Battle.hp > 0:
			var before := Battle.hp
			Battle.hp = clampi(Battle.hp + maxi(1, int(Battle.hp_max() * float(st["hp_pct"]))),
				0, Battle.hp_max())
			if Battle.hp != before:
				evs.append({"kind": "heal", "amount": Battle.hp - before})
		my_status[id] = float(my_status[id]) - delta
		if float(my_status[id]) <= 0.0:
			my_status.erase(id)
	return evs


# ── 내 쪽 ────────────────────────────────────────────────────────────

## 지금 쓸 수 있나. 못 쓰면 까닭 한 마디, 쓸 수 있으면 "".
static func why_not(id: String) -> String:
	if not Battle.SKILLS.has(id) or not Battle.skills().has(id):
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
	return clampf(left / float(Battle.SKILLS.get(id, {}).get("cd", 1.0)), 0.0, 1.0)


## 스킬을 쓴다. 마음력을 내고 틈을 건다. 회복·버프는 여기서 바로 듣는다.
## 공격이면 맞힐 대상은 부르는 쪽(`Place`)이 찾아 `strike()` 로 친다.
static func use(id: String) -> Array:
	if why_not(id) != "":
		return []
	var s: Dictionary = Battle.SKILLS[id]
	Battle.mp -= int(s["mp"])
	cooldown[id] = float(s.get("cd", 1.0))
	var evs: Array = [{"kind": "cast", "skill": id}]
	if String(s["type"]) == "heal":
		var amount := int(Battle.hp_max() * float(s["amount"]) * Battle.skill_power(id))
		if has_status("numb"):
			amount = int(amount * 0.5)
		var before := Battle.hp
		Battle.hp = mini(Battle.hp_max(), Battle.hp + amount)
		evs.append({"kind": "heal", "amount": Battle.hp - before})
	if s.has("guard"):
		invuln = maxf(invuln, float(s["guard"]))
	if s.has("grants"):
		_give_me(String(s["grants"]), evs)
	return evs


static func _give_me(id: String, evs: Array) -> void:
	if not Battle.STATUSES.has(id):
		return
	my_status[id] = float(Battle.STATUSES[id]["turns"]) * BEAT
	evs.append({"kind": "status", "text": String(Battle.STATUSES[id]["name"])})


# ── 몬스터 쪽 ────────────────────────────────────────────────────────

## 마을에 선 몬스터 하나의 몸. `Shade` 가 들고 있는다.
static func new_foe(kind: String, lv: int = 1, elite: bool = false) -> Dictionary:
	var e: Dictionary = Battle.ENEMIES.get(kind, Battle.ENEMIES["drop"])
	var st := Battle.foe_stats(kind, lv)
	var boss := bool(e.get("boss", false))
	var el := elite and not boss
	var hp := int(st["hp"] * (Loop.ELITE_HP if el else 1.0))
	return {
		"kind": kind, "lv": lv, "elem": String(e.get("elem", "none")),
		"hp": hp, "hp_max": hp,
		"atk": int(st["atk"] * (Loop.ELITE_ATK if el else 1.0)),
		"def": int(st["def"]), "xp": int(st["xp"] * (Loop.ELITE_XP if el else 1.0)),
		"boss": boss, "elite": el,
		"turn": 0, "dealt": 0, "status": {}, "staggered": false,
	}


static func foe_has(foe: Dictionary, id: String) -> bool:
	return float(foe["status"].get(id, 0.0)) > 0.0


## 친다. `{dmg, hits: [{dmg, crit}], eff, weak, crit, killed, stagger, events}`.
##   eff  상성 배율 (1.5 굉장해 · 0.6 별로 · 0.8 같은 속성 · 1.0 보통)
static func strike(id: String, foe: Dictionary) -> Dictionary:
	var s: Dictionary = Battle.SKILLS.get(id, {})
	var out := {"dmg": 0, "hits": [], "eff": 1.0, "weak": false, "crit": false,
		"killed": false, "stagger": 0.0, "events": []}
	if String(s.get("type", "")) != "attack" or int(foe["hp"]) <= 0:
		return out
	var evs: Array = out["events"]
	var elem := Battle.skill_elem(id)
	var eff := Battle.matchup(elem, String(foe["elem"]))
	out["eff"] = eff
	var weak := eff > 1.01
	out["weak"] = weak
	if weak:
		if not bool(foe["staggered"]):
			foe["staggered"] = true
			out["stagger"] = STAGGER
		_give_foe(foe, "shake", evs)
	var raw := float(Battle.attack_power()) * float(s["mult"]) * Battle.skill_power(id) * eff
	if elem != "none":
		raw *= 1.0 + Gear.bonus("elem") / 100.0
	if has_status("shrink"):
		raw *= 0.75
	if foe_has(foe, "shake") or foe_has(foe, "sway"):
		raw *= 1.3
	var rate := Battle.crit_rate() + (0.5 if has_status("keen") else 0.0)
	var total := 0
	for i in int(s.get("hits", 1)):
		if int(foe["hp"]) <= 0:
			break
		var crit := bool(s.get("crit", false)) or (jitter and randf() < rate)
		var v := raw * Battle._mitigation(int(foe["def"]))
		if jitter:
			v *= randf_range(0.92, 1.08)
		if crit:
			v *= Battle.crit_mult()
			out["crit"] = true
		var dmg := maxi(1, int(round(v)))
		foe["hp"] = maxi(0, int(foe["hp"]) - dmg)
		total += dmg
		out["hits"].append({"dmg": dmg, "crit": crit})
	foe["dealt"] = int(foe["dealt"]) + total
	if s.has("foe"):
		_give_foe(foe, String(s["foe"]), evs)
	if s.has("grants"):
		_give_me(String(s["grants"]), evs)
	out["dmg"] = total
	out["killed"] = int(foe["hp"]) <= 0
	return out


static func _give_foe(foe: Dictionary, id: String, evs: Array) -> void:
	if not Battle.ENEMY_STATUSES.has(id):
		return
	foe["status"][id] = float(Battle.ENEMY_STATUSES[id]["turns"]) * BEAT
	evs.append({"kind": "foe_status", "text": String(Battle.ENEMY_STATUSES[id]["name"])})


## 몬스터 쪽 시간. 화상은 박자마다 깎는다 - 깎은 양을 돌려준다.
static func foe_tick(foe: Dictionary, delta: float) -> int:
	var lost := 0
	foe["beat"] = float(foe.get("beat", 0.0)) + delta
	var beat := float(foe["beat"]) >= BEAT
	if beat:
		foe["beat"] = float(foe["beat"]) - BEAT
	var st: Dictionary = foe["status"]
	for id in st.keys():
		var def: Dictionary = Battle.ENEMY_STATUSES.get(id, {})
		if beat and def.has("hp_pct") and int(foe["hp"]) > 0:
			var d := maxi(1, int(float(foe["hp_max"]) * float(def["hp_pct"])))
			foe["hp"] = maxi(0, int(foe["hp"]) - d)
			lost += d
		st[id] = float(st[id]) - delta
		if float(st[id]) <= 0.0:
			st.erase(id)
	return lost


## 휘감기면 느려진다 - 걸음도, 덤비는 박자도.
static func foe_slow(foe: Dictionary) -> float:
	return 0.6 if foe_has(foe, "tangle") else 1.0


## 다음에 덤빌 때의 수. 머리 위 예고와 실제가 **같은 함수**를 쓴다.
static func foe_plan(foe: Dictionary) -> Dictionary:
	return Battle.plan_for(String(foe["kind"]), int(foe["turn"]) + 1, int(foe["dealt"]))


## 젖음·조각은 **여기 한 곳에서만** 곱한다 - 예고와 실제가 같이 맞는다.
static func _foe_out(foe: Dictionary) -> float:
	var m := 0.75 if foe_has(foe, "wet") else 1.0
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
			return "되받아친다 %d" % foe_expected(foe)
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

## 쓰러뜨렸다. 경험 · 늘 남기는 먹을 것 · 처음이면 조각 · 꿈조각과 장비.
## 사건: `xp`, `level_up`, `loot`(`Gear.roll_drops` 의 것 - 이미 주웠다).
static func defeat(foe: Dictionary) -> Array:
	var kind := String(foe["kind"])
	var e: Dictionary = Battle.ENEMIES.get(kind, {})
	var got := int(foe.get("xp", Battle.foe_stats(kind, int(foe.get("lv", 1)))["xp"]))
	# 연타가 길면 더 준다 (`Loop.combo_bonus`).
	got = int(round(got * Loop.combo_bonus()))
	var evs: Array = [{"kind": "xp", "amount": got}]
	evs.append_array(Battle.gain_xp(got))
	var drop := String(e.get("drop", ""))
	if drop != "":
		JourneyState.pick(drop)
	var piece := "m-" + kind
	if Catalog.has(piece) and not JourneyState.seen_items.has(piece):
		JourneyState.pick(piece)
	var loot := Gear.roll_drops(kind, int(foe.get("lv", 1)), bool(foe.get("boss", false)),
		bool(foe.get("elite", false)))
	Gear.take(loot)
	evs.append({"kind": "loot", "drops": loot})
	return evs


## **쓰러져도 되돌릴 수 없는 것은 잃지 않는다.** 그 자리에서 체력 절반으로
## 일어나고, 나쁜 상태는 걷히고, 잠깐은 안 맞는다. 꿈조각을 조금 흘린다.
## 잃은 꿈조각을 돌려준다.
static func fall() -> int:
	Battle.hp = maxi(1, Battle.hp_max() / 2)
	Battle.mp = mini(Battle.mp_max(), Battle.mp + Battle.mp_max() / 5)
	for id in my_status.keys():
		if not bool(Battle.STATUSES[id].get("good", false)):
			my_status.erase(id)
	invuln = GUARD_SECS
	var lost := int(Gear.coins * FALL_COIN)
	Gear.coins -= lost
	return lost
