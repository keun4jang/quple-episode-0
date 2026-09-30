extends Node
## **밸런스 시뮬레이션** - 봇이 실제 싸움 규칙(`Field`·`Battle`·`Gear`)으로
## 1구역부터 대마왕과 꿈의 탑까지 싸워 올라간다. 화면은 안 띄운다.
##
##     xvfb-run -a godot --headless --path . res://tools/sim/SimBalance.tscn
##
## 봇이 하는 것 (사람이 할 법한 만큼만):
##   - 가장 센 공격 스킬을 쓰고, 없으면 [공격]. 체력이 35% 밑이면 먹을 것을 먹는다
##   - 싸움 사이에 체력이 반 밑이면 쉰다(심호흡·마음력 도는 것만으로 - 저절로 차는 게 있으면 그것도)
##   - LV 10 에 전직, 떨어진 장비가 더 좋으면 입고, 강화석이 있으면 무기를 강화한다
##   - 몬스터 공격은 **피하지 않는다** (예고를 보고 비키는 건 사람 몫 - 최악을 잰다)
## 구역마다: 마을 몬스터 한 바퀴 ~ 우두머리의 길 졸개 ~ 방의 호위 둘 ~ 우두머리.

const DT := 0.05
const WALK := 4.0          # 몬스터 하나 찾아가는 데 드는 초
const SHADE_EVERY := 1.8
const BOSS_EVERY := 2.3
const WINDUP := 0.6

