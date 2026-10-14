extends Node
## 꿈결 키우기 곡선 시뮬레이션 (`docs/redesign-idle.md`).
## 봇: 자동 전투를 그대로 돌리고, 꿈조각은 가장 이득인 칸에 쓴다 (강화). 우두머리에 지면 몇 번 파밍한 뒤 다시 도전.
## 환경변수: SIM_JOB(직업) SIM_SEED SIM_STAGES(몇 스테이지까지) SIM_LOG=1(구역마다 줄)

var job := "warrior"
var secs := 0.0
var deaths := 0
var farm_clears := 0
var zone_first: Dictionary = {}


func _ready() -> void:
	if OS.get_environment("SIM_JOB") != "":
		job = OS.get_environment("SIM_JOB")
	var seed_v := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	var goal := int(OS.get_environment("SIM_STAGES")) if OS.get_environment("SIM_STAGES") != "" else 100
	IdleState.reset()
	var f := IdleFight.new()
	var guard := 0
	print("\n==== 꿈결 키우기 시뮬레이션: %s ====" % job)
	while IdleState.best <= goal and guard < 200000:
		guard += 1
		if IdleState.can_pick_job() and IdleState.job == "novice" and job != "novice":
			IdleState.set_job(job)
		_spend()
		f.start(IdleState.stage, seed_v + guard)
		while not f.done:
			f.tick(0.5)
			secs += 0.5
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
					_log("%s 우두머리" % String(info["zone_name"]), IdleState.stage - 1)
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
	print("끝: %.1f시간 · 스테이지 %d · LV %d · 쓰러짐 %d · 전투력 %d · 꿈조각 %d" % [
		secs / 3600.0, IdleState.best, IdleState.level, deaths, IdleState.power(), IdleState.coins])
	print("장비: %s" % str(IdleState.gear))
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


## 가장 싸게 가장 크게 오르는 칸에 계속 쓴다.
func _spend() -> void:
	var guard := 0
	while guard < 500:
		guard += 1
		var best_slot := ""
		var best_v := 0.0
		var p0 := float(IdleState.power())
		for s in IdleData.SLOTS:
			if not IdleState.can_enhance(String(s)):
				continue
			var g: Array = IdleState.gear[s]
			var gain := IdleData.slot_value(String(s), int(g[0]), int(g[1]) + 1) - IdleData.slot_value(String(s), int(g[0]), int(g[1]))
			var w := 4.0 if String(IdleData.SLOT_STAT[s]) == "atk" else (1.0 if String(IdleData.SLOT_STAT[s]) == "hp" else 6.0)
			var v := gain * w / float(IdleState.enhance_cost_of(String(s)))
			if v > best_v:
				best_v = v
				best_slot = String(s)
		if best_slot == "":
			return
		IdleState.enhance(best_slot)
