class_name IdleState
extends RefCounted
## 진짜 행복 (키우기)의 지금 상태와 성장 (`docs/redesign-idle.md`). 정적 클래스 - 자동 로드를 늘리지 않는다.
##
## 저장은 새 파일 `user://idle.cfg` 하나. 옛 게임의 저장과 섞이지 않는다.

const SAVE_PATH := "user://idle.cfg"

static var level := 1
static var xp := 0
static var job := "novice"
static var coins := 0
## 지금 싸우는 스테이지와 가장 멀리 간 스테이지.
static var stage := 1
static var best := 1
## 칸 → [단계, 강화].
static var gear: Dictionary = {}
## 수련 단계 (능력치 → 단계).
static var train: Dictionary = {}
static var kills := 0
static var ending_seen := false
static var last_seen := 0
## 보스에 졌다 - [보스 도전] 버튼을 띄운다.
static var boss_failed := false
static var seen_intro := false
## 자동사냥을 켜 두었나 (레벨 5 전에는 켜 둬도 돌지 않는다).
static var auto_on := true


static func reset() -> void:
	level = 1
	xp = 0
	job = "novice"
	coins = 0
	stage = 1
	best = 1
	kills = 0
	ending_seen = false
	last_seen = 0
	boss_failed = false
	seen_intro = false
	auto_on = true
	train = {}
	for t in IdleData.TRAIN_STATS:
		train[t] = 0
	gear = {}
	for s in IdleData.SLOTS:
		gear[s] = [1, 0]


# ── 능력치 ───────────────────────────────────────────────────────────

static func gear_total(stat: String) -> float:
	var sum := 0.0
	for s in IdleData.SLOTS:
		if String(IdleData.SLOT_STAT[s]) == stat:
			var g: Array = gear[s]
			sum += IdleData.slot_value(String(s), int(g[0]), int(g[1]))
	return sum


## 지금 몸 `{hp, atk, def, every, crit, skill}`. 직업 배율과 장비가 합쳐진다.
static func hero() -> Dictionary:
	var j: Dictionary = IdleData.JOBS.get(job, IdleData.JOBS["novice"])
	var l := float(level - 1)
	var hp := ((IdleData.HERO_HP + IdleData.HERO_HP_PER * l) * float(j["hp"]) + gear_total("hp")) * train_mult("hp")
	var atk := ((IdleData.HERO_ATK + IdleData.HERO_ATK_PER * l) * float(j["atk"]) + gear_total("atk")) * train_mult("atk")
	var df := ((IdleData.HERO_DEF + IdleData.HERO_DEF_PER * l) * float(j["def"]) + gear_total("def")) * train_mult("def")
	return {"hp": hp, "atk": atk, "def": df, "every": float(j["every"]), "crit": float(j["crit"]),
		"skill": j["skill"]}


## 전투력 한 숫자 - 화면에 보여 주는 용도 (비교는 이 숫자 하나로).
static func power() -> int:
	var h := hero()
	var dps := float(h["atk"]) / float(h["every"])
	return int(round(dps * 4.0 + float(h["hp"]) * 0.25 + float(h["def"]) * 1.5))


# ── 수련 ─────────────────────────────────────────────────────────────

static func train_mult(stat: String) -> float:
	return 1.0 + IdleData.TRAIN_STEP * float(train.get(stat, 0))


static func train_open() -> bool:
	return best >= IdleData.TRAIN_OPEN


static func train_cost_of(stat: String) -> int:
	return IdleData.train_cost(int(train.get(stat, 0)))


static func can_train(stat: String) -> bool:
	return train_open() and train.has(stat) and coins >= train_cost_of(stat)


## 수련한다 (실패 없음, 끝 없음). 성공하면 참.
static func do_train(stat: String) -> bool:
	if not can_train(stat):
		return false
	coins -= train_cost_of(stat)
	train[stat] = int(train[stat]) + 1
	return true


# ── 레벨 ─────────────────────────────────────────────────────────────

## 경험을 얻는다. 오른 레벨 수를 돌려준다.
static func add_exp(amount: int) -> int:
	if level >= IdleData.LEVEL_MAX:
		return 0
	xp += maxi(0, amount)
	var ups := 0
	while level < IdleData.LEVEL_MAX and xp >= IdleData.exp_need(level):
		xp -= IdleData.exp_need(level)
		level += 1
		ups += 1
	if level >= IdleData.LEVEL_MAX:
		xp = 0
	return ups


