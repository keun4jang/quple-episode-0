extends Node
## 쿼카 군단 곡선 시뮬레이션. 봇: 자동 소환으로 싸우고, 판 사이에 꿈조각으로 레벨을 올린다(가장 싼 것부터).
## 지면 같은 판을 다시 (진 판도 꿈조각 조금). 환경변수: SIM_STAGES, SIM_SEED, SIM_LOG=1, SIM_SPEED(판 시간 배속 표시용)
var secs := 0.0
var losses := 0
var tries := 0

func _ready() -> void:
	var goal := int(OS.get_environment("SIM_STAGES")) if OS.get_environment("SIM_STAGES") != "" else 100
	var seed_v := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	LaneState.reset()
	var b := LaneBattle.new()
	var stuck := 0
	print("\n==== 쿼카 군단 시뮬레이션 ====")
	while LaneState.cleared < goal and tries < 4000:
		tries += 1
		_spend()
		var n := LaneState.cleared + 1
		b.start(n, seed_v + tries)
		b.auto = true
		var t := 0.0
		while not b.done and t < 600.0:
			b.tick(0.25)
			t += 0.25
		secs += t + 8.0   # 판 사이 쉬는 시간
		if b.result == "win":
			var r := LaneState.on_win(n)
			stuck = 0
			if OS.get_environment("SIM_LOG") != "" and (n % 10 == 0 or n <= 3):
				print("  %-12s %5.2f시간 · 판 %4.0f초 · 진 판 %3d · 레벨 %s" % [LaneData.stage_label(n), secs / 3600.0, t,
					losses, _lv()])
			if not (r["new_units"] as Array).is_empty() and OS.get_environment("SIM_LOG") != "":
				print("      새 쿼카: ", r["new_units"])
		else:
			losses += 1
			stuck += 1
			LaneState.xp += int(LaneData.reward(n, false)["xp"]) / 3
			# 앞 판을 돌아 꿈조각을 모은다
			if n > 1:
				var b2 := LaneBattle.new()
				b2.start(n - 1, seed_v + tries + 999)
				b2.auto = true
				var t2 := 0.0
				while not b2.done and t2 < 600.0:
					b2.tick(0.25)
					t2 += 0.25
				secs += t2 + 8.0
				if b2.result == "win":
					LaneState.on_win(n - 1)
			if stuck > 60:
				print("  [막힘] %s 에서 60번 짐 (%s)" % [LaneData.stage_label(n), "판 %.0f초 %s" % [t, b.result if b.result != "" else "시간 초과"]])
				break
	print("끝: %.1f시간 · 깬 곳 %d · 진 판 %d · 꿈조각 %d · 레벨 %s" % [secs / 3600.0, LaneState.cleared, losses, LaneState.xp, _lv()])
	get_tree().quit()


func _lv() -> String:
	var s := ""
	for id in LaneData.UNIT_ORDER:
		if LaneState.has_unit(id):
			s += "%s%d " % [String(id).substr(0, 2), LaneState.level_of(id)]
	return s


func _spend() -> void:
	var guard := 0
	while guard < 500:
		guard += 1
		var best := ""
		var cost := 0
		for id in LaneState.units.keys():
			if LaneState.can_level(String(id)):
				# 가장 낮은 레벨부터 (같으면 싼 것) - 사람처럼 고르게 올린다
				var c := LaneState.level_of(String(id)) * 100000 + LaneData.level_cost(String(id), LaneState.level_of(String(id)))
				if best == "" or c < cost:
					best = String(id)
					cost = c
		if best == "":
			return
		LaneState.level_up(best)
