class_name LaneBattle
extends RefCounted
## 한 판 (세로 한 줄 싸움). 화면과 시뮬레이션이 같은 규칙을 쓴다 - `tick(dt)` 가 사건(events)을 돌려준다.
##
## 길: 0 = 쿼카 성, LaneData.LEN = 벌레 둥지. 쿼카는 + 로, 벌레는 - 로 걷는다.
## 사정거리 안에 적(또는 성)이 들어오면 멈춰서 친다. 체력이 넉백 횟수만큼 나뉘어 깎일 때마다 튕겨 나간다.

const STEP := 0.05
const UNIT_CAP := 50
const OVERLAP := 30.0         ## 이만큼 겹쳐도 앞에 있는 것으로 친다
const FORESWING := 0.25       ## 처음 맞닥뜨리고 첫 공격까지

var n := 1
var info: Dictionary = {}
var rng := RandomNumberGenerator.new()
var time := 0.0
var done := false
var result := ""              ## win · lose
var events: Array = []

var wallet := 0.0
var worker := 1
var cannon := 0.0
var our_hp := 0.0
var our_max := 0.0
var nest_hp := 0.0
var nest_max := 0.0
var cds: Dictionary = {}      ## 쿼카 → 남은 대기시간
var stats: Dictionary = {}    ## 쿼카 → 판에서 쓸 몸
var lineup: Array = []
var ents: Array = []          ## 살아 있는 것들 (쿼카·벌레)
var _uid := 0
var _spawns: Array = []
var _half_fired := false
var _ai_t := 0.0
var auto := false
var boss_alive := false


func start(stage_n: int, seed_value: int = -1) -> void:
	n = stage_n
	info = LaneData.stage_info(n)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	time = 0.0
	done = false
	result = ""
	events = []
	wallet = 0.0
	worker = 1
	cannon = 0.0
	our_max = LaneData.OUR_BASE_HP
	our_hp = our_max
	nest_max = float(info["base_hp"])
	nest_hp = nest_max
	lineup = LaneState.lineup.duplicate()
	stats = {}
	cds = {}
	for id in lineup:
		stats[id] = LaneState.unit_stats(String(id))
		cds[id] = 0.0
	ents = []
	_uid = 0
	_half_fired = false
	boss_alive = false
	_spawns = []
	for s in LaneData.spawns(n):
		var e: Dictionary = s.duplicate()
		e["t"] = float(e["first"])
		e["count"] = 0
		_spawns.append(e)


# ── 바깥에서 부르는 것 ───────────────────────────────────────────────

func wallet_cap() -> int:
	return int(LaneData.WALLET_CAP[worker - 1])


func worker_cost() -> int:
	return int(LaneData.WORKER_COST[worker - 1]) if worker < LaneData.WORKER_MAX else -1


func can_worker() -> bool:
	return not done and worker < LaneData.WORKER_MAX and wallet >= float(worker_cost())


func upgrade_worker() -> bool:
	if not can_worker():
		return false
	wallet -= float(worker_cost())
	worker += 1
	events.append({"k": "worker", "lv": worker})
	return true


func can_summon(id: String) -> bool:
	if done or not stats.has(id) or float(cds.get(id, 0.0)) > 0.0:
		return false
	if _count("q") >= UNIT_CAP:
		return false
	return wallet >= float(stats[id]["cost"])


func summon(id: String) -> bool:
	if not can_summon(id):
		return false
	var s: Dictionary = stats[id]
	wallet -= float(s["cost"])
	cds[id] = float(s["cd"])
	var e := _make(s, "q", rng.randf_range(0.0, 20.0))
	ents.append(e)
	events.append({"k": "spawn", "side": "q", "uid": e["uid"], "kind": id})
	return true


func cannon_ready() -> bool:
	return not done and cannon >= LaneData.CANNON_CHARGE


func fire_cannon() -> bool:
	if not cannon_ready():
		return false
	cannon = 0.0
	var dmg := LaneData.CANNON_DMG * (1.0 + 0.08 * float(n - 1))
	var hit := 0
	for e in ents:
		if e["side"] == "b" and float(e["pos"]) <= LaneData.CANNON_REACH and float(e["hp"]) > 0.0:
			_damage(e, dmg, true)
			hit += 1
	events.append({"k": "cannon", "hit": hit})
	return true


# ── 흐름 ─────────────────────────────────────────────────────────────

func tick(dt: float) -> Array:
	events = []
	var rest := dt
	while rest > 0.0 and not done:
		var d := minf(STEP, rest)
		rest -= d
		_step(d)
	return events


func _step(d: float) -> void:
	time += d
	wallet = minf(float(wallet_cap()), wallet + float(LaneData.WALLET_RATE[worker - 1]) * d)
	cannon = minf(LaneData.CANNON_CHARGE, cannon + d)
	for id in cds.keys():
		cds[id] = maxf(0.0, float(cds[id]) - d)
	_spawn_bugs(d)
	if auto:
		_ai_t -= d
		if _ai_t <= 0.0:
			_ai_t = 0.3
			_auto_play()
	for e in ents:
		_act(e, d)
	# 죽은 것 정리
	var keep: Array = []
	for e in ents:
		if float(e["hp"]) > 0.0 or e["state"] == "kb":
			keep.append(e)
	ents = keep
	if nest_hp <= 0.0 and not done:
		done = true
		result = "win"
		events.append({"k": "win"})
	elif our_hp <= 0.0 and not done:
		done = true
		result = "lose"
		events.append({"k": "lose"})