static func can_auto() -> bool:
	return level >= IdleData.AUTO_LV


## 지금 쿼카가 알아서 싸우나.
static func auto_active() -> bool:
	return can_auto() and auto_on


static func can_pick_job() -> bool:
	return level >= IdleData.JOB_LV


## 직업을 고른다 (언제든 공짜로 바꾼다).
static func set_job(j: String) -> bool:
	if not can_pick_job() or not IdleData.JOBS.has(j) or j == "novice":
		return false
	job = j
	return true


# ── 장비 ─────────────────────────────────────────────────────────────

static func enhance_cost_of(slot: String) -> int:
	var g: Array = gear[slot]
	return IdleData.enhance_cost(int(g[0]), int(g[1]))


static func can_enhance(slot: String) -> bool:
	var g: Array = gear[slot]
	return int(g[1]) < IdleData.PLUS_MAX and coins >= enhance_cost_of(slot)


## 강화한다 (실패 없음). 성공하면 참.
static func enhance(slot: String) -> bool:
	if not can_enhance(slot):
		return false
	coins -= enhance_cost_of(slot)
	(gear[slot] as Array)[1] = int(gear[slot][1]) + 1
	return true


## 그 칸을 이 단계로 올린다 (지금보다 높을 때만). 강화 수치는 이어진다. 바뀌면 참.
static func upgrade_tier(slot: String, tier: int) -> bool:
	var g: Array = gear[slot]
	if tier <= int(g[0]):
		return false
	g[0] = tier
	return true


## 몬스터가 장비를 떨어뜨렸다 - 무작위 한 칸이 이 스테이지 단계로. `[칸, 단계]` 또는 빈 것.
static func roll_drop(rng: RandomNumberGenerator, at_stage: int) -> Array:
	if rng.randf() >= IdleData.DROP_CHANCE:
		return []
	var tier := IdleData.zone_tier(at_stage)
	var slot := String(IdleData.SLOTS[rng.randi_range(0, IdleData.SLOTS.size() - 1)])
	if upgrade_tier(slot, tier):
		return [slot, tier]
	return []


## 우두머리를 처음 깼다 - **다음 구역** 단계로 한 칸 (구역마다 돌아가며). 한 걸음 앞선 선물이다
## (첫 구역은 처음 장비와 같은 단계라 그 구역 단계로는 줄 게 없다).
static func boss_reward(at_stage: int) -> Array:
	var zi := int(IdleData.stage_info(at_stage)["zone"])
	var slot := String(IdleData.SLOTS[zi % IdleData.SLOTS.size()])
	var tier := mini(IdleData.ZONE_COUNT, IdleData.zone_tier(at_stage) + 1)
	# 그 칸이 이미 높으면 가장 낮은 칸을 올린다.
	if not upgrade_tier(slot, tier):
		var low := ""
		var low_t := 99
		for s in IdleData.SLOTS:
			var t := int(gear[s][0])
			if t < low_t:
				low_t = t
				low = String(s)
		if low != "" and upgrade_tier(low, tier):
			return [low, tier]
		return []
	return [slot, tier]


# ── 스테이지 ─────────────────────────────────────────────────────────

## 스테이지를 깼다. 새로 열린 스테이지면 `{new_best, boss_reward}`.
static func on_clear() -> Dictionary:
	var out := {"new_best": false, "reward": []}
	var info := IdleData.stage_info(stage)
	if stage >= best:
		best = stage + 1
		out["new_best"] = true
		if bool(info["boss"]):
			out["reward"] = boss_reward(stage)
		if stage >= IdleData.STAGE_MAX and not ending_seen:
			out["ending"] = true
	boss_failed = false
	stage += 1
	return out


## 쓰러졌다. 한 스테이지 뒤로 물러나 다시 모은다 (우두머리였으면 [보스 도전] 을 띄운다).
static func on_defeat() -> void:
	var info := IdleData.stage_info(stage)
	if bool(info["boss"]):
		boss_failed = true
	stage = maxi(1, stage - 1)
	# 물러난 자리가 우두머리면 한 칸 더 - 모으는 곳이 우두머리 앞이 되면 안 된다.
	if stage > 1 and bool(IdleData.stage_info(stage)["boss"]):
		stage -= 1


