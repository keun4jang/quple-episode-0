extends Node
## 쿼카 군단 곡선 시뮬레이션. 봇: 자동 소환으로 싸우고, 판 사이에 꿈조각으로 레벨을 올린다(가장 싼 것부터).
## 지면 같은 판을 다시 (진 판도 꿈조각 조금). SIM_GACHA=1 이면 뽑기도 하고(하루 1.5시간 놀아 매일 선물), 센 편성을 고른다.
## 환경변수: SIM_STAGES, SIM_SEED, SIM_LOG=1, SIM_SPEED(판 시간 배속 표시용)
var secs := 0.0
var losses := 0
var tries := 0
var gacha := false
var rng := RandomNumberGenerator.new()
var days := 0
var pulled := 0

func _ready() -> void:
	var goal := int(OS.get_environment("SIM_STAGES")) if OS.get_environment("SIM_STAGES") != "" else 100
	var seed_v := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	LaneState.reset()
	gacha = OS.get_environment("SIM_GACHA") == "1"
	rng.seed = seed_v
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
	if gacha:
		print("뽑기 %d번 · 가진 친구 %d / %d" % [pulled, LaneState.owned_count(), LaneData.ALL_ORDER.size()])
	print("끝: %.1f시간 · 깬 곳 %d · 진 판 %d · 꿈조각 %d · 레벨 %s" % [secs / 3600.0, LaneState.cleared, losses, LaneState.xp, _lv()])
	get_tree().quit()


func _lv() -> String:
	var s := ""
	for id in LaneData.UNIT_ORDER:
		if LaneState.has_unit(id):
			s += "%s%d " % [String(id).substr(0, 2), LaneState.level_of(id)]
	return s


func _spend() -> void:
	if gacha:
		while days < int(secs / 5400.0):
			days += 1
			LaneState.daily_day = 0
			LaneState.claim_daily(days * 86400)
		while LaneState.can_pull(1):
			var cnt := 10 if LaneState.tickets == 0 and LaneState.can_pull(10) else 1
			var res := LaneState.pull(cnt, rng)
			pulled += res.size()
			for x in res:
				if bool(x["new"]) and OS.get_environment("SIM_LOG") != "":
					print("      뽑기 (%4.1f시간): %s %s" % [secs / 3600.0, LaneData.RARITY_NAME[String(x["rarity"])], x["id"]])
		_pick_lineup()
	var guard := 0
	while guard < 500:
		guard += 1
		var best := ""
		var cost := 0
		for id in (LaneState.lineup if gacha else LaneState.units.keys()):
			if LaneState.can_level(String(id)):
				# 가장 낮은 레벨부터 (같으면 싼 것) - 사람처럼 고르게 올린다
				var c := LaneState.level_of(String(id)) * 100000 + LaneData.level_cost(String(id), LaneState.level_of(String(id)))
				if best == "" or c < cost:
					best = String(id)
					cost = c
		if best == "":
			return
		LaneState.level_up(best)


## 센 편성: 싼 벽 + 튼튼한 벽 + 나머지는 비싼(센) 것부터.
func _pick_lineup() -> void:
	var walls: Array = []
	var hitters: Array = []
	for id in LaneState.units.keys():
		(walls if LaneData.is_wall(String(id)) else hitters).append(String(id))
	walls.sort_custom(func(a, b) -> bool: return int(LaneData.UNITS[a]["cost"]) < int(LaneData.UNITS[b]["cost"]))
	# 센(비싼) 것부터
	hitters.sort_custom(func(a, b) -> bool: return int(LaneData.UNITS[a]["cost"]) > int(LaneData.UNITS[b]["cost"]))
	var l: Array = []
	if walls.size() > 0:
		l.append(walls[0])
	if walls.size() > 1:
		var tough: String = walls[0]
		for w in walls:
			if float(LaneData.UNITS[w]["hp"]) > float(LaneData.UNITS[tough]["hp"]):
				tough = w
		if tough != walls[0]:
			l.append(tough)
	for h in hitters:
		if l.size() >= LaneData.LINEUP_MAX:
			break
		l.append(h)
	LaneState.lineup = l
