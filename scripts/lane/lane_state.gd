class_name LaneState
extends RefCounted
## 쿼카 군단의 저장되는 상태. 정적 클래스 - 자동 로드를 늘리지 않는다 (`IdleState` 와 같은 이유).
## 저장 파일은 따로 `user://lane.cfg`.

const SAVE_PATH := "user://lane.cfg"
## 실제로 읽고 쓰는 곳. 테스트·검사 도구는 시작할 때 `TEST_SAVE_PATH` 로 바꿔
## 이 PC 의 진짜 저장을 건드리지 않는다. 게임은 그대로 `SAVE_PATH` 를 쓴다.
const TEST_SAVE_PATH := "user://lane_test.cfg"
static var save_path := SAVE_PATH

## 행복 조각 = 레벨업 재화 (냥코의 XP). 행운별 = 뽑기 재화.
static var xp := 0
static var stars := 0
## 쿼카 → 레벨 (가진 것만 들어 있다).
static var units: Dictionary = {}
static var lineup: Array = []
## 가장 멀리 깬 스테이지 (0 = 아직 없음).
static var cleared := 0
## 진화한 친구 (id → true). 레벨 10 에서 행복 조각을 내고 진화해야 그 위로 올릴 수 있다.
static var evolved: Dictionary = {}
static var clears: Dictionary = {}       ## 스테이지 → 깬 횟수
static var auto_summon := false
## 빨리 감기 단계 (0 = 1배, 1 = 3배). 배수는 LaneData.SPEEDS. 옛 저장의 2(10배)는 불러올 때 1(3배)로 잘린다.
static var speed_lv := 0
## 바주카포 강화 단계 (1 부터).
static var bazooka_lv := 1
## 우리 성 강화 단계 (1 부터).
static var fort_lv := 1
static var seen_intro := false
static var last_seen := 0
## 뽑기: 무료 티켓 · 전설 없이 뽑은 수 · 전체 뽑은 수
static var tickets := 0
static var pity := 0
static var pulls := 0
## 매일 선물: 마지막으로 받은 날(유닉스 일 수) · 이어 받은 날 수
static var daily_day := 0
static var daily_streak := 0
## 보물: 구역마다 [등급, 등급, 등급] (0 없음 · 1 하급 · 2 보통 · 3 상급)
static var treasures: Array = []
## 장신구 → 레벨, 유닛 → 단 장신구
static var accs: Dictionary = {}
static var acc_on: Dictionary = {}
## 옛 꿈결 키우기 저장에서 선물을 받았나
static var migrated := false
## 판 → 연달아 진 횟수 (다시 도전 응원). 저장한다.
static var fails: Dictionary = {}
## 처음 안내 단계: 0 아직 · 1 첫 싸움 중 · 2 첫 싸움 끝 · 3 홈 안내 · 99 끝
static var tut := 0
## 판 → 받은 꽃 비트 (1 이기기 · 2 성 60% · 4 손맛 과제). 구역 → 받은 꽃다발 단계 (0~2).
static var flowers: Dictionary = {}
static var bouquet: Dictionary = {}
## 오늘의 임무: 굴린 날(로컬 유닉스 일 수) · [{id, prog, got}] x3 · 오늘 바꾸기를 썼나.
static var mission_day := 0
static var missions: Array = []
static var mission_swap := false
## 이번 주 도장판: 마지막으로 도장을 찍은 날 · 주 번호((일+3)/7, 월요일에 바뀐다) · 찍은 수 · 받은 칸 보상(3·5·7칸).
static var stamp_day := 0
static var week_no := 0
static var stamps := 0
static var week_got: Array = [false, false, false]
static var _rng := RandomNumberGenerator.new()


static func reset() -> void:
	xp = 0
	stars = 0
	units = {"tiny": 1, "shield": 1}
	lineup = ["tiny", "shield"]
	cleared = 0
	evolved = {}
	clears = {}
	auto_summon = false
	speed_lv = 0
	bazooka_lv = 1
	fort_lv = 1
	seen_intro = false
	last_seen = 0
	tickets = 1          # 처음 하나는 선물
	pity = 0
	pulls = 0
	daily_day = 0
	daily_streak = 0
	treasures = []
	for z in LaneData.ZONES.size():
		treasures.append([0, 0, 0])
	accs = {}
	acc_on = {}
	migrated = false
	fails = {}
	tut = 0
	flowers = {}
	bouquet = {}
	mission_day = 0
	missions = []
	mission_swap = false
	stamp_day = 0
	week_no = 0
	stamps = 0
	week_got = [false, false, false]


static func has_unit(id: String) -> bool:
	return units.has(id)


static func level_of(id: String) -> int:
	return int(units.get(id, 0))