## 우두머리에 다시 도전한다 (물러나 있던 스테이지에서 다음 스테이지로).
static func challenge_boss() -> bool:
	if not boss_failed:
		return false
	boss_failed = false
	stage = mini(best, stage + 1)
	return true


## 스테이지를 골라 간다 (지금까지 열린 곳만).
static func go_stage(n: int) -> bool:
	if n < 1 or n > best:
		return false
	stage = n
	boss_failed = false
	return true


# ── 자는 동안 ────────────────────────────────────────────────────────

## 꺼 둔 시간(분)에 따른 보상 `{minutes, coins, xp}` (너무 짧으면 빈 것).
static func offline_reward(now_unix: int) -> Dictionary:
	if last_seen <= 0 or now_unix <= last_seen:
		return {}
	var mins := mini(IdleData.IDLE_MAX_MIN, (now_unix - last_seen) / 60)
	if mins < IdleData.IDLE_MIN_MIN:
		return {}
	# 지금 스테이지 몬스터 한 마리 값 x 분당 마릿수 x 분 (졌던 자리보다 한 칸 쉬운 값 - 조금 박하게).
	var m := IdleData.monster(maxi(1, stage - 1), false)
	var n := float(mins) * IdleData.IDLE_KILLS_PER_MIN
	return {"minutes": mins, "coins": int(n * float(m["coin"])), "exp": int(n * float(m["exp"]))}


static func claim_offline(now_unix: int) -> Dictionary:
	var r := offline_reward(now_unix)
	last_seen = now_unix
	if r.is_empty():
		return r
	coins += int(r["coins"])
	r["levels"] = add_exp(int(r["exp"]))
	return r


# ── 저장 ─────────────────────────────────────────────────────────────

static func to_dict() -> Dictionary:
	return {"v": 1, "level": level, "xp": xp, "job": job, "coins": coins, "stage": stage,
		"best": best, "gear": gear.duplicate(true), "kills": kills, "ending_seen": ending_seen,
		"last_seen": last_seen, "boss_failed": boss_failed, "seen_intro": seen_intro,
		"auto_on": auto_on, "train": train.duplicate()}


static func from_dict(d: Dictionary) -> void:
	reset()
	level = clampi(int(d.get("level", 1)), 1, IdleData.LEVEL_MAX)
	xp = maxi(0, int(d.get("xp", 0)))
	job = String(d.get("job", "novice"))
	if not IdleData.JOBS.has(job):
		job = "novice"
	coins = maxi(0, int(d.get("coins", 0)))
	best = maxi(1, int(d.get("best", 1)))
	stage = clampi(int(d.get("stage", 1)), 1, best)
	kills = maxi(0, int(d.get("kills", 0)))
	ending_seen = bool(d.get("ending_seen", false))
	last_seen = maxi(0, int(d.get("last_seen", 0)))
	boss_failed = bool(d.get("boss_failed", false))
	seen_intro = bool(d.get("seen_intro", false))
	auto_on = bool(d.get("auto_on", true))
	var tr = d.get("train", {})
	if tr is Dictionary:
		for t in IdleData.TRAIN_STATS:
			train[t] = clampi(int((tr as Dictionary).get(t, 0)), 0, 9999)
	var g = d.get("gear", {})
	if g is Dictionary:
		for s in IdleData.SLOTS:
			var e = (g as Dictionary).get(s, [1, 0])
			if e is Array and (e as Array).size() >= 2:
				gear[s] = [clampi(int(e[0]), 1, IdleData.ZONE_COUNT),
					clampi(int(e[1]), 0, IdleData.PLUS_MAX)]


static func has_save() -> bool:
	var c := ConfigFile.new()
	return c.load(SAVE_PATH) == OK and c.has_section_key("idle", "data")


static func save(now_unix: int = -1) -> void:
	if now_unix >= 0:
		last_seen = now_unix
	var c := ConfigFile.new()
	c.set_value("idle", "data", to_dict())
	c.save(SAVE_PATH)


static func load_save() -> bool:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return false
	if not c.has_section_key("idle", "data"):
		return false
	var d = c.get_value("idle", "data")
	if not (d is Dictionary):
		return false
	from_dict(d)
	return true


static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	reset()
