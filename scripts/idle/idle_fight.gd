class_name IdleFight
extends RefCounted
## 자동 전투 한 스테이지 (`docs/redesign-idle.md`). 화면과 시뮬레이션이 같은 규칙을 쓴다.
##
## 쓰는 법: `start(n)` 뒤에 `tick(dt)` 를 계속 부르고, 돌려받은 사건(events)을 화면이 그린다.
## 이기면 `clear`, 지면 `defeat` 사건이 한 번 나가고 `done` 이 참이 된다 - 스테이지 이동은 부른 쪽이
## `IdleState.on_clear()`/`on_defeat()` 로 하고 다시 `start()` 한다.

## 받는 피해 경감: 1 / (1 + 방어 / (BASE + PER x 스테이지)).
const MIT_BASE := 40.0
const MIT_PER := 18.0
## 몬스터 하나를 잡을 때마다 이만큼 체력이 찬다 (한 스테이지 안에서 꾸준히 버티게).
const HEAL_ON_KILL := 0.12
## 몬스터가 나타나기까지.
const SPAWN_DELAY := 0.5
const STEP := 0.05
## 자동사냥 중에 화면을 톡 치면 한 번 더 때린다 (기본 공격의 이만큼, 이 간격보다 자주는 안 된다).
const TAP_POWER := 0.3
const TAP_COOLDOWN := 0.25
## 자동사냥이 아닐 때(레벨 5 전)는 톡 칠 때마다 제대로 한 대 (필살기가 차 있으면 필살기).
const MANUAL_COOLDOWN := 0.45
## 자동사냥이 아닐 때도 쿼카는 혼자 이만큼 느린 박자로 때린다 (필살기는 안 쓴다). 가만히 두면
## 아예 안 때려서, 톡톡 치는 걸 모르는 사람은 1번 스테이지에서 영영 쓰러지기만 했다 (시뮬레이션).
const MANUAL_SLOW := 3.0

var rng := RandomNumberGenerator.new()
var info: Dictionary = {}
var h: Dictionary = {}
var hero_hp := 0.0
var hero_max := 0.0
var mon: Dictionary = {}
var mon_hp := 0.0
var mon_max := 0.0
var left := 0                     ## 아직 안 잡은 몬스터 (지금 서 있는 것 포함)
var total := 0
var state := "spawn"              ## spawn · fight · done
var result := ""                  ## clear · defeat
var done := false
var time := 0.0

var _hero_t := 0.0
var _mon_t := 0.0
## 스킬마다 남은 쿨타임(초). **스테이지가 바뀌어도 이어진다** - 20초 쿨타임 스킬이 스테이지마다
## 처음부터 다시 돌면 거의 못 쓴다. 직업이 바뀌면 `reset_cooldowns()`.
var cds: Array = []
var _cd_job := ""
## 우두머리가 화났나 (체력이 30% 아래).
var raged := false
var _spawn_t := 0.0
var _guard_t := 0.0
var _guard := 1.0
var _tap_t := 0.0
var events: Array = []