## 스테이지를 깨서 새로 생기는 쿼카들 (생긴 것 목록을 돌려준다).
static func unlock_by_stage() -> Array:
	var got: Array = []
	for id in LaneData.UNIT_ORDER:
		var u: Dictionary = LaneData.UNITS[id]
		if not units.has(id) and cleared >= int(u["unlock"]):
			units[id] = 1
			got.append(id)
			if lineup.size() < LaneData.LINEUP_MAX:
				lineup.append(id)
	sort_lineup()
	return got


## 이 판의 다시 도전 응원 (%).
static func cheer_for(n: int) -> float:
	return minf(LaneData.CHEER_MAX, LaneData.CHEER_STEP * float(int(fails.get(n, 0))))


static func on_lose(n: int) -> void:
	fails[n] = int(fails.get(n, 0)) + 1


static func can_level_fort() -> bool:
	return fort_lv < LaneData.FORT_LV_MAX and xp >= LaneData.fort_cost(fort_lv)


static func level_fort() -> bool:
	if not can_level_fort():
		return false
	xp -= LaneData.fort_cost(fort_lv)
	fort_lv += 1
	return true


static func can_level_bazooka() -> bool:
	return bazooka_lv < LaneData.BAZOOKA_LV_MAX and xp >= LaneData.bazooka_cost(bazooka_lv)


static func level_bazooka() -> bool:
	if not can_level_bazooka():
		return false
	xp -= LaneData.bazooka_cost(bazooka_lv)
	bazooka_lv += 1
	return true


static func can_level(id: String) -> bool:
	return units.has(id) and level_of(id) < level_cap(id) and xp >= LaneData.level_cost(id, level_of(id))


## 지금 올릴 수 있는 가장 높은 레벨 - 진화 전엔 EVOLVE_LV 에서 멈춘다.
static func level_cap(id: String) -> int:
	return LaneData.UNIT_LV_MAX if is_evolved(id) else LaneData.EVOLVE_LV


static func is_evolved(id: String) -> bool:
	return evolved.has(id)


## 진화할 차례인가 (레벨이 다 찼다) - 행복 조각이 모자라도 참.
static func evolve_ready(id: String) -> bool:
	return units.has(id) and not is_evolved(id) and level_of(id) >= LaneData.EVOLVE_LV


static func can_evolve(id: String) -> bool:
	return evolve_ready(id) and xp >= LaneData.evolve_cost(id)


static func evolve(id: String) -> bool:
	if not can_evolve(id):
		return false
	xp -= LaneData.evolve_cost(id)
	evolved[id] = true
	return true


static func level_up(id: String) -> bool:
	if not can_level(id):
		return false
	xp -= LaneData.level_cost(id, level_of(id))
	units[id] = level_of(id) + 1
	_bump("lvup", 1)
	return true


## 편성에 넣거나 뺀다. 성공하면 참.
static func toggle_lineup(id: String) -> bool:
	if lineup.has(id):
		if lineup.size() <= 1:
			return false
		lineup.erase(id)
		return true
	if not units.has(id) or lineup.size() >= LaneData.LINEUP_MAX:
		return false
	lineup.append(id)
	sort_lineup()
	return true


## 편성은 늘 도감 순서로 (쿼카 여덟 → 동물 친구) - 넣은 순서가 아니라.
static func sort_lineup() -> void:
	lineup.sort_custom(func(a, b) -> bool:
		return LaneData.ALL_ORDER.find(String(a)) < LaneData.ALL_ORDER.find(String(b)))


## 판에서 쓸 몸 `{hp, atk, ...}` - 레벨 배율이 들어간다.
static func unit_stats(id: String) -> Dictionary:
	var u: Dictionary = LaneData.UNITS[id].duplicate()
	var m := LaneData.unit_mult(level_of(id))
	u["hp"] = float(u["hp"]) * m
	u["atk"] = float(u["atk"]) * m
	if is_evolved(id):
		u["hp"] = float(u["hp"]) * LaneData.EVOLVE_HP
		u["atk"] = float(u["atk"]) * LaneData.EVOLVE_ATK
		u["evo"] = true
	u["id"] = id
	var acc := String(acc_on.get(id, ""))
	if acc != "" and accs.has(acc):
		var lv := int(accs[acc])
		for k in LaneData.ACCESSORIES[acc]["eff"].keys():
			var v := LaneData.acc_value(acc, String(k), lv) / 100.0
			match String(k):
				"atk", "hp", "speed":
					u[k] = float(u[k]) * (1.0 + v)
				"every", "cd", "cost":
					u[k] = float(u[k]) * (1.0 - v)
				"guard":
					u["guard"] = float(u.get("guard", 1.0)) * (1.0 - v)
				"crit":
					u["crit"] = float(u.get("crit", 0.0)) + v
				"slow":
					var sl: Dictionary = (u.get("slow", {}) as Dictionary).duplicate()
					if sl.is_empty():
						sl = {"trait": "all", "chance": v, "secs": 2.0}
					else:
						sl["chance"] = minf(1.0, float(sl["chance"]) + v)
					u["slow"] = sl
		u["cost"] = int(round(float(u["cost"])))
	return u


