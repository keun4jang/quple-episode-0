extends Node
## 꿈결 키우기 곡선 시뮬레이션 (`docs/redesign-idle.md`).
## 봇: 자동 전투를 그대로 돌리고, 꿈조각은 가장 이득인 칸에 쓴다 (강화). 우두머리에 지면 몇 번 파밍한 뒤 다시 도전.
## 환경변수: SIM_JOB(직업) SIM_SEED SIM_STAGES(몇 스테이지까지) SIM_LOG=1(구역마다 줄)

var job := "warrior"
var secs := 0.0
var deaths := 0
var farm_clears := 0
var zone_first: Dictionary = {}
var auto_at := -1.0
var trains := 0
## 몇 초마다 한 번만 꿈조각을 쓰나 (가끔 들여다보는 사람). 0 이면 매번.
var spend_every := 0.0
var _last_spend := -99999.0
## 레벨 5 전에 톡톡 치지 않는 사람.
var no_tap := false
## 우두머리를 처음 깬 판이 몇 초 걸렸나 (한 판 길이 확인용).
var boss_secs: Array = []


func _ready() -> void:
	if OS.get_environment("SIM_JOB") != "":
		job = OS.get_environment("SIM_JOB")
	var seed_v := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	var goal := int(OS.get_environment("SIM_STAGES")) if OS.get_environment("SIM_STAGES") != "" else 100
	spend_every = float(OS.get_environment("SIM_SPEND_EVERY")) if OS.get_environment("SIM_SPEND_EVERY") != "" else 0.0
	no_tap = OS.get_environment("SIM_NO_TAP") != ""
	IdleState.reset()
	var f := IdleFight.new()
	var guard := 0
	print("\n==== 꿈결 키우기 시뮬레이션: %s ====" % job)
	while IdleState.best <= goal and guard < 200000:
		guard += 1
		if auto_at < 0.0 and IdleState.can_auto():
			auto_at = secs
		if IdleState.can_pick_job() and IdleState.job == "novice" and job != "novice":
			IdleState.set_job(job)
		if secs - _last_spend >= spend_every:
			_spend()
			_last_spend = secs
		f.start(IdleState.stage, seed_v + guard)
		while not f.done:
			if IdleState.auto_active():
				f.tick(0.5)
				secs += 0.5
			else:
				# 레벨 5 전: 사람이 초에 세 번쯤 톡톡 친다
				f.tick(0.33)
				secs += 0.33
				if not no_tap:
					f.tap()
			if secs > 60.0 * 60.0 * 40.0:
				break
		if secs > 60.0 * 60.0 * 40.0:
			print("   [중단] 40시간 넘음 - 스테이지 %d 에서 막힘" % IdleState.stage)
			break
		if f.result == "clear":
			var was_best := IdleState.stage >= IdleState.best
			var r := IdleState.on_clear()
			if not was_best:
				farm_clears += 1
			if bool(r["new_best"]):
				var info := IdleData.stage_info(IdleState.stage - 1)
				if bool(info["boss"]):
					boss_secs.append(f.time)
					_log("%s 우두머리 (%.0f초)" % [String(info["zone_name"]), f.time], IdleState.stage - 1)
		else:
			deaths += 1
			IdleState.on_defeat()
		# 파밍 중이면 몇 번 모은 뒤 도전
		if IdleState.boss_failed and farm_clears >= 3:
			IdleState.challenge_boss()
			farm_clears = 0
		elif IdleState.stage < IdleState.best and not IdleState.boss_failed:
			# 졌지만 우두머리 앞이 아니면 곧장 앞으로
			IdleState.stage = IdleState.best
	print("자동사냥 열린 때: %.1f분" % (auto_at / 60.0))
	print("끝: %.1f시간 · 스테이지 %d · LV %d · 쓰러짐 %d · 전투력 %d · 꿈조각 %d" % [
		secs / 3600.0, IdleState.best, IdleState.level, deaths, IdleState.power(), IdleState.coins])
	if not boss_secs.is_empty():
		var lo := 9999.0
		var hi := 0.0
		var sum := 0.0
		for b in boss_secs:
			lo = minf(lo, float(b))
			hi = maxf(hi, float(b))
			sum += float(b)
		print("우두머리 한 판: 평균 %.0f초 · 가장 짧게 %.0f초 · 가장 길게 %.0f초" % [sum / boss_secs.size(), lo, hi])
	print("장비: %s" % str(IdleState.gear))
	print("수련: %s (%d번)" % [str(IdleState.train), trains])
	get_tree().quit()


func _log(label: String, st: int) -> void:
	if OS.get_environment("SIM_LOG") == "":
		return
	var g := IdleState.gear
	print("  %-10s %5.2f시간 · LV %2d · 쓰러짐 %3d · 전투력 %5d · 강화 합 %d" % [label, secs / 3600.0,
		IdleState.level, deaths, IdleState.power(), _plus_sum()])


func _plus_sum() -> int:
	var s := 0
	for k in IdleData.SLOTS:
		s += int(IdleState.gear[k][1])
	return s


## 꿈조각 하나당 전투력이 가장 많이 오르는 곳(장비 강화 또는 수련)에 계속 쓴다.
func _spend() -> void:
	var guard := 0
	while guard < 2000:
		guard += 1
		var p0 := float(IdleState.power())
		var pick := ""
		var best_v := 0.0
		for s in IdleData.SLOTS:
			if not IdleState.can_enhance(String(s)):
				continue
			var g: Array = IdleState.gear[s]
			g[1] = int(g[1]) + 1
			var v := (float(IdleState.power()) - p0) / float(IdleData.enhance_cost(int(g[0]), int(g[1]) - 1))
			g[1] = int(g[1]) - 1
			if v > best_v:
				best_v = v
				pick = "g:" + String(s)
		for t in IdleData.TRAIN_STATS:
			if not IdleState.can_train(String(t)):
				continue
			var cost := IdleState.train_cost_of(String(t))
			IdleState.train[t] = int(IdleState.train[t]) + 1
			var v2 := (float(IdleState.power()) - p0) / float(cost)
			IdleState.train[t] = int(IdleState.train[t]) - 1
			if v2 > best_v:
				best_v = v2
				pick = "t:" + String(t)
		if pick == "":
			return
		if pick.begins_with("g:"):
			IdleState.enhance(pick.substr(2))
		else:
			IdleState.do_train(pick.substr(2))
			trains += 1