var job := "warrior"
var t_total := 0.0
var t_rest := 0.0
var deaths := 0
var eaten := 0
var low_hp := 1.0
var report: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var jobs: Array = ["warrior", "mage", "archer", "thief"]
	var arg := OS.get_environment("SIM_JOB")
	if arg != "":
		jobs = [arg]
	var all: Dictionary = {}
	for j in jobs:
		all[j] = _run_job(j)
	var out := OS.get_environment("SIM_OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(all, "  "))
	get_tree().quit()


func _run_job(j: String) -> Dictionary:
	job = j
	# SIM_SEED=n - 다른 운으로 한 판 (기본 7). 같은 시드면 늘 같은 숫자가 나온다.
	var sd := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	_rng.seed = sd
	seed(sd)
	JourneyState.reset()
	Loop.reset()
	Battle.reset()
	Field.reset()
	Field.jitter = true
	t_total = 0.0
	t_rest = 0.0
	deaths = 0
	eaten = 0
	bought = 0
	report = []
	print("\n==================== 직업: %s ====================" % j)
	var tower_at := {}
	# SIM_ZONES=n - 앞의 n 구역만 (탑·마지막 장 없이). 초반만 빨리 재 볼 때.
	var only := int(OS.get_environment("SIM_ZONES")) if OS.get_environment("SIM_ZONES") != "" else 0
	if only > 0:
		for i in mini(only, Quests.ORDER.size()):
			_zone(String(Quests.ORDER[i]))
			_zone_detail()
		return {"zones": report}
	for i in Quests.ORDER.size():
		_zone(String(Quests.ORDER[i]))
		# 게임 중간에 탑에 들어가 보면 어디까지 가나 (들어갔다 나오면 상태는 되돌린다).
		if i in [0, 2, 5, 8]:
			tower_at[String(Quests.ORDER[i])] = _tower_try(String(Quests.ORDER[i]) + " 뒤")
	# 꿈속 잿마루 타워 ~ 대마왕
	# 타워 → 야근 계단길 → 대마왕의 방 (다른 구역과 같은 세 단계). 대마왕은 반쯤
	# 지치면 졸개 둘을 부른다 (`BossLair.PHASE2`) - 대마왕 뒤에 이어 싸운 것으로 친다.
	var z := _zone_start("잿마루 타워")
	for k in Battle.tower_spawns():
		_fight(String(k[0]), int(k[1]), z)
	for k in Battle.road_spawns("잿마루"):
		_fight(String(k[0]), int(k[1]), z)
	var fl := Battle.lair_spawns("잿마루")
	for i in range(1, fl.size()):
		_fight(String(fl[i][0]), int(fl[i][1]), z)
	_fight(String(fl[0][0]), int(fl[0][1]), z, true)
	for a in BossLair.PHASE2["night"]["adds"]:
		_fight(String(a[0]), int(a[1]), z)
	_zone_end(z, "night")
	JourneyState.mark_quest("엔딩:대마왕")
	# 꿈의 탑 - 어디까지 오르나 (한 층에서 세 번 쓰러지면 멈춘다)
	var floor_n := 1
	var tower_t := t_total
	while floor_n <= 60:
		var d0 := deaths
		var zz := _zone_start("탑 %d층" % floor_n)
		for k in Loop.floor_spawns(floor_n):
			_fight(String(k[0]), int(k[1]), zz, false, Loop.floor_power(floor_n), floor_n)
		if deaths - d0 > 0:
			print("   [탑 쓰러짐] %d층 (몬스터 LV %d 안팎, 나 LV %d) · %d번 · 최저체력 %d%%" % [
				floor_n, int(Loop.floor_spawns(floor_n)[0][1]), Battle.level, deaths - d0, int(float(zz["hp_low"]) * 100.0)])
		if deaths - d0 >= 3:
			break
		Loop.clear_floor(floor_n)
		floor_n += 1
	print("꿈의 탑: %d층까지 (탑에서 %.0f분)" % [Loop.tower_best, (t_total - tower_t) / 60.0])
	var res := {"tower_at": tower_at, "zones": report, "total_min": t_total / 60.0, "rest_min": t_rest / 60.0,
		"deaths": deaths, "tower": Loop.tower_best, "level": Battle.level,
		"coins": Gear.coins, "stones": Gear.stones, "bought": bought}
	print("전체 %.0f분 (쉬는 데 %.0f분) · 쓰러짐 %d · LV %d · 꿈조각 %d · 강화석 %d · 상점에서 산 장비 %d" % [
		t_total / 60.0, t_rest / 60.0, deaths, Battle.level, Gear.coins, Gear.stones, bought])
	return res


## 꿈의 탑을 1층부터 한 번 올라 본다. 층마다 축복을 고르고(힘 > 단단함 > 흡혈 > ...),
## 한 층에서 세 번 쓰러지면 멈춘다. 끝나면 오르기 전 상태로 되돌린다.
const BLESS_PREF := ["might", "shell", "leech", "keen", "flow", "hot", "gold"]


func _tower_try(label: String) -> int:
	var snap := JourneyState.to_dict()
	var t0 := t_total
	var d_save := deaths
	var lv := Battle.level
	Loop.blessings.clear()
	Battle.hp = Battle.hp_max()
	Battle.mp = Battle.mp_max()
	var n := 1
	var stuck_lv := 0
	var cap := mini(80, Loop.tower_cap())
	while n <= cap:
		var d0 := deaths
		var zz := _zone_start("탑")
		for k in Loop.floor_spawns(n):
			_fight(String(k[0]), int(k[1]), zz, false, Loop.floor_power(n), n)
			if deaths - d0 >= 3:
				break
		if deaths - d0 >= 3:
			stuck_lv = Loop.floor_lv(n)
			break
		var offer := Loop.bless_offer(n)
		for id in BLESS_PREF:
			if offer.has(id):
				Loop.add_blessing(id)
				break
		n += 1
	var reached := n - 1
	print("   꿈의 탑 (%s, LV %d 로 들어감 ~ LV %d 로 나옴): %d층까지 (열린 데 %d층) · 막힌 층 몬스터 LV %d · %.0f분 · 쓰러짐 %d" % [
		label, lv, Battle.level, reached, cap, stuck_lv, (t_total - t0) / 60.0, deaths - d_save])
	JourneyState.from_dict(snap)
	Field.reset()
	Loop.blessings.clear()
	t_total = t0
	deaths = d_save
	return reached


## 새 구역에 닿으면 상점에서 산다 - 무기 먼저, 방어구는 돈 되는 대로 (`Gear.shop_gear`).
## 먹을 것 값(꿈조각 100)은 남겨 둔다.
var bought := 0


func _shop(v: String) -> void:
	# SIM_NOSHOP=1 - 상점을 모르고 지나치는 사람 (드랍·첫 처치 보상 장비만 입는다).
	if OS.get_environment("SIM_NOSHOP") != "":
		return
	for e in Gear.shop_gear(v):
		if Gear.coins - int(e["price"]) < 100:
			continue
		if not Gear.better(e["item"]) and not Gear.worn(String(e["slot"])).is_empty():
			continue
		if bool(Gear.buy_gear(v, String(e["slot"]))["ok"]):
			bought += 1


func _zone(v: String) -> void:
	cur_zone = v
	_shop(v)
	var z := _zone_start(v)
	var list: Array = Battle.spawns(v)
	# 사람은 약한 것부터 고른다 - 머리 위 레벨을 보고.
	list.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
	_part = "마을"
	# SIM_RUSH=1 - 마을 몬스터는 건너뛰고 길 졸개와 우두머리만 (서두르는 사람).
	if OS.get_environment("SIM_RUSH") != "":
		list = []
	for k in list:
		_fight(String(k[0]), int(k[1]), z)
	_part = "길"
	for k in Battle.road_spawns(v):
		_fight(String(k[0]), int(k[1]), z)
	_part = "방 호위"
	var lair := Battle.lair_spawns(v)
	for i in range(1, lair.size()):
		_fight(String(lair[i][0]), int(lair[i][1]), z)
	_part = "우두머리"
	var b: Array = lair[0]
	_fight(String(b[0]), int(b[1]), z, true)
	_part = ""
	JourneyState.mark_quest("보스:" + v)
	_zone_end(z, String(b[0]))


func _zone_start(v: String) -> Dictionary:
	return {"v": v, "lv0": Battle.level, "t0": t_total, "deaths": 0, "kills": 0,
		"coins0": Gear.coins, "boss_secs": 0.0, "boss_deaths": 0, "boss_lv": 0,
		"ttk": [], "hits_taken": [], "rest0": t_rest, "eat0": eaten, "hp_low": 1.0, "boss_low": 1.0}


func _zone_end(z: Dictionary, boss: String) -> void:
	var ttk: Array = z["ttk"]
	var avg := 0.0
	for s in ttk:
		avg += float(s)
	avg /= maxf(1.0, float(ttk.size()))
	var line := {"eaten": eaten - int(z["eat0"]), "hp_low": z["hp_low"], "zone": z["v"], "lv_in": z["lv0"], "lv_boss": z["boss_lv"], "lv_out": Battle.level,
		"minutes": (t_total - float(z["t0"])) / 60.0, "rest_min": (t_rest - float(z["rest0"])) / 60.0,
		"kills": z["kills"], "deaths": z["deaths"], "avg_kill_secs": avg,
		"boss": boss, "boss_secs": z["boss_secs"], "boss_deaths": z["boss_deaths"],
		"coins_gain": Gear.coins - int(z["coins0"]), "weapon": Gear.name_of(Gear.worn("weapon")),
		"atk": Battle.attack_power(), "hp_max": Battle.hp_max(), "def": Battle.defense()}
	var probe := Field.new_foe(String(Battle.SPAWNS.get(z["v"], [["drop", Battle.level]])[0][0]), Battle.level)
	line["hits_to_fall"] = float(Battle.hp_max()) / maxf(1.0, float(Field._one_hit(probe, 1.0)))
	report.append(line)
	print("   같은 레벨 몬스터에게 %.1f대 맞으면 쓰러진다 · 꿈조각 %d · 공격력 %d · 주 능력치 %d · 치명타 %d퍼센트 x%.2f" % [
		line["hits_to_fall"], Gear.coins, Battle.attack_power(), Battle.main_stat(),
		int(Battle.crit_rate() * 100.0), Battle.crit_mult()])
	print("%-8s LV %2d~%2d (보스 LV%2d vs 나 %2d) %5.1f분 쉼%4.1f · 한마리 %4.1f초 · 보스 %4.0f초(최저 %2d%%) · 쓰러짐 %d(보스 %d) · 먹음 %d · 최저체력 %2d%% · 꿈조각 +%d 강화석 %d · %s" % [
		z["v"], z["lv0"], Battle.level, _boss_lv_of(String(z["v"])), z["boss_lv"], line["minutes"], line["rest_min"],
		avg, z["boss_secs"], int(float(z["boss_low"]) * 100.0), z["deaths"], z["boss_deaths"], line["eaten"], int(float(z["hp_low"]) * 100.0),
		line["coins_gain"], Gear.stones, line["weapon"]])


## 구역 안을 나눠 본다 - 마을·길·방 몬스터 각각 평균 몇 초 (SIM_ZONES 일 때).
var _parts: Dictionary = {}


func _zone_detail() -> void:
	for k in _parts:
		var a: Array = _parts[k]
		var sum := 0.0
		for v in a:
			sum += float(v)
		print("      %s: %d마리 평균 %.1f초 (합 %.0f초)" % [k, a.size(), sum / maxf(1.0, a.size()), sum])
	_parts = {}


func _boss_lv_of(v: String) -> int:
	return Battle.boss_lv(v) if Battle.boss_of(v) != "" else 50


## 싸움 한 판. 걸어가서 ~ 때리고 ~ 맞고 ~ 쓰러뜨린다.
func _fight(kind: String, lv: int, z: Dictionary, boss := false, power := 1.0, tower_n := 0) -> void:
	_rest_before()
	t_total += WALK
	var foe := Field.new_foe(kind, lv, false)
	# 타워 꼭대기의 대마왕처럼 목록 안에 섞여 나오는 우두머리도 보스전으로 센다.
	boss = boss or (bool(foe["boss"]) and power <= 1.0)
	if tower_n > 0:
		Loop.tower_foe(foe, tower_n)
	elif power > 1.0:
		Loop.power_up(foe, power)
	if boss:
		z["boss_lv"] = Battle.level
		_boss_fever0 = Loop.fever_on()
	var t := 0.0
	var foe_t := 0.7          # 첫 덤빔까지 틈 (`Shade.take_hit`)
	var winding := -1.0
	var every := BOSS_EVERY if bool(foe["boss"]) else SHADE_EVERY
	var d0 := deaths
	while int(foe["hp"]) > 0 and t < 600.0:
		t += DT
		Field.tick(DT)
		Loop.tick(DT)
		Field.foe_tick(foe, DT)
		if int(foe["hp"]) <= 0:
			break
		# 내 차례
		if Battle.hp < Battle.hp_max() * 0.35:
			_eat_something()
		var id := _pick_skill(foe)
		if id != "":
			var sk: Dictionary = Battle.SKILLS[id]
			var evs := Field.use(id)
			if not evs.is_empty() and String(sk["type"]) == "attack":
				var res := Field.strike(id, foe)
				Loop.hit(int(res["hits"].size()))
				if float(res.get("stagger", 0.0)) > 0.0:
					foe_t = maxf(foe_t, float(res["stagger"]))
					winding = -1.0
		# 몬스터 차례
		if winding >= 0.0:
			winding -= DT
			if winding < 0.0:
				Field.foe_attack(foe)
				foe_t = every
				z["hp_low"] = minf(float(z["hp_low"]), maxf(0.0, float(Battle.hp) / float(Battle.hp_max())))
				if boss:
					z["boss_low"] = minf(float(z["boss_low"]), maxf(0.0, float(Battle.hp) / float(Battle.hp_max())))
				if Battle.hp <= 0:
					deaths += 1
					z["deaths"] = int(z["deaths"]) + 1
					Field.fall()
		else:
			foe_t -= DT * Field.foe_slow(foe)
			if foe_t <= 0.0:
				winding = WINDUP
	t_total += t
	(z["ttk"] as Array).append(t)
	if boss and OS.get_environment("SIM_BOSSLOG") != "":
		print("      [우두머리 %s] %.0f초 · 약점 %s · 피버로 시작 %s · 무기 %s" % [kind, t,
			Battle.matchup(Battle.skill_elem("tap"), String(foe["elem"])) > 1.01,
			_boss_fever0, Gear.name_of(Gear.worn("weapon"))])
	if _part != "":
		if not _parts.has(_part):
			_parts[_part] = []
		(_parts[_part] as Array).append(t)
	if boss:
		z["boss_secs"] = t
		z["boss_deaths"] = deaths - d0
	z["kills"] = int(z["kills"]) + 1
	Loop.fever_add(Loop.FEVER_BOSS if bool(foe["boss"]) else Loop.FEVER_KILL)
	for ev in Field.defeat(foe):
		if String(ev.get("kind", "")) == "level_up" and bool(ev.get("job_ready", false)):
			Battle.set_job(job)
	_gear_up()


## 가장 센 것부터. 공격 스킬 중 쓸 수 있는 것, 없으면 회복(반 밑일 때), 없으면 [공격].
func _pick_skill(foe: Dictionary) -> String:
	# SIM_TAPONLY=1 - 공격 버튼만 누르는 사람 (체력이 반 밑이면 심호흡은 한다).
	if OS.get_environment("SIM_TAPONLY") != "":
		if Battle.hp < Battle.hp_max() * 0.5 and Field.why_not("breathe") == "":
			return "breathe"
		return "tap" if Field.why_not("tap") == "" else ""
	var best := ""
	var best_v := 0.0
	# 사람이 누를 수 있는 것만 - [공격] + 전투 칸에 든 스킬 (`FightPad.SLOT_MAX`).
	# 모든 스킬을 쓰게 두었더니 칸이 모자라 버튼이 없던 마법사 무지개 한 방을 봇만 썼다.
	for id in ["tap"] + Battle.slot_skills().slice(0, FightPad.SLOT_MAX):
		var sk: Dictionary = Battle.SKILLS[id]
		if Field.why_not(id) != "":
			continue
		var typ := String(sk["type"])
		if typ == "heal":
			if Battle.hp < Battle.hp_max() * 0.5:
				return id
			continue
		if typ != "attack":
			continue
		var v := float(sk["mult"]) * float(sk.get("hits", 1)) * Battle.skill_power(id) \
			* Battle.matchup(Battle.skill_elem(id), String(foe["elem"]))
		if v > best_v:
			best_v = v
			best = id
	return best


func _eat_something() -> void:
	var best := ""
	var best_hp := 0
	for id in JourneyState.bag.keys():
		if JourneyState.count(id) <= 0 or not Catalog.edible(id):
			continue
		var f := Battle.food_effect(id)
		var h := 99999 if bool(f.get("full", false)) else int(f.get("hp", 0))
		if h > best_hp:
			best_hp = h
			best = id
	if best != "":
		if Battle.eat(best) != "":
			eaten += 1
	elif Gear.coins >= 25:
		Gear.buy("b-riceball")
		if Battle.eat("b-riceball") != "":
			eaten += 1


## 싸움 사이 - 반 밑이면 찰 때까지 쉰다 (심호흡 + 저절로 도는 것).
func _rest_before() -> void:
	var guard := 0.0
	while Battle.hp < Battle.hp_max() * 0.6 and guard < 240.0:
		guard += DT
		t_rest += DT
		t_total += DT
		Field.tick(DT)
		if Field.why_not("breathe") == "":
			Field.use("breathe")
	if guard >= 240.0:
		# 4분을 쉬어도 안 차면 먹는다
		_eat_something()


## 사람다운 차례: 이 구역 상점에서 **아직 안 산 더 좋은 것**이 있으면 그 값만큼은 남겨 두고
## 강화한다 - 강화로 꿈조각을 다 녹여 새 단계 장비를 못 사는 일이 없게.
var cur_zone := ""
var _part := ""
var _boss_fever0 := false


func _shop_reserve() -> int:
	var need := 0
	for e in Gear.shop_gear(cur_zone):
		if Gear.worn(String(e["slot"])).is_empty() or Gear.better(e["item"]):
			need = maxi(need, int(e["price"]))
	return need


func _gear_up() -> void:
	for it in Gear.items.duplicate():
		if Gear.better(it):
			Gear.equip(int(it["uid"]))
	if cur_zone != "":
		_shop(cur_zone)
	var w := Gear.worn("weapon")
	while not w.is_empty() and Gear.stones > 0 and int(w.get("plus", 0)) < 10 \
			and Gear.coins - _shop_reserve() >= Gear.plus_cost(w):
		Gear.enhance(int(w["uid"]))
		w = Gear.worn("weapon")
	Gear.sell_junk(1)