func _spawn_bugs(d: float) -> void:
	if not _half_fired and nest_hp < nest_max * 0.5:
		_half_fired = true
		events.append({"k": "rush"})
		for s in _spawns:
			if bool(s.get("on_half", false)):
				s["t"] = 0.0
	for s in _spawns:
		if float(s["t"]) < 0.0 or int(s["count"]) >= int(s["max"]):
			continue
		s["t"] = float(s["t"]) - d
		if float(s["t"]) <= 0.0:
			s["t"] = float(s["every"])
			s["count"] = int(s["count"]) + 1
			_spawn_bug(String(s["kind"]))


func _spawn_bug(kind: String) -> void:
	var b: Dictionary = LaneData.BUGS[kind].duplicate()
	var m := float(info["mag"])
	var boss_b := bool(b.get("boss", false))
	b["hp"] = float(b["hp"]) * m * (LaneData.BOSS_HP if boss_b else 1.0)
	b["atk"] = float(b["atk"]) * m * (LaneData.BOSS_ATK if boss_b else 1.0)
	b["id"] = kind
	var e := _make(b, "b", LaneData.LEN - rng.randf_range(0.0, 20.0))
	ents.append(e)
	var boss := bool(b.get("boss", false))
	events.append({"k": "spawn", "side": "b", "uid": e["uid"], "kind": kind, "boss": boss})
	if boss:
		boss_alive = true
		# 충격파: 쿼카를 전부 밀어낸다
		for q in ents:
			if q["side"] == "q" and float(q["hp"]) > 0.0:
				_knockback(q, LaneData.SHOCK_DIST)
		events.append({"k": "shock"})


func _make(s: Dictionary, side: String, pos: float) -> Dictionary:
	_uid += 1
	var kb := maxi(1, int(s["kb"]))
	return {"uid": _uid, "side": side, "kind": String(s["id"]), "pos": pos, "hp": float(s["hp"]),
		"max": float(s["hp"]), "atk": float(s["atk"]), "every": float(s["every"]), "range": float(s["range"]),
		"speed": float(s["speed"]), "kb": kb, "kb_next": float(s["hp"]) * float(kb - 1) / float(kb),
		"area": bool(s["area"]), "state": "walk", "st": 0.0, "t_atk": FORESWING, "slow": 0.0,
		"no_kb": bool(s.get("no_kb", false)), "trait": String(s.get("trait", "")), "boss": bool(s.get("boss", false)),
		"reward": float(s.get("reward", 0)), "slow_rule": s.get("slow", {}), "kb_from": 0.0, "kb_to": 0.0}


func _count(side: String) -> int:
	var c := 0
	for e in ents:
		if e["side"] == side and float(e["hp"]) > 0.0:
			c += 1
	return c


## 앞쪽 거리 (쿼카는 위로, 벌레는 아래로). 양수 = 앞.
func _ahead(e: Dictionary, other_pos: float) -> float:
	return (other_pos - float(e["pos"])) if e["side"] == "q" else (float(e["pos"]) - other_pos)


func _base_ahead(e: Dictionary) -> float:
	return (LaneData.LEN - float(e["pos"])) if e["side"] == "q" else float(e["pos"])


func _targets(e: Dictionary) -> Array:
	var foe := "b" if e["side"] == "q" else "q"
	var r := float(e["range"])
	var best: Dictionary = {}
	var best_d := 1e9
	var all: Array = []
	for o in ents:
		if o["side"] != foe or float(o["hp"]) <= 0.0:
			continue
		var d := _ahead(e, float(o["pos"]))
		if d >= -OVERLAP and d <= r:
			all.append(o)
			if d < best_d:
				best_d = d
				best = o
	if bool(e["area"]):
		return all
	return [] if best.is_empty() else [best]


