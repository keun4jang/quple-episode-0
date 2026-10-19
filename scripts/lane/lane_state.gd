class_name LaneState
extends RefCounted
## 쿼카 군단의 저장되는 상태. 정적 클래스 - 자동 로드를 늘리지 않는다 (`IdleState` 와 같은 이유).
## 저장 파일은 따로 `user://lane.cfg`.

const SAVE_PATH := "user://lane.cfg"

## 꿈조각 = 레벨업 재화 (냥코의 XP). 꿈별 = 뽑기 재화.
static var xp := 0
static var stars := 0
## 쿼카 → 레벨 (가진 것만 들어 있다).
static var units: Dictionary = {}
static var lineup: Array = []
## 가장 멀리 깬 스테이지 (0 = 아직 없음).
static var cleared := 0
static var clears: Dictionary = {}       ## 스테이지 → 깬 횟수
static var auto_summon := false
static var speed2 := false
static var seen_intro := false
static var last_seen := 0
## 뽑기: 무료 티켓 · 전설 없이 뽑은 수 · 전체 뽑은 수
static var tickets := 0
static var pity := 0
static var pulls := 0
## 매일 선물: 마지막으로 받은 날(유닉스 일 수) · 이어 받은 날 수
static var daily_day := 0
static var daily_streak := 0


static func reset() -> void:
	xp = 0
	stars = 0
	units = {"tiny": 1, "shield": 1}
	lineup = ["tiny", "shield"]
	cleared = 0
	clears = {}
	auto_summon = false
	speed2 = false
	seen_intro = false
	last_seen = 0
	tickets = 1          # 처음 하나는 선물 - 첫 뽑기는 특급 이상
	pity = 0
	pulls = 0
	daily_day = 0
	daily_streak = 0


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
	return got


static func can_level(id: String) -> bool:
	return units.has(id) and level_of(id) < LaneData.UNIT_LV_MAX and xp >= LaneData.level_cost(id, level_of(id))


static func level_up(id: String) -> bool:
	if not can_level(id):
		return false
	xp -= LaneData.level_cost(id, level_of(id))
	units[id] = level_of(id) + 1
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
	return true


## 판에서 쓸 몸 `{hp, atk, ...}` - 레벨 배율이 들어간다.
static func unit_stats(id: String) -> Dictionary:
	var u: Dictionary = LaneData.UNITS[id].duplicate()
	var m := LaneData.unit_mult(level_of(id))
	u["hp"] = float(u["hp"]) * m
	u["atk"] = float(u["atk"]) * m
	u["id"] = id
	return u


## 판을 이겼다. 받은 것 `{xp, stars, first, new_units}`.
static func on_win(n: int) -> Dictionary:
	var first := n > cleared
	var r := LaneData.reward(n, first)
	xp += int(r["xp"])
	stars += int(r["stars"])
	tickets += int(r.get("tickets", 0))
	clears[n] = int(clears.get(n, 0)) + 1
	if first:
		cleared = n
	r["first"] = first
	r["new_units"] = unlock_by_stage()
	return r


## 자는 동안: 가장 멀리 깬 곳 기준 꿈조각 (최대 8시간).
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
## 돌려주는 것: [{id, rarity, new, lv, xp}] - new 처음 만남, lv 지금 레벨, xp 중복이라 받은 꿈조각.
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
		var floor_r := "super" if (pulls == 0 or (count > 1 and i == count - 1)) else "rare"
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
	elif level_of(id) < LaneData.UNIT_LV_MAX:
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


static func owned_count() -> int:
	return units.size()


static func to_dict() -> Dictionary:
	return {"v": 1, "xp": xp, "stars": stars, "units": units.duplicate(), "lineup": lineup.duplicate(),
		"cleared": cleared, "clears": clears.duplicate(), "auto": auto_summon, "speed2": speed2,
		"seen_intro": seen_intro, "last_seen": last_seen, "tickets": tickets, "pity": pity, "pulls": pulls,
		"daily_day": daily_day, "daily_streak": daily_streak}


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
	var l = d.get("lineup", [])
	if l is Array:
		lineup = []
		for id in l:
			if units.has(String(id)) and not lineup.has(String(id)) and lineup.size() < LaneData.LINEUP_MAX:
				lineup.append(String(id))
	if lineup.is_empty():
		lineup = ["tiny"]
	var c = d.get("clears", {})
	if c is Dictionary:
		for k in (c as Dictionary).keys():
			clears[int(k)] = maxi(0, int(c[k]))
	auto_summon = bool(d.get("auto", false))
	speed2 = bool(d.get("speed2", false))
	seen_intro = bool(d.get("seen_intro", false))
	last_seen = maxi(0, int(d.get("last_seen", 0)))
	tickets = clampi(int(d.get("tickets", 1)), 0, 9999)
	pity = clampi(int(d.get("pity", 0)), 0, LaneData.PITY_LEGEND)
	pulls = maxi(0, int(d.get("pulls", 0)))
	daily_day = maxi(0, int(d.get("daily_day", 0)))
	daily_streak = maxi(0, int(d.get("daily_streak", 0)))
	unlock_by_stage()


static func has_save() -> bool:
	var c := ConfigFile.new()
	return c.load(SAVE_PATH) == OK and c.has_section_key("lane", "data")


static func save(now_unix: int = -1) -> void:
	if now_unix >= 0:
		last_seen = now_unix
	var c := ConfigFile.new()
	c.set_value("lane", "data", to_dict())
	c.save(SAVE_PATH)


static func load_save() -> bool:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK or not c.has_section_key("lane", "data"):
		return false
	var d = c.get_value("lane", "data")
	if not (d is Dictionary):
		return false
	from_dict(d)
	return true


static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	reset()
