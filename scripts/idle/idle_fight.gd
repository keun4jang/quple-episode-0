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
## 화면을 톡 치면 한 번 더 때린다 (기본 공격의 이만큼, 이 간격보다 자주는 안 된다).
const TAP_POWER := 0.3
const TAP_COOLDOWN := 0.25

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
var _skill_cd := 0.0
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
	var sk: Dictionary = h["skill"]
	_skill_cd = float(sk.get("every", 0.0))
	_guard_t = 0.0
	_guard = 1.0
	_tap_t = 0.0
	events = []


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
	_tap_t = TAP_COOLDOWN
	_hit_monster(TAP_POWER, false, false, true)
	return events


func _step(d: float) -> void:
	time += d
	_tap_t = maxf(0.0, _tap_t - d)
	if _guard_t > 0.0:
		_guard_t -= d
		if _guard_t <= 0.0:
			_guard = 1.0
	if state == "spawn":
		_spawn_t -= d
		if _spawn_t <= 0.0:
			_spawn()
		return
	# 영웅 차례
	var sk: Dictionary = h["skill"]
	if not sk.is_empty():
		_skill_cd -= d
	_hero_t -= d
	if _hero_t <= 0.0:
		_hero_t += float(h["every"])
		if not sk.is_empty() and _skill_cd <= 0.0:
			_skill_cd = float(sk["every"])
			_use_skill(sk)
		else:
			_hit_monster(1.0, false, false)
		if state != "fight":
			return
	# 몬스터 차례
	_mon_t -= d
	if _mon_t <= 0.0:
		_mon_t += float(mon["every"])
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
	_mon_t = float(mon["every"])
	state = "fight"
	events.append({"k": "spawn", "kind": String(mon["kind"]), "boss": boss})


func _use_skill(sk: Dictionary) -> void:
	events.append({"k": "skill", "name": String(sk["name"])})
	if sk.has("guard"):
		_guard = float(sk["guard"])
		_guard_t = float(sk.get("guard_secs", 3.0))
	var hits := int(sk.get("hits", 1))
	for i in hits:
		if state != "fight":
			break
		_hit_monster(float(sk.get("power", 1.0)), bool(sk.get("crit", false)), true)


func _hit_monster(power: float, force_crit: bool, skill: bool, tapped := false) -> void:
	var raw := float(h["atk"]) * power
	var crit := force_crit or rng.randf() < float(h["crit"])
	if crit:
		raw *= IdleData.CRIT_MULT
	var dmg := maxf(raw * 0.25, raw - float(mon["def"]) * 0.5)
	dmg = maxf(1.0, dmg)
	mon_hp -= dmg
	events.append({"k": "hero_hit", "dmg": int(round(dmg)), "crit": crit, "skill": skill,
		"tap": tapped})
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