## 이 판에서 받을 꽃을 비트로 (1 이기기 · 2 성 체력 FLOWER_HP 이상 · 4 손맛 과제).
## tally 가 비었으면(시뮬·옛 호출) 꽃 1·2만 센다. 자동을 한 번이라도 켠 판은 꽃 3이 없다.
static func judge_flowers(n: int, tally: Dictionary, hp_ratio: float) -> int:
	var bits := 1
	if hp_ratio >= LaneData.FLOWER_HP - 0.0001:
		bits |= 2
	if tally.is_empty() or bool(tally.get("auto_used", false)):
		return bits
	var task := LaneData.flower_task(n)
	var ok := false
	match String(task["id"]):
		"boss_cannon":
			ok = bool(tally.get("boss_cannon", false))
		"hit":
			ok = int(tally.get("best_hit", 0)) >= int(task["need"])
		"spend":
			ok = float(tally.get("cap_t", 0.0)) <= LaneData.FLOWER_CAP_T
		"hold":
			ok = int(tally.get("holds", 0)) >= 1
	if ok:
		bits |= 4
	return bits


static func _bits(v: int) -> int:
	return (v & 1) + ((v >> 1) & 1) + ((v >> 2) & 1)


## 구역(zk = (판-1)/10, 0~19) 10판에서 모은 꽃 수 (최대 30).
static func flowers_in_zone(zk: int) -> int:
	var c := 0
	for i in LaneData.STAGES_PER_ZONE:
		c += _bits(int(flowers.get(zk * LaneData.STAGES_PER_ZONE + i + 1, 0)))
	return c


## 판을 이겼다. 받은 것 `{xp, stars, tickets, first, new_units, treasure, acc, flowers, new_flowers, flower_stars, bouquet}`.
static func on_win(n: int, rng: RandomNumberGenerator = null, tally: Dictionary = {}, hp_ratio: float = 1.0) -> Dictionary:
	if rng == null:
		rng = _rng
		rng.randomize()
	var first := n > cleared
	fails.erase(n)
	var r := LaneData.reward(n, first)
	r["xp"] = int(round(float(r["xp"]) * (1.0 + float(bonuses().get("xp", 0.0)) / 100.0)))
	xp += int(r["xp"])
	stars += int(r["stars"])
	tickets += int(r.get("tickets", 0))
	clears[n] = int(clears.get(n, 0)) + 1
	if first:
		cleared = n
	r["first"] = first
	r["new_units"] = unlock_by_stage()
	r["treasure"] = _roll_treasure(n, first, rng)
	r["acc"] = ""
	# 장신구는 1장 우두머리만 준다 (2장은 이미 다 가졌다)
	if first and n % LaneData.STAGES_PER_ZONE == 0 and n <= LaneData.CH_STAGES:
		var zi := (n - 1) / LaneData.STAGES_PER_ZONE
		for id in LaneData.ACC_ORDER:
			if int(LaneData.ACCESSORIES[id]["zone"]) == zi and not accs.has(id):
				accs[id] = 1
				r["acc"] = id
	_give_flowers(n, r, tally, hp_ratio)
	return r


## 꽃과 구역 꽃다발 - 새로 받은 것만 보상한다.
static func _give_flowers(n: int, r: Dictionary, tally: Dictionary, hp_ratio: float) -> void:
	var old := int(flowers.get(n, 0))
	var bits := judge_flowers(n, tally, hp_ratio)
	var fresh := bits & ~old
	flowers[n] = old | bits
	var per := int(LaneData.FLOWER_STAR[LaneData.chapter_of(n)])
	var fs := (((fresh >> 1) & 1) + ((fresh >> 2) & 1)) * per
	stars += fs       # r["stars"] 에는 안 더한다 - 결과 창이 '꽃 행운별' 줄로 따로 보여 준다
	r["flowers"] = old | bits
	r["new_flowers"] = fresh
	r["flower_stars"] = fs
	r["bouquet"] = {}
	var zk := (n - 1) / LaneData.STAGES_PER_ZONE
	var have := flowers_in_zone(zk)
	var stage := int(bouquet.get(zk, 0))
	var gs := 0
	var gt := 0
	while stage < LaneData.BOUQUET.size() and have >= int(LaneData.BOUQUET[stage][0]):
		var g: Dictionary = LaneData.BOUQUET[stage][1]
		gs += int(g.get("stars", 0))
		gt += int(g.get("tickets", 0))
		stage += 1
	if stage > int(bouquet.get(zk, 0)):
		bouquet[zk] = stage
		stars += gs
		tickets += gt
		r["bouquet"] = {"stage": stage, "stars": gs, "tickets": gt}


