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


static func to_dict() -> Dictionary:
	return {"v": 1, "xp": xp, "stars": stars, "units": units.duplicate(), "lineup": lineup.duplicate(),
		"cleared": cleared, "clears": clears.duplicate(), "auto": auto_summon, "speed2": speed2,
		"seen_intro": seen_intro, "last_seen": last_seen}


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