func start(stage_n: int, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	info = IdleData.stage_info(stage_n)
	h = IdleState.hero()
	hero_max = float(h["hp"])
	hero_hp = hero_max
	total = int(info["count"])
	left = total
	state = "spawn"
	result = ""
	done = false
	time = 0.0
	_spawn_t = SPAWN_DELAY
	_hero_t = float(h["every"])
	if _cd_job != IdleState.job or cds.size() != (h["skills"] as Array).size():
		reset_cooldowns()
	raged = false
	_guard_t = 0.0
	_guard = 1.0
	_tap_t = 0.0
	events = []


## 스킬 쿨타임을 처음부터 (직업을 바꿨을 때). 처음 배운 스킬은 바로 쓸 수 있게 반만 채운다.
func reset_cooldowns() -> void:
	_cd_job = IdleState.job
	cds = []
	for sk in IdleData.skills_of(IdleState.job):
		cds.append(float((sk as Dictionary)["cd"]) * 0.5)


## 그 스킬을 지금 쓸 수 있나 (배웠고 쿨타임이 찼고 싸우는 중).
func skill_ready(i: int) -> bool:
	return i >= 0 and i < cds.size() and IdleState.skill_unlocked(i) and float(cds[i]) <= 0.0 \
		and state == "fight" and not done


## 쿨타임이 얼마나 찼나 (0 막 씀 ~ 1 다 참).
func skill_charge(i: int) -> float:
	var sk := IdleData.skills_of(IdleState.job)
	if i < 0 or i >= cds.size() or i >= sk.size():
		return 0.0
	return clampf(1.0 - float(cds[i]) / float((sk[i] as Dictionary)["cd"]), 0.0, 1.0)


## 버튼으로 스킬을 쓴다. 생긴 사건들을 돌려준다.
func cast(i: int) -> Array:
	events = []
	if not skill_ready(i):
		return events
	_cast(i)
	return events


func _cast(i: int) -> void:
	var sk: Dictionary = IdleData.skills_of(IdleState.job)[i]
	cds[i] = float(sk["cd"])
	_use_skill(sk, i)


func _mit() -> float:
	return 1.0 / (1.0 + float(h["def"]) / (MIT_BASE + MIT_PER * float(info["stage"])))


## dt 초만큼 흐른다. 이번에 생긴 사건들을 돌려준다.
func tick(dt: float) -> Array:
	events = []
	if done:
		return events
	var rest := dt
	while rest > 0.0 and not done:
		var d := minf(STEP, rest)
		rest -= d
		_step(d)
	return events


## 화면을 톡 쳤다 - 싸우는 중이면 한 번 더 때린다. 생긴 사건들을 돌려준다.
func tap() -> Array:
	events = []
	if done or state != "fight" or _tap_t > 0.0:
		return events
	if IdleState.auto_active():
		_tap_t = TAP_COOLDOWN
		_hit_monster(TAP_POWER, false, false, true)
		return events
	_tap_t = MANUAL_COOLDOWN
	_hit_monster(1.0, false, false)
	return events


func _step(d: float) -> void:
	time += d
	_tap_t = maxf(0.0, _tap_t - d)
	if _guard_t > 0.0:
		_guard_t -= d
		if _guard_t <= 0.0:
			_guard = 1.0
	# 체력은 저절로 찬다 (싸우는 중에도, 다음 몬스터를 기다리는 동안에도)
	hero_hp = minf(hero_max, hero_hp + hero_max * IdleData.HERO_REGEN * d)
	if state == "spawn":
		_spawn_t -= d
		if _spawn_t <= 0.0:
			_spawn()
		return
	# 스킬 쿨타임 - 자동사냥이면 찬 것 중 가장 센(나중에 배운) 것부터 하나 쓴다
	for i in cds.size():
		cds[i] = maxf(0.0, float(cds[i]) - d)
	var auto := IdleState.auto_active()
	if auto:
		for i in range(cds.size() - 1, -1, -1):
			if skill_ready(i):
				_cast(i)
				break
		if state != "fight":
			return
	# 영웅 차례
	_hero_t -= d if auto else d / MANUAL_SLOW
	if _hero_t <= 0.0:
		_hero_t += float(h["every"])
		_hit_monster(1.0, false, false)
		if state != "fight":
			return
	# 몬스터 차례
	if bool(mon["boss"]) and not raged and mon_hp <= mon_max * IdleData.BOSS_RAGE_AT:
		raged = true
		events.append({"k": "rage"})
	_mon_t -= d
	if _mon_t <= 0.0:
		_mon_t += float(mon["every"]) * (IdleData.BOSS_RAGE_EVERY if raged else 1.0)
		var dmg := float(mon["atk"]) * _mit() * _guard
		dmg = maxf(1.0, dmg)
		hero_hp -= dmg
		events.append({"k": "mon_hit", "dmg": int(round(dmg))})
		if hero_hp <= 0.0:
			hero_hp = 0.0
			state = "done"
			done = true
			result = "defeat"
			events.append({"k": "defeat"})


func _spawn() -> void:
	var boss: bool = bool(info["boss"])
	mon = IdleData.monster(int(info["stage"]), boss)
	mon["kind"] = String(info["kind"])
	mon["boss"] = boss
	mon_max = float(mon["hp"])
	mon_hp = mon_max
	raged = false
	_mon_t = float(mon["every"])
	state = "fight"
	events.append({"k": "spawn", "kind": String(mon["kind"]), "boss": boss})


func _use_skill(sk: Dictionary, i: int) -> void:
	events.append({"k": "skill", "name": String(sk["name"]), "i": i, "hits": int(sk.get("hits", 1))})
	if sk.has("guard"):
		_guard = float(sk["guard"])
		_guard_t = float(sk.get("guard_secs", 3.0))
	var hits := int(sk.get("hits", 1))
	for _n in hits:
		if state != "fight":
			break
		_hit_monster(float(sk.get("power", 1.0)), bool(sk.get("crit", false)), true, false, i)


func _hit_monster(power: float, force_crit: bool, skill: bool, tapped := false, skill_i := -1) -> void:
	var raw := float(h["atk"]) * power
	var crit := force_crit or rng.randf() < float(h["crit"])
	if crit:
		raw *= IdleData.CRIT_MULT
	var dmg := maxf(raw * 0.25, raw - float(mon["def"]) * 0.5)
	dmg = maxf(1.0, dmg)
	mon_hp -= dmg
	events.append({"k": "hero_hit", "dmg": int(round(dmg)), "crit": crit, "skill": skill,
		"tap": tapped, "si": skill_i})
	if mon_hp <= 0.0:
		mon_hp = 0.0
		_kill()


func _kill() -> void:
	left -= 1
	IdleState.kills += 1
	var coin := int(mon["coin"])
	IdleState.coins += coin
	var levels := IdleState.add_exp(int(mon["exp"]))
	var drop := IdleState.roll_drop(rng, int(info["stage"]))
	hero_hp = minf(hero_max, hero_hp + hero_max * HEAL_ON_KILL)
	events.append({"k": "kill", "coin": coin, "xp": int(mon["exp"]), "levels": levels,
		"drop": drop, "boss": bool(mon["boss"])})
	if levels > 0 or not drop.is_empty():
		# 레벨이 오르거나 장비가 바뀌면 몸이 바뀐다 - 새 능력치로 다시 읽는다 (체력은 그 비율 그대로 늘려 준다).
		var ratio := hero_hp / maxf(1.0, hero_max)
		h = IdleState.hero()
		hero_max = float(h["hp"])
		hero_hp = hero_max * ratio
		if levels > 0:
			events.append({"k": "level_up", "level": IdleState.level})
	if left <= 0:
		state = "done"
		done = true
		result = "clear"
		events.append({"k": "clear"})
	else:
		state = "spawn"
		_spawn_t = SPAWN_DELAY