func _act(e: Dictionary, d: float) -> void:
	if float(e["hp"]) <= 0.0 and e["state"] != "kb":
		return
	if e["state"] == "kb":
		e["st"] = float(e["st"]) - d
		var k := 1.0 - clampf(float(e["st"]) / LaneData.KB_SECS, 0.0, 1.0)
		e["pos"] = lerpf(float(e["kb_from"]), float(e["kb_to"]), 1.0 - pow(1.0 - k, 2.0))
		if float(e["st"]) <= 0.0:
			if float(e["hp"]) <= 0.0:
				e["state"] = "dead"
				return
			e["state"] = "walk"
			e["t_atk"] = FORESWING
		return
	e["slow"] = maxf(0.0, float(e["slow"]) - d)
	var tg := _targets(e)
	var base_in := _base_ahead(e) <= float(e["range"])
	if tg.is_empty() and not base_in:
		e["state"] = "walk"
		e["t_atk"] = maxf(float(e["t_atk"]), FORESWING)
		var sp := float(e["speed"]) * (0.3 if float(e["slow"]) > 0.0 else 1.0)
		e["pos"] = clampf(float(e["pos"]) + (sp * d if e["side"] == "q" else -sp * d), 0.0, LaneData.LEN)
		return
	e["state"] = "fight"
	e["t_atk"] = float(e["t_atk"]) - d
	if float(e["t_atk"]) > 0.0:
		return
	e["t_atk"] = float(e["every"]) * (1.5 if float(e["slow"]) > 0.0 else 1.0)
	var dmg := float(e["atk"])
	events.append({"k": "swing", "uid": e["uid"], "side": e["side"]})
	if tg.is_empty():
		_hit_base(e, dmg)
		return
	for o in tg:
		_damage(o, dmg, false, e)
	# 범위 공격은 성도 같이 친다
	if bool(e["area"]) and base_in:
		_hit_base(e, dmg)


func _hit_base(e: Dictionary, dmg: float) -> void:
	if e["side"] == "q":
		nest_hp = maxf(0.0, nest_hp - dmg)
		events.append({"k": "base_hit", "side": "b", "dmg": int(round(dmg))})
	else:
		our_hp = maxf(0.0, our_hp - dmg)
		events.append({"k": "base_hit", "side": "q", "dmg": int(round(dmg))})


func _damage(o: Dictionary, dmg: float, cannon_hit: bool, by: Dictionary = {}) -> void:
	o["hp"] = float(o["hp"]) - dmg
	events.append({"k": "hit", "uid": o["uid"], "side": o["side"], "dmg": int(round(dmg)),
		"by": by.get("uid", -1), "cannon": cannon_hit})
	var rule: Dictionary = by.get("slow_rule", {})
	if not rule.is_empty() and String(o["trait"]) == String(rule["trait"]) and rng.randf() < float(rule["chance"]):
		o["slow"] = float(rule["secs"])
		events.append({"k": "slow", "uid": o["uid"]})
	if float(o["hp"]) <= 0.0:
		o["hp"] = 0.0
		if o["side"] == "b":
			wallet = minf(float(wallet_cap()), wallet + float(o["reward"]))
			if bool(o["boss"]):
				boss_alive = false
		events.append({"k": "die", "uid": o["uid"], "side": o["side"], "kind": o["kind"], "reward": int(o["reward"]),
			"boss": bool(o["boss"])})
		_knockback(o, LaneData.KB_DIST)
		return
	if cannon_hit or (float(o["hp"]) <= float(o["kb_next"]) and not bool(o["no_kb"])):
		var steps := maxi(1, int(o["kb"]))
		while float(o["kb_next"]) >= float(o["hp"]) and float(o["kb_next"]) > 0.0:
			o["kb_next"] = float(o["kb_next"]) - float(o["max"]) / float(steps)
		_knockback(o, LaneData.KB_DIST)


func _knockback(o: Dictionary, dist: float) -> void:
	o["state"] = "kb"
	o["st"] = LaneData.KB_SECS
	o["kb_from"] = float(o["pos"])
	o["kb_to"] = clampf(float(o["pos"]) + (-dist if o["side"] == "q" else dist), 0.0, LaneData.LEN)
	events.append({"k": "kb", "uid": o["uid"], "side": o["side"]})


# ── 자동 소환 ─────────────────────────────────────────────────────────
## 사람처럼: 벽이 모자라면 벽부터, 꿈빛이 남으면 일꾼, 그다음 가장 센 것. 벌레가 성 앞에 몰리면 대포.

func _auto_play() -> void:
	var near := 0
	for e in ents:
		if e["side"] == "b" and float(e["hp"]) > 0.0 and float(e["pos"]) < 900.0:
			near += 1
	if cannon_ready() and (near >= 3 or (boss_alive and near >= 1)):
		fire_cannon()
	var walls := 0
	for e in ents:
		if e["side"] == "q" and float(e["hp"]) > 0.0 and (e["kind"] == "tiny" or e["kind"] == "shield"):
			walls += 1
	# 일꾼(수입)에 먼저 투자: 벽이 있거나 앞이 조용하면 6단계까지
	if can_worker() and (worker < 3 or (worker < 6 and (near == 0 or walls >= 2))):
		upgrade_worker()
		return
	if walls < 4:
		for id in ["shield", "tiny"]:
			if can_summon(id):
				summon(id)
				return
	var best := ""
	var best_cost := -1.0
	for id in lineup:
		if id == "tiny" or id == "shield":
			continue
		if can_summon(String(id)) and float(stats[id]["cost"]) > best_cost:
			best_cost = float(stats[id]["cost"])
			best = String(id)
	if best != "":
		summon(best)
		return
	if can_worker() and wallet >= float(wallet_cap()) * 0.9:
		upgrade_worker()
		return
	# 꿈빛이 넘치면 벽을 더
	if wallet >= float(wallet_cap()) * 0.8:
		for id in ["tiny", "shield"]:
			if can_summon(id):
				summon(id)
				return