# ── 보물 ─────────────────────────────────────────────────────────────

## 보물을 굴린다. 나오면 {zone, idx, grade, up(더 좋아졌나)}, 안 나오면 {}.
static func _roll_treasure(n: int, first: bool, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= (LaneData.TREASURE_FIRST if first else LaneData.TREASURE_DROP):
		return {}
	var zi := int(LaneData.stage_info(n)["zone"])
	var row: Array = treasures[zi]
	# 아직 상급이 아닌 것 중에서 고른다 (다 모았으면 아무거나)
	var cands: Array = []
	for i in 3:
		if int(row[i]) < 3:
			cands.append(i)
	if cands.is_empty():
		return {}
	var idx := int(cands[rng.randi() % cands.size()])
	# 2장은 판마다 우두머리만큼 좋은 등급이 잘 나온다 - 1장에서 못 채운 보물을 2장에서 채운다
	var roll: Array = LaneData.GRADE_ROLL_BOSS if n % LaneData.STAGES_PER_ZONE == 0 or n > LaneData.CH_STAGES else LaneData.GRADE_ROLL
	var x := rng.randf()
	var g := 3 if x < float(roll[0]) else (2 if x < float(roll[0]) + float(roll[1]) else 1)
	var up := g > int(row[idx])
	if up:
		row[idx] = g
	return {"zone": zi, "idx": idx, "grade": g, "up": up}


static func treasure_count(zi: int) -> int:
	var c := 0
	for g in treasures[zi]:
		c += int(g)
	return c


# ── 보너스 (보물 + 콤보) ──────────────────────────────────────────────

static func treasure_bonus() -> Dictionary:
	var out := {}
	for zi in treasures.size():
		for i in 3:
			var g := int(treasures[zi][i])
			if g > 0:
				var t: Dictionary = LaneData.TREASURES[zi][i]
				out[t["kind"]] = float(out.get(t["kind"], 0.0)) + float(t["per"]) * float(g)
	return out


## 지금 편성에서 켜진 콤보들.
static func active_combos(l: Array = []) -> Array:
	if l.is_empty():
		l = lineup
	var out: Array = []
	for c in LaneData.COMBOS:
		var ok := true
		for u in c["units"]:
			if not l.has(u):
				ok = false
				break
		if ok:
			out.append(c)
	return out


## 판 전체에 붙는 보너스 {kind: 값}. 장신구는 유닛마다 따로 (`unit_stats`).
static func bonuses() -> Dictionary:
	var out := treasure_bonus()
	for c in active_combos():
		out[c["kind"]] = float(out.get(c["kind"], 0.0)) + float(c["v"])
	return out


# ── 장신구 ───────────────────────────────────────────────────────────

static func equip(unit: String, acc: String) -> bool:
	if not units.has(unit) or not accs.has(acc):
		return false
	for u in acc_on.keys():
		if String(acc_on[u]) == acc:
			acc_on.erase(u)
	acc_on[unit] = acc
	return true


static func unequip(unit: String) -> void:
	acc_on.erase(unit)


## 이 장신구를 달고 있는 유닛 ("" = 아무도).
static func wearer(acc: String) -> String:
	for u in acc_on.keys():
		if String(acc_on[u]) == acc:
			return String(u)
	return ""


static func can_level_acc(acc: String) -> bool:
	return accs.has(acc) and int(accs[acc]) < LaneData.ACC_LV_MAX and xp >= LaneData.acc_level_cost(int(accs[acc]))


static func level_acc(acc: String) -> bool:
	if not can_level_acc(acc):
		return false
	xp -= LaneData.acc_level_cost(int(accs[acc]))
	accs[acc] = int(accs[acc]) + 1
	return true


# ── 옛 꿈결 키우기에서 온 선물 ─────────────────────────────────────────

## 옛 게임 저장이 있으면 한 번만 선물로 바꿔 준다 (옛 저장은 지우지 않는다). 받으면 {stars, tickets, xp}.
static func migrate_from_idle() -> Dictionary:
	if migrated:
		return {}
	migrated = true
	if not IdleState.has_save() or not IdleState.load_save():
		return {}
	var best := maxi(1, IdleState.best)
	var g := {"stars": mini(1500, best * 6), "tickets": mini(10, 2 + best / 15), "xp": mini(60000, IdleState.level * 400)}
	stars += int(g["stars"])
	tickets += int(g["tickets"])
	xp += int(g["xp"])
	return g


## 자는 동안: 가장 멀리 깬 곳 기준 행복 조각 (최대 8시간).
static func offline_reward(now_unix: int) -> Dictionary:
	if last_seen <= 0 or now_unix <= last_seen:
		return {}
	var mins := mini(480, (now_unix - last_seen) / 60)
	if mins < 5:
		return {}
	var per_min := float(LaneData.reward(maxi(1, cleared), false)["xp"]) * 0.35
	return {"minutes": mins, "xp": int(per_min * float(mins))}


static func claim_offline(now_unix: int) -> Dictionary:
	var r := offline_reward(now_unix)
	last_seen = now_unix
	if not r.is_empty():
		xp += int(r["xp"])
	return r


# ── 뽑기 ─────────────────────────────────────────────────────────────

static func can_pull(count: int) -> bool:
	if count == 1:
		return tickets > 0 or stars >= LaneData.GACHA_COST
	return stars >= LaneData.GACHA10_COST


## 1번 또는 10번 뽑는다. 티켓이 있으면 1번은 티켓부터 쓴다.
## 돌려주는 것: [{id, rarity, new, lv, xp}] - new 처음 만남, lv 지금 레벨, xp 중복이라 받은 행복 조각.
static func pull(count: int, rng: RandomNumberGenerator) -> Array:
	if not can_pull(count):
		return []
	if count == 1:
		if tickets > 0:
			tickets -= 1
		else:
			stars -= LaneData.GACHA_COST
	else:
		stars -= LaneData.GACHA10_COST
	var out: Array = []
	for i in count:
		var floor_r := "super" if (count > 1 and i == count - 1) else "rare"
		out.append(_grant(roll(rng, floor_r)))
	return out


## 등급을 굴리고 그 등급 안에서 하나 고른다. floor_r 보다 낮은 등급은 안 나온다.
static func roll(rng: RandomNumberGenerator, floor_r := "rare") -> String:
	var r := "rare"
	if pity + 1 >= LaneData.PITY_LEGEND:
		r = "legend"
	else:
		var x := rng.randf()
		if x < float(LaneData.GACHA_RATES["legend"]):
			r = "legend"
		elif x < float(LaneData.GACHA_RATES["legend"]) + float(LaneData.GACHA_RATES["super"]):
			r = "super"
	if floor_r == "super" and r == "rare":
		r = "super"
	pulls += 1
	pity = 0 if r == "legend" else pity + 1
	var pool: Array = []
	for id in LaneData.ANIMAL_ORDER:
		if LaneData.rarity(String(id)) == r:
			pool.append(String(id))
	# 아직 없는 친구가 조금 더 잘 나온다 (같은 것만 계속 나오면 김이 샌다)
	var weights: Array = []
	var total := 0.0
	for id in pool:
		var w := 1.5 if not units.has(id) else 1.0
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for k in pool.size():
		pick -= float(weights[k])
		if pick <= 0.0:
			return String(pool[k])
	return String(pool[pool.size() - 1])


static func _grant(id: String) -> Dictionary:
	var res := {"id": id, "rarity": LaneData.rarity(id), "new": false, "xp": 0}
	if not units.has(id):
		units[id] = 1
		res["new"] = true
		if lineup.size() < LaneData.LINEUP_MAX:
			lineup.append(id)
			sort_lineup()
	elif level_of(id) < level_cap(id):
		units[id] = level_of(id) + 1
	else:
		var g := LaneData.dupe_xp(id)
		xp += g
		res["xp"] = g
	res["lv"] = level_of(id)
	return res


# ── 매일 선물 ─────────────────────────────────────────────────────────

static func daily_ready(now_unix: int) -> bool:
	return now_unix / 86400 > daily_day


## 받으면 {tickets, stars, streak}, 오늘 이미 받았으면 {}.
static func claim_daily(now_unix: int) -> Dictionary:
	var today := now_unix / 86400
	if today <= daily_day:
		return {}
	daily_streak = daily_streak + 1 if today == daily_day + 1 else 1
	daily_day = today
	var g := LaneData.daily_gift(daily_streak)
	tickets += int(g["tickets"])
	stars += int(g["stars"])
	return {"tickets": int(g["tickets"]), "stars": int(g["stars"]), "streak": daily_streak}


# ── 오늘의 임무 · 이번 주 도장판 ─────────────────────────────────────

## 처음 안내를 마치고 세 판을 깬 뒤부터.
static func missions_open() -> bool:
	return tut == 99 and cleared >= 3


static func _mission_ok(id: String) -> bool:
	var need: Dictionary = LaneData.MISSIONS[id].get("need", {})
	if need.has("cleared") and cleared < int(need["cleared"]):
		return false
	if need.has("lineup") and lineup.size() < int(need["lineup"]):
		return false
	return true


## 등급(tier)에서 열린 임무 id 들 (표 순서).
static func _mission_pool(tier: int) -> Array:
	var out: Array = []
	for id in LaneData.MISSION_ORDER:
		if int(LaneData.MISSIONS[id]["tier"]) == tier and _mission_ok(String(id)):
			out.append(String(id))
	return out


## 오늘 임무를 굴린다 - 날이 바뀌었을 때만. 같은 날은 몇 번 켜도 같은 임무 (씨앗 = today * 7919).
## 못 한 임무는 벌 없이 사라진다. 새로 굴렸으면 참.
static func roll_missions(today: int) -> bool:
	if not missions_open() or today == mission_day:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = today * 7919
	missions = []
	for tier in LaneData.MISSION_TIERS.size():
		var pool := _mission_pool(tier)
		missions.append({"id": String(pool[rng.randi() % pool.size()]), "prog": 0, "got": false})
	mission_day = today
	mission_swap = false
	return true


## 주가 바뀌었으면(월요일 0시) 도장판을 새로.
static func check_week(today: int) -> void:
	var w := (today + 3) / 7
	if w != week_no:
		week_no = w
		stamps = 0
		week_got = [false, false, false]


static func _bump(stat: String, v: int) -> void:
	if v <= 0:
		return
	for m in missions:
		var d: Dictionary = LaneData.MISSIONS.get(String(m["id"]), {})
		if d.is_empty() or bool(m["got"]) or String(d["stat"]) != stat:
			continue
		m["prog"] = mini(int(d["goal"]), int(m["prog"]) + v)


## 판이 끝날 때 (이기든 지든 후퇴하든) 판 기록을 임무에 더한다. 돌려주는 것: 오른 임무 [{i, prog, goal}].
## 자동 소환·자동 바주카는 tally 에 안 들어가 있으니 여기서 따로 거를 것이 없다.
static func add_tally(t: Dictionary, win: bool, hp_ratio: float, new_flower_bits: int, n: int = 0) -> Array:
	var before: Array = []
	for m in missions:
		before.append(int(m["prog"]))
	_bump("summons", int(t.get("summons", 0)))
	_bump("kills", int(t.get("kills", 0)))
	_bump("holds", int(t.get("holds", 0)))
	_bump("multi5", int(t.get("multi5", 0)))
	if win:
		_bump("wins", 1)
		if n > 0 and n % LaneData.STAGES_PER_ZONE == 0:
			_bump("boss_wins", 1)
		if hp_ratio >= 0.7 - 0.0001 and not bool(t.get("auto_used", false)):
			_bump("hp70_wins", 1)
		if bool(t.get("boss_cannon", false)):
			_bump("boss_cannon", 1)
		var kinds = t.get("kinds", {})
		if kinds is Dictionary and (kinds as Dictionary).size() >= 5:
			_bump("kinds5_wins", 1)
		_bump("new_flowers", _bits(new_flower_bits))
	var out: Array = []
	for i in missions.size():
		if int(missions[i]["prog"]) > int(before[i]):
			out.append({"i": i, "prog": int(missions[i]["prog"]),
				"goal": int(LaneData.MISSIONS[String(missions[i]["id"])]["goal"])})
	return out


static func mission_done(i: int) -> bool:
	if i < 0 or i >= missions.size():
		return false
	var m: Dictionary = missions[i]
	return int(m["prog"]) >= int(LaneData.MISSIONS[String(m["id"])]["goal"])


## 다 한 임무를 받는다. 받으면 {stars, stamp(오늘 도장이 찍혔나)}, 못 받으면 {}.
## 셋 다 받으면 그날 도장 하나 (하루에 하나까지).
static func claim_mission(i: int) -> Dictionary:
	if not mission_done(i) or bool(missions[i]["got"]):
		return {}
	var m: Dictionary = missions[i]
	m["got"] = true
	var s := int(LaneData.MISSION_STARS[int(LaneData.MISSIONS[String(m["id"])]["tier"])])
	stars += s
	var stamp := false
	if missions.all(func(x) -> bool: return bool(x["got"])) and stamp_day != mission_day:
		check_week(mission_day)
		stamp_day = mission_day
		stamps = mini(LaneData.WEEK_STAMPS, stamps + 1)
		stamp = true
	return {"stars": s, "stamp": stamp}


## 오늘 한 번 공짜로 임무 하나를 같은 등급의 다른 것으로 (진행은 0 부터).
static func swap_mission(i: int, today: int) -> bool:
	if mission_swap or i < 0 or i >= missions.size() or bool(missions[i]["got"]):
		return false
	var m: Dictionary = missions[i]
	var pool := _mission_pool(int(LaneData.MISSIONS[String(m["id"])]["tier"]))
	pool.erase(String(m["id"]))
	if pool.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = today * 7919 + 101 + i
	m["id"] = String(pool[rng.randi() % pool.size()])
	m["prog"] = 0
	m["got"] = false
	mission_swap = true
	return true


static func week_ready(k: int) -> bool:
	return k >= 0 and k < LaneData.WEEK_REWARDS.size() and not bool(week_got[k]) \
		and stamps >= int(LaneData.WEEK_REWARDS[k][0])


## 도장판 칸 보상 (k = 0·1·2 → 3·5·7칸). 받으면 {tickets, stars, capsule(뽑기 결과 또는 {})}, 못 받으면 {}.
## 7칸 캡슐은 특급 이상 한 번 - 전설 천장(pity)에도 센다.
static func claim_week(k: int, rng: RandomNumberGenerator) -> Dictionary:
	if not week_ready(k):
		return {}
	week_got[k] = true
	var g: Dictionary = LaneData.WEEK_REWARDS[k][1]
	var out := {"tickets": int(g.get("tickets", 0)), "stars": int(g.get("stars", 0)), "capsule": {}}
	tickets += int(out["tickets"])
	stars += int(out["stars"])
	if int(g.get("capsule", 0)) > 0:
		if rng == null:
			rng = _rng
			rng.randomize()
		out["capsule"] = _grant(roll(rng, "super"))
	return out


## 받을 것이 있나 (홈 단추의 분홍 점).
static func missions_ready() -> bool:
	if not missions_open():
		return false
	for i in missions.size():
		if mission_done(i) and not bool(missions[i]["got"]):
			return true
	for k in LaneData.WEEK_REWARDS.size():
		if week_ready(k):
			return true
	return false


static func owned_count() -> int:
	return units.size()


static func to_dict() -> Dictionary:
	return {"v": 1, "xp": xp, "stars": stars, "units": units.duplicate(), "lineup": lineup.duplicate(),
		"cleared": cleared, "evolved": evolved.keys(), "clears": clears.duplicate(), "auto": auto_summon, "speed2": speed_lv > 0, "speed_lv": speed_lv, "bazooka": bazooka_lv, "fort": fort_lv,
		"seen_intro": seen_intro, "last_seen": last_seen, "tickets": tickets, "pity": pity, "pulls": pulls,
		"daily_day": daily_day, "daily_streak": daily_streak, "treasures": treasures.duplicate(true),
		"accs": accs.duplicate(), "acc_on": acc_on.duplicate(), "migrated": migrated, "fails": fails.duplicate(), "tut": tut,
		"flowers": flowers.duplicate(), "bouquet": bouquet.duplicate(),
		"m_day": mission_day, "missions": missions.duplicate(true), "m_swap": mission_swap, "st_day": stamp_day,
		"week_no": week_no, "stamps": stamps, "week_got": week_got.duplicate()}


static func from_dict(d: Dictionary) -> void:
	reset()
	xp = maxi(0, int(d.get("xp", 0)))
	stars = maxi(0, int(d.get("stars", 0)))
	cleared = clampi(int(d.get("cleared", 0)), 0, LaneData.STAGE_MAX)
	var u = d.get("units", {})
	if u is Dictionary:
		for id in (u as Dictionary).keys():
			if LaneData.UNITS.has(String(id)):
				units[String(id)] = clampi(int(u[id]), 1, LaneData.UNIT_LV_MAX)
	var ev = d.get("evolved", null)
	if ev is Array:
		for id in ev:
			if units.has(String(id)):
				evolved[String(id)] = true
	else:
		# 진화가 따로 없던 옛 저장: 레벨 10 이상이면 이미 진화한 모습이었다 - 그대로 둔다
		for id in units.keys():
			if int(units[id]) >= LaneData.EVOLVE_LV:
				evolved[String(id)] = true
	for id in units.keys():
		if not evolved.has(id):
			units[id] = mini(int(units[id]), LaneData.EVOLVE_LV)
	var l = d.get("lineup", [])
	if l is Array:
		lineup = []
		for id in l:
			if units.has(String(id)) and not lineup.has(String(id)) and lineup.size() < LaneData.LINEUP_MAX:
				lineup.append(String(id))
	if lineup.is_empty():
		lineup = ["tiny"]
	sort_lineup()
	var c = d.get("clears", {})
	if c is Dictionary:
		for k in (c as Dictionary).keys():
			clears[int(k)] = maxi(0, int(c[k]))
	auto_summon = bool(d.get("auto", false))
	bazooka_lv = clampi(int(d.get("bazooka", 1)), 1, LaneData.BAZOOKA_LV_MAX)
	fort_lv = clampi(int(d.get("fort", 1)), 1, LaneData.FORT_LV_MAX)
	# 옛 저장은 켜짐/꺼짐(speed2)만 있다 - 켜짐이면 3배로
	speed_lv = clampi(int(d.get("speed_lv", 1 if bool(d.get("speed2", false)) else 0)), 0, LaneData.SPEEDS.size() - 1)
	seen_intro = bool(d.get("seen_intro", false))
	last_seen = maxi(0, int(d.get("last_seen", 0)))
	tickets = clampi(int(d.get("tickets", 1)), 0, 9999)
	pity = clampi(int(d.get("pity", 0)), 0, LaneData.PITY_LEGEND)
	pulls = maxi(0, int(d.get("pulls", 0)))
	daily_day = maxi(0, int(d.get("daily_day", 0)))
	daily_streak = maxi(0, int(d.get("daily_streak", 0)))
	var tr = d.get("treasures", [])
	if tr is Array:
		for zi in mini((tr as Array).size(), treasures.size()):
			if tr[zi] is Array:
				for i in mini((tr[zi] as Array).size(), 3):
					treasures[zi][i] = clampi(int(tr[zi][i]), 0, 3)
	var ac = d.get("accs", {})
	if ac is Dictionary:
		for k in (ac as Dictionary).keys():
			if LaneData.ACCESSORIES.has(String(k)):
				accs[String(k)] = clampi(int(ac[k]), 1, LaneData.ACC_LV_MAX)
	var ao = d.get("acc_on", {})
	if ao is Dictionary:
		for k in (ao as Dictionary).keys():
			if units.has(String(k)) and accs.has(String(ao[k])) and wearer(String(ao[k])) == "":
				acc_on[String(k)] = String(ao[k])
	migrated = bool(d.get("migrated", false))
	# 이미 하던 사람은 안내를 다시 보지 않는다
	tut = clampi(int(d.get("tut", 99 if cleared > 0 else 0)), 0, 99)
	var fl = d.get("fails", {})
	if fl is Dictionary:
		for k in (fl as Dictionary).keys():
			fails[int(k)] = clampi(int(fl[k]), 0, 99)
	var fw = d.get("flowers", null)
	if fw is Dictionary:
		for k in (fw as Dictionary).keys():
			var v := clampi(int(fw[k]), 0, 7)
			if v > 0:
				flowers[int(k)] = v
	else:
		# 꽃이 없던 옛 저장: 깬 판은 첫 꽃(이기기)만 핀 것으로 (보상 없음)
		for i in range(1, cleared + 1):
			flowers[i] = 1
	var bq = d.get("bouquet", {})
	if bq is Dictionary:
		for k in (bq as Dictionary).keys():
			bouquet[int(k)] = clampi(int(bq[k]), 0, LaneData.BOUQUET.size())
	mission_day = maxi(0, int(d.get("m_day", 0)))
	var ms = d.get("missions", [])
	if ms is Array:
		for m in ms:
			if m is Dictionary and LaneData.MISSIONS.has(String(m.get("id", ""))) and missions.size() < 3:
				var goal := int(LaneData.MISSIONS[String(m["id"])]["goal"])
				missions.append({"id": String(m["id"]), "prog": clampi(int(m.get("prog", 0)), 0, goal),
					"got": bool(m.get("got", false))})
	if missions.size() != 3:
		# 깨졌거나 처음이면 오늘 다시 굴린다
		missions = []
		mission_day = 0
	mission_swap = bool(d.get("m_swap", false))
	stamp_day = maxi(0, int(d.get("st_day", 0)))
	week_no = maxi(0, int(d.get("week_no", 0)))
	stamps = clampi(int(d.get("stamps", 0)), 0, LaneData.WEEK_STAMPS)
	var wg = d.get("week_got", [])
	if wg is Array:
		for k in mini((wg as Array).size(), 3):
			week_got[k] = bool(wg[k])
	unlock_by_stage()


static func has_save() -> bool:
	var c := ConfigFile.new()
	return c.load(save_path) == OK and c.has_section_key("lane", "data")


static func save(now_unix: int = -1) -> void:
	if now_unix >= 0:
		last_seen = now_unix
	var c := ConfigFile.new()
	c.set_value("lane", "data", to_dict())
	c.save(save_path)


static func load_save() -> bool:
	var c := ConfigFile.new()
	if c.load(save_path) != OK or not c.has_section_key("lane", "data"):
		return false
	var d = c.get_value("lane", "data")
	if not (d is Dictionary):
		return false
	from_dict(d)
	return true


static func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	reset()
